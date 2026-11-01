# Accounting Backbone Progress Tracker

**Branch:** `feat/accounting-backbone`  
**Base Commit (main):** `993f9c364ab1e582dca0de142d0e0b7491c16d34`  
**Baseline Test Discovery:** 77 test files (discovered)  
**User Directive:** "skip tests for now" — full suite run deferred; focused targeted tests and analyzer checks executed per phase.  

---

## Phase Status Summary

| Phase | Description | Status | Commit SHA | Evidence / Key Artifacts |
|:---|:---|:---|:---|:---|
| **P0** | Read & Design (No Code) | COMPLETED | `2c2648a5ad` | `docs/accounting_backbone_design.md`, `docs/accounting_spec_addendum.md` |
| **P1** | Foundation: Schema, Migration, Models, PostingService & JournalWriter | COMPLETED | `6b044d4bfe` | Schema v25, models, `PostingService`, `JournalWriter`, `BackupService`, 4 test files (13 tests pass) |
| **P2** | Single Stock Writer & Routing | COMPLETED | `3a18306` | `StockLedger.record` authoritative routing, `single_stock_writer_guard_test.dart` (5/5), legacy suites (41/41) |
| **P3** | Shadow Posting & Parity Test Suite | COMPLETED | `37fb6b7` | Shadow posting wired in `DatabaseHelper` across all business events, `journal_parity_test.dart` (11/11 passed) |
| **P4** | Backfill & Parity on Existing Data | COMPLETED | `48b4e2b` | `JournalBackfillService` idempotent engine, `DatabaseHelper` onOpen & `BackupService` legacy restore hooks, `journal_backfill_test.dart` (4/4 passed) |
| **P5** | Report Switch Behind Flag & Diagnostics UI | COMPLETED | Pending commit | `LedgerService` switch behind `journal_reports_enabled`, `DatabaseDiagnosticScreen` accounting books card & backfill trigger, `journal_report_switch_test.dart` (2/2 passed) |
| **P6** | Reason-Coded Adjustments & Period Lock | IN PROGRESS | — | — |
| **P7** | Reconciliation Engine | NOT STARTED | — | — |
| **P8** | Guards & Hard Invariants (INV-14..INV-18) | NOT STARTED | — | — |
| **P9** | Final Verification, Mutation Checks, Reports | NOT STARTED | — | — |

---

## Current Step
Completed P5. Committing P5, then starting Phase P6 (Reason-Coded Adjustments & Period Lock).
