# Architectural Invariants: Custom Sales Units & Wholesale Pricing

**Document Version:** 1.0  
**Effective Branch:** `fix/units-wholesale`  
**Related Test Suites:**
- [`test/invariants/units_wholesale_invariants_test.dart`](file:///data/data/com.termux/files/home/projects/waraqatak/test/invariants/units_wholesale_invariants_test.dart)
- [`test/guards/architecture_guards_test.dart`](file:///data/data/com.termux/files/home/projects/waraqatak/test/guards/architecture_guards_test.dart)
- [`test/audit/units_wholesale_fix_test.dart`](file:///data/data/com.termux/files/home/projects/waraqatak/test/audit/units_wholesale_fix_test.dart)
- [`test/audit/units_wholesale_audit_test.dart`](file:///data/data/com.termux/files/home/projects/waraqatak/test/audit/units_wholesale_audit_test.dart)

---

## 1. Core Invariants (INV-1..INV-9)

| Invariant ID | Name | Formal Invariant Definition |
|---|---|---|
| **INV-1** | **Strict Stock Gate** | Under `strictStock: true`, a document is accepted if and only if $\sum_{\text{lines of } p} \text{effectiveBaseQuantity} \le \text{availableStock}(p)$ for every physical product $p$. Insufficient stock throws `StateError('Insufficient stock for "$name": available X, required Y')` prior to any DB write. |
| **INV-2** | **Physical Stock Non-Negativity** | In all modes (strict and non-strict), `products.stock_quantity` MUST NEVER fall below `0.0`. In non-strict mode, deductions per line are bounded by remaining stock in real time. |
| **INV-3** | **Conservation of Physical Stock** | For every fully backed sale, the net change in `products.stock_quantity` equals exactly $-\sum \text{effectiveBaseQuantity}$. |
| **INV-4** | **Movement Tracking Equivalence** | For every issued document, the sum of `quantity` in `stock_movements` with `type = 'sale'` equals exactly $-\sum \text{effectiveBaseQuantity}$. |
| **INV-5** | **COGS & Unit Cost Backing** | For fully backed sale lines, `document_items.total_cost` equals $\text{effectiveBaseQuantity} \times \text{average\_cost}$. If partially oversold in non-strict mode, cost is untrusted (`null`). |
| **INV-6** | **Cancellation Reversibility** | Cancelling an issued sales document reverses all associated `stock_movements` and restores the exact deducted base quantity back to physical inventory. |
| **INV-7** | **Edit-Then-Cancel Invariance** | Editing an issued document (which rolls back old movements and records new movements) followed by cancellation returns physical stock to its exact initial pre-sale state. |
| **INV-8** | **Repricing Immutability** | Line repricing via `DocumentService.resolveLinePrice` NEVER mutates lines with manual price overrides (`isManualPrice == true`) or legacy lines (`pricingCategory == null && currentPrice != null`). Furthermore, if a line's snapshot conversion factor differs from the catalog unit definition, history wins and price is preserved. |
| **INV-9** | **Reporting Base-Unit Aggregation** | All sales and inventory reporting queries aggregate $\text{COALESCE}(\text{base\_quantity}, \text{quantity})$, correctly summing secondary and base packaging units in terms of standard base stock. |
| **INV-10** | **Document Net Movement Parity** | For every non-cancelled issued document, the net stock movements referencing it equal the signed sum of its items' effective base quantities (+ for purchases, - for sales). Cancelled documents net strictly to zero. |
| **INV-11** | **Physical Stock Balance Integrity** | For every product, `products.stock_quantity` equals the sum of its movements in `stock_movements` at all times. |
| **INV-12** | **Metadata Edit No-Op** | Metadata-only edits (supplier/customer, notes, date, payment method, paid amount, recipient info) produce ZERO stock movements and ZERO changes to physical stock or ledger inventory. |
| **INV-13** | **Ledger-Movement Inventory Valuation Parity** | Inventory balance per ledger (`Accounts.inventory`) equals total inventory per movements valued at cost, except for documented unvalued/unknown cost historical cases. |

---

## 2. Pinned Semantics

### Minimum Wholesale Quantity Evaluation
- **Pinned Rule:** `product.wholesaleMinQuantity` is evaluated against **effective base quantity** ($\text{quantity} \times \text{conversionFactor}$), NOT packaging unit count.
  - *Example:* A product with `wholesaleMinQuantity = 12` and a unit `Carton` (factor = 12). Selling 1 Carton yields $\text{baseQty} = 12 \ge 12$, thereby qualifying for wholesale pricing automatically.
  - *Location:* [`lib/services/document_service.dart:resolveItemPrice`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/document_service.dart#L733).

### Single Authoritative Entry Points
1. **Stock Availability Validation:**  
   - [`DatabaseHelper._assertSaleStockAvailable`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L2420).  
   - Prohibits distributed per-line stock availability checks. Computes available stock including document-specific reversals before any write occurs.
2. **Line Repricing:**  
   - [`DocumentService.resolveLinePrice`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/document_service.dart#L775).  
   - Authoritative wrapper over `resolveItemPrice`. Guarantees packaging unit preservation, manual override retention, and snapshot historical immutability.

---

## 3. Developer Checklist: Adding or Modifying Document Flows

Before merging any change affecting sales, inventory, pricing, or units:

1. **Stock Validation:** Does the new flow call `_assertSaleStockAvailable` inside the transaction before any DB writes?
2. **Line Repricing:** Does every price recalculation route through `DocumentService.resolveLinePrice` passing the full line state?
3. **Snapshot Preservation:** Are all 4 snapshot columns (`sale_unit`, `unit_conversion_factor`, `base_quantity`, `pricing_category`) persisted in `document_items`?
4. **Invariant Test Suite:** Run `flutter test test/invariants/units_wholesale_invariants_test.dart` and confirm all 60 iterations pass.
5. **Architecture Guard Suite:** Run `flutter test test/guards/architecture_guards_test.dart` and confirm zero static violations.
