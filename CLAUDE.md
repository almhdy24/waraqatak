# Engineering Rules & Guidelines

## Double-Check the Double-Check

This is mandatory for every code change, especially database, accounting, inventory, and financial logic.

### 1. First Check — Implementation:

- Inspect existing code and understand the full execution flow.
- Implement the smallest safe change.
- Add targeted regression tests.

### 2. Second Check — Independent Verification:

- Re-read the modified code as a skeptical reviewer.
- Independently trace the affected flows without relying on the implementation summary.
- Challenge assumptions and look for hidden side effects, edge cases, data corruption, and backward-compatibility issues.
- Verify database transactions, rollback behavior, and historical data integrity where relevant.

### 3. Adversarial Testing:

- Test normal, boundary, failure, and historical-data scenarios.
- Test interactions with related features, not only the modified function.
- Verify that tests would actually fail if the bug were reintroduced.

### 4. Final Verification:

- Review the complete Git diff.
- Run relevant tests, the broader test suite when practical, and static analysis.
- Investigate every failure; never hide, skip, or weaken tests to obtain a green result.

### 5. Reporting:

- Separate verified facts from assumptions.
- Report remaining risks and untested scenarios.
- Never claim a fix is safe based only on passing tests.

Never approve your own implementation without completing the independent second review.

This rule applies to all future tasks, not just the current issue.

## Hard Invariants (Units, Wholesale Pricing & Inventory)

Any changes touching sales, stock, pricing, or units code must preserve the core invariants INV-1..INV-9 detailed in `docs/invariants_units_wholesale.md`:
- Authoritative stock availability validation must reside strictly in `DatabaseHelper._assertSaleStockAvailable`.
- Line-level repricing must route strictly through `DocumentService.resolveLinePrice`.
- All snapshot fields (`sale_unit`, `unit_conversion_factor`, `base_quantity`, `pricing_category`) must be preserved across create, edit, duplicate, and quotation conversion.
- `test/invariants/units_wholesale_invariants_test.dart` and `test/guards/architecture_guards_test.dart` MUST pass before committing any changes.
