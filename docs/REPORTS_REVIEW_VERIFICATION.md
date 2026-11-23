# Waraqatak Reports Audit Verification Report

**Date:** 2026-11-23  
**Review Target:** `docs/REPORTS_REVIEW.md`  
**Mode:** Independent Second-Review / Verification Only (No source code modified).

---

## 1. Baseline

- **Git Branch:** `main`
- **HEAD Commit Hash:** `b25831f9b1f2c9bca08df942ad7cc866469384e3`
- **HEAD Commit Date:** `Sun Nov 22 06:54:19 2026 +0200`
- **HEAD Commit Subject:** `fix(test): await expectLater in fifo currency segregation test to prevent race with finally cleanup`
- **Git Status:** Working tree clean (prior to creating this verification report; `docs/REPORTS_REVIEW.md` was untracked and created on 2026-11-23 against this exact commit).
- **Audit Synchronization:** The audit in `docs/REPORTS_REVIEW.md` was written against this identical HEAD commit (`b25831f`).

---

## 2. Verdict Table

Below is the exhaustive verification of all 17 numbered findings, 14 inventory table rows, 17 gap analysis rows, 10 roadmap items, and 3 risk assessments from `docs/REPORTS_REVIEW.md`.

*Verdicts:* **CONFIRMED** (Claim is factually accurate), **PARTIAL** (Finding exists but specific mechanism, scope, or severity is inaccurate), **WRONG** (Claim is factually incorrect), **UNVERIFIED** (Cannot be established from static review).

### Numbered Findings (1–17)

