# Waraqatak Reports Implementation Audit Report

**Date:** 2026-11-23  
**Target Branch:** `feat/reports-improvements`  
**Base Branch:** `main`  
**HEAD Commit:** `7c53c91` (`docs(reports): update changelog, add reports architecture guide and manual test checklist`)  
**Mode:** Independent Technical Audit Only (No source or test code modified).

---

## 1. Executive Summary & Merge-Readiness Verdict

### Verdict: **READY AFTER FIXES**

The implementation across Batches A through J delivers an extraordinary amount of value (~11,100 insertions across 43 files): complete N+1 costing query elimination via SQL subquery, RBAC enforcement via `ScreenAccessGate`, unified session date filtering, universal CSV/PDF/WhatsApp exports, and three essential retail financial reports (Daily Closing, Debt Aging, and Taxes & Discounts).

However, **4 concrete blockers** must be remediated before merging into `main`:
1. **[BLOCKER 1 - CI Test Failure] CSV Negative Number Corruption:** `CsvService.exportReportToCsv` prepends a single-quote formula escape (`'`) to legitimate negative numbers (e.g. `-250` becomes `'-250`). Consequently, `test/services/csv_report_export_test.dart:58` (`expect(lines[2], contains(',-250,'))`) will fail when CI runs `flutter test`.
2. **[BLOCKER 2 - Tile vs Gate Mismatch] Low Stock Report Access Denied:** In `lib/screens/reports_screen.dart:228`, the Low Stock tile requires `PermissionRegistry.productsView`, but the target screen `InventoryReportScreen` enforces `PermissionRegistry.reportsViewInventoryCost` via `ScreenAccessGate`. Roles with `productsView` (e.g. Stockkeeper) see the tile, tap it, and are blocked by Access Denied.
3. **[BLOCKER 3 - Un-migrated Existing Databases] Receivables Permission Migration:** `migrateReceivablesPermissions` was placed inside `AccessSeeder.ensureDefaults(db)`, which is only executed during `_onCreate` on fresh databases. Existing databases upgraded from earlier app versions will never execute this migration, causing custom roles with `contactsViewBalances` to silently lose Customer and Supplier report access.
4. **[BLOCKER 4 - Draft Document Leak in Aging Report]** `BusinessReportingService.getAgingReport` filters with `WHERE d.status != 'cancelled'`. Unposted draft invoices/purchases (`status = 'draft'`) with remaining balance are improperly included in customer/supplier debt aging.

---

## 2. Requirement Coverage Matrix

