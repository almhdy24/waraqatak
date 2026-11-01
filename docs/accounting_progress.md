# Accounting & Single-Currency Audit Progress

| Phase | Description | Status | Commit SHA | Checks Run |
|---|---|---|---|---|
| Phase 0 | Baseline, Test Runner, CI Failure Root-Cause | COMPLETE | dde0020 (amended) | 63 files / 881 tests passed; play_compliance OK; analyze OK |
| Phase 1 | Read-Only Audit & Specification | COMPLETE | 522616c | Completed comprehensive audit and as-implemented spec |
| Phase 2 | Red-First Oracle & Invariant Harness | COMPLETE | 57ad95a | 4 suites / 11 tests passed, 1 skipped (BUG-01) |
| Phase 3 | Single-Currency Refactor | COMPLETE | e35e10a | Removed UI multi-currency selectors/pickers; enforced base currency with legacy preservation; all mapped tests pass |
| Phase 4 | Fix Proven Defects | PENDING | - | - |
| Phase 5 | Structural Guards | PENDING | - | - |
| Phase 6 | Final Verification & Docs | PENDING | - | - |

---

## Detailed Phase Logs

### Phase 0: Baseline, Test Runner, CI Failure
- **Branch:** `feat/single-currency-accounting-audit` created from `main` (`d150613`).
- **CI Failure Root-Cause:**
  - In `v1.1.5-alpha+15`, `CustomerDetailScreen` defined `_fmt = NumberFormat('#,##0')` (0 decimals), rendering a single combined `Text` widget `'50,000 ج.س'`.
  - In `ux/ui-polish` (Batch 2), this was replaced with `AppAmountText`, which defaulted to 2 decimal places (`50,000.00`) and rendered two sibling `Text` widgets inside a `Row` without a unified accessibility label.
  - The older test in `multi_currency_phase1_test.dart:542` looked for `find.textContaining('50,000 ج.س')`, which failed.
- **Proper Fix:**
  - `CustomerDetailScreen`: passed `decimalDigits: fmt.maximumFractionDigits` to `AppAmountText` to restore intentional zero-decimal formatting for whole currency amounts.
  - `AppAmountText`: added canonical getters (`formattedAmount`, `resolvedPrefix`, `fullText`) and wrapped the `Row` in a unified `Semantics(container: true, label: resolvedSemantics, excludeSemantics: true)` node for accessibility and testing.
  - `multi_currency_phase1_test.dart`: strengthened test assertions to verify `fullText`, `find.bySemanticsLabel`, and exact token widgets instead of weakening the finder.
  - `test/widgets/app_amount_text_test.dart`: created 10-test suite covering 0, 2, and 3 decimals, RTL/LTR layout, debit/credit badges, negative amounts, custom prefix and semantics. All 10 passed.
- **One-by-One Test Runner:**
  - Created `tool/run_tests_one_by_one.sh`.
  - Executed baseline run across all 63 discovered test files.
  - Results: 63 / 63 test files passed, 881 tests passed, 0 failed, 0 skipped.
  - Play compliance guard passed: `bash tool/check_play_compliance.sh` -> OK.
  - **Dart analyze passed on all modified files.**

### Phase 1: Read-Only Audit & Specification
- Audited Sections A through E with line-by-line evidence from source code.
- Mapped currency architecture, locking mechanism, creation invariants, and nominal segregation of legacy records.
- Verified MoneyUtils half-up rounding, epsilon compensation, and Hamilton-Hare Largest-Remainder discount distribution.
- Cataloged the 13-account chart of accounts, IAS perpetual moving-average costing, and proof of 6 accounting identities.
- Cataloged transaction boundaries, atomic document number generation, foreign key cascading, and diagnostic coverage.
- Created `docs/accounting_audit.md` (audit report & defect catalog BUG-01 through BUG-05) and `docs/accounting_spec.md` (formal as-implemented specification).

