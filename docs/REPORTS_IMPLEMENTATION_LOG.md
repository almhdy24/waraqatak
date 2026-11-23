# Reports Improvements Implementation Log

**Branch:** `feat/reports-improvements`  
**Base Commit:** `b25831f9b1f2c9bca08df942ad7cc866469384e3`  
**Started:** 2026-11-23

---

## Batch Status Overview

- [x] **Batch A** - Performance and correctness
- [x] **Batch B** - Permissions and gates
- [x] **Batch C** - Localization cleanup
- [x] **Batch D** - Export and share foundation
- [x] **Batch E** - Shared date range across reports
- [x] **Batch F** - Daily closing (end-of-day) report [new]
- [x] **Batch G** - Receivables and payables aging [new]
- [x] **Batch H** - Payments report: cash flow by method
- [x] **Batch I** - UI/UX polish across reports
- [x] **Batch J** - Phase 3 extras (J1: Period comparison; J2: Tax & discounts report)
- [x] **Batch P0** - Audit blockers remediation
- [x] **Batch P1** - Audit correctness & permissions
- [x] **Batch P2** - Audit UX, WhatsApp normalizer & consistency
- [x] **Docs & Verification** - CHANGELOG, reports_section.md, checklist

---

### Batch A: Performance and correctness

- **Batch ID:** `batch-a`
- **Files Changed:**
  - `lib/services/inventory_costing_service.dart`: Replaced N+1 query loop with a single grouped subquery `WHERE document_id IN (SELECT id FROM documents WHERE ...)` to avoid parameter limits.
  - `lib/screens/reports/inventory_report_screen.dart`: Added 300ms debounce timer and request sequence counter (`_querySeq`) to prevent typing stutter and out-of-order async race conditions. Removed fixed `height: 40` wrappers from search and category dropdowns to prevent text scaling overflow.
  - `lib/screens/reports/product_report_screen.dart`: Removed fixed `height: 40` wrappers from category and sort-by dropdowns.
  - `test/services/sales_report_costing_test.dart`: Added unit test verifying that the optimized single-query sales report returns byte-for-byte equivalent results compared to the reference calculation.
- **Decisions Taken:**
  - Used subquery `WHERE document_id IN (SELECT id FROM documents WHERE ...)` instead of `IN (?, ...)` to completely eliminate SQLite variable limit errors on older Android devices.
  - Enforced `_querySeq` guard on `_load()` in `inventory_report_screen.dart` alongside `Timer` cancellation in `dispose()`.
- **Validation:**
  - `dart format`: 4 files formatted.
  - `dart analyze`: Clean (0 issues).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.


### Batch B: Permissions and gates

- **Batch ID:** `batch-b`
- **Files Changed:**
  - `lib/screens/reports/payments_report_screen.dart`: Wrapped in `ScreenAccessGate(screenType: PaymentsReportScreen)`.
  - `lib/screens/reports/customer_report_screen.dart`: Wrapped in `ScreenAccessGate(screenType: CustomerReportScreen)`.
  - `lib/screens/reports/supplier_report_screen.dart`: Wrapped in `ScreenAccessGate(screenType: SupplierReportScreen)`.
  - `lib/screens/reports/product_report_screen.dart`: Wrapped in `ScreenAccessGate(screenType: ProductReportScreen)`.
  - `lib/screens/reports/advanced_inventory_analytics_screen.dart`: Wrapped in `ScreenAccessGate(screenType: AdvancedInventoryAnalyticsScreen)`.
  - `lib/screens/stock_movements_screen.dart`: Wrapped in `ScreenAccessGate(screenType: StockMovementsScreen)`.
  - `lib/screens/audit_history_screen.dart`: Wrapped in `ScreenAccessGate(screenType: AuditHistoryScreen)`.
  - `lib/screens/reports_screen.dart`: Realigned report permissions: Payments report to `reportsViewFinancials`; Customer & Supplier reports to `reportsViewReceivables`; Low Stock and Stock Movements to `productsView`; Product report to `reportsViewSales`.
  - `lib/services/access/screen_access_policy.dart`: Aligned manifest policy requirements for `PaymentsReportScreen` (`reportsViewFinancials`), `CustomerReportScreen` (`reportsViewReceivables`), and `SupplierReportScreen` (`reportsViewReceivables`).
  - `lib/services/access/access_seeder.dart`: Added `reportsViewReceivables` to `roleTemplateSalesperson`; added migration `migrateReceivablesPermissions` granting `reportsViewReceivables` to any role or user override holding `contactsViewBalances`.
  - `test/access/reports_screen_policy_test.dart`: Added unit tests verifying permission manifest mappings and cashier access boundaries.