| Batch | Sub-Item | Status | Evidence (File:Line) | Audit Analysis / Details |
| :--- | :--- | :---: | :--- | :--- |
| **A1** | N+1 costing query elimination | **DONE** | `lib/services/inventory_costing_service.dart:521-532` | Eliminated O(N) loop using grouped SQL subquery `WHERE document_id IN (SELECT id FROM documents WHERE $where)`. Bypasses SQLite parameter limit. |
| **A2** | Inventory search debounce + sequence guard | **DONE** | `lib/screens/reports/inventory_report_screen.dart:51, 62-80` | Added 300ms `Timer` debounce, `_querySeq` counter check on async return, and `dispose()` timer cancellation. |
| **A3** | Remove fixed `height: 40` wrappers | **DONE** | `inventory_report_screen.dart:455`, `product_report_screen.dart:356, 407` | Replaced fixed 40dp height with flexible `constraints: BoxConstraints(minHeight: 44)` and content padding to prevent font scale clipping. |
| **B1** | Permissions realignment | **DONE** | `lib/screens/reports_screen.dart:171, 188, 197`, `screen_access_policy.dart:225, 229, 232` | Gated Customer & Supplier reports by `reports.view_receivables`; gated Payments report by `reports.view_financials`. |
| **B2** | `ScreenAccessGate` on 7 report screens | **DONE** | `accounting_screen.dart:366`, `customer_report_screen.dart:320`, `supplier_report_screen.dart:363`, `inventory_report_screen.dart:450`, `product_report_screen.dart:271`, `purchases_report_screen.dart:288`, `sales_report_screen.dart:427` | Wrapped all 7 previously unguarded screens in `ScreenAccessGate` matching `ScreenAccessPolicy.manifest`. |
| **B3** | Receivables migration for existing roles | **PARTIAL** | `lib/services/access/access_seeder.dart:147-178` | Logic is correct, but only called in `ensureDefaults()` during `_onCreate`. Existing upgraded databases do not execute it. No unit test exists for `migrateReceivablesPermissions`. |
| **C** | Replace inline `langCode == 'ar'` ternaries | **DONE** | `lib/localization/app_localizations.dart:2120-2210` | Extracted all 4 inline ternaries into localized getters in `AppLocalizations`. 0 inline ternaries remain in `lib/screens/reports/`. |
| **D1** | PDF export for Accounting & Payments | **DONE** | `accounting_screen.dart:458, 1378`, `payments_report_screen.dart:315` | Active financial statements, General Ledger, and Payments report export to A4/80mm PDF via `ReportExportMenu`. |
| **D2** | Uniform export menu with permission checks | **PARTIAL** | `lib/widgets/report_export_menu.dart:10-85` | Export bottom sheet is unified across all screens. However, menu tiles do NOT check `PermissionRegistry.reportsExportPdf` or `dataExportCsv` before displaying. |
| **D3** | Standard RFC 4180 CSV export in `CsvService` | **PARTIAL** | `lib/services/csv_service.dart:130-187` | Implements UTF-8 BOM, multiline RFC 4180 quoting. However, formula defense prepends `'` to legitimate negative numbers (`-250` -> `'-250`). |
| **D4** | Thermal roll (80mm) page format support | **DONE** | `lib/services/pdf/pdf_report_builder.dart:45, 102`, `pdf_service.dart:170, 205` | Added `PdfPageFormat? pageFormat` throughout PDF report builders and service. Supports `PdfPageFormat.roll80`. |
| **E** | Session date filter persistence & touch targets | **PARTIAL** | `lib/screens/reports/reports_date_scope.dart:1-49`, `report_date_filter.dart:63` | Synchronized across 9 report screens and enlarged touch targets to >= 48dp. However, `AuditHistoryScreen` still uses hardcoded `DateRangeFilter.thisMonth()`. |
| **F** | Daily closing report & cash reconciliation | **DONE** | `lib/screens/reports/daily_closing_report_screen.dart:1-969`, `business_reporting_service.dart:1174-1340` | Segregates cash sales from credit debt collection, method breakdown, live cash drawer variance feedback (balanced/surplus/shortage). |
| **G** | Debt aging report (receivables & payables) | **DEVIATION** | `lib/screens/reports/aging_report_screen.dart:1-699`, `business_reporting_service.dart:1345-1425` | Implemented 4 standard buckets (0–30, 31–60, 61–90, 90+) instead of 3 (0–30, 31–60, 61+). Harmless, standard accounting deviation. WhatsApp reminder lacks phone targeting. |
| **H** | Payments cash flow by method & voucher drilldown | **DONE** | `database_helper.dart:8090-8148`, `payments_report_screen.dart:362-446, 646` | Added `getPaymentMethodCashFlow` SQL aggregation, cash flow chips, `AppPercentageBar`, and enabled drilldown for standalone vouchers via `row['document_id'] ?? row['id']`. |
| **I1** | Responsive `AppMetricCard(compact: true)` | **DONE** | `sales_report_screen.dart:452-498`, `purchases_report_screen.dart:495-535`, `customer_report_screen.dart:342`, `supplier_report_screen.dart:385` | Eliminated cramped horizontal 3-chip rows on 360dp phone screens using structured 2-column or full-width `AppMetricCard`. |
| **I2** | Empty, error, loading states | **DONE** | `customer_report_screen.dart:453-465`, `supplier_report_screen.dart:455-467`, `purchases_report_screen.dart:705-715` | Consistent `AppLoadingView`, `AppErrorState`, and `AppEmptyState` across all reports. |
| **I3** | Pull-to-refresh on report lists | **DONE** | `customer_report_screen.dart:468`, `supplier_report_screen.dart:469`, `sales_report_screen.dart:738`, `purchases_report_screen.dart:720`, `product_report_screen.dart:700` | Wrapped all report `ListView`s in `RefreshIndicator(onRefresh: _load)`. |
| **I4** | Search & sort with debounce + sequence guard | **PARTIAL** | `customer_report_screen.dart:66, 86, 131`, `supplier_report_screen.dart:67, 86, 131`, `inventory_report_screen.dart:51, 62` | Added debounced search & `_querySeq` on Customer, Supplier, Inventory reports. Sales and Purchases lack search/sort. |
| **I5** | Legacy foreign-currency banner | **DONE** | `customer_report_screen.dart:351-383`, `supplier_report_screen.dart:394-426` | Shows informational alert banner if pre-1.1.5 foreign-currency documents exist. |
| **I6** | Drilldown to `StockMovementsScreen` | **DONE** | `inventory_report_screen.dart:883-890`, `product_report_screen.dart:716-730` | Product tiles in Inventory and Product Performance reports navigate to `StockMovementsScreen(initialProduct: p)`. |
| **I7** | Lightweight visual bars & charts | **DONE** | `lib/widgets/app_percentage_bar.dart:1-105`, `payments_report_screen.dart:447-485` | Created zero-dependency CustomPainter horizontal percentage bar and integrated payment method shares into Payments Report. |
| **I8** | Dark mode & text scaling accessibility | **DONE** | Throughout changed files | Colors route through `AppStatusColors` and `Theme.of(context).colorScheme`; removed rigid height wrappers. |
| **J1** | Sales report period comparison & growth delta | **DONE** | `date_range_filter.dart:143-164`, `sales_report_screen.dart:110, 420, 456` | Added `previousPeriod()`, single-query prior sales total, and `+X.X% vs previous period` badge with zero-division protection. |
| **J2** | Taxes and discounts summary report | **DONE** | `lib/screens/reports/tax_discount_report_screen.dart:1-538`, `business_reporting_service.dart:1435-1510` | Added comprehensive report for sales tax collected, purchase tax paid, net tax, discounts given/received, transaction drilldown, and PDF/CSV export. |
| **Docs** | Changelog, Architecture Guide, Test Checklist | **DONE** | `CHANGELOG.md`, `docs/reports_section.md`, `docs/REPORTS_MANUAL_TEST_CHECKLIST.md`, `docs/REPORTS_IMPLEMENTATION_LOG.md` | Updated unreleased notes, comprehensive architecture guide, manual QA checklist, and batch-by-batch engineering log. |

