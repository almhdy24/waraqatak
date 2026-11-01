# Accounting & Single-Currency Audit Final Report

## Executive Summary
This report summarizes the comprehensive audit, refactoring, and verification performed on the Waraqatak application repository (`./waraqatak`) under branch `feat/single-currency-accounting-audit`.

All six phases have been completed with zero regressions:
1. **Phase 0:** CI failure root-caused and resolved in `AppAmountText` and `CustomerDetailScreen` with canonical accessibility semantics. Resumable one-by-one test runner created.
2. **Phase 1:** In-depth audit of currency architecture, money mathematics, accounting models, and data integrity. Created `docs/accounting_audit.md` and `docs/accounting_spec.md`.
3. **Phase 2:** Reference oracle and invariant harness developed in `test/accounting/` (money oracle, cross-layer consistency, accounting identities, edge cases).
4. **Phase 3:** Complete transition to single base currency (`businesses.currency_code`, permanently locked upon first transaction). UI currency selectors removed; reports and period summaries segregated to protect base-currency totals from legacy non-base currency mixing. Zero schema drops, zero destructive updates, zero deleted tests.
5. **Phase 4:** Fixed proven defect BUG-01 (`DocumentItemInput` decimalDigits precision scaling). Skipped BUG-03 and BUG-05 per historical-number preservation rules, logged in `docs/accounting_skipped.md` and `docs/accounting_decisions.md`.
6. **Phase 5:** Implemented 8 structural and runtime guards in `test/guards/single_currency_guard_test.dart`, enforcing architectural isolation, test preservation, and database rejection of foreign currency. Mutation verified.
7. **Phase 6:** Full-suite verification executed one-by-one across all 68 test files with 901 tests passing (0 failures, 0 skips). Static analysis (`dart analyze lib test`) clean (0 issues). Play compliance guard verified OK.

---

## 1. Test Execution & Verification Evidence

### One-by-One Test Suite Execution
- **Command:** `bash tool/run_tests_one_by_one.sh`
- **Discovered Test Files:** 68
- **Executed Files:** 68
- **Passed Files:** 68
- **Failed Files:** 0
- **Total Tests Passed:** 901
- **Total Tests Failed:** 0
- **Total Tests Skipped:** 0

### Test Count Reconciliation
- Baseline in CI (`v1.1.5-beta+16`): 871 executed tests (870 passed + 1 failed `multi_currency_phase1_test:542`).
- Phase 0 additions: +10 tests in `test/widgets/app_amount_text_test.dart` (Total = 881 passed).
- Phase 2 additions: +12 tests across 4 suites in `test/accounting/` (identities: 1, consistency: 1, edge cases: 5, money oracle: 5; Total = 893 passed).
- Phase 5 additions: +8 tests in `test/guards/single_currency_guard_test.dart` (Total = 901 passed).
- Final count: 901 tests executed and passed. Zero missing files.

### Static Analysis
- **Command:** `dart analyze lib test`
- **Output:**
  ```text
  Analyzing lib, test...
  No issues found!
  ```
- **Exit Code:** 0

### Google Play Compliance Guard
- **Command:** `bash tool/check_play_compliance.sh`
- **Output:**
  ```text
  Play compliance guard: OK
  ```
- **Exit Code:** 0
- Confirms zero digital goods / Play billing vocabulary introduced, zero Pro acquisition copy or URLs in reviewer-facing screens, and strict adherence to URL allowlists.

---

## 2. Defects Addressed & Historical-Number Rules

