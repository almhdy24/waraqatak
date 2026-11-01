# Autonomous Fix & Quality Verification Final Report

**System:** Waraqatak (ورقتك) Flutter Application  
**Branch:** `fix/snackbar-and-purchase-edit`  
**Base Commit:** `e2ce47fc19084bc5badae196a68769d3abafebc4` (contains `v1.1.5-beta+17`)  
**Commit Log:**
- `7e58229` Part 1: `fix(ui): central 5-second snackbar with countdown`
- `254b3ef` Part 2: `fix(accounting): atomic stock delta on document edit and guided repair`
- `b5b0fc0` Part 3: `docs(accounting): posting rules addendum`

---

## 1. Executive Summary

All three requested parts have been fully resolved, structurally guarded, cross-verified through mutation testing, and documented:
1. **SnackBars that Never Disappear (Part 1):** Proved root cause in Flutter SDK (`snack_bar.dart:303` where `persist = persist ?? action != null` caused SnackBars with actions to stay indefinitely). Implemented central `AppSnackBar.show(...)` with a 5-second circular countdown timer (10s under `accessibleNavigation`), fallback timer, and migrated all 35 call sites across the application.
2. **Purchase Edit Double Stock Movement & Historical Reconciliation (Part 2):** Proved root cause in `DatabaseHelper.updateDocumentWithItems` where editing an issued document unconditionally invoked `_insertStockMovement` in the `newItems` loop. Implemented authoritative delta routine `_applyDocumentEditStockDeltas`, making metadata edits 100% no-ops. Added structural invariants INV-10..INV-13, read-only diagnostic checks, and a guided safe repair tool in `DatabaseRepairService` (Option A & Option B) with dry-run preview, automatic backup, and confirmation tokens without hard-deleting historical records.
3. **Missing Accounting Posting Rules (Part 3):** Authored canonical specification `docs/accounting_spec_addendum.md` detailing exact double-entry posting rules, account mappings, and edge cases with line-level code citations.

---

## 2. Part 1 — SnackBars: Root Cause, Solution & Evidence

### 2.1 Root Cause (SDK & Application)
- **SDK Root Cause (`packages/flutter/lib/src/material/snack_bar.dart:303-311`):**
  When `persist` is omitted, Flutter resolves persistence as `persist = persist ?? action != null`.
- **Scaffold Messenger Controller (`packages/flutter/lib/src/material/scaffold.dart:619-626`):**
  When `persist == true`, the auto-dismiss timer is never scheduled. Furthermore, if `accessibleNavigation` was enabled, Flutter used `duration = const Duration(days: 1)`.
- **Application Root Cause:** 35 call sites in `lib/` invoked `ScaffoldMessenger.of(context).showSnackBar(...)` with an `action:` parameter (e.g. Undo), leaving SnackBars permanently pinned to the viewport.

### 2.2 Central Helper Implementation (`lib/widgets/app_snackbar.dart`)
- **Central Helper:** `AppSnackBar.show(...)` with fixed `defaultDuration = Duration(seconds: 5)` and `accessibleDuration = Duration(seconds: 10)`.
- **Circular Countdown Widget:** Built-in `_SnackBarCountdownTimer` rendering a smooth circular progress indicator (and remaining seconds text) alongside the action button.
- **Robust Dismissal:** Sets `persist: false` on all instances, clears previous SnackBars immediately, and arms a fallback timer at `duration + 300ms` to guarantee dismissal even if framework animations stall.
- **Accessibility & RTL:** Accessible semantics labels, RTL-safe layouts, 48dp minimum touch targets, and non-overflowing text scaled up to 2.0x.

### 2.3 Verification & Guard Evidence
- **Guard Test (`test/guards/snackbar_guard_test.dart`):** PASS (2/2 tests). Verifies 0 direct `showSnackBar` or `SnackBar(` calls outside the helper, and 0 durations > 10s.
- **Widget Tests (`test/widgets/app_snackbar_test.dart`):** PASS (6/6 tests). Verifies auto-dismiss at 5.0s, accessible extension to 10s, single action execution, and layout at 1.0, 1.3, 2.0 text scales in Arabic and English.

---

## 3. Part 2 — Purchase Edit Double Count & Reconciliation: Solution & Evidence

### 3.1 Root Cause
In `lib/database/database_helper.dart:updateDocumentWithItems`:
```dart
// OLD CODE:
for (final item in newItems) {
  if (item.productId != null && item.quantity > 0) {
    if (newIsIssued) { // BUG: executed for edits of already-issued documents!
      await _insertStockMovement(...); // Inserted duplicate movement (+100)
    }
  }
}
```
When an issued purchase without a supplier was edited to attach a supplier, the second movement was appended, inflating physical stock by 100%. If the user subsequently performed a compensating stock adjustment of -100, the ledger derived purchases from documents but adjustments from `stock_movements`, booking the manual adjustment as an inventory loss (Dr 5200 / Cr 1140) while physical stock and ledger inventory diverged.

### 3.2 Authoritative Delta Routine (`DatabaseHelper._applyDocumentEditStockDeltas`)
- Computes signed net differences per product between old and new document items.
- Only writes stock movements if the effective base quantity or cost changed.
- Metadata-only edits (supplier, notes, date, payment method) produce **zero movements** and **zero ledger changes**.
- Repeated edits with the identical payload are strictly **idempotent**.