---

## 3. Findings by Severity

### High Severity Findings

#### 1. [BUG / CI FAILURE] Negative Numbers Corrupted in CSV Export
- **File & Line:** `lib/services/csv_service.dart:136-146, 175-177`
- **Evidence:**
  ```dart
  // In sanitizeCell():
  if (firstChar == '=' || firstChar == '+' || firstChar == '-' || ...) {
    text = "'$text";
  }
  ```
  When `val is num` (e.g. `-250.0`), `val.toString()` starts with `'-'`. `sanitizeCell` unconditionally prepends a single quote, producing `'-250.0`. In spreadsheet software, this turns numbers into text strings, preventing arithmetic and formula calculations.
  Furthermore, `test/services/csv_report_export_test.dart:58` asserts `expect(lines[2], contains(',-250,'))`, which will fail on CI because the output contains `,'-250,`.
- **Concrete Fix:** Skip formula sanitization when `val is num`, or only sanitize `text` if `double.tryParse(text) == null`:
  ```dart
  if (val is num) {
    return val.toString(); // Numbers cannot be formulas
  }
  ```
- **Effort:** **S**

#### 2. [SECURITY / ACCESS] Hub Tile vs Screen Gate Mismatch on Low Stock Report
- **File & Line:** `lib/screens/reports_screen.dart:226-229` vs `lib/services/access/screen_access_policy.dart:222-224`
- **Evidence:**
  In `reports_screen.dart:228`:
  ```dart
  screen: const InventoryReportScreen(initialFilter: 'low_stock'),
  permission: PermissionRegistry.productsView,
  ```
  In `screen_access_policy.dart:222`:
  ```dart
  InventoryReportScreen: const ScreenPolicy.require(
    PermissionRegistry.reportsViewInventoryCost,
  ),
  ```
  The tile is visible to any role with `productsView` (Cashier, Stockkeeper). When tapped, `InventoryReportScreen` executes `ScreenAccessGate(screenType: InventoryReportScreen)`, which checks `reportsViewInventoryCost`. The user is denied access.
- **Concrete Fix:** Align tile requirement with `reportsViewInventoryCost` in `reports_screen.dart:228`, OR split `LowStockReportScreen` into its own lightweight screen requiring `productsView` (displaying item quantities and shortage thresholds without cost/valuation data).
- **Effort:** **S**

