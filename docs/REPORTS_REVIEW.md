# Waraqatak Reports Section Audit & Comprehensive Review

**Date:** 2026-11-23  
**Target:** Waraqatak Flutter App (Offline-first, Arabic-first RTL, SQLite, key-activated Pro, consumption-only model, designed for small Sudanese merchants on low-end Android devices).  
**Review Type:** Static Architecture, UI/UX, Performance, and Functional Gap Analysis.

---

## 1. Executive Summary

Waraqatak offers a robust reporting foundation powered by local SQLite aggregations and double-entry bookkeeping, but its usability on low-end devices suffers from noticeable architectural friction. While core sales, purchase, inventory valuation, and accounting ledgers exist, key screens lack export capabilities (accounting statements and payment reports cannot be exported or printed), zero reports support CSV export, and none provide direct WhatsApp text summaries critical for the Sudanese market. Multiple performance bottlenecks exist, including an N+1 query loop on sales report loads and un-debounced search queries hitting SQLite on every keystroke. Security and access policy discrepancies expose sensitive cash-flow reports to basic cashiers while bypassing dedicated permissions. Furthermore, essential retail workflows—notably an End-of-Day cash drawer summary, debt aging (receivables/payables buckets), and tax/discount reports—are completely missing despite underlying data already existing in the database.

---

## 2. Current Reports Inventory

The following table details all existing report screens and financial summary views available in the application:

