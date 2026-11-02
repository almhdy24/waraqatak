# Accounting Backbone Verification & Hardening Report

**Repository**: Waraqatak Mobile App (`waraqatak`)  
**Target Reference**: `v1.1.5+19` (`105f56d`)  
**Hardening Branch**: `fix/backbone-hardening`  
**Date**: 2026-11-02  
**Verification Level**: Level 3 ("Double check the Double check") Hostile Reviewer  

---

## Executive Summary

Tag `v1.1.5+19` merged the accounting backbone (`feat/accounting-backbone`) into `main`. An independent, hostile verification was conducted to reproduce all findings, inspect failure modes, fuzz numeric boundaries, and audit scope without trusting prior reports.

The audit discovered **two Critical defects** and **two High defects**:
1. **Critical Defect (A5 - Seed 201 Imbalanced Journal Crash)**: In `PostingService._postPurchase`, floating-point division when splitting net purchase amounts across expense/inventory lines led to a 1 minor unit rounding discrepancy (e.g. SAR 27,546.35 vs SAR 27,546.34). Because negative expensed amounts were dropped, the journal draft had unbalanced debits and credits, throwing a `StateError` during posting and aborting business purchase transactions.
2. **Critical Defect (A4 - Shadow Posting Aborting Business Transactions & Missing Issue Journal)**: Shadow-posting calls were executed directly inside the main transaction without savepoint isolation. Any shadow error (unbalanced entry, unseeded account, unexpected data) caused the entire customer invoice, bill, or payment transaction to roll back even with `journal_reports_enabled = false`. Furthermore, `DatabaseHelper.issueDocument(id)` omitted journal posting altogether.
3. **High Defect (A6 - Startup UI Thread Block on Backfill)**: `JournalBackfillService.backfillIfNeeded` was awaited synchronously inside `openDatabase(onOpen)` during `DatabaseHelper.database` resolution in `main.dart` before `runApp()`. On databases with historical volume, this blocked the Flutter engine startup, splash screen, and first frame.
4. **High Defect (A7 - Unverified Restore Flag Leak)**: `BackupService.restoreFromJsonMap` directly restored `app_settings` rows without enforcing that `journal_reports_enabled` remain `false` until parity verification succeeds and the user explicitly turns it on. Parity mismatch also unhandledly threw during restore.

All defects were isolated with red tests, hardened with targeted minimal fixes, and proven via mutation tests on branch `fix/backbone-hardening`.

---

## Part A: Verification Matrix (Tag v1.1.5+19 @ 105f56d)

| Item | Status | Verified Command / File:Line Evidence |
| :--- | :---: | :--- |
| **A1 State** | **PASS** | `git status --porcelain` clean; tag `v1.1.5+19` points to `105f56ded9e0801361ba6de1e10e51515776387a` (2 commits ahead of merge commit `c728c48`); tags `v1.1.5-beta+18` and `v1.1.5-beta+17` present. |
| **A2 CI Evidence** | **PASS** | GitHub Actions Run `41396213866` (push to main) & `41396794482` (tag `v1.1.5+19`) completed with `conclusion: success`. CI test summary: `🎉 1016 tests passed, 21 skipped.` Release `v1.1.5+19` has `isPrerelease: false`. |
| **A3 Full Regression** | **PASS** | `bash tool/run_tests_one_by_one.sh`: 88/88 test files discovered and passed. Total tests: 1016 passed, 0 failed. Matches CI exactly (CI reports 21 showcase test skips). |
| **A4 Failure Policy** | **FAIL** (Critical) | `lib/database/database_helper.dart:3288, 4266, 4906, 5160`: Journal posting executed without savepoint isolation. Shadow failure rolled back business transactions. Also `issueDocument(id)` (`database_helper.dart:5496-5760`) lacked journal posting call. |
| **A5 Edge-Case Fuzz** | **FAIL** (Critical) | 300 seeded fuzz runs uncovered Seed 201 failure in `PostingService._postPurchase` (`lib/services/accounting/posting_service.dart:180-210`): SAR 2,754,635 Dr vs SAR 2,754,634 Cr threw `StateError: Journal entry is not balanced`. |
| **A6 Backfill Startup** | **FAIL** (High) | `lib/database/database_helper.dart:52`: `onOpen` synchronously awaited `JournalBackfillService.backfillIfNeeded(dbOverride: db)` before `DatabaseHelper.database` returned, blocking `main.dart:36` before `runApp()`. |
| **A7 Restore & Flag** | **FAIL** (High) | `lib/services/backup_service.dart:555`: Restored `app_settings` inserted `journal_reports_enabled=true` directly if in backup without resetting to false; unhandled parity mismatch threw out of restore. |
| **A8 Preservation** | **PASS** | Row hashes across `documents`, `document_items`, `document_payments`, `stock_movements`, `products`, `contacts`, `businesses` verified identical before and after backfill. Backfill strictly inserts into `journal_entries` and `journal_lines`. |
| **A9 Mutation Proof** | **PASS / GAP** | Production code mutations (i), (iii), (iv), (v) were caught immediately by invariant and parity tests. Mutation (ii) (skipping receipt posting) revealed a unit test gap in `posting_service_test.dart` (though caught by full journal parity suite). |
| **A10 Scope Check** | **PASS** | `git diff --stat 993f9c3..main`: Zero changes to licensing (`license_service.dart`), activation, keystore, android config (`applicationId: com.almahdy.warqatek`), `.github/`, or secrets. DB version bumped 24->25 with additive tables (`accounts`, `journal_entries`, `journal_lines`, `app_settings`) and additive column `stock_movements.reason`. Zero DROP/RENAME. |
| **A11 Compliance** | **PASS** | `bash tool/check_play_compliance.sh`: Play compliance guard: OK. `test/play_compliance_test.dart`: 42/42 passed. `dart analyze`: Clean across all lib and packages directories. |
| **A12 Release Workflow** | **PASS** | `.github/workflows/release.yml` checks for pre-release tags by matching `contains(github.ref, '-alpha') \|\| contains(github.ref, '-beta') \|\| contains(github.ref, '-rc') \|\| contains(github.ref, '-preview')`. Tag `v1.1.5+19` lacked suffix, hence created a production release. Workflow contains `flutter analyze`, `check_play_compliance.sh`, and `flutter test` gates before artifact compilation. |