#### 3. [DATA INTEGRITY / MIGRATION] Existing Upgraded Databases Miss Receivables Permission Migration
- **File & Line:** `lib/services/access/access_seeder.dart:147` & `lib/database/access_dao.dart:258`
- **Evidence:**
  `migrateReceivablesPermissions(db)` was only called inside `AccessSeeder.ensureDefaults(db)`. `ensureDefaults` is called exclusively in `AccessDao.seedAccessControlDefaults(db)` during initial table creation (`_onCreate`). In `database_helper.dart:56-63`, there is no `onOpen` hook and no schema migration was run. Upgraded databases will never execute `migrateReceivablesPermissions`.
- **Concrete Fix:** Invoke `AccessSeeder.migrateReceivablesPermissions(db)` inside `DatabaseHelper._openDatabase` or during session initialization if not already migrated, and add a test in `reports_screen_policy_test.dart`.
- **Effort:** **S**

#### 4. [ACCOUNTING / DATA LEAK] Draft Documents Included in Debt Aging Report
- **File & Line:** `lib/services/business_reporting_service.dart:1363-1365`
- **Evidence:**
  ```sql
  WHERE d.type = ?
    AND d.status != 'cancelled'
    AND d.remaining > 0.001
  ```
  `documents.status` has values `'draft'`, `'issued'`, and `'cancelled'`. An unposted draft quotation or draft invoice with balance remaining is NOT cancelled, so it is included in open receivables and payables aging.
- **Concrete Fix:** Update the query to `AND d.status = 'issued'` or `AND d.status NOT IN ('cancelled', 'draft')`.
- **Effort:** **S**

---

### Medium Severity Findings

#### 5. [SECURITY] `ReportExportMenu` Does Not Enforce Export Permissions
- **File & Line:** `lib/widgets/report_export_menu.dart:45-80`
- **Evidence:**
  `ReportExportMenu.show` displays Print/Preview, Share PDF, and Export CSV tiles based solely on whether callbacks (`onPrintPdf`, `onExportCsv`) are non-null. It does not check if the current user possesses `PermissionRegistry.reportsExportPdf` or `PermissionRegistry.dataExportCsv`. While `CsvService.exportReportToCsv` has an internal guard (`AccessGuard.require`), the user encounters an unexpected exception SnackBar rather than a clean disabled/hidden button.
- **Concrete Fix:** Check `AccessGuard.hasPermission(PermissionRegistry.reportsExportPdf)` and `hasPermission(PermissionRegistry.dataExportCsv)` before rendering export tiles in `ReportExportMenu`.
- **Effort:** **S**

#### 6. [UX / FUNCTIONALITY] WhatsApp Payment Reminder Ignores Recipient Phone Number
- **File & Line:** `lib/screens/reports/aging_report_screen.dart:315-325`
- **Evidence:**
  `_sendReminder(l10n, item, baseCurrency)` compiles the reminder text and calls `PdfService.shareText(text: text)`. It completely ignores `item.phone`! It does not normalize the phone number for Sudan (`+249` prefix) or attempt to launch WhatsApp directly via `whatsapp://send?phone=...`.
- **Concrete Fix:** If `item.phone` is present, normalize it (e.g., replace leading `0` with `+249`) and launch via `url_launcher` (`whatsapp://send?phone=$normalized&text=$encodedText`), falling back to `PdfService.shareText` only if WhatsApp cannot be launched or phone is absent.
- **Effort:** **S**

#### 7. [CONCURRENCY / RACE CONDITION] Missing Query Sequence Guard on Date Filter Changes
- **File & Line:** `sales_report_screen.dart:103-140`, `purchases_report_screen.dart:85-120`, `payments_report_screen.dart:95-130`, `tax_discount_report_screen.dart:47-75`
- **Evidence:**
  While `CustomerReportScreen`, `SupplierReportScreen`, and `InventoryReportScreen` utilize `_querySeq` counters to prevent out-of-order async query overwrites, `SalesReportScreen`, `PurchasesReportScreen`, `PaymentsReportScreen`, and `TaxDiscountReportScreen` do not. Rapidly switching date filters can result in a slower previous query overwriting the latest selection.
- **Concrete Fix:** Add `int _querySeq = 0;` and verify `if (!mounted || seq != _querySeq) return;` after each `Future.wait` in `_load()`.
- **Effort:** **S**

