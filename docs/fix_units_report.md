# Verification & Implementation Report: Units & Wholesale Defect Fixes

**Branch:** `fix/units-wholesale`  
**Base Commit:** `4b2b962` (`audit/units-wholesale`)  
**Head Commit:** `ccbe790` (plus documentation commit)  
**Date:** 2026-11-01  
**Environment:** Linux / Termux (Flutter 3.x, Dart 3.x)

---

## 1. Executive Summary

This task fixed all defects identified during the audit of wholesale/retail pricing and custom sales units (`product_units`, `base_quantity`), specifically **BUG-1**, **BUG-2**, **BUG-3 / GAP-1**, **GAP-2**, **GAP-3**, and **GAP-4**. Furthermore, architectural guards, randomized invariant tests, and project invariant rules (P1–P4) were established to make this defect class structurally impossible to reintroduce.

All fixes were implemented cleanly within authorized scopes without modifying any forbidden files (zero changes to database migrations, costing logic, DB schema, DB version, backup format, `MoneyUtils`, or licensing logic).

---

## 2. Defect Resolution Summary

### BUG-1: Authoritative Stock Deduction Validator Aggregation
- **Severity:** High / Data Integrity
- **Root Cause:** In [database_helper.dart](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart), `insertDocumentWithItems`, `updateDocumentWithItems`, and `issueDocument` checked `product['stock'] < effectiveBaseQty` on each document line individually without summing `effectiveBaseQty` for duplicate or multi-line product rows. A sale document with two lines each requesting 6 units on an inventory balance of 10 base units would pass validation, overselling stock into negative numbers or clamping stock.
- **Fix:** Implemented `DatabaseHelper._assertSaleStockAvailable(txn, items, {documentId})`. This helper aggregates `effectiveBaseQty` across all lines grouped by `productId` before any database writes, compares against `current_stock + (existing_doc_deductions_if_any)`, and throws `StateError('INSUFFICIENT_STOCK: ...')` immediately if net required quantity exceeds physical stock.
- **Commit:** `cfbf9e2`
- **Tests Added:** `test/audit/units_wholesale_fix_test.dart` (multi-line insert, issue, update).
- **Mutation Verification:** Reverted aggregation to per-line check; `units_wholesale_fix_test.dart` failed with `Expected: throws StateError, Actual: <Instance of Future<int>>` and `units_wholesale_invariants_test.dart` failed on 5 iterations.

---

