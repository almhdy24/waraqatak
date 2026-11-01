# Accounting & Single-Currency Audit Progress

| Phase | Description | Status | Commit SHA | Checks Run |
|---|---|---|---|---|
| Phase 0 | Baseline, Test Runner, CI Failure Root-Cause | COMPLETE | dde0020 (amended) | 63 files / 881 tests passed; play_compliance OK; analyze OK |
| Phase 1 | Read-Only Audit & Specification | PENDING | - | - |
| Phase 2 | Red-First Oracle & Invariant Harness | PENDING | - | - |
| Phase 3 | Single-Currency Refactor | PENDING | - | - |
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
  - Dart analyze passed on all modified files.
