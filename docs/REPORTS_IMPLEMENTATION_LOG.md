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
- [ ] **Batch H** - Payments report: cash flow by method
- [ ] **Batch I** - UI/UX polish across reports
- [ ] **Batch J** - Phase 3 extras (J1: Period comparison; J2: Tax & discounts report)
- [ ] **Docs & Verification** - CHANGELOG, reports_section.md, checklist

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
  - Used explicit SQL migration in `AccessSeeder.migrateReceivablesPermissions(db)` so existing installations seamlessly receive `reportsViewReceivables` for roles with `contactsViewBalances`.
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
  - Designed Free vs Pro split: Bucket totals are Free to all merchants; granular customer/supplier breakdown with reminder triggers requires Pro (`Feature.advancedReports`), consistent with the product tier boundary.
- **Validation:**
  - `dart format`: 6 files formatted.
  - `dart analyze`: Clean (0 issues across all touched files).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.
