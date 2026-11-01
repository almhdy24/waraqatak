# Fix Progress: SnackBars & Purchase Edit Integrity

Branch: `fix/snackbar-and-purchase-edit`
Base Commit: `e2ce47fc19084bc5badae196a68769d3abafebc4` (contains `v1.1.5-beta+17`)

## Phases

| Phase | Description | Status | Commit SHA | Verification & Test Evidence |
|-------|-------------|--------|------------|------------------------------|
| 1.0 | Setup & Baseline Verification | COMPLETE | - | Base branch created off main (`e2ce47f`); play compliance verified OK |
| 1.1 | Root Cause Analysis (SnackBars) | COMPLETE | - | Proved SDK `persist = persist ?? action != null` in `snack_bar.dart:303` & `scaffold.dart:619-626` |
| 1.2 | Implement AppSnackBar & Countdown Widget | COMPLETE | - | `lib/widgets/app_snackbar.dart` (5s timeout, 10s a11y, 48dp, Telegram countdown, fallback timer) |
| 1.3 | Migrate All Call Sites | COMPLETE | - | All 35 files migrated to `AppSnackBar.show(...)`; 0 bare `SnackBar`/`showSnackBar` in `lib/` |
| 1.4 | SnackBar Guards & Tests | COMPLETE | - | `test/guards/snackbar_guard_test.dart` (2 tests), `test/widgets/app_snackbar_test.dart` (6 tests) pass; mutations verified |
| Part 1 Commit | `fix(ui): central 5-second snackbar with countdown` | COMPLETE | 7e58229 | Clean tests & guard pass, mutation verified |
| 2.1 | Purchase Edit Integrity Test (RED) | COMPLETE | - | Reproduced exact double-count bug: expected 100.0, actual 200.0 |
| 2.2 | Root Cause Analysis (Purchase Edit) | COMPLETE | - | Proved `_insertStockMovement` re-applied unconditionally in `updateDocumentWithItems` |
| 2.3 | Implement Delta Logic on Document Edit | COMPLETE | - | Atomic delta stock movement `_applyDocumentEditStockDeltas` in `database_helper.dart` |
| 2.4 | Test Matrix (Purchases & Sales) | COMPLETE | - | 13 test cases in `test/accounting/purchase_edit_integrity_test.dart` all pass (10s) |
| 2.5 | Structural Invariants (INV-10..13) & Source Guard | COMPLETE | - | Added P2 to `units_wholesale_invariants_test.dart`, `document_edit_guard_test.dart` passes (6s), docs updated |
| 2.6 | Diagnostics for Corrupted Data | COMPLETE | - | Read-only mismatch detection in `DatabaseDiagnosticService` (`document_movement_mismatch`, `ledger_movement_inventory_mismatch`) |
| 2.7 | Guided Safe Repair Service & Fixture Test | COMPLETE | - | Guided repair tool in `DatabaseRepairService` (Option A & B) + 5 tests in `purchase_repair_test.dart` pass (11s) |
| Part 2 Commit | `fix(accounting): atomic stock delta on document edit and guided repair` | COMPLETE | 0b4e0bd | 13 purchase edit tests, 5 repair tests, 2 invariants P1+P2 pass |
| 3.1 | Read-Only Accounting Spec Addendum | COMPLETE | - | `docs/accounting_spec_addendum.md` documents all posting rules & file:line citations |
| Part 3 Commit | `docs(accounting): posting rules addendum` | IN_PROGRESS | - | Canonical reference completed |
| 4.0 | Full Verification, Report & Docs | COMPLETE | - | run_tests_one_by_one (77 files, 965 tests pass), analyze (0 issues), compliance OK, final report written |

## Test Mapping Updates
- Prior to Part 1, no existing tests asserted on `SnackBar` directly (`grep -rn "SnackBar" test/` returned 0 matches).
- Added `test/guards/snackbar_guard_test.dart`:
  1. No file under `lib/` other than `app_snackbar.dart` contains `showSnackBar` or direct `SnackBar(` instantiation.
  2. No SnackBar-related code specifies a Duration longer than 10 seconds.
- Added `test/widgets/app_snackbar_test.dart`:
  1. SnackBar without action: present at 4.9s and gone at 5.5s.
  2. SnackBar with action: present at 4.9s and gone at 5.5s.
  3. `accessibleNavigation` extends duration: present at 9.9s and gone at 10.5s.
  4. Action tap fires callback exactly once and closes SnackBar immediately.
  5. Clears previous snackbar immediately upon showing a new one.
  6. RTL and Text scale 1.0, 1.3, 2.0 layout check with no overflow.