| Report Name | File Location | Primary Data Source | Available Filters | Export Capabilities | Permission / Pro Gate | Currency Handling |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Financial Accounting** | `lib/screens/reports/accounting_screen.dart` | `LedgerService.load()` via `LedgerBuilder.buildDerived` or `DatabaseHelper.getLedgerData` | Date range (`ReportDateFilter`: today, yesterday, week, month, last month, year, custom) | **None** (No PDF, CSV, or share action) | Pro (`Feature.advancedReports`) & `reports.view_financials` | Base currency isolated; foreign currency documents excluded with an informational banner |
| **Account Ledger** | `lib/screens/reports/accounting_screen.dart` (`AccountLedgerScreen`) | `LedgerBook.entries` filtered by account code | Date range (`ReportDateFilter`) | **None** | Pro (`Feature.advancedReports`) & `reports.view_financials` | Single base currency per ledger |
| **Sales Report** | `lib/screens/reports/sales_report_screen.dart` | `InventoryCostingService.getSalesReportWithCost()` | Date range (`ReportDateFilter`) | PDF via `Printing.layoutPdf` (Requires `reports.export_pdf`). **No CSV / No direct share** | Free (`Feature.basicReports` / null) & `reports.view_sales` | Base currency totals at top; legacy foreign currencies listed in segregated read-only box below |
| **Purchases Report** | `lib/screens/reports/purchases_report_screen.dart` | `BusinessReportingService.getPurchasesReport()` | Date range (`ReportDateFilter`), Supplier dropdown, Document status, Payment status | PDF via `Printing.layoutPdf`. **No CSV / No direct share** | Pro (`Feature.advancedReports`) & `reports.view_purchases` | Base currency totals at top; legacy foreign currencies listed in segregated read-only box below |
| **Payments Report** | `lib/screens/reports/payments_report_screen.dart` | `DatabaseHelper.getPaymentReport()` | Date range (`ReportDateFilter`) | **None** (No PDF, CSV, or share button) | Free (null) & `payments.record` *(Mismapped permission)* | Base currency totals at top; legacy foreign currencies below |
| **Customer Balances** | `lib/screens/reports/customer_report_screen.dart` | `DatabaseHelper.getContactBalances('customer', 'invoice')` | **None** (All-time cumulative debts) | PDF via `Printing.layoutPdf`. **No CSV** | Free (null) & `contacts.view_balances` *(Bypasses `reports.view_receivables`)* | Base currency forced (`currencyCode ?? 'SDG'`); foreign currency debts silently dropped |
| **Supplier Balances** | `lib/screens/reports/supplier_report_screen.dart` | `DatabaseHelper.getContactBalances('supplier', 'purchase')` | **None** (All-time cumulative payables) | PDF via `Printing.layoutPdf`. **No CSV** | Pro (`Feature.advancedReports`) & `contacts.view_balances` | Base currency forced (`currencyCode ?? 'SDG'`); foreign currency payables silently dropped |
| **Inventory Report** | `lib/screens/reports/inventory_report_screen.dart` | `BusinessReportingService.getInventoryReport()` | Status tabs (All, Low Stock, Out of Stock, Valuation), Category dropdown, Live search | PDF via `Printing.layoutPdf` (custom dynamic columns). **No CSV** | Pro (`Feature.advancedReports`) & `reports.view_inventory_cost` | Single base currency valuation |
| **Low Stock Report** | `lib/screens/reports/inventory_report_screen.dart` (`initialFilter: 'low_stock'`) | `BusinessReportingService.getInventoryReport(stockStatus: 'low_stock')` | Pre-filtered to Low Stock, Category dropdown, Live search | PDF via `Printing.layoutPdf`. **No CSV** | Pro (`Feature.advancedReports`) & `stock.adjust` | Single base currency |
| **Stock Movements** | `lib/screens/stock_movements_screen.dart` | `BusinessReportingService.getStockMovementsReport()` | Date range (`ReportDateFilter`), Product picker dialog, Movement type dropdown | PDF via `Printing.layoutPdf`. **No CSV** | Pro (`Feature.advancedReports`) & `stock.view_cost` | Single base currency quantities & unit costs |
| **Product Report** | `lib/screens/reports/product_report_screen.dart` | `BusinessReportingService.getProductPerformance()` | Tabs (Sales by Product, Profit by Product, Performance), Date range, Category, Sort By (revenue/qty/profit) | PDF via `Printing.layoutPdf`. **No CSV** | Pro (`Feature.advancedReports`) & `reports.view_inventory_cost` *(Discrepancy with policy)* | Base currency; flags uncosted or multi-currency warnings |
| **Advanced Inventory Analytics** | `lib/screens/reports/advanced_inventory_analytics_screen.dart` | `BusinessReportingService.getAdvancedInventoryMetrics()` | Tabs (Velocity, Slow Moving, Negative Margins, Category Share), Date range, Category | PDF via `Printing.layoutPdf`. **No CSV** | Pro (`Feature.advancedReports`) & `reports.view_inventory_cost` | Single base currency valuation & margins |
| **Audit History Log** | `lib/screens/audit_history_screen.dart` | `AuditService.queryLogs()` | Action type filter, Date range | **None** | Pro (`Feature.inventoryAudit`) & `audit.view` | Event log only |
| **Customer Statement** *(Contact detail modal)* | `lib/widgets/customer_statement_dialog.dart` & `CustomerStatementService` | `CustomerStatementService.getStatementForContact()` | Contact ID, Date range, Currency selector dropdown | PDF preview, direct WhatsApp sharing via `SharePlus` with Arabic pre-filled caption | Free & `contacts.view_balances` | Multi-currency selectable (produces statement in any currency on record) |

---

## 3. UI/UX Findings & Technical Audit

### High Severity Issues

1. **N+1 Database Query Loop on Sales Report Loading**
   - **Reference:** `lib/services/inventory_costing_service.dart:515-534`
   - **Details:** When loading the Sales Report, `getSalesReportWithCost` queries the `documents` table, iterates through every document row in Dart, and triggers a separate `db.query('document_items', where: 'document_id = ?', whereArgs: [doc.id])` for every single invoice. For a business with 400 invoices in a month, 401 distinct SQLite queries are executed sequentially. On low-end 4 GB RAM Android phones, this locks the UI thread, causing perceptible frame freezes (jank) and potential ANR dialogs.
   - **Fix:** Replace the iterative querying loop with a single SQL query using `LEFT JOIN document_items di ON di.document_id = d.id` or batch-fetch line items with `WHERE document_id IN (...)`.

