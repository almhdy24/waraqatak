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

