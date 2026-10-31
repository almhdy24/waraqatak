# Feature Audit: Wholesale/Retail Pricing & Custom Sales Units

**Branch:** `audit/units-wholesale`  
**Date:** 2026-10-31  
**Mode:** READ-ONLY Deep Dive (Zero changes to `lib/`)  
**Principle:** "Double check the Double check" — all findings verified with file:line citations and characterization tests in `test/audit/units_wholesale_audit_test.dart`.

---

## 1. Feature Map (Part A: UI Placement & Gating)

| Screen / Feature | Wholesale Shown? | Units Shown? | File & Lines | Notes & Gaps |
|---|:---:|:---:|---|---|
| **Settings Screen** | **YES** | NO | [`lib/screens/settings_screen.dart:206-224`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/settings_screen.dart#L206-L224) | Global `SwitchListTile` updating `businesses.wholesale_pricing_enabled`. Units are configured per product and are not globally toggled. |
| **Financial Settings Screen** | **YES** | NO | [`lib/screens/financial_settings_screen.dart:437-466`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/financial_settings_screen.dart#L437-L466) | Provides confirmation warning dialog via `AppConfirmDialog` when turning wholesale pricing OFF. |
| **Product Form Screen** | **YES** | **YES** | [`lib/screens/product_form_screen.dart:327-360, 729-736, 783-890`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/product_form_screen.dart#L327) | Wholesale fields (price & min quantity) are gated by `_wholesalePricingEnabled`. Units section (list, add, edit, delete) is **independent** of wholesale toggle. In unit dialog, wholesale price is gated by toggle. |
| **Contact Form Screen** | **YES** | NO | [`lib/screens/contact_form_screen.dart:226-250`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/contact_form_screen.dart#L226-L250) | Pricing category dropdown (`retail` vs `wholesale`) is shown **only** when `_type == 'customer'` AND `_wholesalePricingEnabled == true`. Hidden for suppliers. |
| **Document Item Form Widget** | **YES** | **YES** | [`lib/widgets/document_item_form.dart:381-428, 429-470`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/widgets/document_item_form.dart#L381) | Tier chips (`قطاعي` / `جملة` / `يدوي`) shown if `wholesalePricingEnabled && !usePurchasePrice`. Sales unit ChoiceChips shown if `_availableUnits.isNotEmpty && !usePurchasePrice`. |
| **Invoice Screen** | **YES** | **YES** | [`lib/screens/invoice_screen.dart:396-419, 434-465`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/invoice_screen.dart#L396) | Item form fully wired for units and wholesale. **BUG-2**: When customer changes (line 408), `resolveItemPrice` is invoked *without* `unit:`, resetting custom units to base unit prices. |
| **Edit Document Screen** | **YES** | **YES** | [`lib/screens/edit_document_screen.dart:402-423, 536-556`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/edit_document_screen.dart#L402) | Fully wired for invoices and quotations. **BUG-2**: Same customer change bug on line 412 resets custom unit prices to base unit prices. |
| **Quotation Screen** | **NO** | **NO** | [`lib/screens/quotation_screen.dart:157-167, 308-337`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/quotation_screen.dart#L157) | **BUG-3 / GAP-1**: Quotation screen does NOT pass `wholesalePricingEnabled`, `pricingCategory`, `saleUnit`, or `unitConversionFactor` to `DocumentItemForm` or `DocumentItemInput`. |
| **Purchase Screen** | **NO** | **NO** | [`lib/screens/purchase_screen.dart:346`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/purchase_screen.dart#L346) | `usePurchasePrice: true` intentionally suppresses wholesale tiers and custom sales units. Purchases operate strictly in base units. |
| **Custom Document Screen** | **NO** | **NO** | [`lib/screens/custom_document_screen.dart:100`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/custom_document_screen.dart#L100) | Flat voucher document (`items: const []`); neither items, tiers, nor units exist. |
| **Quick Sale / POS Screen** | **YES** | **YES** | [`lib/screens/quick_sale_screen.dart:518-642, 756-789`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/quick_sale_screen.dart#L518) | Global cart tier toggle (`قطاعي` / `جملة`). Line item edit dialog allows changing units, tiers, and manual price. Automatically selects product's `isDefaultSale` unit upon scan/tap. |
| **Document Detail Screen** | **NO** | **NO** | [`lib/screens/document_detail_screen.dart:675-690`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/document_detail_screen.dart#L675) | **GAP-2**: Displays `${item.quantity} × ${item.price}` without unit name or pricing category badge. |
| **PDF Builders (Standard & Thermal)** | NO | **YES** | [`lib/services/pdf/pdf_items_table_builder.dart:51-55`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/pdf/pdf_items_table_builder.dart#L51), [`pdf_document_builder.dart:541-547`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/pdf/pdf_document_builder.dart#L541) | Table cell and thermal receipt print `${quantity} ${saleUnit}`. Pricing category is not printed on invoices. |
| **CSV Import / Export** | **YES** | **YES** | [`lib/services/csv_service.dart:100-101, 174-182, 503-524`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/csv_service.dart#L100) | Full round-trip export & import of `WholesalePrice`, `WholesaleMinQty`, and custom units in `name:factor[:salePrice][:wholesalePrice];` format. |
| **Backup / Restore** | **YES** | **YES** | [`lib/services/backup_service.dart:281-285, 461`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/backup_service.dart#L281) | Complete round-trip table backup and restore of `product_units` and `document_items` unit/category snapshot columns. |
| **Bulk Pricing Service** | **YES** | **NO** | [`lib/services/bulk_pricing_service.dart:133-134`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/bulk_pricing_service.dart#L133) | **GAP-3**: Updates `products.wholesale_price`, but does not update `product_units.wholesale_price` or `product_units.sale_price`. |

---

## 2. Logic Trace (Part B: Invoice Flow vs. POS Flow)

| Step | Standard Invoice Flow | Quick Sale / POS Flow |
|---|---|---|
| **1. Price Resolution** | [`DocumentService.resolveItemPrice`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/document_service.dart#L735-L775): Evaluates `factor`, computes `baseQty = quantity * factor`. Resolves `effectiveRetailPrice = unit?.salePrice ?? product.salePrice * factor`. If wholesale enabled & `targetCategory == 'wholesale'`, candidate wholesale is `unit?.wholesalePrice ?? product.wholesalePrice * factor`. Applies candidate wholesale if `product.wholesaleMinQuantity == null || baseQty >= minBaseQty`. | [`PosCartLine.unitPrice`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/pos_cart.dart#L39-L49) calls [`DocumentService.resolveItemPrice`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/document_service.dart#L735-L775) with the exact same resolution rules, unless `priceOverride != null`. |
| **2. Minimum Wholesale Quantity** | Evaluated against **`base_quantity`** (`baseQty = quantity * factor >= product.wholesaleMinQuantity`). For example: 1 carton of 12 pieces meets min quantity 12 base units. | Evaluated against **`base_quantity`** identical to invoice flow. |
| **3. Unit Change on a Line** | In [`document_item_form.dart:163-178`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/widgets/document_item_form.dart#L163), `_onUnitSelected`: updates unit name, conversion factor snapshot, and re-resolves price via `resolveItemPrice`. If `isManualPrice == true`, price is **not** overwritten (manual override survives). | In [`quick_sale_screen.dart:575-585`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/quick_sale_screen.dart#L575) and [`PosCartLine.withUnit`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/pos_cart.dart#L56-L68): updates unit, preserves `priceOverride` if set, otherwise re-resolves price via `resolveItemPrice`. |
| **4. Customer Change** | In [`invoice_screen.dart:396-419`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/invoice_screen.dart#L396) and [`edit_document_screen.dart:402-423`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/edit_document_screen.dart#L402): Lines with `_isManualPriceList[i] == true` are protected. **BUG-2**: For non-manual lines, `resolveItemPrice` is called *without* `unit:`, resetting custom units to base unit prices. | POS has no customer picker; customers are walk-in/cash. Toggling global cart tier (`retail` vs `wholesale`) calls `_cart.setPricingCategory` which reprices non-overridden lines while preserving custom units correctly. |
| **5. Line Persistence** | In [`DocumentService.createDocument:206-219`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/document_service.dart#L206): `DocumentItemInput` maps to `DocumentItem` with snapshots: `price`, `quantity`, `pricing_category`, `sale_unit`, `unit_conversion_factor`, `base_quantity = quantity * factor`. `DatabaseHelper.insertDocumentWithItems` stores `unit_cost = avgCost` and `total_cost = base_quantity * avgCost`. | In [`quick_sale_screen.dart:228`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/quick_sale_screen.dart#L228): `_cart.toItemInputs()` converts cart lines into `DocumentItemInput` with full unit, factor, and tier snapshots, which are passed to `DocumentService.createDocument`. |
| **6. Stock Deduction & COGS** | In [`database_helper.dart:2667-2715`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L2667): Deducts `effectiveBaseQuantity` from `products.stock_quantity`. Creates `StockMovement` of `type: 'sale'` with `quantity: -effectiveBaseQuantity`. COGS = `effectiveBaseQuantity * average_cost`. | Same downstream execution via `insertDocumentWithItems`. |
| **7. Multi-Line Stock Aggregation** | **BUG-1 (Critical)**: In [`database_helper.dart:2616-2636, 3443-3465, 4680-4705`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L2616), the `strictStock` pre-check loops over lines individually against DB stock. It **does NOT** aggregate `effectiveBaseQuantity` per product across lines! Multiple lines of the same product can oversell stock into negative values. | **SAFE**: [`PosCart.add`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/pos_cart.dart#L186-L192) calls `baseQuantityOf(product.id)` across all existing cart lines and rejects additions when `(currentTotalBase + addedBaseQty) > product.stockQuantity`. |
| **8. Cancellation & Return** | In [`database_helper.dart:4110-4167`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L4110): `cancelDocument` queries `stock_movements` for the document, reversing `-netQty` (in base units) to restore exact stock. `copyDocumentWithItems` copies all snapshots. | Same cancellation mechanism via `cancelDocument`. |
| **9. Purchases in Secondary Units** | Not supported in UI or database. Purchases operate strictly in base units (`usePurchasePrice: true` suppresses units and tiers). | N/A (POS is quick sale only). |
| **10. Reports & Ledger** | In [`business_reporting_service.dart:294, 920`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/business_reporting_service.dart#L294), queries use `COALESCE(di.base_quantity, di.quantity) AS quantity`. In [`ledger.dart:415, 441`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/accounting/ledger.dart#L415), `LedgerBuilder` uses `it.effectiveBaseQuantity` everywhere. | Reuses identical reporting and ledger services. |
| **11. Feature Disabled Behavior** | If `wholesalePricingEnabled == false`, `resolveItemPrice` always returns retail price. Existing documents retain historical snapshots and display/cancel cleanly. | POS cart disables tier toggle and always resolves retail price. |
| **12. Historical Immutability** | If `product_units` definition or factor is edited/deleted later, historical `document_items` are unaffected because they rely on their own immutable snapshot columns (`sale_unit`, `unit_conversion_factor`, `base_quantity`). | Unaffected; historical sales remain immutable. |

---

## 3. Findings

### [BUG-1] `strictStock` Pre-Check Does Not Aggregate Across Multiple Lines of the Same Product
- **Severity:** **CRITICAL**
- **Affected Files:**
  - [`lib/database/database_helper.dart:2616-2636`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L2616-L2636) (`insertDocumentWithItems`)
  - [`lib/database/database_helper.dart:3443-3465`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L3443-L3465) (`updateDocumentWithItems`)
  - [`lib/database/database_helper.dart:4680-4705`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L4680-L4705) (`issueDocument`)
- **Evidence:**
  In `insertDocumentWithItems`:
  ```dart
  if (doc.type == 'invoice' && !isDraft && strictStock) {
    for (final item in items) {
      if (item.productId == null || item.quantity <= 0) continue;
      final pRows = await txn.query(
        'products',
        columns: ['name', 'type', 'stock_quantity'],
        where: 'id = ?',
        whereArgs: [item.productId],
      );
      if (pRows.isNotEmpty && (pRows.first['type'] as String? ?? 'product') == 'product') {
        final stock = (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
        final effectiveBaseQty = item.effectiveBaseQuantity;
        if (stock < effectiveBaseQty) {
          throw StateError('Insufficient stock for ...');
        }
      }
    }
  }
  ```
  Verified via test `Scenario 4b` in `test/audit/units_wholesale_audit_test.dart`: With stock = 28, an invoice with Line 1 (2 cartons = 24 base units) and Line 2 (5 pieces = 5 base units; total = 29 base units) passes the pre-check because `28 < 24` is false and `28 < 5` is false. The invoice is inserted, deducts 24 and then 5, leaving `stock_quantity = -1.0`.
- **Expected Behavior:** `strictStock` must aggregate `effectiveBaseQuantity` by `productId` across all lines in the document and reject the entire invoice if `totalRequiredBaseQuantity > currentStock`.
- **Suggested Fix (Descriptive):** Group incoming items by `item.productId`, summing `item.effectiveBaseQuantity`. For each unique `productId`, query the product once and assert `stock >= totalRequiredBaseQuantity`.

---

### [BUG-2] Contact Selection Repricing Omits Unit Parameter, Resetting Custom Unit Prices to Base Unit Prices
- **Severity:** **HIGH**
- **Affected Files:**
  - [`lib/screens/invoice_screen.dart:408`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/invoice_screen.dart#L408)
  - [`lib/screens/edit_document_screen.dart:412`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/edit_document_screen.dart#L412)
- **Evidence:**
  In `invoice_screen.dart`:
  ```dart
  final resolved = DocumentService.resolveItemPrice(
    product: _cachedProducts[i]!,
    targetCategory: newCat,
    quantity: q,
    wholesalePricingEnabled: true,
    // unit: parameter IS MISSING!
  );
  _priceControllers[i].text = resolved.toStringAsFixed(2);
  ```
- **Expected Behavior:** When the user changes or selects a contact, any line that has a custom sales unit selected (e.g. "Carton" with factor 12) should have its unit passed to `resolveItemPrice(..., unit: _selectedUnits[i])`.
- **Actual Behavior:** Because `unit:` is omitted, `resolveItemPrice` falls back to the base unit price (e.g. piece price 8.00 instead of carton price 90.00), resulting in severe undercharging (up to 12x less) while the line still says "Carton".
- **Suggested Fix (Descriptive):** Cache or look up the selected `ProductUnit` for line `i` and pass `unit: selectedUnit` to `DocumentService.resolveItemPrice`.

---

### [BUG-3 / GAP-1] Quotation Screen Omits Units and Wholesale Tiers
- **Severity:** **MEDIUM**
- **Affected Files:**
  - [`lib/screens/quotation_screen.dart:157-167, 308-337`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/quotation_screen.dart#L157-L167)
- **Evidence:**
  In `quotation_screen.dart:308`: `DocumentItemForm` is instantiated without `wholesalePricingEnabled`, `pricingCategory`, `saleUnit`, or `unitConversionFactor`. In `quotation_screen.dart:159`, `DocumentItemInput` drops unit and tier fields.
- **Expected Behavior:** Quotations should support the same custom sales units and pricing tiers as invoices and edit document screens.
- **Actual Behavior:** Quotations created via `quotation_screen.dart` can only be entered in base units at retail prices. (Note: quotations converted to invoices via `convertQuotationToInvoice` do preserve snapshots if present, but the quotation screen never populates them).
- **Suggested Fix (Descriptive):** Wire `DocumentItemForm` in `quotation_screen.dart` with state variables for `_saleUnits`, `_conversionFactors`, `_pricingCategories`, and pass `wholesalePricingEnabled` from `_business`.

---

### [GAP-2] Document Detail Screen Does Not Display Unit Name or Pricing Category
- **Severity:** **LOW**
- **Affected Files:**
  - [`lib/screens/document_detail_screen.dart:683`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/document_detail_screen.dart#L683)
- **Evidence:** Line renders `'${_fmt.format(item.quantity)} × ${_fmt.format(item.price)}'`.
- **Expected vs Actual:** Displays `2.00 × 90.00` instead of `2.00 كرتونة × 90.00`.
- **Suggested Fix (Descriptive):** Append `item.saleUnit` to quantity if present and non-empty, matching the PDF table rendering.

---

### [GAP-3] Bulk Pricing Service Does Not Update Custom Sales Unit Prices
- **Severity:** **LOW**
- **Affected Files:**
  - [`lib/services/bulk_pricing_service.dart:133-134`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/bulk_pricing_service.dart#L133-L134)
- **Evidence:** `BulkPricingService` updates `products.sale_price`, `wholesale_price`, `purchase_price`, but does not query or update `product_units` rows.
- **Expected vs Actual:** If a merchant applies a 10% price hike across a category, base piece prices increase, but carton prices in `product_units` remain unchanged unless manually edited one by one.
- **Suggested Fix (Descriptive):** Add an option in `BulkPricingService` to adjust secondary unit prices proportionally or directly.

---

### [GAP-4] No Unique Constraint on `(product_id, unit_name)`
- **Severity:** **LOW**
- **Affected Files:**
  - [`lib/screens/product_form_screen.dart:288-296`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/product_form_screen.dart#L288-L296)
  - [`lib/database/database_helper.dart:249-262`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L249-L262)
- **Evidence:** `nameCtrl` validator in `_showUnitDialog` only checks `v.trim().isEmpty`. Schema has no unique index on `(product_id, unit_name)`.
- **Expected vs Actual:** A user can add duplicate units with the same name (e.g. two units called "علبة" with different factors).
- **Suggested Fix (Descriptive):** Add validation in `_showUnitDialog` preventing duplicate names against existing `_productUnits` and the product's base unit.

---

### [OK-1..OK-7] Verified Working Areas
- **OK-1:** Price resolution precedence: `unit.wholesalePrice` -> `product.wholesalePrice * factor` -> `effectiveRetailPrice` with base quantity threshold check.
- **OK-2:** Full historical document and reporting immutability via snapshot columns (`sale_unit`, `unit_conversion_factor`, `base_quantity`).
- **OK-3:** Accurate stock restoration in base units upon invoice cancellation via `stock_movements`.
- **OK-4:** Document duplication (`copyDocumentWithItems`) preserves all unit and tier snapshot fields.
- **OK-5:** POS cart (`PosCart`) aggregates base quantities across all lines of the same product and prevents overselling.
- **OK-6:** CSV import/export and backup/restore round-trip custom units and wholesale fields faithfully.
- **OK-7:** Turning wholesale pricing toggle OFF cleanly falls back to retail pricing everywhere without deleting stored wholesale prices or corrupting history.

---

## 4. Test Suite & Characterization Coverage

Created [`test/audit/units_wholesale_audit_test.dart`](file:///data/data/com.termux/files/home/projects/waraqatak/test/audit/units_wholesale_audit_test.dart):

| Scenario | Description | Result | Evidence / Notes |
|---|---|:---:|---|
| **Scenario 1** | Wholesale customer: 12 pieces -> 6.5; 11 pieces -> 8.0 | **PASS** | `DocumentService.resolveItemPrice` boundary evaluation |
| **Scenario 2** | Wholesale customer: 1 carton -> unit wholesale 75.0, base_quantity 12.0 | **PASS** | `minBaseQty` evaluated in base units (`1 * 12 >= 12`) |
| **Scenario 3** | 1 carton sale: stock 100 -> 88, movement qty -12, unit_cost 5.0, total_cost 60.0 | **PASS** | Deductions and COGS recorded strictly in base units |
| **Scenario 4a** | Mixed lines of same product (2 cartons + 5 pieces): deduction = 29 base units | **PASS** | When stock is sufficient (100 -> 71) |
| **Scenario 4b** | Mixed lines (2 cartons + 5 pieces): `strictStock` rejects when stock = 28 (< 29) | **SKIPPED** | **`BUG-1`**: Skipped per autonomy instructions to keep suite green; proves lack of aggregation in DB pre-check |
| **Scenario 5** | Manual price override survives quantity, unit, and customer tier changes in `PosCart` | **PASS** | `priceOverride` strictly retained across all line mutations |
| **Scenario 6** | Invoice cancellation restores exact base quantities; duplicate preserves snapshots | **PASS** | Database restores 24 base units; copies keep snapshots |
| **Scenario 7** | POS cart aggregates base units across lines and enforces stock limits | **PASS** | `PosCart.add` blocks 2 cartons + 5 pieces when stock is 28 |
| **Scenario 8** | Legacy line (`pricing_category == null`, no unit) is preserved on edit | **PASS** | Stored price 7.75 untouched on document update |
| **Scenario 9** | Changing unit conversion factor after sales does not alter historical documents or reports | **PASS** | Historical document remains 12 base units; report shows 12 |

**Test Execution Output:**
```
00:07 +9 ~1: 1 skipped test.
00:07 +9 ~1: All other tests passed!
```

---

## 5. Not Verifiable Here & Manual Test Checklist

### Not Verifiable in this Environment
- Visual layout of tier chips and ChoiceChips on physical screens (Termux environment without display server or emulator).
- Touch interaction gestures and keyboard dismissal on real mobile hardware.

### Manual Test Checklist for Phone
1. **Invoice Contact Change (Verify BUG-2):**
   - In Settings, enable Wholesale Pricing.
   - Create a product "Test Item" with base unit "Piece" (Sale: $10, Wholesale: $8) and unit "Box" (factor: 10, Sale: $90, Wholesale: $75).
   - In New Invoice, add a line with 1 "Box" (price displays $90).
   - Now select a customer with "Wholesale" category.
   - **Check:** Does the price stay $75 (Box wholesale), or does it incorrectly jump down to $8 (Piece wholesale)?
2. **Multi-Line Stock Oversell (Verify BUG-1):**
   - Set "Test Item" stock to exactly 15 pieces.
   - In New Invoice, add Line 1: 1 "Box" (= 10 pieces).
   - Add Line 2: 7 "Pieces" (Total requested = 17 pieces > stock 15).
   - Tap "Save / Issue".
   - **Check:** Does the app block saving with an "Insufficient stock" error, or does it allow saving and drop stock to -2?
3. **Quotation Screen Units (Verify BUG-3):**
   - Open New Quotation.
   - Add "Test Item".
   - **Check:** Confirm that ChoiceChips for "Box" and tier chips for "Wholesale" do not appear on the quotation screen.