2. **Permission Guard Discrepancies and Insecure Cash-Flow Gating**
   - **Reference:** `lib/screens/reports_screen.dart:151-153, 159-161, 210` vs `lib/services/access/screen_access_policy.dart:163, 166`
   - **Details:**
     - In `reports_screen.dart:151-153` and `screen_access_policy.dart:163`, `PaymentsReportScreen` is guarded by `PermissionRegistry.paymentsRecord` (`payments.record`). Any cashier granted permission to create payments can access the full Payments Report, exposing aggregate company-wide cash in/out flows.
     - In `reports_screen.dart:159-161`, `CustomerReportScreen` and `SupplierReportScreen` use `contactsViewBalances`, leaving the dedicated `PermissionRegistry.reportsViewReceivables` (`reports.view_receivables`) completely unused (dead code).
     - In `reports_screen.dart:210`, `ProductReportScreen` checks `PermissionRegistry.reportsViewInventoryCost`, but `screen_access_policy.dart:166` specifies `PermissionRegistry.reportsViewSales`.
     - `ScreenAccessGate` is completely missing from `payments_report_screen.dart`, `customer_report_screen.dart`, `supplier_report_screen.dart`, `product_report_screen.dart`, and `advanced_inventory_analytics_screen.dart`.
   - **Fix:** Map `PaymentsReportScreen` to `reportsViewSales` or `reportsViewFinancials`; enforce `reportsViewReceivables` on customer/supplier reports; synchronize `ProductReportScreen` permissions; and wrap all unguarded report screens in `ScreenAccessGate`.

3. **Flagship Financial Accounting Statements Are Entirely Unexportable**
   - **Reference:** `lib/screens/reports/accounting_screen.dart:80-95`
   - **Details:** The `AccountingScreen` contains Income Statement, Balance Sheet, Trial Balance, and General Ledger tabs, but its `AppBar` contains no action icons. Users cannot print, export to PDF, save, or share these statements with accountants or partners.
   - **Fix:** Add an export button to `AccountingScreen`'s AppBar that formats the active tab's statement into a standardized PDF report via `PdfReportBuilder`.

4. **Un-debounced SQLite Search Causes Typing Freezes in Inventory Reports**
   - **Reference:** `lib/screens/reports/inventory_report_screen.dart:472-474`
   - **Details:** `TextField(onChanged: (val) { _searchQuery = val; _load(); })` invokes `_load()` on every character typed, immediately triggering `BusinessReportingService.getInventoryReport` across the entire database without debounce.
   - **Fix:** Implement a 300ms `Timer` debounce pattern before invoking `_load()`.

5. **Silent Exclusion of Foreign-Currency Customer and Supplier Balances**
   - **Reference:** `lib/screens/reports/customer_report_screen.dart:66-70` and `lib/screens/reports/supplier_report_screen.dart:66-70`
   - **Details:** Both screens query `getContactBalances` with `currencyCode: business?.currencyCode ?? 'SDG'`. If a customer or supplier transacted in another currency (e.g. USD or SAR), their debts are completely omitted from the screen without any indicator or warning.
   - **Fix:** Include currency badges or a currency switcher, or display a warning banner indicating that non-base currency balances exist.

---

### Medium Severity Issues

6. **Complete Absence of CSV Export Across All Reports**
   - **Reference:** `lib/services/csv_service.dart:105-1252` and `lib/screens/reports/*.dart`
   - **Details:** While `CsvService` exists, it only supports product catalog import/export. Zero report screens provide CSV export functionality. Merchants cannot export tabular data into Excel or Google Sheets.
   - **Fix:** Add a generic tabular CSV export helper to `CsvService` and provide a CSV export option on all report screens.

7. **Print Spooler Triggered Instead of Direct WhatsApp / Native Share**
   - **Reference:** `lib/services/pdf_service.dart:168-192`
   - **Details:** Every report screen's export button invokes `PdfService.printOrShareReportPdf`, which unconditionally launches `Printing.layoutPdf` (the Android system print preview). In Sudan, where WhatsApp is the primary business conduit, merchants cannot directly share report summaries or PDFs to WhatsApp without navigating through print spooler dialogs.
   - **Fix:** Introduce an action sheet allowing the user to choose between "Print / PDF Preview" (`Printing.layoutPdf`) and "Share via WhatsApp / Apps" (`SharePlus.instance.share` with pre-filled Arabic summary text).

