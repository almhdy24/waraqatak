# Pro Feature Gating & Modular Isolation Audit

**Project:** Waraqatak (ورقتك) Flutter App (`com.elmahdi.waraqatak`)  
**Branch:** `feat/pro-gating-currency-wholesale`  
**Date:** 2026-11-08  
**Audit Scope:** Reference Currency Pricing & Wholesale/Retail Tiered Pricing  

---

## 1. Executive Summary

This audit maps every place touched by two advanced commercial features in Waraqatak:
1. **Reference-Currency Pricing & Exchange Rates:** Manual exchange rate management, reference currency selection, automatic recalculation of base-currency catalog prices from secondary reference rates, and rounding rules.
2. **Wholesale & Retail Tiered Pricing:** Business-level wholesale toggle, wholesale catalog prices and minimum order quantities, customer-level default tier assignment ('retail' vs 'wholesale'), and line-level price-type selection across sales documents.

Currently, both features are mixed directly into core catalog, transaction, and UI components without modular isolation, and neither feature is restricted to Pro subscribers. Free users currently have unrestricted access to both features.

This audit details the exact touchpoints, architectural mixing, and the blueprint for clean modularization and entitlement-based gating.

---

## 2. Feature 1: Reference Currency & Exchange Rates

### 2.1 Database Layer

#### Tables & Columns
- **`exchange_rates` table:**
  - `code TEXT PRIMARY KEY` (3-letter currency code, e.g. 'USD', 'SAR', 'EUR').
  - `name_ar TEXT NOT NULL`, `name_en TEXT NOT NULL`, `symbol TEXT NOT NULL`.
  - `rate REAL NOT NULL` (conversion rate relative to base currency, satisfying `isValidRate > 0`).
  - `is_manual INTEGER NOT NULL DEFAULT 1`.
  - `is_active INTEGER NOT NULL DEFAULT 1`.
  - `updated_at TEXT NOT NULL`.
- **`products` table columns:**
  - `price_currency TEXT` (null for base currency products, or matching `exchange_rates.code`).
  - `reference_sale_price REAL` (stored price in reference currency).
  - `reference_wholesale_price REAL` (stored wholesale price in reference currency).
  - `reference_purchase_price REAL` (stored purchase cost in reference currency).
  - Index: `idx_products_price_currency ON products(price_currency)`.
- **`product_units` table columns:**
  - `reference_currency TEXT` (must match parent `products.price_currency`).
  - `reference_sale_price REAL`.
  - `reference_wholesale_price REAL`.
- **`settings` table keys:**
  - `reference_pricing_rounding`: Integer step for converted base-currency price rounding (0 = none, 1, 5, 10, 50, 100, 500, 1000).

#### Database Operations & DAO
- **`lib/database/reference_pricing_dao.dart` (756 lines):**
  - Manages rates CRUD, product linking, catalog repricing transactions, invariant audits (I1..I5), and setting read/writes.
  - Mixes reference pricing with wholesale prices: updates both `sale_price` and `wholesale_price` during currency conversions.
- **`lib/database/database_helper.dart`:**
  - `isCurrencyLocked()` checks whether any exchange rate exists to prevent changing base business currency.
  - Table creation and schema migrations 27/28.

### 2.2 Application Services & Logic

- **`lib/services/reference_pricing_service.dart` (227 lines):**
  - Static facade coordinating transactions between `DatabaseHelper` and `ReferencePricingDao`.
  - Methods: `getRates()`, `hasRates()`, `getRounding()`, `setRounding()`, `setCurrencyActive()`, `deleteCustomCurrency()`, `updateRate()`, `repriceAll()`, `saveProductReferencePricing()`, `unlinkProduct()`, `getStats()`, `auditInvariants()`.
- **`lib/utils/reference_pricing_math.dart` (143 lines):**
  - Math utility for currency multiplication, division, validation, and rounding.
- **`lib/services/bulk_pricing_service.dart`:**
  - Imports `ReferencePricingDao` and skips reference-priced products during standard base-currency bulk updates.
- **`lib/services/csv_service.dart`:**
  - Exports and imports `price_currency`, `reference_sale_price`, `reference_wholesale_price`, `reference_purchase_price`.
- **`lib/services/backup_service.dart`:**
  - Exports and restores the `exchange_rates` table and product reference columns.

### 2.3 UI Screens & Widgets

- **`lib/screens/exchange_rates_screen.dart` (798 lines):**
  - Full screen for editing exchange rates, creating custom currencies, configuring rounding rules, archiving currencies, and triggering full catalog repricing with live progress dialog.