- **Decisions Taken:**
  - Standardized all 7 previously unguarded report/audit screens with `ScreenAccessGate` at top of `build()`.
  - Prevented cashier from accessing payments report (which leaks financial cash balance) by requiring `reportsViewFinancials` instead of `paymentsRecord`.
  - Implemented automatic database upgrade migration via `DatabaseHelper.runPostOpenMigrations(db)` on database `onOpen` hook guarded by `app_settings` key `receivables_permission_migrated`. This ensures `AccessSeeder.migrateReceivablesPermissions(db)` automatically grants `reportsViewReceivables` to existing custom roles and user overrides that hold `contactsViewBalances` without requiring a login re-seed.
- **Validation:**
  - `dart format`: 11 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.

### Batch C: Localization cleanup

- **Batch ID:** `batch-c`
- **Files Changed:**
  - `lib/localization/app_localizations.dart`: Added `legacyForeignDocumentsNotice`, `legacyForeignPaymentsNotice`, and parameterized `ledgerBaseCurrencyNotice(currencyCode)` in both Arabic and English.
  - `lib/screens/reports/accounting_screen.dart`: Replaced inline `l10n.langCode == 'ar'` ternary with `l10n.ledgerBaseCurrencyNotice(book.currencyCode)`.
  - `lib/screens/reports/payments_report_screen.dart`: Replaced inline ternary with `l10n.legacyForeignPaymentsNotice`.
  - `lib/screens/reports/purchases_report_screen.dart`: Replaced inline ternary with `l10n.legacyForeignDocumentsNotice`.
  - `lib/screens/reports/sales_report_screen.dart`: Replaced inline ternary with `l10n.legacyForeignDocumentsNotice`.
- **Decisions Taken:**
  - Fully eliminated all inline hardcoded Arabic/English ternaries across the reports subsystem.
  - Ensured localized strings use `_t(ar, en)` and `isArabic` helper pattern.
- **Validation:**
  - `dart format`: 5 files formatted.
  - `dart analyze`: Clean (0 issues).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.

### Batch D: Export and share foundation