8. **Hardcoded User-Facing Strings Violating Localization Architecture**
   - **Reference:** `lib/screens/reports/sales_report_screen.dart:388-390`, `lib/screens/reports/purchases_report_screen.dart:375-377`, `lib/screens/reports/payments_report_screen.dart:134-136`, `lib/screens/reports/accounting_screen.dart:142-144`
   - **Details:** Inline ternaries like `l10n.langCode == 'ar' ? 'وثائق قديمة بعملات أخرى' : 'Legacy documents in other currencies'` bypass `AppLocalizations`.
   - **Fix:** Move all hardcoded strings into getter methods in `lib/localization/app_localizations.dart`.

9. **Date Filter State Is Ephemeral and Resets Across Report Screens**
   - **Reference:** `lib/screens/reports/sales_report_screen.dart:67`, `purchases_report_screen.dart:29`, `payments_report_screen.dart:27`, `product_report_screen.dart:30`
   - **Details:** Each screen declares `DateRangeFilter _range = DateRangeFilter.thisMonth()`. When a merchant reviews today's business and switches from Sales to Payments to Purchases, they must re-select "Today" on every screen.
   - **Fix:** Persist the current session's active date filter or manage it via an inherited state / service.

10. **Digit Truncation and UI Squishing on Narrow Screens (320–360 dp)**
    - **Reference:** `lib/screens/reports/sales_report_screen.dart:314-358`, `purchases_report_screen.dart:210-299`, `purchases_report_screen.dart:320-346`, `inventory_report_screen.dart:542-550`
    - **Details:** Multiple report screens force 3 `_summaryChip` widgets into a single horizontal `Row` with `Expanded`. Due to `TextOverflow.ellipsis`, large monetary figures in SDG (e.g. `1,250,000 ج.س`) are cut off. In `purchases_report_screen.dart:210`, three dropdowns are placed in one row, rendering supplier names illegible.
    - **Fix:** Wrap summary metrics in a 2x2 grid or responsive wrap, and move secondary dropdown filters into a filter sheet or vertically stacked chips.

11. **Total Absence of Charts and Visual Summaries**
    - **Reference:** Entire `lib/screens/reports/` directory
    - **Details:** All reports rely purely on text lists or basic chips. In `advanced_inventory_analytics_screen.dart:425`, category share is simply a `CircleAvatar` with a text percentage. There are no bar charts, sparklines, or comparison graphs.
    - **Fix:** Implement lightweight, dependency-free custom painter bars or progress bars to visualize category distribution, top sales items, and revenue breakdown.

12. **Full Database Scan on Derived Accounting Screen Loads**
    - **Reference:** `lib/services/accounting/ledger_service.dart:60-106`
    - **Details:** By default, `journal_reports_enabled` is set to false. Consequently, `LedgerService.buildDerived` loads every document, document item, product, stock movement, and payment across the company's entire history into memory to derive journal entries on the fly.
    - **Fix:** Enable `journal_reports_enabled` by default so that reports query the indexed `journal_entries` and `journal_lines` tables directly.

---

### Low Severity Issues

13. **Inconsistent UI Tokens and Custom Chip Duplication**
    - **Reference:** `lib/screens/reports/customer_report_screen.dart:163-181`, `lib/screens/reports/payments_report_screen.dart:172-190`, `lib/screens/reports/sales_report_screen.dart:530`
    - **Details:** The official `AppMetricCard` (`lib/widgets/app_metric_card.dart`) is used only on `HomeScreen` and is completely ignored in Reports. Each report screen writes its own private `_chip` implementation with differing paddings, borders, and corner radiuses.
    - **Fix:** Refactor report metric cards to utilize `AppMetricCard(compact: true)`.

14. **Customer and Supplier Reports Lack Date Range Filtering**
    - **Reference:** `lib/screens/reports/customer_report_screen.dart:66-72` and `supplier_report_screen.dart:66-72`
    - **Details:** Balances are strictly cumulative lifetime totals. Merchants cannot view debts incurred or cleared during a specific period.
    - **Fix:** Integrate `ReportDateFilter` into customer and supplier reports.

15. **Lack of Sorting and Search on Sales, Purchases, and Debts**
    - **Reference:** `lib/screens/reports/sales_report_screen.dart:289`, `customer_report_screen.dart:144`
    - **Details:** Invoices and customer balances cannot be searched by document number, customer name, or sorted by value.
    - **Fix:** Add search text fields and sort criteria (amount, date, alphabetical).