| # | Finding / Claim | Verdict | Evidence (File:Line) | Corrected Severity | Corrected Effort | Notes / Verification Details |
| :- | :--- | :---: | :--- | :---: | :---: | :--- |
| **1** | N+1 database query loop in `getSalesReportWithCost` | **PARTIAL** | `lib/services/inventory_costing_service.dart:515, 530` | High | S | Confirmed sequential per-document query loop on `document_items`. However, `sqflite` operations are asynchronous and do not block the OS main Looper (will not trigger ANR directly); the real issue is async latency, GC churn, and frame drops. Moreover, `document_items.total_cost` is a stored snapshot, so no dynamic FIFO calculation is needed in the loop. |
| **2** | Permission guard discrepancies & `ScreenAccessGate` omissions | **CONFIRMED** | `lib/screens/reports_screen.dart:153, 161, 210` vs `lib/services/access/screen_access_policy.dart:163, 166` | High | S | Fully confirmed. `PaymentsReportScreen` uses `payments.record`; `CustomerReportScreen` bypasses `reports.view_receivables`; `ProductReportScreen` has mismatched policies (`view_inventory_cost` vs `view_sales`). In addition, 7 report screens (not just 5) lack `ScreenAccessGate`. |
| **3** | Financial Accounting statements unexportable | **CONFIRMED** | `lib/screens/reports/accounting_screen.dart:80-95` | High | S | Fully confirmed. `AccountingScreen`'s `AppBar` specifies only `title` and `bottom` (TabBar); `actions` is completely null. Income Statement, Balance Sheet, and Trial Balance cannot be exported, printed, or shared. |
| **4** | Un-debounced search in Inventory Report | **CONFIRMED** | `lib/screens/reports/inventory_report_screen.dart:472-474` | High | S | Fully confirmed. `TextField.onChanged` fires `_load()` immediately without debounce. Furthermore, it lacks a request-sequence guard (`_querySeq`), introducing an asynchronous race condition where an older query can overwrite a newer result. |
| **5** | Silent omission of foreign-currency customer/supplier balances | **PARTIAL** | `lib/screens/reports/customer_report_screen.dart:66-70`, `supplier_report_screen.dart:66-70` | Med (was High) | S | Foreign rows are indeed filtered out without a UI banner in customer/supplier screens. However, this is **only relevant for legacy pre-1.1.5 databases**. Since 1.1.5, base currency is locked and multi-currency document creation is completely blocked. |
| **6** | Absence of CSV export across all reports | **CONFIRMED** | `lib/services/csv_service.dart:105-1252`, `lib/screens/reports/*.dart` | Med | M | Fully confirmed. `CsvService` is solely used for product catalog import/export (`csv_import_export_screen.dart:58`). Zero report screens contain CSV export logic. |
| **7** | Print spooler triggered instead of direct WhatsApp/native share | **CONFIRMED** | `lib/services/pdf_service.dart:186` | Med | S | Fully confirmed. `printOrShareReportPdf` unconditionally calls `Printing.layoutPdf`. The direct `SharePlus.instance.share` pattern present in `shareCustomerStatementPdf` (lines 139–145) is not utilized for business reports. |
| **8** | Hardcoded user-facing strings violating localization | **CONFIRMED** | `sales_report_screen.dart:388-390`, `purchases_report_screen.dart:375-377`, `payments_report_screen.dart:134-136`, `accounting_screen.dart:142-144` | Med | S | Fully confirmed. All four screens utilize inline ternary expressions checking `l10n.langCode == 'ar'` instead of defining getters in `AppLocalizations`. |
| **9** | Ephemeral date filter state resets across reports | **CONFIRMED** | `sales_report_screen.dart:67`, `purchases_report_screen.dart:29`, `payments_report_screen.dart:27`, `product_report_screen.dart:30` | Med | S | Fully confirmed. Each screen instantiates its own `DateRangeFilter _range = DateRangeFilter.thisMonth()` in private State. Date selection is not retained across navigation. |
| **10** | Digit truncation and layout squishing on narrow screens (320–360 dp) | **CONFIRMED** | `sales_report_screen.dart:314-358, 550`, `purchases_report_screen.dart:210-299`, `inventory_report_screen.dart:542-550` | Med | S | Fully confirmed. Placing 3 summary chips in a single horizontal `Row` with `TextOverflow.ellipsis` truncates formatted SDG monetary figures. `PurchasesReportScreen` squeezes 3 dropdowns into one row. |
| **11** | Total absence of charts and visual summaries | **CONFIRMED** | Entire `lib/screens/reports/`, `pubspec.yaml` | Med | M | Fully confirmed. No charting library is imported; category share is rendered as a text percentage inside a `CircleAvatar` (`advanced_inventory_analytics_screen.dart:425`). |
| **12** | Full database scan on derived accounting screen loads | **CONFIRMED** | `lib/services/accounting/ledger_service.dart:60, 102` | Med | S | Fully confirmed. `LedgerService.buildDerived` loads all documents, items, movements, and payments via `db.getLedgerData()` and derives ledger entries in memory via `Isolate.run`. |
| **13** | Inconsistent UI tokens and custom chip duplication | **CONFIRMED** | `customer_report_screen.dart:163`, `payments_report_screen.dart:172`, `sales_report_screen.dart:530` | Low | S | Fully confirmed. `AppMetricCard` is used only on `HomeScreen:900`; report screens implement divergent custom containers. |
| **14** | Customer and supplier reports lack date range filtering | **CONFIRMED** | `customer_report_screen.dart:66-72`, `supplier_report_screen.dart:66-72` | Low | S | Fully confirmed. Both screens execute `getContactBalances` without date parameters; no `ReportDateFilter` widget is present. |
| **15** | Lack of sorting and search on sales, purchases, and debts | **CONFIRMED** | `sales_report_screen.dart:289`, `customer_report_screen.dart:144` | Low | S | Fully confirmed. No search text field or sort dropdown exists on Sales, Purchases, Customer, or Supplier reports. |
| **16** | Thermal roll (80mm) paper size unsupported for reports | **CONFIRMED** | `lib/services/pdf/pdf_report_builder.dart:101` | Low | S | Fully confirmed. `PdfReportBuilder` hardcodes `PdfPageFormat.a4`. Receipt roll formats are not supported for reports. |
| **17** | Missing pull-to-refresh on report lists | **CONFIRMED** | `sales_report_screen.dart:301`, `purchases_report_screen.dart:195` | Low | S | Fully confirmed. None of the primary report `ListView`s are wrapped in `RefreshIndicator`. |

---

### Inventory Table Claims (Section 2)