### 3.3 Test Matrix & Invariants
- **Integrity Matrix (`test/accounting/purchase_edit_integrity_test.dart`):** 13 comprehensive test cases passed (10s):
  1. Add supplier to issued purchase preserves stock and movements.
  2. Metadata-only edit produces zero stock movements.
  3. Quantity increase applies delta and updates moving average cost.
  4. Quantity decrease applies delta cancellation movement.
  5. Price-only edit updates moving average cost without adding movements.
  6. Add and remove lines applies correct signed deltas.
  7. Draft to issued creates initial movements.
  8. Edit then cancel results in net zero movements.
  9. Editing twice with identical payload is strictly idempotent.
  10. Fractional quantities handled with precision.
  11. Reducing purchase below already-consumed stock is rejected.
  12. Sales metadata edits produce zero stock movements.
  13. Sales quantity edits adjust stock and movements accurately.
- **Invariants Extended:** Added INV-10 (Document Movement Net Invariant), INV-11 (Stock Ledger Invariant), INV-12 (Metadata Edit Invariant), and INV-13 (Ledger Inventory Identity Invariant) to `test/invariants/units_wholesale_invariants_test.dart` (60 seeded iterations, passed in 28s).
- **Source Scan Guard (`test/guards/document_edit_guard_test.dart`):** Passed (2/2 tests). Ensures only `_applyDocumentEditStockDeltas` writes movements on edits of issued documents.

### 3.4 Diagnostics & Guided Safe Repair
- **Read-Only Detection (`DatabaseDiagnosticService`):**
  - `document_movement_mismatch`: detects discrepancies between net document stock movements and line item quantities.
  - `ledger_movement_inventory_mismatch`: detects differences between ledger-derived inventory and stock movement sums.
- **Guided Safe Repair (`DatabaseRepairService`):**
  - **Option A:** Neutralizes surplus movements by recording a compensating reversal movement (`type: 'cancellation'`).
  - **Option B (PURCHASE-0001 Resolution):** Pairs the duplicate purchase edit movement with the compensating manual adjustment and marks both as `type: 'neutralized'` (`[NEUTRALIZED-OPTION-B]`).
  - **Guarantees:** Dry-run preview listing exact rows, automatic safety backup via `BackupService`, explicit confirmation token (`CONFIRM-REPAIR-...`), single atomic transaction, audit log entry in `audit_log`, and zero hard-deletions of historical rows.
- **Repair Test (`test/accounting/purchase_repair_test.dart`):** 5 test cases passed (11s), verifying fixture reproduction, dry-run, token enforcement, Option A, and Option B (removing phantom adjustment loss from ledger).

---

## 4. Part 3 — Accounting Spec Addendum

Created `docs/accounting_spec_addendum.md` documenting:
- Full 13-account chart of accounts with normal debit/credit balances.
- In-memory derived general ledger architecture and stable timestamp sorting.
- Exact posting rules for Invoices, Purchases, Settlements, Payment Receipts, Expense Vouchers, Document Cancellations, and IAS 2 Perpetual Weighted-Average Inventory Replay.
- Accounting edge cases: uncosted sales disclosure (`isCostMissing: true`), unlinked payments vs active receipt allocations (`linkedPaid`), cancelled document payments (automatic liability re-routing), negative stock replay, and cross-currency price isolation.
- File and line references for every posting rule in `lib/services/accounting/ledger.dart`.

---

## 5. Level 3 Verification Results

### (a) Completeness (`tool/run_tests_one_by_one.sh --fresh`)
```
==================================================
Waraqatak One-By-One Test Runner
Discovered 77 test files
Results file: .dart_tool/test_results.tsv
Mode: FRESH (all tests will run)
==================================================
SUMMARY:
Files Discovered : 77
Files Executed   : 77
Files Passed     : 77
Files Failed     : 0
Tests Passed     : 965
Tests Failed     : 0
Tests Skipped    : 0
Total Executed   : 965
==================================================
```
- **Comparison to Baseline (901 tests):** Total increased from 901 to 965 (+64 tests).
- **Difference Breakdown:**
  - `test/guards/snackbar_guard_test.dart`: +2 tests
  - `test/widgets/app_snackbar_test.dart`: +6 tests
  - `test/accounting/purchase_edit_integrity_test.dart`: +13 tests
  - `test/guards/document_edit_guard_test.dart`: +2 tests
  - `test/accounting/purchase_repair_test.dart`: +5 tests
  - `test/invariants/units_wholesale_invariants_test.dart`: +1 test (added Phase 2 testing INV-10..13 across 60 randomized iterations)
  - Other tests added on `main` before branching: +35 tests.
  - **Net Result:** 100% of discovered test files passed with non-zero counts.

### (b) Mutation Testing Evidence
- **Part 1 Mutation:**
  - Mutated `persist: false` to default / removed countdown timer -> `test/widgets/app_snackbar_test.dart` failed.
  - Restored -> PASSED.
- **Part 2 Mutation:**
  - Mutated `_applyDocumentEditStockDeltas` bypass in `updateDocumentWithItems` -> 12 out of 13 tests in `purchase_edit_integrity_test.dart` failed with `Expected: <100.0>, Actual: <200.0>`.
  - Restored -> PASSED.

### (c) Static Analysis & Compliance
- **Codebase Analysis (`dart analyze lib test`):**
  `Analyzing lib, test... No issues found!` (0 errors, 0 warnings).
- **Play Compliance (`bash tool/check_play_compliance.sh`):**
  `Play compliance guard: OK`
- **Play Compliance Tests (`test/services/play_compliance_test.dart`):**
  `42 passed, 0 failed`.

### (d) Remaining Unverified Items
- Physical capacitive touch response timing on physical low-end Android hardware.
- Subjective perceptual feel of the circular countdown animation on high-refresh (120Hz) screens.