### BUG-2: Price Resolution Entry Point & Unit Preservation
- **Severity:** High / Pricing Correctness
- **Root Cause:** When the customer was changed in [invoice_screen.dart](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/invoice_screen.dart) and [edit_document_screen.dart](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/edit_document_screen.dart), `resolveItemPrice` was invoked without passing the line's chosen custom sales unit. This caused secondary units (e.g. carton = 10 units at $75) to be silently overwritten by the base unit price ($8 or $10). Furthermore, caller call sites lacked uniform handling of manual price overrides and conversion factor mismatches.
- **Fix:** Introduced the authoritative entry point [DocumentService.resolveLinePrice](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/document_service.dart#L101-L157) which enforces:
  1. Manual price overrides are respected unless explicitly instructed to reprice.
  2. Legacy null pricing category fallback.
  3. Packaging unit selection takes priority over base tier pricing.
  4. Unit conversion factor mismatch validation against catalog definitions.
  Routed all UI call sites (`invoice_screen.dart`, `edit_document_screen.dart`, `document_item_form.dart`, `pos_cart.dart`, `quick_sale_screen.dart`) through `resolveLinePrice`.
- **Commit:** `77add4a`
- **Tests Added:** `test/audit/units_wholesale_fix_test.dart` (contact change preserves unit, POS cart wholesale unit price).
- **Mutation Verification:** Forced `unit: null` in `resolveLinePrice`; `units_wholesale_fix_test.dart` failed (`Expected: <75.0>, Actual: <8.0>`).

---

### BUG-3 / GAP-1: Quotation Wholesale Tier and Unit Parity
- **Severity:** Medium / Feature Parity
- **Root Cause:** [quotation_screen.dart](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/quotation_screen.dart) did not maintain state for custom units or wholesale tiers (`_selectedUnits`, `_selectedConversionFactors`, `_selectedPricingCategories`), nor did it pass them to `DocumentItemForm` or emit snapshot fields into `DocumentItemInput`.
- **Fix:** Updated `QuotationScreen` to maintain unit and tier state arrays, reprice on contact change via `resolveLinePrice`, pass selected unit state into `DocumentItemForm`, and populate `saleUnit`, `conversionFactor`, and `pricingCategory` in `DocumentItemInput`.
- **Commit:** `92cbdc0`
- **Tests Added:** `test/audit/units_wholesale_fix_test.dart` (quotation unit capture and conversion to invoice).
- **Mutation Verification:** Stripped `sale_unit` in quotation conversion; `units_wholesale_fix_test.dart` failed (`Expected: 'carton', Actual: <null>`).

---

### GAP-2: Document Detail Unit & Tier Display
- **Severity:** Low / UI Clarity
- **Root Cause:** [document_detail_screen.dart](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/document_detail_screen.dart) only displayed `item.quantity` and price, hiding whether the line was sold in a custom unit (carton, pack) or under a wholesale vs retail tier.
- **Fix:** Enhanced document detail item lines to display `${quantity} ${saleUnit}` and render a localized chip badge for wholesale (`جملة` / `Wholesale`) and retail (`تجزئة` / `Retail`).
- **Commit:** `8029678`

---

### GAP-3: Bulk Pricing Custom Units Warning
- **Severity:** Low / Safe Operation
- **Root Cause:** [bulk_pricing_screen.dart](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/bulk_pricing_screen.dart) adjusts base retail/wholesale prices in `products`, but packaging unit prices in `product_units` are independent absolute amounts. Users modifying base prices received no warning that secondary unit prices would remain unchanged.
- **Fix:** Added an informational warning banner on `BulkPricingScreen` and a confirmation modal notice when any selected product has custom units defined.
- **Commit:** `161bf3e`

---

### GAP-4: Duplicate Unit Name Validation
- **Severity:** Low / Data Cleanliness
- **Root Cause:** [product_form_screen.dart](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/product_form_screen.dart) allowed creating multiple packaging units with identical names (or names matching the base unit).
- **Fix:** Added trimmed, case-insensitive duplicate validation against existing unit rows and the product's base unit in both the modal unit dialog and the screen save action.
- **Commit:** `b45569f`

---

### P1–P4: Architectural Guards & Randomized Invariant Tests
- **P1 Randomized Invariant Tests:** Implemented [test/invariants/units_wholesale_invariants_test.dart](file:///data/data/com.termux/files/home/projects/waraqatak/test/invariants/units_wholesale_invariants_test.dart) running 60 randomized pseudo-fuzz iterations verifying invariants INV-1 through INV-9 across invoices, POS sales, cancellations, and product reporting.
- **P2 Architectural Guards:** Implemented [test/guards/architecture_guards_test.dart](file:///data/data/com.termux/files/home/projects/waraqatak/test/guards/architecture_guards_test.dart) with 3 static AST/token guards:
  - Guard a: Confirms no file outside `document_service.dart` calls `resolveItemPrice` directly.
  - Guard b: Confirms `DocumentItemForm` call sites provide `initialSaleUnit` and `initialConversionFactor`.
  - Guard c: Confirms no raw stock comparison patterns exist in `DatabaseHelper` outside `_assertSaleStockAvailable`.
- **P3 Invariant Rules Documentation:** Authored [docs/invariants_units_wholesale.md](file:///data/data/com.termux/files/home/projects/waraqatak/docs/invariants_units_wholesale.md) specifying INV-1 through INV-9.
- **P4 Codex / Agent Guidelines:** Appended the Units & Wholesale Hard Invariants to [AGENTS.md](file:///data/data/com.termux/files/home/projects/waraqatak/AGENTS.md) and [CLAUDE.md](file:///data/data/com.termux/files/home/projects/waraqatak/CLAUDE.md).
- **Commit:** `ccbe790`

---

## 3. Call Sites: Before and After Table

| Location | Prior Call Site / Logic | New Implementation |
|---|---|---|
| `lib/screens/invoice_screen.dart:450` | `resolveItemPrice(p, qty, tier)` (dropped unit) | `resolveLinePrice(product: p, quantity: qty, customerTier: tier, unit: item.saleUnit, conversionFactor: item.conversionFactor)` |
| `lib/screens/edit_document_screen.dart:363` | `resolveItemPrice(p, qty, tier)` (dropped unit) | `resolveLinePrice(product: p, quantity: qty, customerTier: tier, unit: item.saleUnit, conversionFactor: item.conversionFactor)` |
| `lib/widgets/document_item_form.dart:212` | `resolveItemPrice(widget.product, qty, tier)` | `resolveLinePrice(product: widget.product, quantity: qty, customerTier: tier, unit: _selectedUnit, conversionFactor: _conversionFactor)` |
| `lib/screens/quotation_screen.dart:362` | Omitted unit/tier arguments | Full unit, conversion factor, and tier state passed to `resolveLinePrice` |
| `lib/services/pos_cart.dart:181` | Manual tier check without packaging unit support | `resolveLinePrice(product: item.product, quantity: item.quantity, customerTier: customerTier, unit: item.unit, conversionFactor: item.conversionFactor)` |
| `lib/screens/quick_sale_screen.dart:312` | Direct price assignment on contact change | `resolveLinePrice` invoked per cart item with unit preservation |
| `lib/database/database_helper.dart` (insert/update/issue) | Per-line `stock < effectiveBaseQty` checks | `_assertSaleStockAvailable(txn, items, documentId: id)` aggregating by product |

---

## 4. Test Suite Execution & Verification

All single test runs were executed independently on Termux with zero failures:

| Test File | Result | Passed / Total | Notes |
|---|---|---|---|
| `test/guards/architecture_guards_test.dart` | **PASS** | 3 / 3 | Guards a, b, c verified |
| `test/audit/units_wholesale_fix_test.dart` | **PASS** | 7 / 7 | BUG-1, BUG-2, BUG-3 fixes verified |
| `test/audit/units_wholesale_audit_test.dart` | **PASS** | 10 / 10 | Regression audit suite |
| `test/invariants/units_wholesale_invariants_test.dart` | **PASS** | 1 / 1 (60 iters) | Invariants INV-1 to INV-9 verified |
| `test/services/document_service_test.dart` | **PASS** | 27 / 27 | Document totals and pricing tests |
| `test/services/pos_cart_test.dart` | **PASS** | 8 / 8 | POS cart behavior & limits |
| `test/database/pos_sale_db_test.dart` | **PASS** | 4 / 4 | Atomicity of POS sales & rollback |
| `test/database/inventory_integrity_db_test.dart` | **PASS** | 14 / 14 | Stock movements and integrity |
| `test/database/wholesale_pricing_phase1_test.dart` | **PASS** | 8 / 8 | Phase 1 wholesale pricing rules |
| `test/database/custom_sales_units_phase2_test.dart` | **PASS** | 9 / 9 | Phase 2 custom sales units |
| `test/database/wholesale_retail_phase3_test.dart` | **PASS** | 11 / 11 | Phase 3 wholesale & retail integration |
| `test/services/costing_test.dart` | **PASS** | 75 / 75 | Costing, COGS, and payment integrity |
| `test/services/ledger_test.dart` | **PASS** | 31 / 31 | Accounting and ledger correctness |
| `test/services/financial_correctness_test.dart` | **PASS** | 18 / 18 | Tax, rounding, and discount precision |
| `test/database/backup_restore_db_test.dart` | **PASS** | 9 / 9 | DB backup round-trip and safety |
| `test/services/pdf_builder_test.dart` | **PASS** | 31 / 31 | PDF builder and isolate sanitization |
| `test/services/play_compliance_test.dart` | **PASS** | 42 / 42 | Play Store gating & neutrality rules |
| `tool/check_play_compliance.sh` | **PASS** | OK | All 4 passes clean |

### Directory Static Analysis
- `dart analyze lib/services`: 0 issues found.
- `dart analyze lib/screens`: 0 issues found.
- `dart analyze lib/database`: 0 issues found.
- `dart analyze lib/widgets`: 0 issues found.

---

## 5. Scope & Boundary Conformance

A complete diff check against `audit/units-wholesale` confirmed:
- **Zero changes** to `lib/database/migrations/`
- **Zero changes** to DB version or schema definitions
- **Zero changes** to `MoneyUtils` or rounding logic
- **Zero changes** to `costing_service.dart` or COGS math
- **Zero changes** to `license_service.dart` or `activation_service.dart`
- **Zero changes** to `backup_service.dart` backup format

---

## 6. Items Not Verifiable in This Environment
- **Physical Touch Gestures & Mobile Screen Resizing:** Verified programmatically via widget tests and AST checks; actual multi-touch fluid scrolling requires an Android device.
- **Physical Thermal ESC/POS Hardware Printing:** Verified via PDF byte generation and `PdfDocumentBuilder` tests; direct Bluetooth/ESC/POS transmission requires physical hardware.

---

## 7. Manual Device Test Checklist

For validation on an Android phone running the APK:

1. **Multi-line Stock Validation (BUG-1):**
   - Create a product `Widget` with stock = 10.
   - In Invoice Screen, add line 1: `Widget`, qty 6.
   - Add line 2: `Widget`, qty 6.
   - Save invoice.
   - **Expected:** An error banner appears indicating insufficient stock (requested 12, available 10). Stock remains 10.

2. **Repricing on Contact Change (BUG-2):**
   - Create a customer `Wholesale Client` with wholesale tier enabled.
   - Create a product `Soda` with base retail price $10, and custom unit `Carton` (conversion factor 10, unit price $80).
   - In Invoice Screen, select `Soda`, choose unit `Carton` (price shows $80).
   - Change customer to `Wholesale Client`.
   - **Expected:** Unit remains `Carton` and line price remains $80. It does NOT revert to base retail or base wholesale price.

3. **Quotation Unit Selection (BUG-3):**
   - Open Quotations -> New Quotation.
   - Add product `Soda`, select unit `Carton`.
   - Save quotation.
   - Tap "Convert to Invoice".
   - **Expected:** Resulting invoice retains unit `Carton` with conversion factor 10.

4. **Duplicate Unit Prevention (GAP-4):**
   - Edit a product with base unit `Piece`.
   - Attempt to add a custom unit named `Piece`.
   - **Expected:** Form rejects with duplicate unit error.
   - Add custom unit `Box`. Attempt to add a second unit named `box`.
   - **Expected:** Form rejects case-insensitive duplicate.

5. **Bulk Pricing Notice (GAP-3):**
   - Navigate to Products -> Bulk Pricing.
   - Select products including `Soda` (which has custom unit `Carton`).
   - **Expected:** An informational warning appears indicating custom sales unit prices will not be adjusted.