| Report Item | Claimed Details in Audit | Verdict | Evidence (File:Line) | Verification Details |
| :--- | :--- | :---: | :--- | :--- |
| **Financial Accounting** | `accounting_screen.dart`, `LedgerService`, DateFilter, No export, Pro, Base currency isolated | **CONFIRMED** | `accounting_screen.dart:80-120` | Exactly matches code. |
| **Account Ledger** | `accounting_screen.dart`, `LedgerBook.entries`, DateFilter, No export, Pro, Base currency | **CONFIRMED** | `accounting_screen.dart:739` | Exactly matches code. |
| **Sales Report** | `sales_report_screen.dart`, `InventoryCostingService`, DateFilter, PDF only, Free, Base + legacy | **CONFIRMED** | `sales_report_screen.dart:94, 287` | Exactly matches code. |
| **Purchases Report** | `purchases_report_screen.dart`, `BusinessReportingService`, DateFilter + 3 dropdowns, PDF, Pro | **CONFIRMED** | `purchases_report_screen.dart:45, 181` | Exactly matches code. |
| **Payments Report** | `payments_report_screen.dart`, `DatabaseHelper.getPaymentReport`, DateFilter, No export, Free | **CONFIRMED** | `payments_report_screen.dart:43, 89` | Exactly matches code. |
| **Customer Balances** | `customer_report_screen.dart`, `DatabaseHelper.getContactBalances`, No filters, PDF only, Free | **CONFIRMED** | `customer_report_screen.dart:66, 144` | Exactly matches code. |
| **Supplier Balances** | `supplier_report_screen.dart`, `DatabaseHelper.getContactBalances`, No filters, PDF only, Pro | **CONFIRMED** | `supplier_report_screen.dart:66, 155` | Exactly matches code. |
| **Inventory Report** | `inventory_report_screen.dart`, `BusinessReportingService`, Status tabs + search, PDF, Pro | **CONFIRMED** | `inventory_report_screen.dart:67, 379` | Exactly matches code. |
| **Low Stock Report** | `inventory_report_screen.dart`, Pre-filtered to `low_stock`, PDF, Pro (`stock.adjust`) | **CONFIRMED** | `reports_screen.dart:190-193` | Exactly matches code. |
| **Stock Movements** | `stock_movements_screen.dart`, `BusinessReportingService`, DateFilter + product picker, PDF, Pro | **CONFIRMED** | `stock_movements_screen.dart:58, 369` | Exactly matches code. |
| **Product Report** | `product_report_screen.dart`, `BusinessReportingService`, 3 tabs + sort/category, PDF, Pro | **CONFIRMED** | `product_report_screen.dart:68, 286` | Exactly matches code. |
| **Advanced Inventory**| `advanced_inventory_analytics_screen.dart`, `BusinessReportingService`, 4 tabs, PDF, Pro | **CONFIRMED** | `advanced_inventory_analytics_screen.dart:88, 166` | Exactly matches code. |
| **Audit History Log** | `audit_history_screen.dart`, `AuditService.queryLogs`, Action/Date filters, No export, Pro | **CONFIRMED** | `audit_history_screen.dart:58, 162` | Exactly matches code. |
| **Customer Statement**| Claimed: "Currency selector dropdown" & "Multi-currency selectable" | **WRONG** | `lib/widgets/customer_statement_dialog.dart:85-110` | The currency dropdown was **removed** during single-currency consolidation (`docs/single_currency_design.md`). `_selectedCurrency = fallback;` is hardcoded; if legacy foreign documents exist, an informational banner is shown. |

---

### Gap Analysis Table Claims (Section 4)

| Feature | Audit Claimed Status | Audit Claimed Data Dependency | Verdict | Evidence (File:Line) | Verification Details |
| :--- | :---: | :--- | :---: | :--- | :--- |
| **Daily Sales / EOD** | Missing | `documents`, `document_payments`, `vouchers` | **CONFIRMED** | `database_helper.dart:411, 485` | Missing; data is fully present in tables. |
| **Debt Aging** | Missing | `documents.date`, `due_date`, `remaining` | **PARTIAL** | `database_helper.dart:411-435` | The feature is missing, but **`due_date` column does not exist** on `documents`. Aging must be computed from `documents.date`. |
| **Cash Flow by Method** | Partial | `document_payments.payment_method`, `vouchers` | **CONFIRMED** | `payments_report_screen.dart:80-84` | Flat list exists; summary by method is missing. |
| **Full P&L** | Partial | `journal_lines` or `documents` + `vouchers` | **CONFIRMED** | `ledger.dart:829-854` | Income statement exists in Pro Accounting; missing for Free users. |
| **Top Customers/Products**| Partial | `documents`, `document_items`, `products` | **CONFIRMED** | `product_report_screen.dart:354` | Product sorting exists; customer volume sorting is missing. |
| **Profit by Category** | Missing | `products.category`, `document_items.total_cost` | **CONFIRMED** | `lib/screens/reports/` | Only stock valuation share exists; profit by category is missing. |
| **Profit per Customer** | Missing | `documents.contact_id`, `document_items.total_cost`| **CONFIRMED** | `customer_report_screen.dart:66` | Only customer sales and debt exist; profit per customer is missing. |
| **Sales by Cashier** | Missing | Claimed: `documents.created_by_user_id` / `actor_id` | **WRONG** | `database_helper.dart:411-435`, `document.dart:1-135` | The feature is missing, but **neither `created_by_user_id` nor `actor_id` exists on `documents`**! User attribution is only recorded in `audit_log.user_id`. Requires schema migration or audit join. |
| **Sales by Hour/Day** | Missing | `documents.date` timestamps | **CONFIRMED** | `document.dart:8` | Missing; ISO timestamps exist in `documents.date`. |
| **Tax Report** | Missing | `documents.tax_rate`, `tax_amount`, `document_items` | **CONFIRMED** | `database_helper.dart:422-423, 462` | Missing; tax rates and amounts exist per document and item. |
| **Discounts Report** | Missing | `documents.discount` | **CONFIRMED** | `database_helper.dart:421` | Missing; `discount` is recorded on every document. |
| **Returns / Cancelled**| Partial | `status = 'cancelled'`, `stock_movements` | **CONFIRMED** | `sales_report_screen.dart:495` | Simple cancelled count exists; financial/stock return analysis missing. |
| **Period Comparison** | Missing | Historical SQLite records | **CONFIRMED** | `lib/screens/reports/` | No delta comparisons or trends exist anywhere in reports. |
| **Batch Statements** | Partial | `CustomerStatementService` | **CONFIRMED** | `customer_statement_dialog.dart:104` | Single statement modal exists; batch generation is missing. |
| **Scheduled Summaries**| Missing | Local notifications / alarms | **CONFIRMED** | `pubspec.yaml` | No local notifications library or background worker exists. |
| **Pinned Reports** | Missing | UI preference / local storage | **CONFIRMED** | `home_screen.dart:657` | Only generic shortcut to `ReportsScreen` exists. |
| **Export All Package** | Missing | SQLite batch queries | **CONFIRMED** | `lib/screens/reports_screen.dart` | No multi-report archive export exists. |

