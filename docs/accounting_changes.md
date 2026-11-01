# Accounting Changes & Defect Resolutions

This document records any change that modifies how existing or new data is totalled, ledgered, or reported.
Format: Defect ID | Description | Root Cause | Before/After Fixture Proof | Files Changed.

---

## Change 1: BUG-01 — DocumentItemInput Decimal Precision Scale

| Field | Detail |
|---|---|
| **Defect ID** | BUG-01 |
| **Severity** | High |
| **Component** | `lib/services/document_service.dart: DocumentItemInput` |
| **Description** | `DocumentItemInput.total` hardcoded 2 decimal places (`MoneyUtils.round(quantity * price, 2)`), failing to respect non-2 decimal currency precision. |
| **Root Cause** | Default parameter `decimalDigits = 2` in `MoneyUtils.round` was used without allowing the currency's decimal precision to be provided to the input model. |
| **Resolution** | Added optional `decimalDigits` property to `DocumentItemInput` and `calculateTotal([int? digits])` method. |
| **Files Changed** | `lib/services/document_service.dart`, `test/accounting/money_oracle_test.dart` |

### Before / After Fixture Proof
```dart
// Test fixture: Zero-decimal precision currency item
const item = DocumentItemInput(
  description: 'Sample',
  quantity: 3.333,
  price: 100.0,
  decimalDigits: 0,
);

// BEFORE FIX:
// item.total returned 333.3 (hardcoded 2 decimals).
// Test failed: Expected: <333.0>, Actual: <333.3>

// AFTER FIX:
// item.total returns 333.0 (honors decimalDigits: 0).
// Test passed: 333.0 == 333.0
```

### Mutation Verification:
1. Revert `calculateTotal([int? digits]) => MoneyUtils.round(quantity * price, digits ?? decimalDigits ?? 2);` to `MoneyUtils.round(quantity * price);`
2. Run `flutter test test/accounting/money_oracle_test.dart`
3. Result: **FAILS** with `Expected: <333.0>, Actual: <333.3>`
4. Restore fix -> Run `flutter test test/accounting/money_oracle_test.dart` -> **PASSES** (5/5 tests passed).

### Impact:
- **Existing Data:** ZERO impact. Stored database records in SQLite are snapshot totals and are not recomputed.
- **New Data:** Enables line items to calculate line totals respecting currency decimal precision.


---

## Change 2: BUG-02 — Double Stock Movement on Purchase Edit & Historical Neutralization

| Field | Detail |
|---|---|
| **Defect ID** | BUG-02 |
| **Severity** | Critical |
| **Component** | `lib/database/database_helper.dart: updateDocumentWithItems` |
| **Description** | Editing an issued purchase invoice re-inserted incoming stock movements, inflating physical stock by 100% of the purchase quantity. Compounding the issue, manual compensating stock adjustments were ledgered as inventory losses (Dr 5200 / Cr 1140), creating phantom losses on the income statement while physical stock and ledger inventory diverged. |
| **Root Cause** | In `updateDocumentWithItems`, the loop over `newItems` called `_insertStockMovement` whenever `newIsIssued` was true, failing to condition direct insertion on first-time issuance (`!oldWasIssued && newIsIssued`). |
| **Resolution** | 1. Implemented authoritative single delta routine `_applyDocumentEditStockDeltas` in `DatabaseHelper` to compute signed per-product quantity and cost deltas. Metadata-only edits produce zero movements.<br>2. Added read-only diagnostic checks to `DatabaseDiagnosticService` (`document_movement_mismatch`, `ledger_movement_inventory_mismatch`).<br>3. Implemented guided repair in `DatabaseRepairService` (Option A & Option B) with dry-run preview, backup, token confirmation, and movement neutralization without hard deletes. |
| **Invariants Added** | INV-10 (Document Movement Net Invariant), INV-11 (Stock Ledger Invariant), INV-12 (Metadata Edit Invariant), INV-13 (Ledger Inventory Identity Invariant). |
| **Files Changed** | `lib/database/database_helper.dart`, `lib/services/database_diagnostic_service.dart`, `lib/services/database_repair_service.dart`, `docs/invariants_units_wholesale.md`, `CLAUDE.md`, `AGENTS.md`, `test/accounting/purchase_edit_integrity_test.dart`, `test/accounting/purchase_repair_test.dart`, `test/invariants/units_wholesale_invariants_test.dart`, `test/guards/document_edit_guard_test.dart` |

### Before / After Fixture Proof
```dart
// Test fixture: test/accounting/purchase_edit_integrity_test.dart
// 1. Issue purchase with 100 units. Stock = 100.
// 2. Edit purchase to attach supplier (metadata edit).

// BEFORE FIX:
// Stock quantity became 200 (Expected: <100.0>, Actual: <200.0>)
// Net movements became 200 (Expected: <100.0>, Actual: <200.0>)

// AFTER FIX:
// Stock quantity remains 100.0.
// Net movements remain 100.0.
// Metadata edits produce 0 movements.
```

### Mutation Verification:
1. Revert `_applyDocumentEditStockDeltas` bypass and change `!oldWasIssued && newIsIssued` to `newIsIssued`.
2. Run `flutter test test/accounting/purchase_edit_integrity_test.dart`.
3. Result: **FAILS** (12 out of 13 tests fail, reproducing exact double-counting bug).
4. Restore delta routine -> **PASSES** (13/13 tests pass).