16. **Thermal Roll (80mm) Paper Size Unsupported for Report Printing**
    - **Reference:** `lib/services/pdf/pdf_report_builder.dart:100`
    - **Details:** `PdfReportBuilder` hardcodes `PdfPageFormat.a4`. Merchants equipped with 80mm POS receipt printers cannot print daily summaries on roll paper.
    - **Fix:** Support 80mm thermal roll format in `PdfReportBuilder`.

17. **Missing Pull-to-Refresh on Report Lists**
    - **Reference:** `lib/screens/reports/sales_report_screen.dart:301`, `purchases_report_screen.dart:195`
    - **Details:** Reports do not wrap their content in `RefreshIndicator`, requiring back navigation to refresh data.
    - **Fix:** Wrap scrollable report views in `RefreshIndicator`.

---

## 4. Missing Features & Gap Analysis

The following matrix evaluates critical business reporting capabilities against current implementations, user value, development effort, data availability, and proposed licensing tier:

| Reporting Feature | Current Status | User Value | Dev Effort | Data Already in SQLite? | Proposed Model Tier | Evidence & Architecture Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Daily Sales Summary / End-of-Day (Z-Report)** | **Missing** | High | S | Yes (`documents`, `document_payments`, `vouchers`) | Free | Merchants need daily register reconciliation: cash collected, Bankak transfers, credit sales, debts collected, and expense payouts. Currently requires manual calculation across multiple screens. |
| **Receivables & Payables Aging (0-30 / 31-60 / 60+ days)** | **Missing** | High | M | Yes (`documents.date`, `due_date`, `remaining`) | Pro (`advancedReports`) | Translation exists (`app_localizations.dart:3252`), but no calculation exists. Merchants cannot differentiate between fresh debt and overdue debt. |
| **Cash Flow by Payment Method (Cash, Bankak, Cheque)** | **Partial** | High | S | Yes (`document_payments.payment_method`, `vouchers`) | Free | `PaymentsReportScreen` lists entries but does not aggregate totals by payment method or show net cash flow. |
| **Full Profit & Loss (Revenue, COGS, Expenses, Net Profit)** | **Partial** | High | M | Yes (`journal_lines` or `documents` + `vouchers`) | Free (Basic P&L) / Pro (Detailed) | `AccountingScreen` tab 0 has an Income Statement, but it is locked under Pro and unexportable. Free users have no way to view operating expenses or Net Profit. |
| **Top Customers / Top Products by Sales & Margin** | **Partial** | Med | S | Yes (`documents`, `document_items`, `products`) | Free (Top 5) / Pro (Full) | `ProductReportScreen` supports sorting by revenue/profit; `CustomerReportScreen` does not support sorting by sales volume or margin. |
| **Profit by Category** | **Missing** | Med | S | Yes (`products.category`, `document_items.total_cost`) | Pro (`advancedReports`) | `AdvancedInventoryAnalyticsScreen` has category stock valuation share, but no report shows sales revenue, COGS, or profit broken down by category. |
| **Profit per Customer** | **Missing** | Med | M | Yes (`documents.contact_id`, `document_items.total_cost`) | Pro (`advancedReports`) | Customer balances only compute sales total and remaining amount; no customer-specific gross margin calculation exists. |
| **Sales by User / Cashier** | **Missing** | Med | S | Yes (`documents.created_by_user_id` / `actor_id`) | Pro (`multiUser`) | Multi-user tracking records user IDs on documents, but no report breaks down sales performance, cash collections, or discounts by cashier. |
| **Sales by Hour / Day of Week** | **Missing** | Low | S | Yes (`documents.date` timestamps) | Pro (`advancedReports`) | Enables retail rush-hour staffing analysis. Not currently analyzed. |
| **Tax Report (VAT / Sales Tax Breakdown)** | **Missing** | Med | S | Yes (`documents.tax_rate`, `tax_amount`, `document_items`) | Free | Tax rates and amounts are stored per invoice, and Account 2120 exists, but there is no report summarizing taxable sales, tax collected, and tax on purchases. |
| **Discounts Given Report** | **Missing** | Med | S | Yes (`documents.discount`) | Free | Discounts are stored on all documents, but there is no summary of total discounts granted or average discount rates. |
| **Returns & Cancellations Report** | **Partial** | Med | S | Yes (`status = 'cancelled'`, `stock_movements`) | Free | `SalesReportScreen` shows a simple count of cancelled invoices. There is no analysis of return reasons, refunded amounts, or stock impact. |
| **Period Comparison (This Month vs Last Month / Trends)** | **Missing** | Med | M | Yes (Historical SQLite records) | Pro (`advancedReports`) | Zero comparative analysis or percentage delta indicators exist across the application. |
| **Customer & Supplier Batch Statements** | **Partial** | Med | M | Yes (`CustomerStatementService`) | Pro (`advancedReports`) | Single customer statements can be generated from `CustomerDetailScreen`, but there is no batch statement generator or statement hub in Reports. |
| **Scheduled / Automated Daily Summary Notifications** | **Missing** | Low | M | Yes | Pro (`advancedReports`) | No background job or local notification schedules daily closing metrics. |
| **Pinned / Favorite Reports on Home Screen** | **Missing** | Low | S | N/A (UI preference) | Free | No report shortcuts or customization on `HomeScreen`. |
| **Comprehensive All-Reports Export Package** | **Missing** | Med | M | Yes | Pro (`advancedReports`) | No one-click package export (e.g. ZIP containing monthly P&L, sales ledger, stock report, and debt balances for the accountant). |