### Phase 2: Red-First Oracle & Invariant Harness
- Created independent integer-only minor-unit oracle (`test/accounting/money_oracle_test.dart`):
  - 50+ property-based random tests checking round-half-up, line total, proportional discount (Hamilton-Hare), tax, and grand total.
  - Exposes BUG-01 with `skip: 'BUG-01: DocumentItemInput.total hardcodes 2 decimals'`.
  - 4 passed, 1 skipped.
- Created cross-layer consistency test (`test/accounting/cross_layer_consistency_test.dart`):
  - Injected an invoice with line discount, document discount, and tax.
  - Proved identical numbers across DocumentService calculation, SQLite row, PDF builder, Period summary, and Ledger journal entries.
  - 1 passed.
- Created accounting identities test (`test/accounting/accounting_identities_test.dart`):
  - Validated 5 core accounting identities under mixed operations (10 invoices, 5 purchases, 2 cancellations, partial payments, and stock adjustments).
  - Validated zero-sum journal entries, AR/AP subledger reconciliation, inventory valuation asset match, and profit equation.
  - 1 passed.
- Created edge cases test (`test/accounting/edge_cases_test.dart`):
  - Validated 100% discount, zero unit price, fractional quantities (0.001), 10-line Hamilton-Hare largest remainder apportionment, and end-of-period date boundaries.
  - 5 passed.
- All 4 test suites pass analysis (`dart analyze test/accounting/`) and pass tests.

### Phase 3: Single-Currency Refactor
- Created `docs/single_currency_design.md`:
  - Detailed single base currency architecture (`businesses.currency_code`, permanently locked upon first transaction).
  - Explicit legacy data policy: zero schema drops, zero destructive updates, null/empty currency fallback to base currency at read time, historical foreign records preserved and segregated.
  - Complete test mapping table ensuring 0 deleted tests.
- Central Currency Accessor:
  - Created `lib/services/currency_service.dart` (`CurrencyContext`) providing cached resolution of base currency, symbol, decimal scale, and base currency match validation.
- UI & Report Simplification:
  - `lib/screens/reports/accounting_screen.dart`: Removed currency selection dropdown; journal automatically defaults to base currency. Added informational banner for legacy foreign records.
  - `lib/widgets/customer_statement_dialog.dart`: Removed currency dropdown picker; statement generates strictly for base currency with informational notice when legacy foreign documents exist.
  - `lib/screens/reports/sales_report_screen.dart`: Primary summary chips and PDF cards always show base currency figures; added dedicated read-only section for legacy foreign-currency documents.
  - `lib/screens/reports/purchases_report_screen.dart`: Primary summary chips and PDF cards always show base currency figures; added dedicated read-only section for legacy foreign-currency purchases.
  - `lib/screens/reports/payments_report_screen.dart`: Primary summary chips show base currency received/made payments; legacy payments isolated in dedicated read-only section.
  - `lib/screens/customer_detail_screen.dart`: Financial stat cards display base currency receivable/payable balance; legacy foreign balances isolated in read-only section below.
- Database & Reporting Services:
  - `DatabaseHelper.getPeriodSummary`: Defaults unfiltered scalar totals to base currency, avoiding cross-currency nominal addition while keeping `totalsByCurrency` breakdown.
  - `BusinessReportingService.getProductPerformance` & `getPurchasesReport`: Primary scalar figures strictly represent base currency.
  - `DatabaseDiagnosticService`: Added diagnostic check `legacy_foreign_currency_documents` (severity: info, category: documentStatusMismatch) to enumerate any legacy non-base currency records.
- Verification:
  - `test/services/multi_currency_phase1_test.dart`: 5 / 5 passed.
  - `test/services/multi_currency_phase2_stage1_test.dart`: 3 / 3 passed.
  - `test/services/single_base_currency_test.dart`: 14 / 14 passed.
  - `test/accounting/cross_layer_consistency_test.dart`: 1 / 1 passed.
  - `bash tool/check_play_compliance.sh`: Play compliance guard OK.
  - `dart analyze`: Clean on all modified files.
