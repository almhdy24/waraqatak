# Waraqatak Reports Section — Architecture and Guide

This document provides a comprehensive reference for the Reports section of Waraqatak (ورقتك), an offline-first Flutter application tailored for Sudanese small and wholesale merchants running on low-resource Android devices.

---

## 1. Architectural Principles

1. **Offline-First & Local Computing:** All report queries execute against the local SQLite database. No external network requests or cloud telemetry are involved.
2. **Single Base Currency (SDG):** All active operations and reporting default to the merchant's configured base currency (SDG). Any legacy foreign-currency transactions are segregated and presented in read-only informational warning cards without nominal mixing.
3. **Strict Authorization & Deny-by-Default:** Every report screen is wrapped in a `ScreenAccessGate` backed by `ScreenAccessPolicy.manifest`. A user without the required permission is immediately blocked at the gate.
4. **Session-Scoped State:** User date selections persist during the active app session via `ReportsDateNotifier` and `ReportsDateScope` without unnecessary disk I/O.
5. **Memory & UI Fluidity:** Queries avoid N+1 per-document iterations, batch lookups in chunked `IN (...)` queries (<= 250 items), and UI debounces prevent background query race conditions.

---

## 2. Reports Inventory Table

| Report Screen | File Path | Data Source | Filters | Export Formats | Permission Required | Pro Gated? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Sales Report** | `lib/screens/reports/sales_report_screen.dart` | `InventoryCostingService.getSalesReportWithCost` | Date Range, Search (Customer/Invoice), Sort (Date/Amount) | PDF (A4/80mm), CSV, WhatsApp | `reports.view_sales` | No (Free) |
| **Daily Closing Report** | `lib/screens/reports/daily_closing_report_screen.dart` | `BusinessReportingService.getDailyClosingSummary` | Single Date (Today/Custom) | PDF (A4/80mm), CSV, WhatsApp | `reports.view_sales` | No (Free) |
| **Purchases Report** | `lib/screens/reports/purchases_report_screen.dart` | `BusinessReportingService.getPurchasesReport` | Date Range, Search (Supplier/Bill), Sort (Date/Amount) | PDF (A4/80mm), CSV, WhatsApp | `reports.view_purchases` | Yes (`Feature.advancedReports`) |
| **Payments Report** | `lib/screens/reports/payments_report_screen.dart` | `DatabaseHelper.getPaymentsReport` & `getPaymentMethodCashFlow` | Date Range, Type, Method | PDF (A4/80mm), CSV, WhatsApp | `reports.view_financials` | No (Free) |
| **Customer Balances** | `lib/screens/reports/customer_report_screen.dart` | `DatabaseHelper.getContactBalances` | Search, Sort (Name/Debt) | PDF (A4), CSV, WhatsApp | `reports.view_receivables` | No (Free) |
| **Supplier Balances** | `lib/screens/reports/supplier_report_screen.dart` | `DatabaseHelper.getContactBalances` | Search, Sort (Name/Debt) | PDF (A4), CSV, WhatsApp | `reports.view_receivables` | Yes (`Feature.advancedReports`) |
| **Debt Aging Report** | `lib/screens/reports/aging_report_screen.dart` | `BusinessReportingService.getAgingReport` | Contact Type (Customer/Supplier), As Of | PDF (A4/80mm), CSV, WhatsApp | `reports.view_receivables` | Free (Buckets) / Pro (Per-Contact) |
| **Taxes & Discounts** | `lib/screens/reports/tax_discount_report_screen.dart` | `BusinessReportingService.getTaxDiscountSummary` | Date Range | PDF (A4/80mm), CSV, WhatsApp | `reports.view_financials` | No (Free) |
| **Inventory Report** | `lib/screens/reports/inventory_report_screen.dart` | `BusinessReportingService.getInventoryReport` | Search, Filter (All/Low/Out) | PDF (A4), CSV, WhatsApp | `reports.view_inventory_cost` | Yes (`Feature.advancedReports`) |
| **Low Stock Report** | `lib/screens/reports/low_stock_report_screen.dart` | `BusinessReportingService.getInventoryReport` | Search | PDF (A4), CSV, WhatsApp | `products.view` | No (Free) |
| **Stock Movements** | `lib/screens/stock_movements_screen.dart` | `BusinessReportingService.getStockMovementsReport` | Date Range, Product, Movement Type | PDF (A4), CSV, WhatsApp | `products.view` | No (Free) |
| **Product Performance** | `lib/screens/reports/product_report_screen.dart` | `BusinessReportingService.getProductPerformance` | Date Range, Category, Metric Tab | PDF (A4), CSV, WhatsApp | `reports.view_sales` | Yes (`Feature.advancedReports`) |
| **Advanced Analytics** | `lib/screens/reports/advanced_inventory_analytics_screen.dart` | `BusinessReportingService.getAdvancedInventoryMetrics` | Date Range | PDF (A4), CSV, WhatsApp | `reports.view_inventory_cost` | Yes (`Feature.advancedReports`) |
| **Accounting Backbone** | `lib/screens/reports/accounting_screen.dart` | `LedgerService` & `JournalService` | Date Range, Account Filter | PDF (A4), CSV | `reports.view_financials` | Yes (`Feature.advancedReports`) |
| **Account Ledger** | `lib/screens/reports/accounting_screen.dart` | `LedgerService` (per-account GL) | Date Range | PDF (A4), CSV | `reports.view_financials` | Yes (`Feature.advancedReports`) |
| **Audit History** | `lib/screens/audit_history_screen.dart` | `DatabaseHelper.getAuditEvents` | Date Range, Event Type | PDF (A4), CSV, WhatsApp | `system.view_audit_trail` | Yes (`Feature.inventoryAudit`) |