---

### Roadmap Claims (Section 5)

| Roadmap Item | Audit Plan & File List | Verdict | Evidence (File:Line) | Corrected Notes |
| :--- | :--- | :---: | :--- | :--- |
| **Quick Win 1 (N+1)** | Refactor `getSalesReportWithCost` in `inventory_costing_service.dart` | **CONFIRMED** | `inventory_costing_service.dart:515` | Sound plan. Batch IN-query or JOIN must chunk or avoid parameter overflow on SQLite (max 999 vars). |
| **Quick Win 2 (Exports)** | Add PDF export to `AccountingScreen` and `PaymentsReportScreen` | **CONFIRMED** | `accounting_screen.dart:80`, `payments_report_screen.dart:90` | Sound plan. Reuses `PdfReportBuilder`. |
| **Quick Win 3 (Permissions)**| Fix `paymentsRecord`, `reportsViewReceivables`, and `ScreenAccessGate` | **CONFIRMED** | `reports_screen.dart:153, 161`, `screen_access_policy.dart:163` | Sound plan. Must wrap all 7 unguarded report screens. |
| **Quick Win 4 (Debounce)** | Add 300ms debounce to `InventoryReportScreen` search | **CONFIRMED** | `inventory_report_screen.dart:472` | Sound plan. Must also add sequence guard (`_querySeq`) to prevent async overwrite. |
| **Quick Win 5 (L10n)** | Extract hardcoded ternary strings to `AppLocalizations` | **CONFIRMED** | `sales_report_screen.dart:388` etc. | Sound plan. Preserves clean RTL translation architecture. |
| **Big Item 1 (EOD Report)** | Create `daily_closing_report_screen.dart` and aggregation service | **CONFIRMED** | `database_helper.dart:411` | High user value for daily retail shop closing. |
| **Big Item 2 (Aging Report)**| Create receivables/payables aging buckets | **PARTIAL** | `database_helper.dart:411` | Sound plan, but must compute aging from `documents.date` (not `due_date` which does not exist). |
| **Big Item 3 (CSV Export)** | Add generic CSV export helper in `CsvService` | **CONFIRMED** | `csv_service.dart:105` | High utility for merchants exporting to spreadsheets. |
| **Big Item 4 (WhatsApp)** | Add direct WhatsApp share with formatted Arabic text via `SharePlus` | **CONFIRMED** | `pdf_service.dart:139` | High value; directly replicates existing customer statement pattern. |
| **Big Item 5 (Multi-Currency)**| "Multi-Currency & Reference Currency Support in Reports" | **PARTIAL** | `docs/single_currency_design.md:1-50` | **Multi-currency document reporting is obsolete/invalid** under the single-currency architecture. Only the reference-currency pricing toggle (converting base SDG to USD/SAR for inflation tracking) is valid. |

---

### Risks (Section 6)

| Risk Item | Audit Assessment | Verdict | Evidence (File:Line) | Verification Details |
| :--- | :--- | :---: | :--- | :--- |
| **Memory Pressure** | Unpaginated datasets cause memory spikes on 4 GB RAM phones | **CONFIRMED** | `ledger_service.dart:60`, `sales_report_screen.dart:94` | Confirmed. However, warning: blindly setting `journal_reports_enabled = true` without prior parity verification poses data synchronization risk. |
| **Single-Currency Invariance** | Uncontrolled mixing of currencies distorts accounting | **CONFIRMED** | `docs/single_currency_design.md:20` | Confirmed. Adheres to Hard Invariants INV-14..18. |
| **Permission Leaks** | Cashiers accessing payments report via `paymentsRecord` | **CONFIRMED** | `reports_screen.dart:153`, `access_seeder.dart:21` | Confirmed. Cashier default template role has `paymentsRecord`. |

