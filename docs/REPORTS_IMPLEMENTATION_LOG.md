# Reports Improvements Implementation Log

**Branch:** `feat/reports-improvements`  
**Base Commit:** `b25831f9b1f2c9bca08df942ad7cc866469384e3`  
**Started:** 2026-11-23

---

## Batch Status Overview

- [x] **Batch A** - Performance and correctness
- [x] **Batch B** - Permissions and gates
- [x] **Batch C** - Localization cleanup
- [ ] **Batch D** - Export and share foundation
- [ ] **Batch E** - Shared date range across reports
- [ ] **Batch F** - Daily closing (end-of-day) report [new]
- [ ] **Batch G** - Receivables and payables aging [new]
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