| Defect ID | Severity | File & Location | Resolution | Evidence |
|---|---|---|---|---|
| **CI Failure** | Critical | `lib/widgets/app_amount_text.dart`, `lib/screens/customer_detail_screen.dart:464` | Restored decimal precision formatting (`fmt.maximumFractionDigits`) and wrapped `Row` in unified `Semantics(container: true, label: resolvedSemantics, excludeSemantics: true)`. | `test/widgets/app_amount_text_test.dart` (10/10 PASS), `test/services/multi_currency_phase1_test.dart` (5/5 PASS) |
| **BUG-01** | High | `lib/services/document_service.dart:184` | Added optional `decimalDigits` to `DocumentItemInput` and `calculateTotal([int? digits]) => MoneyUtils.round(quantity * price, digits ?? decimalDigits ?? 2)`. | Red test in `test/accounting/money_oracle_test.dart` failed before fix (`333.3 != 333.0`), passed after fix (`333.0 == 333.0`). Mutation verified. |
| **BUG-02** | Medium | `lib/services/currency_service.dart`, `lib/screens/reports/*` | Segregated period summary and financial reports so legacy foreign currency records do not nominally sum into base currency totals. | `DatabaseHelper.getPeriodSummary` tested in `single_currency_guard_test.dart:Guard 8` (PASS). |
| **BUG-03** | Low | `lib/services/accounting/ledger.dart:421` | **Skipped** per historical-number rule to prevent mutating derived historical cost of sales for existing stored transactions. Logged in `docs/accounting_skipped.md`. | - |
| **BUG-04** | Low | UI screens | Resolved by removing currency dropdown pickers from accounting screen and customer statement dialog. Enforced by Guard 1. | `single_currency_guard_test.dart:Guard 1` (PASS). Mutation verified. |
| **BUG-05** | Low | `lib/services/database_diagnostic_service.dart` | **Skipped** per historical-number rule as SQLite `ON DELETE CASCADE` guarantees payment referential integrity at the engine level. Logged in `docs/accounting_skipped.md`. | - |

---

## 3. Structural Guards Implemented (`test/guards/single_currency_guard_test.dart`)

1. **Guard 1 (Static UI Scan):** Enforces that no currency dropdown, picker, or `Currency.supportedCurrencies` reference exists in `lib/screens/` or `lib/widgets/` outside `lib/screens/business_setup_screen.dart`.
2. **Guard 2 (Direct SQL Bypass Guard):** Enforces that UI screens never issue raw `insert` or `update` SQL statements against the `documents` table directly.
3. **Guard 3 (Authoritative Context Guard):** Verifies that `CurrencyContext` correctly fetches and validates base currency against active business records.
4. **Guard 4 (Test Preservation Guard):** Verifies that all mapped tests from `docs/single_currency_design.md` remain intact and active across test files.
5. **Guard 5 (Database Insertion Guard):** Verifies `DatabaseHelper.insertDocumentWithItems` throws `ArgumentError` when a foreign currency document is supplied.
6. **Guard 6 (Database Issuance Guard):** Verifies `DatabaseHelper.issueDocument` throws `ArgumentError` when attempting to issue a draft with foreign currency.
7. **Guard 7 (Database Duplication Guard):** Verifies `DatabaseHelper.copyDocumentWithItems` throws `StateError` when attempting to duplicate a legacy foreign-currency invoice.
8. **Guard 8 (Period Summary Segregation Guard):** Verifies `DatabaseHelper.getPeriodSummary` segregates historical foreign-currency records into `totalsByCurrency` and never contaminates scalar base currency metrics.

---

## 4. Mutation Verification Evidence

### Mutation 1: BUG-01 Precision Scaling
- **Action:** Reverted `decimalDigits` propagation in `DocumentItemInput.calculateTotal` to hardcoded 2 decimals.
- **Result:** `test/accounting/money_oracle_test.dart` failed with `Expected: <333.0>, Actual: <333.3>`.
- **Restoration:** Restored `digits ?? decimalDigits ?? 2`.
- **Result:** Test passed cleanly (5/5).

### Mutation 2: Guard 1 Static Scanner
- **Action:** Removed `lib/screens/business_setup_screen.dart` from the allowlist in `test/guards/single_currency_guard_test.dart`.
- **Result:** Guard test failed with `Actual: ['lib/screens/business_setup_screen.dart: contains currency picker/selector']`.
- **Restoration:** Restored allowlist.
- **Result:** Test passed cleanly (8/8).

---

## 5. Scope & Limitations (What Could Not Be Verified Locally)
Due to running in a headless Termux Linux CLI environment:
1. **Real Physical Hardware:** Execution was verified in a headless Linux environment; physical Android device hardware execution (touch responsiveness, screen transitions) was not run.
2. **Visual Inspection:** Visual font rendering of Arabic glyphs and layout styling were verified via widget tree matchers and accessibility semantics, not human eyes.
3. **Thermal Printer Output:** ESC/POS physical hardware receipt printouts were verified via bytes and text assertions in test suites, not a physical thermal printer.
4. **Interactive Dialogs:** Dialog rendering and user dismissal behavior were verified via widget tests (`CustomerStatementDialogTest`), not interactive human taps.