---

## 3. Specific Doubts Settled (Step 2 Detailed Answers)

### Doubt 1: Sales Report N+1 Query Loop
- **Is it really a per-document query loop?** Yes. `lib/services/inventory_costing_service.dart:515-534` iterates over `docMaps` and executes `await db.query('document_items', where: 'document_id = ?', whereArgs: [doc.id])` sequentially for every non-cancelled document.
- **How many queries per N documents?** Exactly $1 + K$ queries, where $K$ is the number of non-cancelled documents in the date range. If all $N$ documents are active, exactly $N + 1$ queries.
- **Is cost calculation per item (FIFO/AVCO) dependent on the loop?** No. The loop simply accumulates `docCogs += (item['total_cost'] as num?)?.toDouble() ?? 0.0`. `total_cost` is a static snapshot persisted on `document_items` at document issuance. A joined query or grouped aggregation preserves this calculation with 100% precision.
- **SQLite parameter limits:** Older Android versions limit SQL variables to 999 (`SQLITE_MAX_VARIABLE_NUMBER`). If `WHERE document_id IN (?, ?, ...)` is used with over 999 documents, SQLite throws an exception. The query must either:
  1. Use chunking (batches of 400 IDs), or
  2. Use a direct subquery: `WHERE document_id IN (SELECT id FROM documents WHERE ...)` which requires zero variable bindings.
- **UI thread impact:** `sqflite` runs on a background native thread via platform channels. It does not block the Android UI Looper synchronously (no direct ANR from a blocked Looper). However, awaiting hundreds of micro-futures sequentially delays data display by multiple seconds and causes garbage collection stutter. Corrected severity remains **High** for user experience, but technical wording must specify *async latency and GC jank*, not *thread deadlock*.

### Doubt 2: Inventory Search Race Condition
- **Is it only un-debounced?** No. It contains a critical asynchronous race condition.
- **Evidence:** In `lib/screens/reports/inventory_report_screen.dart:40-75, 472-474`, `_load()` is invoked on every character change without any sequence counter (`_querySeq`) or cancellation token.
- **Race scenario:** If query #1 (triggered by typing "s") takes 150ms and query #2 (triggered by typing "su") takes 50ms, query #2 updates the UI first. Query #1 then finishes later and overwrites the UI state with stale results. The search field displays "su" while the list renders products matching "s". A sequence guard (`_querySeq`) must be added alongside a 300ms debounce timer.

### Doubt 3: `journal_reports_enabled` Analysis
- **Definition & Default:** Defined in `lib/services/accounting/ledger_service.dart:28` (`settingKeyJournalReportsEnabled = 'journal_reports_enabled'`). Stored in `app_settings` table. Defaults to `'false'` (`ledger_service.dart:35`).
- **Why was it false?** Introduced in commit `2021952` ("feat: report switch behind flag and diagnostics UI (Phase 5)"). As documented in `docs/accounting_backbone_design.md:209` and commit `ab1a778`, it is an intentional architectural safety rail: the app preserves the trusted derived ledger until the user or test suite runs parity verification on production data. Furthermore, commit `ab1a778` enforces that **any database restore resets `journal_reports_enabled` to `false`**.
- **Is backfill complete?** `JournalBackfillService.backfillIfNeeded()` executes automatically on startup and legacy restore. However, if backfill encounters a parity discrepancy, it rolls back and writes `journal_parity_failed_at`.
- **Verdict on flipping default:** **Do NOT blindly flip the default to `true` in code.** If a merchant's database has incomplete backfill or parity discrepancies, forcing `journal_reports_enabled = true` will render empty or corrupted accounting statements. Backfill completion and zero parity diff must be verified before enabling the persisted journal report switch.

### Doubt 4: Permissions & Cashier Leak Analysis
- **Seeded Roles:** In `lib/services/access/access_seeder.dart:14-85`:
  - `roleTemplateSalesperson` (Cashier) holds: `salesView`, `salesCreate`, `salesEdit`, `salesEditPrice`, `salesEditDiscount`, `paymentsRecord`, `productsView`, `productsViewWholesale`, `contactsView`, `contactsManage`, `contactsViewBalances`, `reportsViewSales`, `reportsExportPdf`.
  - `roleTemplateInventory` holds stock and purchase permissions.
  - `roleTemplateAccountant` holds all reporting permissions.
  - `roleTemplateManager` holds all except dangerous system recovery permissions.