- **`lib/screens/settings_screen.dart` (line 330):**
  - Displays `ListTile` navigation to `ExchangeRatesScreen` under "General Settings" without entitlement gating.
- **`lib/screens/product_form_screen.dart`:**
  - Shows pricing currency selector dropdown, reference prices input fields, live converted base price preview badge, and "Manage Exchange Rates" action button.
- **`lib/screens/business_setup_screen.dart`:**
  - Calls `ReferencePricingService.hasRates()` to lock base currency if rates exist.
- **`lib/widgets/reference_pricing_widgets.dart` (280 lines):**
  - `ReferencePricingBadge`, `ReferencePriceDisplay`, input formatters.

---

## 3. Feature 2: Wholesale & Retail Tiered Pricing

### 3.1 Database Layer

#### Tables & Columns
- **`businesses` table:**
  - `wholesale_pricing_enabled INTEGER NOT NULL DEFAULT 0` (master switch).
- **`products` table:**
  - `wholesale_price REAL` (retail selling price alternative).
  - `wholesale_min_quantity REAL` (minimum base quantity required to qualify for wholesale tier).
  - `reference_wholesale_price REAL` (stored wholesale price in reference currency).
- **`product_units` table:**
  - `wholesale_price REAL` (unit-level wholesale override).
  - `reference_wholesale_price REAL`.
- **`contacts` table:**
  - `pricing_category TEXT NOT NULL DEFAULT 'retail'` ('retail' vs 'wholesale').
- **`document_items` table:**
  - `pricing_category TEXT` (persisted tier applied to the line: 'retail', 'wholesale', or null for legacy/purchase).

### 3.2 Application Services & Logic

- **`lib/services/document_service.dart`:**
  - `resolveItemPrice()` & `resolveLinePrice()`:
    - Authoritative single entry point for pricing calculation.
    - If `wholesalePricingEnabled` is false, strictly returns effective retail price.
    - If `targetCategory == 'wholesale'`, checks `candidateWholesalePrice` and validates `baseQty >= minBaseQty`.
- **`lib/services/pos_cart.dart`:**
  - Holds `_wholesalePricingEnabled` boolean state and recalculates line prices when customer pricing category changes.
- **`lib/services/csv_service.dart`:**
  - Exports and imports `wholesale_price` and `wholesale_min_quantity` for products and units.
- **`lib/services/backup_service.dart`:**
  - Preserves `wholesale_pricing_enabled` and line `pricing_category` snapshots across backups.

### 3.3 UI Screens & Widgets

- **`lib/screens/settings_screen.dart` (lines 225-255):**
  - Displays `SwitchListTile` for "Wholesale Pricing" (`wholesalePricing`) directly in main settings without any Pro license gate.
- **`lib/screens/financial_settings_screen.dart`:**
  - Preserves business `wholesalePricingEnabled` state during updates.
- **`lib/screens/product_form_screen.dart`:**
  - Displays `_wholesalePriceController` and `_wholesaleMinQuantityController` when business has `wholesalePricingEnabled = true`.
  - Allows entering unit wholesale prices in `_showUnitDialog`.
- **`lib/screens/contact_form_screen.dart` (lines 229-300):**
  - Renders customer pricing category dropdown ('retail' vs 'wholesale') when `_wholesalePricingEnabled` is true.
- **`lib/screens/invoice_screen.dart` & `lib/screens/quick_sale_screen.dart` & `lib/screens/quotation_screen.dart` & `lib/screens/edit_document_screen.dart`:**
  - Displays document-level pricing tier selector (`retail` / `wholesale`).
  - Auto-switches pricing category when customer with wholesale assignment is chosen.
  - Passes `wholesalePricingEnabled` and `pricingCategory` into `DocumentItemForm`.
- **`lib/widgets/document_item_form.dart`:**
  - Shows price-type radio selector / toggle chips (`Retail` vs `Wholesale`) when `wholesalePricingEnabled == true` and not purchase.

---

## 4. Current State: Logic Mixing & Coupling Hotspots

1. **Mixed into Core Product Form (`product_form_screen.dart`):**
   - The screen is 1,600+ lines. Wholesale and reference currency logic are intertwined with core product validation, unit setup, and barcode scanning.
   - If reference pricing is active, it overrides wholesale and sale price controller values.
2. **Mixed into Settings (`settings_screen.dart`):**
   - Wholesale switch and Exchange Rates navigation tile sit alongside basic backup, theme, and company details without feature checks.