---

## 3. Security & Access Model

- **ScreenAccessGate:** Every report screen is declared in `ScreenAccessPolicy.manifest` and evaluated against the authenticated user's assigned role permissions.
- **Granular Permissions:**
  - `reports.view_sales`: Granted to Cashier, Salesperson, Manager, Admin, Owner.
  - `reports.view_purchases`: Granted to Stockkeeper, Manager, Admin, Owner.
  - `reports.view_receivables`: Granted to Salesperson, Manager, Admin, Owner.
  - `reports.view_financials`: Reserved strictly for Manager, Admin, Owner.
  - `reports.view_inventory_cost`: Reserved strictly for Manager, Admin, Owner.
  - `products.view`: Granted to Cashier, Stockkeeper, Salesperson, Manager, Admin, Owner.
  - `system.view_audit_trail`: Reserved strictly for Admin and Owner.
- **Cashier Privacy & Separation of Concerns:**
  - The Cashier role is strictly blocked from `reports.view_financials` (Payments Report, Accounting) and `reports.view_inventory_cost` (Inventory Valuation, Cost Reconciliation, Stock Valuation in Advanced Analytics).
  - To enable operational replenishment without disclosing cost data, Cashiers navigate to **Low Stock Report** (`LowStockReportScreen`), which requires `products.view` and excludes all unit cost, purchase price, and total valuation metrics.
- **Export Action Permissions:**
  - `ReportExportMenu` verifies permissions before showing export options:
    - Print / Share PDF: requires `reports.export_pdf`.
    - Export CSV: requires `data.export_csv`.
    - If a user has neither permission, the export icon button in the AppBar is completely hidden via `ReportExportMenu.canExport()`.
- **Automatic Migration on Upgrade:**
  - Databases upgraded from earlier versions run `DatabaseHelper.runPostOpenMigrations` upon `onOpen`.
  - Roles and user overrides holding `contacts.view_balances` automatically receive `reports.view_receivables`, persisted via the `receivables_permission_migrated` app setting key to prevent loss of customer/supplier balance visibility.

---

## 4. Export & Sharing Standard

All exports are routed through `ReportExportMenu` presenting a unified bottom sheet:
1. **PDF Export:** Rendered using `PdfReportBuilder` with Arabic RTL font reshaping, support for Western numerals (`0-9`), and responsive page formats (A4 Portrait or 80mm POS Thermal Roll).
2. **CSV Export:** Generated via `CsvService.exportReportToCsv` adhering strictly to RFC 4180 with UTF-8 BOM (`\uFEFF`) and CRLF (`\r\n`) line endings:
   - Real numeric values (`val is num`) and strings that represent valid numbers (`^[+-]?\d+(\.\d+)?$`) are emitted raw without leading apostrophe, preserving negative amounts (`-250`, `-12.75`) and contact phone numbers (`+249912345678`).
   - Non-numeric strings starting with dangerous formula or command characters (`=, +, -, @, \t, \r`) are safely escaped with a leading single quote (`'`).
3. **WhatsApp Text Sharing & Direct Reminders:**
   - General report summaries generate clean, copy-paste friendly text formatted for Sudanese merchant communications.
   - **Aging Payment Reminders:** Recipient phone numbers are automatically normalized via `normalizeSudanPhone` (auto-detecting `09x` Zain/MTN and `01x` Sudani, standardizing to international `249` + 9 digits). If a valid phone is present, the app launches WhatsApp directly via `https://wa.me/<digits>?text=<encodedMessage>`. If WhatsApp is not installed or phone number is absent, it falls back seamlessly to the Android system share sheet via `PdfService.shareText`.

---

## 5. Debt Aging & Calculation Invariants

- **Posted Documents Only:** Financial and aging aggregations strictly exclude draft and cancelled documents (`status NOT IN ('draft', 'cancelled')`).
- **Eligible Types:** Debt aging calculates exclusively on `invoice` (receivables) and `purchase` (payables) documents. Quotations and pro-forma documents are excluded.
- **Partial Payments:** Accurately accounts for partial payments by subtracting `paid_amount` from `total_amount`, bucketing the remaining outstanding balance.
- **Aging Buckets:** Standard 4-bucket breakdown based on days elapsed since issue:
  - 0–30 days
  - 31–60 days
  - 61–90 days
  - 90+ days
- **Currency Isolation:** Aggregations strictly filter by `(currency_code = ? OR currency_code IS NULL)` to prevent summing mixed nominal currencies. Any legacy foreign transactions are highlighted with an informational warning banner.