- **Cashier sees payments report leak:** **100% REAL.** In `reports_screen.dart:151-153`, `PaymentsReportScreen` is gated on `PermissionRegistry.paymentsRecord`. Because `roleTemplateSalesperson` possesses `paymentsRecord` (necessary to accept cash from customers), every cashier can open `PaymentsReportScreen` and view all incoming and outgoing company cash flows.
- **Is `reports.view_receivables` unused?** **YES, 100% DEAD CODE.** Grepping `lib/` and `test/` reveals it is referenced only in `permission_registry.dart`, `access_seeder.dart`, and `app_localizations.dart`. It is not enforced by any screen or guard.
- **ScreenAccessGate Wrap Status:**
  - *Wrapped (5 screens):* `AccountingScreen`, `AccountLedgerScreen`, `SalesReportScreen`, `PurchasesReportScreen`, `InventoryReportScreen`.
  - *NOT Wrapped (7 screens):* `PaymentsReportScreen`, `CustomerReportScreen`, `SupplierReportScreen`, `ProductReportScreen`, `AdvancedInventoryAnalyticsScreen`, `StockMovementsScreen`, `AuditHistoryScreen`.
- **Why is Low Stock gated by `stock.adjust`?** In `reports_screen.dart:192`, it was mapped to `PermissionRegistry.stockAdjust` because inventory clerks adjusting stock needed it. This is defective design: reading low stock is an analytical read operation; gating it behind a write/mutation permission prevents sales and management staff from viewing stock shortages.
- **Migration requirement:** If `PaymentsReportScreen` is remapped to `reportsViewFinancials`, custom roles or users created prior to the update will retain their existing role permission sets. A database migration script in `access_dao.dart` must ensure that custom cashier roles do not retain unintended access.

### Doubt 5: Currency Consolidation Reality
- **Single-Currency Policy:** As documented in `docs/single_currency_design.md`, Waraqatak eliminated multi-currency switching in v1.1.5. Base currency is irrevocably locked at first transaction.
- **Legacy foreign-currency handling:** Handled in `SalesReportScreen`, `PurchasesReportScreen`, and `PaymentsReportScreen` via segregated read-only cards at the bottom of the list (`sales_report_screen.dart:363`).
- **Relevance of Finding 5:** `CustomerReportScreen` and `SupplierReportScreen` pass `currencyCode: currency` to `getContactBalances`, which filters out foreign currency rows. However, this is **relevant only for legacy data prior to v1.1.5**. No new foreign-currency documents can be created in the app.
- **Customer Statement Currency Selector:** **DOES NOT EXIST.** The audit was factually mistaken. `customer_statement_dialog.dart:85-110` binds directly to base currency; the selector was eliminated in v1.1.5.
- **Roadmap Item 5 Verdict:** Re-introducing multi-currency document reporting is **OBSOLETE and violates project invariants**. However, adding a toggle to display report totals in Reference Currency (e.g. converting base SDG to USD based on current exchange rates for inflation tracking) is valid.

### Doubt 6: Date Filter & Numerical Formatting
- **Shared state:** Confirmed. Reports do not share date filter state. Each screen instantiates its own `DateRangeFilter _range = DateRangeFilter.thisMonth()`.
- **Digit style:** All report screens strictly use Western numerals (`0-9`). Dates are formatted using `AppDateUtils.formatDate` (which normalizes Arabic-Indic digits to Western digits), and monetary quantities use `FormatUtils` and `NumberFormat('#,##0.##', 'en_US')`.

### Doubt 7: Export Capabilities & WhatsApp Reuse
- **PDF Export Screens:** 9 out of 11 report screens support PDF export. The only screens lacking PDF export are `AccountingScreen` and `PaymentsReportScreen`.
- **`PdfService.printOrShareReportPdf` mechanism:** Confirmed. Line 186 exclusively calls `Printing.layoutPdf`.
- **WhatsApp Share Path:** `SharePlus.instance.share` is already utilized in `shareCustomerStatementPdf` (`lib/services/pdf_service.dart:139-145`). It can be directly adapted for general reports to share an Arabic text summary alongside a generated PDF.

### Doubt 8: Gap Table & Schema Column Verification
- **`due_date`:** **DOES NOT EXIST.** Not in `documents` or anywhere in `lib/`. Documents have `valid_until` (for quotes) and `date` (issue date). Debt aging must use `documents.date`.
- **`created_by_user_id` / `actor_id`:** **DOES NOT EXIST ON `documents`.** User attribution is only recorded in `audit_log.user_id`. Sales attribution by cashier requires adding a `user_id` column to `documents` via migration or querying `audit_log`.
- **All other claimed columns exist:** `documents.date`, `remaining`, `discount`, `tax_rate`, `tax_amount`, `document_payments.payment_method`, `vouchers`, `products.category`, `document_items.total_cost`.

