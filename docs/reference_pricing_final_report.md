# Reference Currency Pricing — Final Verification Report

**Branch:** `feat/reference-currency-pricing`  
**Base Branch:** `main`  
**Date:** 2026-11-07  
**Device Environment:** Termux Linux (Android userland, ARM64)

---

## 1. Phase 0 Results

### 1.1 Confirmation of Facts F1–F14

All facts F1 through F14 were inspected in the codebase during Phase 0 and confirmed:

| Fact | Status | Code Evidence & Verification Summary |
|---|---|---|
| **F1** | **CONFIRMED** | `DatabaseHelper.dbVersion = 26` (migrated from `25`). `onConfigure` runs `PRAGMA foreign_keys = ON;`. `_createTables` creates `products`, `product_units`, `app_settings`, `audit_log`. `_upgradeTables` contains incremental migration blocks with column existence guards ([`database_helper.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L125-L270)). |
| **F2** | **CONFIRMED** | Pure money utilities: `MoneyUtils.round(double, [int decimalDigits = 2])` safely returns `0.0` when `!value.isFinite`. `Currency.decimalDigitsForCode(code)` handles supported currency minor-unit precision ([`money_utils.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/utils/money_utils.dart#L10-L28)). |
| **F3** | **CONFIRMED** | `Product` and `ProductUnit` immutability: models previously used `x ?? this.x` in `copyWith`. Updated to support explicit null resets where appropriate (`priceCurrency: () => null`). `Product.toMap` converts `createdAt`/`updatedAt` with `toIso8601String()` ([`product.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/models/product.dart#L166-L225)). |
| **F4** | **CONFIRMED** | `insertProduct` runs in `db.transaction`, sets `average_cost` and `cost_status` from `purchasePrice`, and logs opening stock movement. `updateProduct` verifies stocked product cannot convert to service if stock > 0, and preserves cost/quantity columns ([`database_helper.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2535-L2645)). |
| **F5** | **CONFIRMED** | `syncProductUnits` deletes existing units and inserts new list. `insertProductUnit` and `updateProductUnit` validate `conversionFactor > 0` and non-empty `unitName` ([`database_helper.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2870-L3005)). |
| **F6** | **CONFIRMED** | Form lifecycle: `product_form_screen._save` previously ran separate transactions for product and units. Re-engineered to use atomic `DatabaseHelper.saveProductWithUnits`. Unit dialog captures reference currency and reference prices ([`product_form_screen.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/screens/product_form_screen.dart#L400-L480)). |
| **F7** | **CONFIRMED** | `CsvService` defines `csvHeaders`, lowercase header matching in `previewImport`, direct transaction writes in `applyImport`, audit row `'csv_import'` ([`csv_service.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/csv_service.dart#L25-L600)). |
| **F8** | **CONFIRMED** | `BulkPricingService.preview` computes in-memory diffs; `applyBatch` updates products inside a transaction. Preserves reference-driven price fields by skipping reference-bound prices ([`bulk_pricing_service.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/bulk_pricing_service.dart#L30-L160)). |
| **F9** | **CONFIRMED** | `DatabaseHelper.updateBusiness` prevents currency change when exchange rates or locked records exist. `business_setup_screen.dart` disables currency selector when locked or rates exist ([`business_setup_screen.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/screens/business_setup_screen.dart#L430-L450)). |
| **F10** | **CONFIRMED** | Document pricing isolation: `DocumentService.resolveItemPrice` and `resolveLinePrice` derive prices strictly from base-currency fields. `document_items` records base-currency snapshots only; reference pricing never touches sales/invoicing documents ([`document_service.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/document_service.dart#L150-L210)). |
| **F11** | **CONFIRMED** | `DatabaseHelper.getSetting` and `setSetting(key, value, {txn})` manage key-value settings. `logAuditEvent` writes to `audit_log` ([`database_helper.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2380-L2440)). |
| **F12** | **CONFIRMED** | `ProductsScreen` uses `refreshToken` and `_load()`. Card displays formatted `salePrice` and unit pricing badge ([`products_screen.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/screens/products_screen.dart#L500-L540)). |
| **F13** | **CONFIRMED** | `quick_sale_screen.dart` loads catalog in `_load()`. Catalog refresh reloads product prices without clearing active cart lines ([`quick_sale_screen.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/screens/quick_sale_screen.dart#L85-L140)). |
| **F14** | **CONFIRMED** | Documents store business base `currency_code`. Reference currencies and exchange rates are strictly excluded from documents and journal ledgers ([`database_helper.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L1250-L1300)). |

---

### 1.2 Callers of Product & Unit Database Methods

Every caller in `lib/` was inspected:

1. **`DatabaseHelper.insertProduct`**:
   - [`lib/database/database_helper.dart:2630`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2630) (method definition).
   - Internal helper: `_insertProductTxn` called from `saveProductWithUnits` ([`lib/database/database_helper.dart:2665`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2665)).
   - [`lib/services/product_service.dart:41`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/product_service.dart#L41): called by `ProductService.createProduct`.
2. **`DatabaseHelper.updateProduct`**:
   - [`lib/database/database_helper.dart:2637`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2637) (method definition).
   - Internal helper: `_updateProductTxn` called from `saveProductWithUnits` ([`lib/database/database_helper.dart:2667`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2667)).
   - [`lib/services/product_service.dart:46`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/product_service.dart#L46): called by `ProductService.updateProduct`.
3. **`DatabaseHelper.syncProductUnits`**:
   - [`lib/database/database_helper.dart:2997`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2997) (method definition).
   - Internal helper: `_syncProductUnitsTxn` called from `saveProductWithUnits` ([`lib/database/database_helper.dart:2674`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2674)).
4. **`DatabaseHelper.insertProductUnit`**:
   - [`lib/database/database_helper.dart:2899`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2899) (method definition).
5. **`DatabaseHelper.updateProductUnit`**:
   - [`lib/database/database_helper.dart:2941`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/database_helper.dart#L2941) (method definition).

---

### 1.3 `Product(` and `ProductUnit(` Constructions Outside Tests

| Construction | File & Line | Treatment / Refactoring |
|---|---|---|
| `Product(` constructor | [`lib/models/product.dart:106`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/models/product.dart#L106) | Standard const constructor, supports new reference pricing fields. |
| `Product.copyWith` | [`lib/models/product.dart:166`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/models/product.dart#L166) | Preserves reference fields by default; allows clearing via explicit value or sentinel. |
| `Product.fromMap` | [`lib/models/product.dart:229`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/models/product.dart#L229) | Deserializes `price_currency`, `reference_sale_price`, `reference_wholesale_price`, `reference_purchase_price`. |
| `Product(` in `ProductService.createProduct` | [`lib/services/product_service.dart:22`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/product_service.dart#L22) | Creates basic base-currency product; reference fields default to `null`. |
| `Product(` in `ProductService.updateProduct` | [`lib/services/product_service.dart:45`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/product_service.dart#L45) | **Refactored:** Previously reconstructed `Product` from scratch, dropping reference fields. Replaced with `final updated = product.copyWith(updatedAt: DateTime.now());` to safely preserve all reference pricing fields. |
| `Product(` in `product_form_screen._save` | [`lib/screens/product_form_screen.dart:406, 455`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/screens/product_form_screen.dart#L406-L455) | **Refactored:** Now derives and captures reference fields (`priceCurrency`, `referenceSalePrice`, `referenceWholesalePrice`, `referencePurchasePrice`). Routed through atomic `DatabaseHelper.saveProductWithUnits`. |
| `ProductUnit(` constructor | [`lib/models/product_unit.dart:41`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/models/product_unit.dart#L41) | Standard const constructor, supports `referenceCurrency`, `referenceSalePrice`, `referenceWholesalePrice`. |
| `ProductUnit.fromMap` | [`lib/models/product_unit.dart:69`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/models/product_unit.dart#L69) | Deserializes `reference_currency`, `reference_sale_price`, `reference_wholesale_price`. |
| `ProductUnit.copyWith` | [`lib/models/product_unit.dart:99`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/models/product_unit.dart#L99) | Preserves reference fields across copy mutations. |
| `ProductUnit(` in unit modal | [`lib/screens/product_form_screen.dart:710`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/screens/product_form_screen.dart#L710) | **Refactored:** Unit modal captures reference sale price and wholesale price when parent product uses reference pricing. |
| `ProductUnit(` in CSV import | [`lib/services/csv_service.dart:565`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/csv_service.dart#L565) | Parses unit from CSV row; reference currency fields remain `null` (CSV unit pricing is base-currency). |

---

## 2. Git History & Isolation Verification

### 2.1 Branch Before Current & Commit Count

From `git reflog`:
- Checkout event: `c60ddc4 HEAD@{22}: checkout: moving from l10n/batch4-merchant-wording to feat/reference-currency-pricing`
- Preceding branch name: `l10n/batch4-merchant-wording`

Command executed:
```bash
git log main..l10n/batch4-merchant-wording --oneline | wc -l
```
**Output:**
```
25
```

### 2.2 Git Diff Stat Against `main`

Command executed:
```bash
git diff --stat main...HEAD
```
**Output:**
```
 .github/workflows/ci.yml                    |   7 +
 docs/reference_pricing_verification.md      | 106 ++++
 lib/core/catalog_events.dart                |  15 +
 lib/database/database_helper.dart           | 400 ++++++++++---
 lib/database/reference_pricing_dao.dart     | 745 ++++++++++++++++++++++++
 lib/localization/app_localizations.dart     | 147 ++++-
 lib/models/exchange_rate.dart               | 182 ++++++
 lib/models/product.dart                     | 106 ++++
 lib/models/product_unit.dart                |  59 ++
 lib/models/reference_pricing_types.dart     | 178 ++++++
 lib/screens/bulk_pricing_screen.dart        |   9 +-
 lib/screens/business_setup_screen.dart      |  18 +-
 lib/screens/csv_import_export_screen.dart   |  17 +
 lib/screens/exchange_rates_screen.dart      | 798 +++++++++++++++++++++++++
 lib/screens/product_form_screen.dart        | 663 +++++++++++++++++----
 lib/screens/products_screen.dart            |  16 +
 lib/screens/quick_sale_screen.dart          |  12 +
 lib/screens/settings_screen.dart            |  14 +
 lib/services/backup_service.dart            |   9 +
 lib/services/bulk_pricing_service.dart      | 134 ++++-
 lib/services/csv_service.dart               | 316 ++++++++--
 lib/services/product_service.dart           |  22 +-
 lib/services/reference_pricing_service.dart | 227 ++++++++
 lib/utils/error_utils.dart                  |  23 +
 lib/utils/reference_pricing_math.dart       | 206 +++++++
 lib/widgets/reference_pricing_widgets.dart  | 214 +++++++
 test/reference_pricing_db_test.dart         | 862 ++++++++++++++++++++++++++++
 test/reference_pricing_math_test.dart       | 308 ++++++++++
 test/reference_pricing_widgets_test.dart    | 249 ++++++++
 29 files changed, 5785 insertions(+), 277 deletions(-)
```

### 2.3 Confirmation of NEVER-Touch Files

Verified that **zero** NEVER-touch files were modified:
- `documents`, `document_items`, `document_payments` schemas: **Untouched**.
- `accounts`, `journal_entries`, `journal_lines`: **Untouched**.
- `stock_movements`, `stocktake_sessions`, `stocktake_items`: **Untouched**.
- `lib/services/accounting/` directory: **Untouched**.
- `lib/services/pdf/` directory: **Untouched**.
- `lib/screens/reports/` directory: **Untouched**.
- `lib/services/document_service.dart`: **Untouched**.
- `lib/models/pos_cart.dart`: **Untouched**.
- `lib/screens/invoice_screen.dart`, `quotation_screen.dart`, `purchase_screen.dart`, `edit_document_screen.dart`, `custom_document_screen.dart`, `voucher_screen.dart`: **Untouched**.
- `lib/widgets/document_item_form.dart`: **Untouched**.
- `lib/services/inventory_costing_service.dart`: **Untouched**.

The only sales screen modified was `lib/screens/quick_sale_screen.dart` (+12 lines) exclusively to subscribe a `CatalogEvents.pricesChanged` listener to refresh product cards in memory when rates change.

---

## 3. Test Mapping (Spec vs Repository)

### 3.1 Pure Math Tests (M1–M5)
Located in [`test/reference_pricing_math_test.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/test/reference_pricing_math_test.dart):

| Spec Item | Test Name in Repository | Line | Status |
|---|---|---|---|
| **M1** | `'decimalPlaces handles standard, exponents, and edge cases'` | L24 | Exact |
| **M1** | `'isValidRate and isValidReferencePrice return false for non-finite values'` | L47 | Exact |
| **M2** | `'normalizes Arabic-Indic and Persian digits and decimal marks'` | L60 | Exact |
| **M2** | `'allowCommaDecimal behavior'` | L77 | Exact |
| **M2** | `'rejects signs, exponents, words, spaces, empty, multiple dots'` | L89 | Exact |
| **M3** | `'parseRate accepts valid bounds and at most 6 decimal places'` | L117 | Exact |
| **M3** | `'parseReferencePrice accepts 0 and up to 4 decimal places, rejects negatives and > 1e12'` | L143 | Exact |
| **M4** | `'assertValidRate throws ReferencePricingException with invalidRate'` | L173 | Exact |
| **M4** | `'assertValidReferencePrice throws ReferencePricingException with invalidPrice'` | L195 | Exact |
| **M5** | `'converts cleanly with rounding = 0'` | L217 | Exact |
| **M5** | `'converts with rounding steps 5, 50, 100'` | L242 | Exact |
| **M5** | `'range checks throw priceOutOfRange even if intermediate rounding brings it back'` | L291 | Exact |

### 3.2 Widget Tests (W1–W2)
Located in [`test/reference_pricing_widgets_test.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/test/reference_pricing_widgets_test.dart):

| Spec Item | Test Name in Repository | Line | Status |
|---|---|---|---|
| **W1** | `'PricingCurrencySelector W1 renders base currency and notifies on change'` | L86 | Exact |
| **W1** | `'PricingCurrencySelector W1 selecting base currency returns null'` | L119 | Exact |
| **W2** | `'PricingSelection.reconcile W2 all truth-table branches'` | L22 | Exact |
| **W2** | `'ReferencePriceField W2 renders suffixText and live helper reflects typing'` | L152 | Exact |
| **W2** | `'ReferencePriceField W2 validation rejects invalid reference prices'` | L213 | Exact |

### 3.3 Database, Integration & Guard Tests (D1–D19, D20, D21, T-static 1 & 2)
Located in [`test/reference_pricing_db_test.dart`](file:///data/data/com.termux/files/home/Projects/waraqatak/test/reference_pricing_db_test.dart):

| Spec Item | Test Name in Repository | Line | Status / Notes |
|---|---|---|---|
| **D1** | `'D1: Migration 25 -> 26 on a populated DB'` | L81 | Exact |
| **D2** | `'D2: 1000 -> 1100 -> 1000 returns exact original base prices'` | L113 | Exact |
| **D3** | `'D3: updateRateAndReprice reprices base prices of all products and units in currency, writes audit log, notifies CatalogEvents'` | L153 | Split / Exact |
| **D4** | `'D4: Unit identity, non-reference units, and conversion factors preserved during updateRateAndReprice'` | L222 | Split / Exact |
| **D5** | `'D5: Per-field rule derives only non-null reference prices'` | L287 | Exact |
| **D6** | `'D6: Rollback on rate update failure preserves previous rate'` | L333 | Split / Exact |
| **D7** | `'D7: Rollback on rate update failure leaves product and unit prices completely unchanged'` | L364 | Split / Exact |
| **D8** | `'D8: Re-entrancy throws repricingInProgress'` | L400 | Exact |
| **D9** | `'D9: Stored rate is used at write time'` | L437 | Exact |
| **D10** | `'D10: Implicit clear guard protects reference pricing'` | L468 | Exact |
| **D11** | `'D11: Currency change clears unit references'` | L511 | Exact |
| **D12** | `'D12: saveProductWithUnits atomicity rollback'` | L571 | Exact |
| **D13** | `'D13: Service-layer validation rejects invalid rates and reference prices'` | L612 | Split / Exact |
| **D14** | `'D14: Specific ReferencePricingError exception codes thrown for all failure modes'` | L655 | Split / Exact |
| **D15** | `'D15: updateBusiness blocked when exchange rates exist'` | L698 | Exact |
| **D16** | `'D16: Bulk pricing skips reference-driven products'` | L727 | Exact |
| **D17** | `'D17: CSV import/export round-trip'` | L780 | Exact |
| **D18** | `'D18: Backup and Restore preserves exchange_rates'` | L819 | Exact |
| **D19** | `'D19: ReferencePricingDao.verifyInvariants catches violations'` | L857 | Exact |
| **D20** | `'D20 (Benchmark): 5,000 products with 2 units each in one currency'` | L895 | Added (seeds 5,000 products + 10,000 units, measures ms) |
| **D21** | `'D21 (Backup Legacy Compatibility): Restore v25 payload without exchange_rates and reference columns through local, encrypted, and drive paths'` | L957 | Added (tests v25 payload across local, encrypted, drive) |
| **T-static (1)** | `'T-static (1): Sales and non-pricing code contains zero forbidden identifiers'` | L1049 | Exact (scans restricted files) |
| **T-static (2)** | `'T-static (2): Restricted directories (accounting, pdf, reports) contain zero forbidden identifiers'` | L1086 | Exact (scans accounting, pdf, reports directories) |

---

## 4. Backup & Restore Invariants

### 4.1 Existing Backup & Restore Paths
Three distinct paths exist in Waraqatak:
1. **Local Unencrypted Backup (`.waraq`):**
   - Created via `BackupService.createLocalBackup()` ([`backup_service.dart:67`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/backup_service.dart#L67)).
   - Restored via `BackupService.restoreFromFile(...)` or `BackupService.restoreFromJsonMap(...)` ([`backup_service.dart:370`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/backup_service.dart#L370)).
2. **Local Encrypted Backup (`.waraq`):**
   - Created via `BackupService.createEncryptedBackup(password)` using `BackupEncryptionService.encryptBackup` with AES-GCM-256 ([`backup_service.dart:78`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/backup_service.dart#L78)).
   - Restored via `BackupService.restoreFromEncryptedFile(file, password)` which decrypts to JSON and invokes `BackupService.restoreFromJsonMap`.
3. **Google Drive Cloud Backup:**
   - Uploaded via `GoogleDriveBackupService.uploadBackup` ([`google_drive_backup_service.dart:331`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/google_drive_backup_service.dart#L331)).
   - Restored via `GoogleDriveBackupService.restoreFromDrive(...)` ([`google_drive_backup_service.dart:404`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/google_drive_backup_service.dart#L404)), which downloads bytes, decrypts in-memory if encrypted, and delegates to `BackupService.restoreFromJsonMap`.

### 4.2 Tables & Columns Serialized
In `BackupService._buildBackupJson` ([`backup_service.dart:704-756`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/backup_service.dart#L704-L756)), the following 19 tables are serialized via `await db.query(...)`:
`businesses`, `contacts`, `products`, `product_units`, `documents`, `document_items`, `document_counters`, `document_payments`, `stock_movements`, `tax_profiles`, `payment_methods`, `stocktake_sessions`, `stocktake_items`, `audit_log`, `accounts`, `journal_entries`, `journal_lines`, `app_settings`, `exchange_rates`.

Because `db.query(table)` issues `SELECT * FROM <table>;`, every column defined in SQLite is captured.
- **Proof for `exchange_rates`:** Explicitly added to `_buildBackupJson` at line 751:
  ```dart
  'exchange_rates': await db.query('exchange_rates'),
  ```
- **Proof for 7 new columns:**
  - `products`: `price_currency`, `reference_sale_price`, `reference_wholesale_price`, `reference_purchase_price` are returned in `await db.query('products')`.
  - `product_units`: `reference_currency`, `reference_sale_price`, `reference_wholesale_price` are returned in `await db.query('product_units')`.

### 4.3 Restoration of v25-Shaped Payload
During `BackupService.restoreFromJsonMap`:
1. Schema columns are inspected via `PRAGMA table_info(table)` ([`backup_service.dart:392`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/services/backup_service.dart#L392)).
2. `sanitizeRow(row, cols)` drops non-existent keys.
3. In a v25-shaped payload, the 7 new columns are absent from the JSON map. When inserted into SQLite, SQLite sets them to their default: `NULL`.
4. `exchange_rates` is handled conditionally at lines 450–456:
   ```dart
   if (data.containsKey('exchange_rates') && data['exchange_rates'] is List) { ... }
   ```
   If omitted in a v25 backup, the table remains empty.
5. Invariant check: `ReferencePricingDao.verifyInvariants` verifies invariants I1..I4 only for records where reference currency is NOT NULL. When all new columns are `NULL`, `verifyInvariants` returns an empty list (`[]`), proving backward compatibility across all three restore paths.

---

## 5. Diagnostic & Repair Services Enumeration

- **`lib/services/database_diagnostic_service.dart`**:
  - Scanned for table/column enumerations.
  - Result: **Does NOT enumerate** reference pricing tables or columns. Its diagnostics focus exclusively on document items vs stock movements (`di.product_id = p.id`), accounting double-entry balance, and historical inventory costing (`cost_status`).
- **`lib/services/database_repair_service.dart`**:
  - Scanned for table/column enumerations.
  - Result: **Does NOT enumerate** reference pricing tables or columns.
- Dedicated invariant verification for reference pricing is encapsulated in [`ReferencePricingDao.verifyInvariants`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/reference_pricing_dao.dart#L650-L745).

---

## 6. Dropdown Form Field Style Convention

### 6.1 Project Convention
Across Waraqatak (e.g. [`lib/screens/business_setup_screen.dart:431-433`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/screens/business_setup_screen.dart#L431-L433)), Flutter's `DropdownButtonFormField` avoids the deprecated `value` parameter in favor of `initialValue` combined with an explicit `ValueKey`:
```dart
DropdownButtonFormField<String>(
  key: ValueKey('currency_dropdown_$_currencyCode'),
  initialValue: _currencyCode,
  items: Currency.supportedCurrencies.map(...),
  onChanged: ...
)
```

### 6.2 Confirmation for `PricingCurrencySelector`
[`lib/widgets/reference_pricing_widgets.dart:45-47`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/widgets/reference_pricing_widgets.dart#L45-L47) adheres strictly to this convention:
```dart
return DropdownButtonFormField<String>(
  key: ValueKey('pricing_currency_selector_$effectiveValue'),
  initialValue: effectiveValue,
  decoration: InputDecoration(...),
  items: [ ... ],
  onChanged: ...
);
```
No analyzer deprecation warnings are generated.

---

## 7. Performance Architecture & Benchmarks

### 7.1 Architecture for Large Catalogs (5,000 Products + 10,000 Units)
Repricing performance in `ReferencePricingDao.repriceCurrency` ([`reference_pricing_dao.dart:419-480`](file:///data/data/com.termux/files/home/Projects/waraqatak/lib/database/reference_pricing_dao.dart#L419-L480)) is optimized for scale:
1. **Single Transaction & Batching:**
   Uses `final batch = txn.batch();` inside `db.transaction(...)`.
2. **Selective Filtering:**
   Only selects products where `price_currency = ?`, skipping base-currency products entirely.
3. **Pure Math Calculations:**
   Derived prices are calculated in-memory with `ReferencePricingMath.convert` and queued into the batch.
4. **Zero Interleaved Roundtrips:**
   `await batch.commit(noResult: true);` issues a single SQLite bulk write operation.

### 7.2 Benchmark Timing
Under benchmark execution with 5,000 products and 2 units each (15,000 entities):
- **`updateRateAndReprice`**: **NOT MEASURED** (Awaiting CI Run Numbers)
- **`recalculateAll`**: **NOT MEASURED** (Awaiting CI Run Numbers)
- Benchmark test `D20 (Benchmark): 5,000 products with 2 units each in one currency` has been added to `test/reference_pricing_db_test.dart` and will print exact measured milliseconds in CI execution.

*(Note: On local Termux environment, native SQLite FFI dynamic library loading dlopen fails with `libc.so.6 not found` due to Android Bionic libc userland; test group is explicitly skipped with `~21` skipped tests. Full SQLite tests run unskipped on the Ubuntu CI runner with `libsqlite3-dev` installed).*

---

## 8. Deviations & Unverified Items

### 8.1 Deviations from Specification
**None.** The implementation strictly conforms to the specification:
- Exact file layout and separation of concerns maintained (no SQL in services/widgets, no DB in math utility).
- All 14 Phase 0 facts confirmed.
- Transaction rollback and re-entrancy protection fully enforced.
- Single conversion code path (`ReferencePricingMath.convert`) used everywhere.
- Audit logs and `CatalogEvents` correctly triggered.

### 8.2 Items Not Verifiable Locally in Termux
1. **Native SQLite FFI Execution in Local Termux Shell:**
   Termux Android userland lacks standard GNU `libc.so.6`. SQLite FFI in `sqflite_common_ffi` requires glibc when running on Linux architecture.
   - **Local Status:** Database tests D1–D21 are **NOT executed locally**; they are probed at declaration time and explicitly reported as **SKIPPED** (`~21`).
   - **CI Status:** Previous GitHub Actions run `42337733012` on Ubuntu Linux tested commit `8b8d212` (which contained early returns). The current commit containing hardened test cases D20, D21, and unskipped CI enforcement has **NOT been pushed to CI**.
   - **Explicit Confirmation:** Tests **D1–D21 have NOT been executed anywhere yet**. They will execute for the first time once pushed to GitHub Actions CI.
2. **Physical UI Frame Rendering:**
   Headless Linux / Termux CLI lacks a display server or Android emulator for visual rendering. Widget structure and behavior were verified via headless `testWidgets` in `test/reference_pricing_widgets_test.dart`.

---

## 9. Final Verification Check (Double-Check)

### 9.1 Static Analysis (`dart analyze`)
```bash
$ dart analyze
Analyzing waraqatak...
No issues found!
```
- **Total Warnings:** 0
- **Total Errors:** 0
- **Total Lints:** 0

### 9.2 Test Suite Execution
```bash
$ flutter test test/reference_pricing_math_test.dart test/reference_pricing_widgets_test.dart
00:18 +17: All tests passed!

$ flutter test test/reference_pricing_db_test.dart
00:26 +2 ~21: 21 skipped tests.
00:26 +2 ~21: All other tests passed!
```
- **Math & Widget Suite:** 17 tests passed (12 pure math + 5 widget/reconcile tests).
- **Database & Static Guard Suite (Termux Local):**
  - 2 static guard tests passed (`T-static (1)` & `T-static (2)`).
  - 21 database tests explicitly marked as **SKIPPED** (`~21`) with reason `Native SQLite unavailable: dlopen failed: library "libc.so.6" not found`.
  - Zero early returns; tests are impossible to report as passed without running assertions.
- **CI Enforcement:** On Ubuntu CI, `libsqlite3-dev` is installed and the CI workflow asserts that 0 tests are skipped (fails build if any test is skipped).
