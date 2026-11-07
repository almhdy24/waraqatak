# Reference Pricing Verification — Phase 0

## 1. Confirmation of Facts F1–F14

- **F1 (DatabaseHelper structure):** Confirmed. `dbVersion = 25`. `onConfigure` executes `PRAGMA foreign_keys = ON;`. `_createTables` creates `products`, `product_units`, `app_settings(key,value)`, `audit_log(action, entity_type, entity_id, details, timestamp)`. `_upgradeTables` uses `columnExists` and `tableExists`, with the last block `if (oldVersion < 25 && newVersion >= 25)`. Visible-for-testing helpers `createTablesForTest` and `upgradeTablesForTest` are present.
- **F2 (MoneyUtils and Currency):** Confirmed. `MoneyUtils.round(double, [int decimalDigits = 2])` exists and returns `0.0` when `!value.isFinite`. `Currency.decimalDigitsForCode(code)` exists.
- **F3 (Product & ProductUnit copyWith/toMap):** Confirmed. Both models use `x ?? this.x` in `copyWith` (cannot reset to null). `Product.toMap` converts `createdAt` and `updatedAt` with `toIso8601String()`. `ProductUnit` contains `productId`.
- **F4 (insertProduct / updateProduct):** Confirmed. `insertProduct` runs in `db.transaction`, sets `average_cost` and `cost_status` from `purchasePrice`, and creates an opening stock movement. `updateProduct` runs in `db.transaction`, queries `stock_quantity` and `type`, rejects stocked product -> service conversion if active stock > 0, and strips `stock_quantity`, `average_cost`, and `cost_status` from the update map.
- **F5 (syncProductUnits & unit CRUD):** Confirmed. `syncProductUnits` deletes all existing units of a product and inserts the new list with `map.remove('id')`. `insertProductUnit` and `updateProductUnit` validate `conversionFactor > 0` and non-empty `unitName`.
- **F6 (Product Form & Unit Dialog):** Confirmed. `product_form_screen._save` constructs a new `Product(...)`, calls `insertProduct`/`updateProduct`, then `syncProductUnits` in two separate transactions. Error presentation routes through `ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n)`. Unit dialog builds a new `ProductUnit` and sets `wholesalePrice` null when wholesale pricing is disabled. Price inputs use `double.tryParse`. Unsaved changes are detected via `_isDirty`.
- **F7 (CSV Service):** Confirmed. `csvHeaders` is a const list. `exportProducts` writes headers followed by rows (and `templateOnly` outputs a sample row). `previewImport` matches column headers in lowercase. `CsvParsedRow`, `CsvImportPreview`, and `CsvImportResult` exist. `applyImport` runs a transaction and writes directly to `products` and `product_units`. `errors` is defined on `CsvImportResult`. Messages are hard-coded Arabic strings. Audit row `'csv_import'` is logged.
- **F8 (Bulk Pricing Service):** Confirmed. `BulkPricingService.preview` builds `BulkPricePreviewItem` objects in memory. `applyBatch` updates `products` directly inside a transaction. Targets include `sellingPrice`, `purchasePrice`, `wholesalePrice`, and `both`. `BulkPriceResult` includes `affectedCount`.
- **F9 (Business Setup & Currency Lock):** Confirmed. `DatabaseHelper.updateBusiness` throws `StateError` if currency is changed while `_isCurrencyLockedTxn` is true. `business_setup_screen.dart` uses `Currency.supportedCurrencies` and disables currency selection when locked.
- **F10 (Document Pricing Isolation):** Confirmed. `DocumentService.resolveItemPrice` and `resolveLinePrice` derive prices using unit/product base prices and conversion factors. All sales screens read prices through these methods. `document_items` stores a base-currency price snapshot (`price`).
- **F11 (Settings and Audit in DB Helper):** Confirmed. `DatabaseHelper.getSetting` and `setSetting(key, value, {txn})` exist. `logAuditEvent` catches and swallows errors.
- **F12 (Products Screen Refresh & Card):** Confirmed. `ProductsScreen` has `refreshToken` parameter and `_load()`. `_ProductCard` formats `product.salePrice` using `priceFmt` and displays `l10n.unitPrice`.
- **F13 (Quick Sale Screen):** Confirmed. `quick_sale_screen.dart` loads business, active products, payment methods, and product units once in `initState` via `_load()`. Calling `_load()` again reloads catalog data without clearing the cart. Products are added to cart via `_cart.add(p, ...)`.
- **F14 (Documents Currency):** Confirmed. Documents store business `currency_code`; reference currencies are never stored in documents or accounting.

---

## 2. Product and ProductUnit Callers & Constructions Outside Tests