---

## 5. Recommended Roadmap

### Top 5 Quick Wins (Low Effort, High Impact)

1. **Fix the N+1 Query Bottleneck in Sales Report**
   - **Files to touch:** `lib/services/inventory_costing_service.dart:515-560`
   - **Implementation:** Refactor `getSalesReportWithCost` to execute a single joined query between `documents` and `document_items` (or fetch all items for the period in one batch using `WHERE document_id IN (...)`). This eliminates hundreds of sequential SQLite round-trips and makes opening the Sales Report instantaneous on low-end devices.

2. **Add PDF Export Action to Financial Accounting & Payments Screens**
   - **Files to touch:** `lib/screens/reports/accounting_screen.dart:80-95`, `lib/screens/reports/payments_report_screen.dart:90-95`
   - **Implementation:** Wire an export `IconButton` in the `AppBar` of `AccountingScreen` and `PaymentsReportScreen` that compiles the active tab (Income Statement, Balance Sheet, Trial Balance, or Payments List) into a `PdfReportData` payload and invokes `PdfService.printOrShareReportPdf`.

3. **Remediate Permission Inconsistencies and ScreenAccessGate Omissions**
   - **Files to touch:** `lib/screens/reports_screen.dart:151-161, 210`, `lib/services/access/screen_access_policy.dart:163, 166`, `lib/screens/reports/payments_report_screen.dart`, `customer_report_screen.dart`, `supplier_report_screen.dart`, `product_report_screen.dart`, `advanced_inventory_analytics_screen.dart`
   - **Implementation:** Reassign `PaymentsReportScreen` to `reportsViewSales` or `reportsViewFinancials`; enforce `PermissionRegistry.reportsViewReceivables` on `CustomerReportScreen` and `SupplierReportScreen`; align `ProductReportScreen` to `reportsViewSales`; and wrap all 5 unguarded report screen widget trees with `ScreenAccessGate`.

4. **Add Debounce to Inventory Report Live Search**
   - **Files to touch:** `lib/screens/reports/inventory_report_screen.dart:470-476`
   - **Implementation:** Replace direct `_load()` calls inside `TextField.onChanged` with a 300ms `Timer` cancellation and recreation cycle, preventing database locks and keyboard lag during product searching.

5. **Extract Hardcoded Localization Strings**
   - **Files to touch:** `lib/localization/app_localizations.dart`, `lib/screens/reports/sales_report_screen.dart:388-390`, `purchases_report_screen.dart:375-377`, `payments_report_screen.dart:134-136`, `accounting_screen.dart:142-144`
   - **Implementation:** Define proper bilingual getters in `AppLocalizations` (`legacyForeignDocumentsNotice`, `legacyPaymentsNotice`, `ledgerBaseCurrencyNotice`) and remove all inline `l10n.langCode == 'ar'` ternary conditionals.

---

### Top 5 Bigger Items (Medium-to-Large Projects)