#### 8. [MULTI-CURRENCY / INVARIANCE] Nominal Currency Aggregation in Aging and Daily Closing
- **File & Line:** `business_reporting_service.dart:1194, 1221, 1362`
- **Evidence:**
  Unlike `getPaymentMethodCashFlow` and `getTaxDiscountSummary` which filter by `d.currency_code = ?`, `getDailyClosingSummary` and `getAgingReport` omit the currency filter in their SQL queries. On pre-1.1.5 databases with legacy USD or SAR documents, amounts are aggregated nominally into the base currency.
- **Concrete Fix:** Add `AND (d.currency_code = ? OR d.currency_code IS NULL)` to `getDailyClosingSummary` and `getAgingReport`.
- **Effort:** **S**

---

### Low Severity Findings

#### 9. [L10N] Hardcoded Arabic Strings in SQL and WhatsApp Reminder
- **File & Line:** `business_reporting_service.dart:1358`, `aging_report_screen.dart:319-322`
- **Evidence:**
  `COALESCE(c.name, d.recipient_name, 'غير محدد')` in SQL hardcodes Arabic in the database layer. The reminder template in `aging_report_screen.dart:319` is hardcoded in Arabic and does not localize if the app is in English mode.
- **Concrete Fix:** Use a sentinel or translate via `AppLocalizations` in the UI layer.
- **Effort:** **S**

#### 10. [INCONSISTENCY] `AuditHistoryScreen` Bypasses `ReportsDateScope`
- **File & Line:** `lib/screens/audit_history_screen.dart:28`
- **Evidence:**
  Initializes `_range` with `DateRangeFilter.thisMonth()` instead of `ReportsDateNotifier.instance.range`.
- **Concrete Fix:** Initialize with `ReportsDateNotifier.instance.range`.
- **Effort:** **S**

---

## 4. Constraint Violations Review

| Constraint | Evaluation | Verdict | Notes |
| :--- | :--- | :---: | :--- |
| **No new pub dependencies** | `pubspec.yaml` was completely untouched | **PASS** | Visual bars built with `CustomPaint`/`CustomPainter`. |
| **No DB schema bump** | `database_helper.dart` `dbVersion` unchanged | **PASS** | No schema migration required; reused existing columns. |
| **`journal_reports_enabled` untouched** | `ledger_service.dart` default remains `'false'` | **PASS** | Verified safety rail is fully preserved. |
| **No multi-currency selectors** | No currency selector added anywhere | **PASS** | Single base currency SDG preserved; legacy warnings used. |
| **Play compliance** | Zero pricing/subscription wording introduced | **PASS** | `tool/check_play_compliance.sh` passed cleanly: **OK**. |
| **Western numerals (0-9)** | No Arabic-Indic digits (`٠-٩`) introduced | **PASS** | Number formatting strictly adheres to Western digits. |
| **No inline `langCode == 'ar'`** | All inline ternaries replaced | **PASS** | Verified 0 occurrences across all report screens. |
| **Dark mode preservation** | All colors use `AppStatusColors` and `colorScheme` | **PASS** | Zero hardcoded hex colors in report screens. |
| **Unrelated files untouched** | Only report-related screens, models, services | **PASS** | Core documents, point-of-sale, and settings untouched. |

---

## 5. Tests Review & CI Impact

### Analysis of New Tests:
1. `test/services/sales_report_costing_test.dart`: **Excellent.** Verifies single-query costing results match baseline.
2. `test/services/daily_closing_report_test.dart`: **High Quality.** Seeds realistic data, tests cash vs credit sales, and debt collection segregation.
3. `test/services/debt_aging_test.dart`: **High Quality.** Validates bucket mathematics and query grouping.
4. `test/services/payment_cash_flow_test.dart`: **High Quality.** Exercises multi-method inflows, outflows, and net cash flow.
5. `test/services/tax_discount_report_test.dart`: **High Quality.** Tests tax/discount arithmetic and query aggregation.
6. `test/screens/reports_date_scope_test.dart`: **Good.** Validates InheritedNotifier synchronization.
7. `test/access/reports_screen_policy_test.dart`: **Good.** Validates Cashier boundaries and screen policies.
8. `test/services/csv_report_export_test.dart`: **FLAWED (Will Fail on CI).** Line 58 asserts `expect(lines[2], contains(',-250,'))`, but production code produces `,'-250,`.

### What CI Actually Runs:
`.github/workflows/ci.yml` runs:
1. `bash tool/check_play_compliance.sh`
2. `dart analyze` (across entire repo)
3. `flutter test --reporter=expanded test/reference_pricing_math_test.dart ...`
4. `flutter test --reporter expanded` (all tests under `test/`)