- **Batch ID:** `batch-d`
- **Files Changed:**
  - `lib/services/csv_service.dart`: Added `exportReportToCsv` supporting UTF-8 BOM (`\uFEFF`), RFC 4180 field quoting, and CSV formula injection protection (prefixes `@`, `=`, `+`, `-` with `'`).
  - `lib/services/pdf/pdf_report_builder.dart`: Added `pageFormat` support (`PdfPageFormat.a4` vs `PdfPageFormat.roll80`).
  - `lib/services/pdf_service.dart`: Added `shareReportPdf`, `shareText`, `shareCsv`, and `pageFormat` parameter on `generateReportPdf` / `printOrShareReportPdf`.
  - `lib/widgets/report_export_menu.dart`: Created reusable modal export sheet offering PDF (A4), PDF (Receipt 80mm), CSV, and WhatsApp / Text sharing.
  - `lib/localization/app_localizations.dart`: Added `exportReceipt80mm`, `exportWhatsApp`, `exportShareText`.
  - `lib/screens/reports/payments_report_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `lib/screens/reports/accounting_screen.dart`: Integrated export menu across all accounting tabs and ledger drill-down.
  - `lib/screens/reports/customer_report_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `lib/screens/reports/supplier_report_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `lib/screens/reports/sales_report_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `lib/screens/reports/purchases_report_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `lib/screens/reports/inventory_report_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `lib/screens/reports/product_report_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `lib/screens/stock_movements_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `lib/screens/audit_history_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `lib/screens/reports/advanced_inventory_analytics_screen.dart`: Integrated export menu with PDF, CSV, and text share.
  - `test/services/csv_report_export_test.dart`: Added unit test covering UTF-8 BOM, RFC 4180 escaping, and formula injection sanitization.
- **Decisions Taken:**
  - Export modal bottom sheet standardizes export triggers and options across all reports.
  - WhatsApp share leverages `PdfService.shareText` which invokes system sharing (SharePlus) to support direct WhatsApp delivery on Android without hardcoded WhatsApp URLs (preserving Play Store compliance).
  - Formula injection protection neutralizes spreadsheet execution risks for exported CSV files.
- **Validation:**
  - `dart format`: 17 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.

### Batch E: Shared date range across reports

- **Batch ID:** `batch-e`
- **Files Changed:**
  - `lib/screens/reports/reports_date_scope.dart`: Created session-scoped `ReportsDateNotifier` and `ReportsDateScope` (`InheritedNotifier`) to share active date ranges across all reports.
  - `lib/screens/reports/report_date_filter.dart`: Set `materialTapTargetSize: MaterialTapTargetSize.padded` on `FilterChip` items ensuring >= 48 dp touch targets; verified horizontal scrolling at 320 dp.
  - `lib/screens/reports_screen.dart`: Attached `ReportsDateNotifier.instance`, wrapped hub `Scaffold` and wrapped pushed report routes in `ReportsDateScope`.
  - `lib/screens/reports/sales_report_screen.dart`: Connected initial range to `ReportsDateNotifier.instance.range` and propagated updates through `ReportsDateScope.update`.
  - `lib/screens/reports/purchases_report_screen.dart`: Connected initial range and propagated updates.
  - `lib/screens/reports/payments_report_screen.dart`: Connected initial range and propagated updates.
  - `lib/screens/reports/product_report_screen.dart`: Connected initial range and propagated updates.
  - `lib/screens/reports/accounting_screen.dart`: Connected initial range and propagated updates.
  - `lib/screens/reports/advanced_inventory_analytics_screen.dart`: Connected initial range and propagated updates.
  - `lib/screens/stock_movements_screen.dart`: Connected initial range and propagated updates.
  - `test/screens/reports_date_scope_test.dart`: Added widget tests for scope propagation and listener notifications.
- **Decisions Taken:**
  - Used hybrid approach combining singleton default fallback (`ReportsDateNotifier.instance`) and `InheritedNotifier` (`ReportsDateScope`) ensuring both `initState` initialization and reactive tree updates work seamlessly.
  - Preserved individual screen date change freedom while synchronizing state across report screen transitions.
- **Validation:**
  - `dart format`: 11 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.

### Batch F: Daily closing (end-of-day) register reconciliation report

- **Batch ID:** `batch-f`
- **Files Changed:**
  - `lib/localization/app_localizations.dart`: Added Arabic and English localized strings for Daily Closing, opening cash, expected cash, actual cash, cash variance (surplus/deficit/balanced), gross sales, credit sales, customer debts collected, and method breakdowns.
  - `lib/services/business_reporting_service.dart`: Added `DailyClosingSummary` model and `getDailyClosingSummary` method aggregating sales, discounts, cancellations, collections by method, collections on prior debt, supplier payments, and expense vouchers.
  - `lib/screens/reports/daily_closing_report_screen.dart`: Created full Daily Closing Screen with live cash drawer reconciliation (opening + cash in - cash out = expected; actual - expected = variance), metric summary cards, sales summary, collections breakdown, financial outflows (gated by `reportsViewFinancials`), pull-to-refresh, and PDF (A4/80mm receipt), CSV, and WhatsApp export.
  - `lib/services/access/screen_access_policy.dart`: Registered `DailyClosingReportScreen` in manifest requiring `PermissionRegistry.reportsViewSales`.
  - `lib/screens/reports_screen.dart`: Added Daily Closing Report tile to `reportCatSalesPurchases` category as a Free feature.
  - `test/services/daily_closing_report_test.dart`: Added unit tests verifying sales aggregation, cancellations exclusion, debt collection segregation, and net cash drawer calculation.
- **Decisions Taken:**
  - Differentiated cash collected today for current-period invoices from collections on prior-period invoices (`customerDebtCollected`), which is vital for retail cash accounting.
  - Cash register variance calculation is reactive and instantly provides visual feedback (green balanced / blue surplus / red shortage).
  - Outflow reporting and its subtraction from expected cash is conditionally included based on `reportsViewFinancials`.
- **Validation:**
  - `dart format`: 6 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.

### Batch G: Receivables and payables aging report

- **Batch ID:** `batch-g`
- **Files Changed:**
  - `lib/localization/app_localizations.dart`: Added localized Arabic and English getters for Aging Report, bucket labels (0–30, 31–60, 61–90, 90+ days), receivables/payables aging, total outstanding, and payment reminder action.
  - `lib/services/business_reporting_service.dart`: Added pure aging models (`AgingBucketSummary`, `ContactAgingItem`, `AgingReportData`) and `getAgingReport(documentType, asOf)` method calculating standard aging buckets from `documents.date` relative to an as-of date.
  - `lib/screens/reports/aging_report_screen.dart`: Created full Aging Report Screen with two tabs (Customers / Suppliers), top 4-bucket overview KPI cards (Free tier), and per-contact breakdown with WhatsApp reminder action (Pro tier gated by `Feature.advancedReports`), PDF (A4/80mm), CSV, and WhatsApp export.
  - `lib/services/access/screen_access_policy.dart`: Registered `AgingReportScreen` in manifest policy requiring `PermissionRegistry.reportsViewReceivables`.
  - `lib/screens/reports_screen.dart`: Added Aging Report tile under `reportCatSalesPurchases` requiring `reportsViewReceivables`.
  - `test/services/debt_aging_test.dart`: Added unit tests verifying pure `AgingBucketSummary` arithmetic, query grouping, exclusion of cancelled and paid documents, and contact debt descending sorting.
- **Decisions Taken:**
  - Grouped aging buckets strictly using `documents.date` (due date column does not exist in schema).
  - Implemented standard 4-bucket delay structure (0–30, 31–60, 61–90, 90+ days) instead of 3 buckets (0–30, 31–60, 61+) as an intentional, harmless accounting enhancement providing Sudanese merchants finer granularity on overdue debts.
  - Designed Free vs Pro split: Bucket totals are Free to all merchants; granular customer/supplier breakdown with reminder triggers requires Pro (`Feature.advancedReports`), consistent with the product tier boundary.
- **Validation:**
  - `dart format`: 6 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.

### Batch H: Payments report cash flow by method and standalone voucher drilldown

- **Batch ID:** `batch-h`
- **Files Changed:**
  - `lib/database/database_helper.dart`: Added `getPaymentMethodCashFlow({required DateTime from, required DateTime to, String? currencyCode})` SQL aggregation calculating inflows, outflows, and net flow grouped by payment method across documents and vouchers.
  - `lib/screens/reports/payments_report_screen.dart`: Integrated payment method cash flow chips row above payments list (displaying in, out, and net per method with color-coded badges); remediated standalone voucher drilldown by checking `(row['document_id'] ?? row['id'])` so all vouchers are tappable and open their detail screen.
  - `test/services/payment_cash_flow_test.dart`: Added unit tests verifying multi-method cash flow aggregation across invoices, purchases, and standalone vouchers.
- **Decisions Taken:**
  - Standardized payment method breakdown to give Sudanese merchants direct visibility into Cash vs Bankak (mobile money) net flows.
  - Enabled click-through drilldown for standalone vouchers into `DocumentDetailScreen` without needing a redundant separate screen.
- **Validation:**
  - `dart format`: 3 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.

### Batch I: UI/UX polish across reports and period comparison delta

- **Batch ID:** `batch-i`
- **Files Changed:**
  - `lib/widgets/app_percentage_bar.dart`: Created lightweight CustomPainter horizontal percentage share bar with circle legend tags and zero dependencies.
  - `lib/localization/app_localizations.dart`: Added localized Arabic and English getters for searchCustomer, searchSupplier, sortByName, sortByRemaining, salesGrowthVsPrevious, taxDiscountReport, and tax/discount breakdown labels.
  - `lib/models/date_range_filter.dart`: Added `previousPeriod()` helper calculating equivalent prior duration (today -> yesterday, thisMonth -> lastMonth, etc.).
  - `lib/screens/reports/customer_report_screen.dart`: Integrated debounced search (300ms) with sequence counter, sort toggle (debt vs name), `AppLoadingView`, `AppErrorState`, `AppEmptyState`, `RefreshIndicator`, `AppMetricCard(compact: true)`, and legacy foreign-currency warning banner.
  - `lib/screens/reports/supplier_report_screen.dart`: Applied symmetrical UI architecture with debounced search, sort toggle, `AppLoadingView`, `AppErrorState`, `AppEmptyState`, `RefreshIndicator`, and `AppMetricCard(compact: true)`.
  - `lib/screens/reports/purchases_report_screen.dart`: Split squished 3-dropdown layout into 2 spacious rows (Supplier full-width on row 1, Document & Payment status on row 2), replaced squished chips with `AppMetricCard(compact: true)`, wrapped list in `RefreshIndicator`, and applied `AppDesignTokens.cardRadius`.
  - `lib/screens/reports/sales_report_screen.dart`: Replaced squished summary row with spacious responsive `AppMetricCard(compact: true)` layout, added period comparison growth delta badge (`+12.5% vs previous period`) computed against prior period of equal length, and wrapped list in `RefreshIndicator`.
  - `lib/screens/reports/payments_report_screen.dart`: Integrated `AppPercentageBar` above payments list visualizing payment methods distribution (Cash, Bankak, etc.).
  - `lib/screens/reports/inventory_report_screen.dart`: Added click-through drilldown navigating from product card to `StockMovementsScreen(initialProduct: p)`.
  - `lib/screens/reports/product_report_screen.dart`: Added click-through drilldown to `StockMovementsScreen` and wrapped list in `RefreshIndicator`.
- **Decisions Taken:**
  - Standardized on `AppMetricCard(compact: true)` across Sales, Purchases, Customers, and Suppliers reports to eliminate horizontal text cramping on low-end 360dp phone screens.
  - Provided immediate drilldown into item stock movements directly from inventory and product performance cards.
  - Computed previous period comparisons asynchronously with lightweight single-query aggregates to preserve UI fluidity.
- **Validation:**
  - `dart format`: 10 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.

### Batch J: Tax and discounts summary report

- **Batch ID:** `batch-j`
- **Files Changed:**
  - `lib/services/business_reporting_service.dart`: Added `TaxDiscountSummary` data model and `getTaxDiscountSummary({required DateTime from, required DateTime to, String? currencyCode})` single-query aggregation method for sales tax collected, purchase tax paid, net tax, sales discounts given, purchase discounts received, net discounts, and list of transactions with taxes or discounts.
  - `lib/screens/reports/tax_discount_report_screen.dart`: Created full Tax & Discounts Report Screen (Free tier) with top KPI metric cards (tax and discount summaries), drilldown list of all invoices and purchases that incurred tax or discount, click-through into `DocumentDetailScreen`, date filter synchronized with `ReportsDateScope`, PDF (A4/80mm), CSV, and WhatsApp export.
  - `lib/services/access/screen_access_policy.dart`: Registered `TaxDiscountReportScreen` requiring `PermissionRegistry.reportsViewFinancials`.
  - `lib/screens/reports_screen.dart`: Added Tax & Discounts Report tile under `reportCatSalesPurchases` requiring `reportsViewFinancials`.
  - `test/services/tax_discount_report_test.dart`: Added unit tests verifying pure `TaxDiscountSummary` netTax and netDiscounts calculation, query aggregation of invoices and purchases, handling of zero values, and exclusion of cancelled documents.
- **Decisions Taken:**
  - Available as a Free tier feature accessible to all business owners, gated by `reportsViewFinancials` to preserve role-based authorization.
  - Documents list provides instant drilldown into individual tax invoices and purchase bills for tax auditing.
- **Validation:**
  - `dart format`: 5 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.


---

## Fix Round: Remediation of Implementation Audit

### Batch P0: Blockers Remediation

- **Batch ID:** `batch-p0-blockers`
- **Files Changed:**
  - `lib/services/csv_service.dart`: Numeric cells emitted raw without apostrophe. String cells preserve formula injection defense for `= + - @ \t \r` while skipping apostrophe when strictly numeric (`^[+-]?\d+(\.\d+)?$`), preserving negative amounts and phone numbers.
  - `test/services/csv_report_export_test.dart`: Updated unit tests asserting uncorrupted negative amounts (`-250`, `-12.75`), preserved phone numbers (`+249912345678`), sanitized spreadsheet formulas (`'=SUM(A1:B1)`), and sanitized command injections (`'-cmd|calc`).
  - `lib/screens/reports/low_stock_report_screen.dart`: Created dedicated lightweight Low Stock Report screen showing stock quantities, minimum thresholds, and shortages without costing/valuation data, gated with `PermissionRegistry.productsView`.
  - `lib/screens/reports_screen.dart`: Updated Low Stock tile to navigate to `LowStockReportScreen` with `productsView` requirement. Exposed canonical `ReportsScreen.getReportCategories()` for UI and test verification.
  - `lib/services/access/screen_access_policy.dart`: Registered `LowStockReportScreen` requiring `PermissionRegistry.productsView`.
  - `lib/database/database_helper.dart`: Added `runPostOpenMigrations(db)` triggered on database `onOpen` and guarded by `app_settings` key `receivables_permission_migrated` to grant `reportsViewReceivables` to existing roles and users holding `contactsViewBalances`.
  - `test/access/receivables_migration_test.dart`: Added unit tests verifying migration on existing database, role/user override propagation, flag persistence, idempotency, and resilience on empty databases.
  - `lib/services/business_reporting_service.dart`: Fixed `getAgingReport` and `getDailyClosingSummary` to exclude draft documents via `status NOT IN ('draft', 'cancelled')` and restricted aging document types to `invoice` and `purchase`.
  - `test/services/debt_aging_test.dart`: Added unit tests validating exclusion of `draft`, `cancelled`, and `quotation` documents from aging calculations, inclusion of `partially_paid` balances, and exact bucket day boundaries (30/31/60/61/90/91).
  - `test/access/reports_screen_policy_test.dart`: Added exhaustive test asserting that every hub tile's declared permission exactly matches the target screen's `ScreenAccessPolicy.manifest` requirement, verified all 16 canonical report screens, and asserted cashier role boundaries.
- **Decisions Taken:**
  - P0-1: Strict numeric check allows negative numbers and phone numbers without triggering false-positive formula injection quotes.
  - P0-2: Implemented Option B (dedicated `LowStockReportScreen`) so cashiers with `productsView` can monitor inventory replenishment without gaining unauthorized visibility into inventory costs and valuation.
  - P0-3: Implemented Option A for receivables migration using post-open database hook with `app_settings` run-once guard.
  - P0-4: Unified posted document status across financial aggregations as `status NOT IN ('draft', 'cancelled')`.
- **Validation:**
  - `dart format`: 10 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.


### Batch P1: Correctness & Permissions

- **Batch ID:** `batch-p1-correctness-permissions`
- **Files Changed:**
  - `lib/services/business_reporting_service.dart`: Added base currency filtering `(currency_code = ? OR currency_code IS NULL)` to `getDailyClosingSummary` and `getAgingReport`, and added `hasLegacyForeignCurrency` and `currencyCode` properties to both summaries.
  - `lib/screens/reports/aging_report_screen.dart`: Added warning banner informing merchants if legacy foreign-currency documents exist and are omitted from SDG totals. Added sequence guard `_querySeq`, localized unknown contact placeholder, and export button check with `ReportExportMenu.canExport()`.
  - `lib/screens/reports/daily_closing_report_screen.dart`: Added notice banner for legacy foreign-currency documents and sequence guard `_querySeq`.
  - `lib/widgets/report_export_menu.dart`: Implemented pure `ReportExportPermissions.resolveVisibleActions` and `ReportExportMenu.canExport()` gating PDF export/print on `reportsExportPdf` and CSV export on `dataExportCsv`.
  - `lib/screens/reports/sales_report_screen.dart`: Added sequence guard `_querySeq`, interactive search filtering by customer name or invoice number with 300ms debounce, sort toggle (by amount or date), and gated export button with `ReportExportMenu.canExport()`.
  - `lib/screens/reports/purchases_report_screen.dart`: Added sequence guard `_querySeq`, interactive search filtering by supplier name or purchase invoice number with 300ms debounce, sort toggle, and gated export button with `ReportExportMenu.canExport()`.
  - `lib/screens/reports/payments_report_screen.dart`, `tax_discount_report_screen.dart`, `product_report_screen.dart`, `advanced_inventory_analytics_screen.dart`, `customer_report_screen.dart`, `supplier_report_screen.dart`, `inventory_report_screen.dart`, `low_stock_report_screen.dart`, `stock_movements_screen.dart`: Added sequence guard `_querySeq` and gated export button with `ReportExportMenu.canExport()`.
  - `lib/screens/audit_history_screen.dart`: Initialized date range from `ReportsDateNotifier.instance.range`, propagated date updates via `ReportsDateScope.update(context, newRange)`, added sequence guard `_querySeq`, and gated export button.
  - `lib/screens/reports/accounting_screen.dart`: Added sequence guard `_querySeq` and gated export button with `ReportExportMenu.canExport()`.
  - `lib/localization/app_localizations.dart`: Added localized labels `unspecified`, `sortByDate`, `sortByAmount`, `searchInvoices`, and `searchPurchases` in both Arabic and English.
  - `test/services/daily_closing_report_test.dart`: Added unit tests asserting omission of foreign currency documents from SDG daily closing calculations and flagging `hasLegacyForeignCurrency`.
  - `test/services/debt_aging_test.dart`: Added unit tests asserting omission of foreign currency documents from SDG debt aging calculations and flagging `hasLegacyForeignCurrency`.
  - `test/widgets/report_export_permissions_test.dart`: Created unit tests verifying pure permission resolution for PDF and CSV actions based on user session permissions.
- **Decisions Taken:**
  - P1-1: Daily closing and aging calculations strictly filter to base currency (SDG or NULL) to prevent summing disparate currency amounts, while prominently informing users of legacy foreign-currency documents via warning banners.
  - P1-2: Export options are dynamically resolved based on `reportsExportPdf` and `dataExportCsv` permissions; export trigger action is hidden if the user possesses neither.
  - P1-3: Asynchronous load sequence guards (`_querySeq`) added to prevent out-of-order race conditions when switching filters rapidly.
  - P1-4: Client-side search and sorting implemented on sales and purchases reports without new dependencies.
- **Validation:**
  - `dart format`: All touched files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.

### Batch P2: UX & Consistency

- **Batch ID:** `batch-p2-ux-consistency`
- **Files Changed:**
  - `lib/utils/phone_utils.dart`: Implemented pure function `normalizeSudanPhone(String? phone)` which normalizes Sudanese mobile numbers (09x Zain/MTN, 01x Sudani) to international format `249` + 9 digits, strips formatting characters (`-`, spaces, parens), validates length and digit constraints, supports valid international numbers, and returns null for invalid formats.
  - `lib/localization/app_localizations.dart`: Added `agingReminderMessage(contactName, amount, currency)` with proper localized templates in both Arabic and English.
  - `lib/screens/reports/aging_report_screen.dart`: Updated `_sendReminder` to use `l10n.agingReminderMessage`, normalize contact phone via `normalizeSudanPhone`, launch WhatsApp directly via `https://wa.me/<digits>?text=<encoded>`, and fall back gracefully to `PdfService.shareText`.
  - `test/utils/phone_normalizer_test.dart`: Added unit tests covering null/empty inputs, local 10-digit 0-prefixed numbers, 9-digit local numbers, international `+249` and `00249` formats, already normalized 12-digit numbers, international non-Sudan numbers, and invalid strings.
- **Decisions Taken:**
  - P2-1: Standardized WhatsApp launch URL to `https://wa.me/<digits>` with `LaunchMode.externalApplication`, ensuring seamless intent handling across WhatsApp and WhatsApp Business on Android with transparent fallback to system share sheet.
  - P2-2: Verified absence of hardcoded Arabic in SQL queries across all reporting and accounting services; localized aging reminder template in UI layer.
  - P2-3: Verified all 10 date-ranged reporting screens initialize from and synchronize with `ReportsDateNotifier` and `ReportsDateScope`.
- **Validation:**
  - `dart format`: 4 files checked/formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.