### Callers of Database Methods
1. `DatabaseHelper.insertProduct`:
   - `lib/database/database_helper.dart` (definition)
   - `lib/screens/product_form_screen.dart`: builds `Product` from form inputs (to be replaced by `saveProductWithUnits`).
   - `lib/services/product_service.dart`: `createProduct` builds a new `Product` from scratch (new product creation).
2. `DatabaseHelper.updateProduct`:
   - `lib/database/database_helper.dart` (definition)
   - `lib/screens/product_form_screen.dart`: builds `Product` from form inputs (to be replaced by `saveProductWithUnits`).
   - `lib/services/product_service.dart`: `updateProduct` builds a brand new `Product` from scratch. **RISK:** Drops reference fields. Must be refactored in Step 5 to `product.copyWith(updatedAt: DateTime.now())`.
3. `DatabaseHelper.syncProductUnits`:
   - `lib/database/database_helper.dart` (definition)
   - `lib/screens/product_form_screen.dart`: called immediately after insert/update (to be replaced by `saveProductWithUnits`).
4. `DatabaseHelper.insertProductUnit`:
   - `lib/database/database_helper.dart` (definition)
5. `DatabaseHelper.updateProductUnit`:
   - `lib/database/database_helper.dart` (definition)

### Constructions of `Product(`
- `lib/models/product.dart`: constructor, `fromMap`, `copyWith`.
- `lib/screens/product_form_screen.dart`: `Product(...)` constructed in `_save` (re-engineered in Step 12).
- `lib/services/product_service.dart:22`: `ProductService.createProduct` (new product).
- `lib/services/product_service.dart:45`: `ProductService.updateProduct` (rebuilt from scratch -> will fix in Step 5 to `copyWith`).

### Constructions of `ProductUnit(`
- `lib/models/product_unit.dart`: constructor, `fromMap`, `copyWith`.
- `lib/screens/product_form_screen.dart:398`: unit modal builder (re-engineered in Step 12).
- `lib/services/csv_service.dart:513`: parses unit from CSV row (unit reference prices not supported in CSV).

---

## 3. Direct Writers to Product / Unit Prices in `lib/`

- `lib/services/bulk_pricing_service.dart`: `applyBatch` updates `products` (`sale_price`, `wholesale_price`, `purchase_price`) with `txn.update`.
- `lib/services/csv_service.dart`: `applyImport` updates/inserts `products` (`sale_price`, `purchase_price`, `wholesale_price`) and inserts `product_units` (`sale_price`, `wholesale_price`).
- `lib/services/backup_service.dart`: `restoreFromJsonMap` inserts restored table rows into `products` and `product_units`.

No other raw SQL or transaction writes to catalog price columns exist in `lib/`.

---

## 4. Backup & Restore Mechanism

- `BackupService._buildBackupJson` serializes database tables to a JSON payload with metadata.
- `BackupService.restoreFromJsonMap` restores data into the currently open database (`DatabaseHelper.instance.database`). It does not reopen the DB with `openDatabase`, meaning `onUpgrade` does not run during restore itself.
- Instead, `onUpgrade` runs during app startup when `DatabaseHelper.database` initializes.
- Existing restore logic queries `PRAGMA table_info(table)` and uses `sanitizeRow` to discard keys not present in the current schema. Older backups lacking new v26 columns will restore with `NULL` for those columns.
- In Step 10: `exchange_rates` must be added to `_buildBackupJson` and `restoreFromJsonMap` (with existence checks).

---

## 5. Schema and Column Enumerators in `lib/`

- Files referencing `product_units`:
  - `lib/database/database_helper.dart`
  - `lib/screens/bulk_pricing_screen.dart`
  - `lib/services/backup_service.dart`
  - `lib/services/csv_service.dart`
- Files referencing `wholesale_price`:
  - `lib/database/database_helper.dart`
  - `lib/models/product.dart`
  - `lib/models/product_unit.dart`
  - `lib/services/bulk_pricing_service.dart`
  - `lib/services/csv_service.dart`
- Files referencing `sqlite_master`:
  - `lib/database/database_helper.dart`
  - `lib/services/accounting/journal_reconciliation_service.dart`
  - `lib/services/backup_service.dart`
  - `lib/services/database_diagnostic_service.dart`

---

## 6. Hosting of QuickSaleScreen and ProductsScreen & Cart API

- `main_shell.dart`: Hosts `ProductsScreen(refreshToken: _productsRefreshToken)` inside navigation.
- `home_screen.dart`: Pushes `QuickSaleScreen` via `Navigator.push`.
- `pos_cart.dart`: API for emptiness check is `posCart.isEmpty` (getter: `bool get isEmpty => _lines.isEmpty`).

---

## 7. SDK Constraint & DropdownButtonFormField Conventions

- `pubspec.yaml`: `sdk: '>=3.11.0 <4.0.0'`.
- `DropdownButtonFormField`: Uses `initialValue: value` with `Key` rather than deprecated `value:` parameter.