3. **Mixed into Sales Document Screens (`invoice_screen.dart`, `quick_sale_screen.dart`, etc.):**
   - Every sales screen checks `_business?.wholesalePricingEnabled == true` directly and renders custom tier chips.
4. **Scattered Entitlement Evaluation:**
   - Some screens call `LicenseService.instance.checkEntitlement()`, while others use `FeatureAccess.canAccess()`.
   - Neither `Feature.referenceCurrency` nor `Feature.wholesalePricing` exists in `enum Feature` or `FeatureAccess.proFeatures`.

---

## 5. Entitlement & Gating Architecture

### 5.1 "Free" Definition
Under the existing licensing model in `lib/models/entitlement.dart`:
- **Free User:** Any installation where `EntitlementState.isSubscriptionActive == false` (i.e. `status != EntitlementStatus.trialActive && status != EntitlementStatus.licensed`). This includes new installs with expired trials, unlicensed installs, expired licenses, and revoked licenses.
- **Pro User:** Any installation where `isSubscriptionActive == true`.

### 5.2 Central Feature Gate Strategy
We will extend `enum Feature` in `lib/services/feature_access.dart` (or provide a dedicated `ProFeatureGate` / `FeatureGate`):
- `Feature.referenceCurrency` (Pro)
- `Feature.wholesalePricing` (Pro)

Both features will be registered in `FeatureAccess.proFeatures`.

For Free users:
- **UI Gating:** Entry points are completely hidden (no disabled buttons, no locked chips, no half-visible cards).
  - Settings: Hide Exchange Rates tile and Wholesale Pricing switch.
  - Product Form: Hide Pricing Currency section and Wholesale Price fields.
  - Contact Form: Hide Customer Pricing Category dropdown.
  - Sales/POS/Invoices: Hide Tier selection chips (`retail`/`wholesale`); treat all documents as retail.
- **Service/Data Gating:**
  - If a Free user attempts to call `ReferencePricingService.updateRate()` or reprice, the service rejects the operation or returns early without mutations.
  - In `DocumentService.resolveLinePrice()` and `resolveItemPrice()`: even if `business.wholesalePricingEnabled` was previously set to true in SQLite, when the user is Free, `wholesalePricingEnabled` is treated as strictly `false`.
  - CSV Import: If a Free user imports a CSV with reference currencies or wholesale prices, the importer safely falls back to standard retail base pricing without throwing errors.

---

## 6. Downgrade & Upgrade Safety Rules

1. **Zero Data Loss on Downgrade:**
   - When Pro expires or trial ends, `exchange_rates` rows, `products.price_currency`, `products.reference_*`, and `products.wholesale_*` remain intact in SQLite. No rows or columns are deleted.
2. **Deterministic Free Fallback:**
   - A product with reference currency continues to sell and display using its already-computed `products.sale_price` (in base currency).
   - A product with wholesale prices sells strictly at `products.sale_price` (retail price).
   - Past invoices, receipts, and journal entries preserve historical prices and `document_items.pricing_category` snapshots. Historical reports remain 100% accurate.
3. **Seamless Upgrade Restoration:**
   - When a user enters a valid license key or starts an active trial, the feature gate immediately opens: previous exchange rates, currency selections, and wholesale tiers re-appear without user intervention.
4. **Backup & Restore Compatibility:**
   - Backups created by a Pro user can be restored cleanly on a Free installation. The data is preserved in the database, while the UI adheres to the Free restrictions.

---

## 7. Plan for Isolation & Implementation (Steps 2–5)

1. **Module Creation:**
   - Create `lib/features/reference_currency/` with clean public API facade (`reference_currency_feature.dart`).
   - Create `lib/features/wholesale/` with clean public API facade (`wholesale_feature.dart`).
2. **Central FeatureGate:**
   - Integrate `referenceCurrency` and `wholesalePricing` into `FeatureAccess` and provide a reactive / synchronous `FeatureGate` helper.
3. **Screen Refactoring:**
   - Refactor `settings_screen.dart`, `product_form_screen.dart`, `contact_form_screen.dart`, and sales screens (`invoice_screen.dart`, `quick_sale_screen.dart`, `quotation_screen.dart`, `edit_document_screen.dart`) to consume the feature facades.
4. **Exchange Rate Validation Polish:**
   - Positive rate validation, bounds checking, and clean number formatting.
5. **Localization:**
   - Add concise, merchant-friendly Arabic and English strings in `app_localizations.dart`.
6. **Testing:**
   - Comprehensive test suite verifying Free/Trial/Pro gating, downgrade behavior, upgrade restoration, and core flows.
