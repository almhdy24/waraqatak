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

Any changes touching sales, stock, pricing, or units code must preserve the core invariants INV-1..INV-13 detailed in `docs/invariants_units_wholesale.md`:
- Authoritative stock availability validation must reside strictly in `DatabaseHelper._assertSaleStockAvailable`.
- Line-level repricing must route strictly through `DocumentService.resolveLinePrice`.
- Authoritative stock movement delta calculation for edits must reside strictly in `DatabaseHelper._applyDocumentEditStockDeltas`.
- All snapshot fields (`sale_unit`, `unit_conversion_factor`, `base_quantity`, `pricing_category`) must be preserved across create, edit, duplicate, and quotation conversion.
- `test/invariants/units_wholesale_invariants_test.dart`, `test/guards/architecture_guards_test.dart`, and `test/guards/document_edit_guard_test.dart` MUST pass before committing any changes.

## Hard Invariants (Accounting Backbone & Journal)

Any changes touching accounting, journal, stock movements, or period closing must preserve invariants INV-14..INV-18:
- **INV-14 (Double-Entry Balance Invariance):** Every persisted entry must balance debits and credits in minor units exactly. `JournalWriter.write` rejects unbalanced drafts.
- **INV-15 (Journal Immutability):** No `UPDATE` or `DELETE` on journal tables outside rollback. Revisions and cancellations are append-only reversals dated at original effective date.
- **INV-16 (Single Stock Writer):** All physical stock and average cost mutations MUST route through `StockLedger.record(txn, ...)`. Direct inserts into `stock_movements` or manual column updates outside `StockLedger` are strictly prohibited (enforced by `single_stock_writer_guard_test.dart`).
- **INV-17 (Accounting Period Lock):** Mutations on or before `books_closed_through` are blocked across documents, payments, vouchers, receipts, and stock adjustments before any database writes.
- **INV-18 (Parity Invariance):** Persisted journal balances match the reference derived ledger with zero tolerance on base monetary accounts (1110, 1120, 1130, 2110, 2120, 4100, 1150).
- `test/invariants/accounting_backbone_invariants_test.dart` and `test/guards/single_stock_writer_guard_test.dart` MUST pass.
