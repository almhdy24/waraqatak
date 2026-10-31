# Decisions Log: Units & Wholesale Fixes

| Decision ID | Issue | Decision Made | Alternatives Considered | Why Safest | How to Reverse |
|---|---|---|---|---|---|
| DEC-1 | BUG-1 (Stock pre-check aggregation) | Create single `_assertSaleStockAvailable(txn, items, {documentId})` that groups base quantities by `productId` and checks availability before any writes or reversals in insert, update, and issue flows. | 1. Keep per-line check and track running stock in memory during loop.<br>2. Rely only on SQLite non-negative check. | Single authoritative helper guarantees identical validation logic everywhere and rolls back before dirtying DB. | Revert `_assertSaleStockAvailable` and restore previous per-line checks in `database_helper.dart`. |