Because `flutter test` cannot run inside Termux (missing `libc.so.6`), test executions must be evaluated statically. When GitHub CI runs `flutter test`, **`csv_report_export_test.dart` will fail until Blocker 1 is resolved**.

---

## 6. Documentation Inaccuracies

1. **`docs/REPORTS_IMPLEMENTATION_LOG.md` (Batch B):**
   * *Claim:* Stated that existing users and roles were migrated to `reportsViewReceivables`.
   * *Reality:* Migration was only added to `ensureDefaults()` in `_onCreate`. Existing production databases will not execute it without an explicit upgrade hook.
2. **`docs/reports_section.md` (Low Stock Report):**
   * *Claim:* Reports inventory table states Low Stock report permission is `reports.view_inventory_cost`, while Section 3 states it was remapped to `products.view`.
   * *Reality:* In code, the tile in `reports_screen.dart:228` requires `productsView`, but the screen gate in `screen_access_policy.dart:222` requires `reportsViewInventoryCost`.
3. **`docs/REPORTS_IMPLEMENTATION_LOG.md` (Batch G):**
   * *Claim:* Did not mention the bucket deviation (4 buckets instead of 3).
   * *Reality:* 4 buckets were implemented (0–30, 31–60, 61–90, 90+). This should be explicitly documented as an intentional enhancement.

---

## 7. Prioritized Remediation Plan

| Priority | Task | File(s) | Risk Mitigated | Effort |
| :---: | :--- | :--- | :--- | :---: |
| **P0** | Fix negative number handling in CSV export so `-250` is not quoted as `'-250'` | `lib/services/csv_service.dart:170-179` | Fixes CI failure in `csv_report_export_test.dart` & spreadsheet usability | **S** |
| **P0** | Resolve Low Stock Report tile vs screen gate permission mismatch | `lib/screens/reports_screen.dart:226-229` | Eliminates Access Denied crash for Cashier/Stockkeeper | **S** |
| **P0** | Ensure `migrateReceivablesPermissions` runs on existing databases | `lib/database/database_helper.dart` or `access_seeder.dart` | Prevents custom roles from losing Customer/Supplier reports | **S** |
| **P0** | Exclude `status = 'draft'` from `getAgingReport` query | `lib/services/business_reporting_service.dart:1363` | Eliminates draft document leakage in debt aging | **S** |
| **P1** | Add currency filtering `AND (currency_code = ? OR currency_code IS NULL)` to Aging and Daily Closing queries | `lib/services/business_reporting_service.dart:1194, 1362` | Prevents nominal mixing of legacy currencies | **S** |
| **P1** | Add permission checks in `ReportExportMenu` before showing PDF and CSV tiles | `lib/widgets/report_export_menu.dart:40-80` | Enforces export permissions cleanly in UI | **S** |
| **P1** | Add `_querySeq` counter check to `_load()` in Sales, Purchases, Payments, Tax reports | `sales_report_screen.dart`, `purchases_report_screen.dart`, etc. | Eliminates out-of-order async race condition on rapid date filter switching | **S** |
| **P2** | Normalize Sudanese phone numbers and launch WhatsApp directly via URL in Aging reminder | `lib/screens/reports/aging_report_screen.dart:315-325` | Delivers seamless 1-tap WhatsApp reminder | **S** |
| **P2** | Update `AuditHistoryScreen` to use `ReportsDateNotifier.instance.range` | `lib/screens/audit_history_screen.dart:28` | Full date persistence consistency across all hub screens | **S** |

---

## 8. Open Product Decisions

1. **Low Stock Report Architecture:**
   * *Option A (Recommended):* Keep `InventoryReportScreen` gated by `reports.view_inventory_cost`, and update the tile in `reports_screen.dart:228` to require `reports.view_inventory_cost`.
   * *Option B:* Create a dedicated `LowStockReportScreen` that requires `products.view` and displays quantities and replenishment alerts only, without exposing average cost or stock valuation.
2. **Receivables Migration Trigger:**
   * *Option A (Recommended):* Run `AccessSeeder.migrateReceivablesPermissions(db)` in `DatabaseHelper.openDatabase` if a flag `receivables_permission_migrated` is not set in `app_settings`.
   * *Option B:* Increment database version to bump schema and run a formal SQLite migration.