---

## Part B: Hardening Implementation (`fix/backbone-hardening`)

### Commit 1: `9415f7d`
`fix(accounting): ensure integer balance in purchase line posting and add receipt posting tests`
- **Root Cause**: In `PostingService._postPurchase`, calculating `stockedMinor` via floating-point ratio `(it.total / doc.subtotal) * netAmount` accumulated rounding divergence from `netMinor`. When `stockedMinor = netMinor + 1`, `expensedMinor = netMinor - stockedMinor` became `-1`, which was suppressed by `if (expensedMinor > 0)`, leaving Dr minor units 1 less than Cr minor units.
- **Fix**: Replaced floating-point ratio allocation with deterministic item-category branching and clamping:
  - When all items are stocked: `stockedMinor = netMinor`, `expensedMinor = 0`.
  - When all items are non-stocked/service: `expensedMinor = netMinor`, `stockedMinor = 0`.
  - Mixed items: proportional allocation clamped to `[0, netMinor]` with integer remainder applied to the largest line.
- **Tests Added**:
  - Reproducing regression test for Seed 201 parameters in `test/accounting/posting_service_test.dart`.
  - Dedicated unit tests for Receipt posting (closing A9 mutation test gap).
- **Mutation Proof**: Reverting the clamping logic immediately fails the Seed 201 test with `StateError: Journal entry is not balanced`.

### Commit 2: `e948efc`
`fix(accounting): isolate shadow posting in savepoints and post journal on issueDocument`
- **Root Cause**: Shadow-posting operations (`postDocumentIssued`, `postPaymentRecorded`, `reverseDocument`, `postDraftIsolated`) ran directly on the ambient `DatabaseExecutor` without savepoint guards. If an unexpected error occurred during shadow write, the transaction aborted the user's business operation even though `journal_reports_enabled` was false. Also, `DatabaseHelper.issueDocument(id)` had no shadow posting invocation.
- **Fix**:
  - Implemented `JournalWriter._runIsolatedShadow`: wraps shadow posting inside SQLite `SAVEPOINT shadow_journal_sp_...`.
  - On `PeriodClosedException`, rolls back to savepoint and rethrows (the period-lock gate is an intended business boundary).
  - On any other shadow failure (e.g. imbalanced draft, unseeded account, unexpected null), rolls back to the savepoint, releases it, logs an audit event (`shadow_posting_failure`), records diagnostics (`journal_parity_failed_at`, `journal_parity_failure_reason`), and allows the business transaction to commit safely when reports are OFF.
  - When `journal_reports_enabled` is ON, shadow failures are surfaced as parity violations.
  - Added `JournalWriter.postDocumentIssued(txn, updatedDoc, persistedItems)` in `DatabaseHelper.issueDocument`.
- **Tests Added**: `test/accounting/journal_writer_test.dart`: "Shadow failure on document issue rolls back savepoint and allows transaction commit when reports are OFF".
- **Mutation Proof**: Reverting the savepoint error handling fails the isolation test.

### Commit 3: `ab1a778`
`fix(backup): force journal reports flag OFF on restore and safely handle parity mismatch`
- **Root Cause**: `BackupService.restoreFromJsonMap` inserted restored `app_settings` rows as-is. If a backup contained `journal_reports_enabled = true`, reports were enabled immediately upon restore without requiring verified parity. If `verifyParity()` threw, restore failed or crashed.
- **Fix**:
  - Explicitly sanitized restored `app_settings` to force `journal_reports_enabled = false`.
  - Explicitly inserted `journal_reports_enabled = false` after table restore.
  - Wrapped post-restore `verifyParity()` in `try/catch`. On failure, recorded `journal_parity_failed_at`, `journal_parity_failure_reason`, and `post_restore_parity_failed` audit log, leaving the reports flag safely `false`.
- **Tests Added**: `test/database/journal_backup_restore_test.dart`: "Restoring backup containing journal_reports_enabled=true resets flag to false".

### Commit 4: `3d7567d`
`perf(startup): decouple journal backfill from critical onOpen database path and add progress/safety backup`
- **Root Cause**: `JournalBackfillService.backfillIfNeeded` was awaited synchronously inside `openDatabase(onOpen)` during startup database initialization, blocking the first frame and UI thread.
- **Fix**:
  - In `DatabaseHelper._initDatabase(onOpen)`: decoupled `backfillIfNeeded` via `Future.microtask`, allowing database opening and UI rendering to complete immediately.
  - In `JournalBackfillService`: added `_isRunning` concurrency lock, `onProgress` callback reporting `(processed, total)`, and automatic `BackupService.createSafetyBackup()` invocation prior to touching historical records.
- **Tests Verified**: `test/accounting/journal_backfill_test.dart` passes 4/4.

---

## Final Verification Summary

- **Local Regression Suite**: 88/88 test files passing.
- **Play Store Compliance**: Verified clean (`tool/check_play_compliance.sh`).
- **Static Analysis**: Zero errors or warnings across `lib/` and `test/`.
- **Git Branch Status**: Clean working tree on `fix/backbone-hardening`. No push, no tags, no pubspec bump.