1. **Daily Sales Summary & Cash Drawer (End-of-Day Z-Report)**
   - **Files to touch:** `lib/services/business_reporting_service.dart`, `lib/screens/reports/daily_closing_report_screen.dart` *(new)*, `lib/screens/reports_screen.dart`, `lib/localization/app_localizations.dart`
   - **Implementation:** Create a dedicated screen and service method aggregating today's activity: total gross sales, cash received, digital transfers (Bankak), credit sales, customer debts collected, supplier payments made, and cash expense vouchers paid. Present a clear "Expected Physical Cash in Drawer" calculation with an 80mm receipt-format PDF print option.

2. **Receivables & Payables Aging Analysis (0–30, 31–60, 60+ Days)**
   - **Files to touch:** `lib/database/database_helper.dart`, `lib/services/business_reporting_service.dart`, `lib/screens/reports/aging_report_screen.dart` *(new)*, `lib/screens/reports/customer_report_screen.dart`
   - **Implementation:** Implement SQL queries calculating remaining unpaid document balances grouped into aging intervals based on `JULIANDAY('now') - JULIANDAY(date)`. Provide tabular views for customers and suppliers with drill-downs into individual overdue invoices and direct WhatsApp debt reminder generation.

3. **Universal CSV Export Support Across All Reports**
   - **Files to touch:** `lib/services/csv_service.dart`, `lib/screens/reports/*.dart`, `lib/services/access/permission_registry.dart`
   - **Implementation:** Add a generic `Future<Uint8List> exportReportToCsv({required String title, required List<String> headers, required List<List<dynamic>> rows})` method in `CsvService`. Add a CSV export button on all report screens guarded by `PermissionRegistry.dataExportCsv`.

4. **Direct WhatsApp Sharing & Arabic Summary Cards**
   - **Files to touch:** `lib/services/pdf_service.dart`, `lib/screens/reports/*.dart`, `lib/localization/app_localizations.dart`
   - **Implementation:** Add an action sheet or split button on report headers providing "Share Summary via WhatsApp" alongside PDF export. Generate concise, pre-formatted Arabic text messages (e.g. Daily Sales: SDG 250,000, Invoices: 34, Cash: 180,000, Bankak: 70,000) sent directly via `SharePlus.instance.share`.

5. **Multi-Currency & Reference Currency Support in Reports**
   - **Files to touch:** `lib/screens/reports/customer_report_screen.dart`, `supplier_report_screen.dart`, `sales_report_screen.dart`, `inventory_report_screen.dart`
   - **Implementation:** Update customer and supplier balance queries to support a currency selector rather than blindly forcing base currency. In sales and inventory reports, add a toggle for merchants using `ReferenceCurrencyFeature` to display valuations and sales in reference currency (e.g. USD) based on recorded exchange rates.

---

## 6. Risks & Architectural Constraints

1. **Memory Pressure on 4 GB Low-End Devices**
   - **Risk:** Querying unpaginated datasets (e.g. thousands of historical invoices in `getSalesReportWithCost` or loading the entire database in `LedgerService.buildDerived`) creates memory spikes in Flutter. On devices under 4 GB RAM, the Android low-memory killer (LMK) will terminate backgrounded app instances.
   - **Mitigation:** Ensure all reporting queries use SQL-level aggregation (`SUM`, `COUNT`, `GROUP BY`) rather than fetching raw rows into Dart memory; enforce date ranges by default; and switch `journal_reports_enabled` to true.

2. **Single-Currency Invariance & Historical Data Integrity**
   - **Risk:** Waraqatak enforces a single operational currency model with isolated legacy currencies. Attempting naive currency conversion in reports without an authoritative transaction-date exchange rate table will corrupt financial metrics and violate accounting invariants (INV-14 through INV-18).
   - **Mitigation:** Maintain strict separation of legacy currencies in summary reports; never aggregate different currencies into a single numerical total without explicit user-configured exchange rates.

3. **Permission Leaks in Multi-User Deployments**
   - **Risk:** Cashiers having access to `PaymentsReportScreen` or navigating directly to unguarded report screens can inspect shop profitability and supplier costs, compromising business confidentiality.
   - **Mitigation:** Enforce `ScreenAccessGate` across all report screens and conduct automated guard checks in test suites to verify that no report screen can be rendered without corresponding report-level permissions.