### Doubt 9: Omissions in Original Audit
The original audit thinly covered:
1. **Touch Targets:** `FilterChip` in `report_date_filter.dart:53` uses `VisualDensity.compact` (~32dp height), below the 48dp accessibility guideline.
2. **Text Scaling:** Fixed container heights (`height: 40`) in `inventory_report_screen.dart:455, 484` and `product_report_screen.dart:308, 346` cause text clipping when system font size is increased.
3. **Empty/Error States:** Inconsistent implementations; `payments_report_screen.dart`, `customer_report_screen.dart`, and `supplier_report_screen.dart` use raw `CircularProgressIndicator` instead of `AppLoadingView` and `AppErrorState`.
4. **Drill-Down Gaps:** Product report rows and inventory report rows cannot be tapped to view product stock cards or document details. Standalone vouchers in `PaymentsReportScreen` have null `document_id` and cannot be opened.
5. **Pagination:** Absent across all report screens except `StockMovementsScreen`.

### Doubt 10: Verification Honesty
The audit marked zero items as "unverified" despite containing two demonstrably wrong claims:
1. Claiming `documents` has `created_by_user_id` and `due_date` columns (they do not exist).
2. Claiming `CustomerStatementDialog` has a currency dropdown selector (it was removed in v1.1.5).

---

## 4. New Issues Found (Missed by Original Audit)

1. **Async Race Condition on Inventory Search (`inventory_report_screen.dart:472-474`)**
   - **Severity:** High
   - **Details:** In addition to being un-debounced, search queries lack an incrementing request counter (`_querySeq`). An older slow query can resolve after a newer faster query, overwriting results and displaying stale data.
   - **Fix:** Introduce `int _querySeq = 0;` and verify `if (seq != _querySeq) return;` before calling `setState`.

2. **Missing `ScreenAccessGate` on Stock Movements & Audit History**
   - **Severity:** High
   - **Details:** The audit noted 5 unguarded screens, but missed that `StockMovementsScreen` (`lib/screens/stock_movements_screen.dart:369`) and `AuditHistoryScreen` (`lib/screens/audit_history_screen.dart:162`) also return raw `Scaffold` without `ScreenAccessGate`.
   - **Fix:** Wrap both screens with `ScreenAccessGate`.

3. **Standalone Vouchers Unclickable in Payments Report (`payments_report_screen.dart:233-235`)**
   - **Severity:** Med
   - **Details:** `ListTile.onTap` is conditional on `row['document_id'] != null`. Standalone expense vouchers and payment receipts have `document_id == null`, making them unclickable dead tiles with no way to view the voucher details.
   - **Fix:** Check `row['voucher_id']` or `doc_type` and navigate to `VoucherScreen` or voucher detail dialog.

4. **Hardcoded Container Heights Clamping Accessibility Text Scaling**
   - **Severity:** Med
   - **Details:** `inventory_report_screen.dart:455, 484` and `product_report_screen.dart:308, 346` force `height: 40` on containers wrapping dropdowns and search inputs. When Android system accessibility font scale exceeds 1.0, vertical overflow errors occur.
   - **Fix:** Remove hardcoded container heights and use standard `InputDecoration.isDense` with vertical content padding.

5. **No Product Card Drill-Down from Product and Inventory Reports**
   - **Severity:** Low
   - **Details:** In `ProductReportScreen` and `InventoryReportScreen`, product list tiles have `onTap: null`. Merchants cannot tap a product to inspect its movement history or stock details.
   - **Fix:** Add `onTap` navigating to product stock card or editing view.

---

## 5. Corrected Priority List & Implementation Roadmap

| Priority | Task | Target Files | Effort | Risks & Considerations |
| :---: | :--- | :--- | :---: | :--- |
| **1** | **Fix Sales Report N+1 Query Loop** | `lib/services/inventory_costing_service.dart:515-560` | **S** | *Risk: Low.* Stored `total_cost` must be preserved; use subquery or batching under 500 parameters to avoid SQLite variable limits on older Android versions. |
| **2** | **Debounce & Race-Guard Inventory Search** | `lib/screens/reports/inventory_report_screen.dart:470-476` | **S** | *Risk: Low.* Add 300ms `Timer` debounce and `_querySeq` counter to eliminate typing stutter and out-of-order UI overwrites. |
| **3** | **Remediate Security & Missing ScreenAccessGates** | `lib/screens/reports_screen.dart:153, 161`, `screen_access_policy.dart:163`, 7 report screens | **S** | *Risk: Medium (Permissions Migration).* Remap `PaymentsReportScreen` to `reportsViewSales` or `reportsViewFinancials`; enforce `reportsViewReceivables`; wrap all 7 unguarded screens in `ScreenAccessGate`. Note: custom role overrides in existing databases must be updated. |
| **4** | **Add PDF Export to Accounting & Payments** | `accounting_screen.dart:80`, `payments_report_screen.dart:90` | **S** | *Risk: Low.* Compile active tab into `PdfReportData` and call `PdfService.printOrShareReportPdf`. |
| **5** | **Extract Hardcoded Localization Strings** | `sales_report_screen.dart:388`, `purchases_report_screen.dart:375`, `payments_report_screen.dart:134`, `accounting_screen.dart:142`, `app_localizations.dart` | **S** | *Risk: Zero.* Replaces inline ternary strings with proper bilingual getters in `AppLocalizations`. |
| **6** | **Daily Sales Summary & EOD (Z-Report)** | `business_reporting_service.dart`, `daily_closing_report_screen.dart` *(new)*, `reports_screen.dart` | **M** | *Risk: Low (Additive).* Essential retail feature. Aggregates today's cash, Bankak, credit sales, debt collected, and cash expenses with drawer reconciliation. |
| **7** | **Direct WhatsApp Share with Arabic Summary** | `pdf_service.dart:168-192`, `reports/*.dart` | **S** | *Risk: Low.* Reuses existing `SharePlus.instance.share` pattern with pre-formatted Arabic summary text. |
| **8** | **Receivables & Payables Aging Report** | `business_reporting_service.dart`, `aging_report_screen.dart` *(new)* | **M** | *Risk: Low.* Group remaining balances into 0–30, 31–60, 60+ days based on `documents.date` (not non-existent `due_date`). |
| **9** | **Universal CSV Export for Reports** | `csv_service.dart`, `reports/*.dart` | **M** | *Risk: Low.* Add generic tabular CSV exporter guarded by `PermissionRegistry.dataExportCsv`. |
| **10**| **Cash Flow by Payment Method Breakdown** | `payments_report_screen.dart:80-160` | **S** | *Risk: Low.* Aggregate `document_payments` and `vouchers` by method (Cash, Bankak, Cheque) and show net flow. |
| **11**| **Persist Report Date Filter in Session** | `reports_screen.dart`, `reports/*.dart`, `report_date_filter.dart` | **S** | *Risk: Low.* Maintain active `DateRangeFilter` across the reports hub during the session. |
| **12**| **Reference Currency Pricing Toggle in Reports**| `sales_report_screen.dart`, `inventory_report_screen.dart` | **M** | *Risk: Medium (Accounting Invariants).* Strictly presentation-layer conversion for inflation tracking; do not alter base-currency ledger invariance. |

---

## 6. Open Questions for Decision

1. **Permission Remapping for Payments Report:**
   - *Question:* Should `PaymentsReportScreen` require `reports.view_sales` or `reports.view_financials`?
   - *Context:* Cashiers currently see it because it requires `payments.record`. Re-mapping to `reports.view_sales` lets salespeople see cash flow, whereas `reports.view_financials` restricts it strictly to Accountants and Owners.
   - *Recommendation:* Require `PermissionRegistry.reportsViewFinancials`.

2. **Low Stock Report Gating:**
   - *Question:* Should Low Stock Report be accessible to Free users or kept Pro? And should its permission be changed from `stock.adjust` to `reports.view_sales` or a read-only stock permission?
   - *Recommendation:* Remap permission to `PermissionRegistry.productsView` (so cashiers can inform customers of shortages), but keep the advanced replenishment metrics in `AdvancedInventoryAnalyticsScreen` under Pro.

3. **Due Date and Credit Terms Policy:**
   - *Question:* Should Waraqatak introduce an explicit `due_date` / payment terms column on invoices, or should debt aging strictly be calculated from document issue date (`documents.date`)?
   - *Recommendation:* Calculate aging from `documents.date` initially (0–30, 31–60, 60+ days from issue date). Add explicit `due_date` only if credit terms (e.g. Net 15/30) are formally requested.

4. **Accounting Report Source Default:**
   - *Question:* Should `journal_reports_enabled` remain `false` by default, or should a startup parity check automatically enable it once parity is verified?
   - *Recommendation:* Keep `false` by default to preserve the safety rail on restored backups. Add an automatic one-time promotion to `true` inside `JournalBackfillService` only after continuous reconciliation passes with zero findings.
