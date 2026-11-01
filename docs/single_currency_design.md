# Single-Currency Architecture & Legacy Data Design

## 1. Executive Summary & Policy

Waraqatak is designed as an offline-first commercial management application operating strictly on **ONE base currency** per business installation (`businesses.currency_code`).

### Core Policy:
1. **Single Base Currency per Installation:**
   - Established during initial business onboarding (`lib/screens/business_setup_screen.dart`).
   - Irrevocably locked (`businesses.currency_locked_at`) upon the very first financial activity (issuance of an invoice/purchase, opening stock entry, or payment).
   - Changing the base currency after locking is completely blocked at both database and service layers (`DatabaseHelper.updateBusiness`).
2. **Elimination of Multi-Currency Switching & Grouping:**
   - No per-document currency pickers exist anywhere in document creation workflows (Invoices, Purchases, Quotations, Returns, Vouchers, Payments).
   - All financial reports, ledger books, customer statements, and dashboard summaries display figures in the single base currency.
   - Dropdown currency pickers in `accounting_screen.dart` and `customer_statement_dialog.dart` are removed; reports and statements default directly to the active business base currency.
   - Per-currency grouped tab/chip switching in `sales_report_screen.dart`, `purchases_report_screen.dart`, and `payments_report_screen.dart` is consolidated to primary base-currency presentation.
3. **Service Layer & Database Enforcement:**
   - Authoritative guards in `DatabaseHelper` (`insertDocumentWithItems`, `updateDocumentWithItems`, `issueDocument`, `copyDocumentWithItems`, `convertQuotationToInvoice`) reject any new or modified document whose `currency_code` does not match the active base currency.
   - `DocumentService` strictly binds `business.currencyCode` to every created document.
   - Restoring backups and importing data cannot alter the base currency once locked.
4. **Legacy Data Policy (Safe Isolation, Zero Data Loss):**
   - **No Destructive DB Changes:** Existing historical documents with foreign or legacy `currency_code` are **never deleted, rewritten, or mutated**. Database schema columns (`documents.currency_code`, `businesses.currency_code`) remain completely preserved.
   - **Read-Time Base Fallback:** Any document where `currency_code` is `NULL` or empty whitespace is treated as the base currency at read time.
   - **Segregated Presentation:** Existing documents in foreign currencies are never nominally added to base-currency totals (preventing mathematical distortion). Wherever money from such documents would otherwise vanish from an aggregate (e.g. in sales/purchase reports or customer balances), it is presented in a clearly demarcated read-only section: *"Legacy documents in other currencies"*.
   - **Integrity Diagnostic:** `DatabaseDiagnosticService` runs check `legacy_foreign_currency_documents` (severity: `info`, `category: DiagnosticCategory.documentStatusMismatch`), enumerating all legacy foreign-currency documents and their affected IDs.

---

## 2. Component Architecture Changes

### A. Central Accessor: `CurrencyContext` (`lib/services/currency_service.dart`)
- Provides synchronous and cached asynchronous resolution of the current business base currency, symbol, and decimal precision.
- Caches the base `Currency` instance in memory; invalidated when `DatabaseHelper.updateBusiness` or `FinancialSettingsScreen` commits changes.
- Provides standard helpers:
  - `CurrencyContext.getBaseCurrency()`
  - `CurrencyContext.getBaseCurrencyCode()`
  - `CurrencyContext.getBaseCurrencySymbol()`
  - `CurrencyContext.getBaseCurrencyDecimals()`
  - `CurrencyContext.isBaseCurrency(String? code, String baseCurrencyCode)`

### B. Reports & Screen Simplifications
- **`lib/screens/reports/accounting_screen.dart`:**
  - Removed currency selection dropdown.
  - Automatically loads and renders the journal in the base currency (`LedgerService.load()`).
- **`lib/widgets/customer_statement_dialog.dart`:**
  - Removed currency dropdown filter.
  - Statement generates strictly in the business base currency. If foreign legacy documents exist for the contact, an informational note indicates they are excluded.
- **`lib/screens/reports/sales_report_screen.dart`:**
  - Top summary cards show base currency metrics.
  - If legacy foreign-currency sales exist in the selected period, a dedicated read-only card displays their per-currency subtotals separately.
- **`lib/screens/reports/purchases_report_screen.dart`:**
  - Top summary cards display base currency metrics.
  - Legacy foreign purchases are listed in a separate read-only legacy section below.
- **`lib/screens/reports/payments_report_screen.dart`:**
  - Summary chips display base currency payments in/out.
  - Legacy foreign payments are shown in a segregated legacy section.
- **`lib/screens/customer_detail_screen.dart`:**
  - Stat cards display the customer's base-currency receivable/payable balance.
  - When legacy foreign balances exist, they are displayed in a clearly labeled read-only legacy section without replacing or corrupting the main balance card.

### C. Database Integrity & Diagnostics
- **`lib/services/database_diagnostic_service.dart`:**
  - Diagnostic check `legacy_foreign_currency_documents` inspects `documents` table:
    `WHERE currency_code IS NOT NULL AND TRIM(currency_code) != '' AND TRIM(currency_code) != ?`
  - Reports count, affected IDs, and metadata for audit review.

---

## 3. Comprehensive Test Mapping (Zero Test Deletion)

Every existing multi-currency test is mapped to a contract test or legacy-data preservation test. No tests are deleted.

| Original Test File & Name | New Classification | Purpose & Target Verification |
|---|---|---|
| `test/services/multi_currency_phase1_test.dart`<br>`1. Customer: real getContactBalances result schema matches CustomerReportScreen PDF row extraction and 5-column alignment` | Contract Test | Asserts `getContactBalances` schema matches customer report 5-column PDF layout under base currency. |
| `test/services/multi_currency_phase1_test.dart`<br>`2. Supplier: real getContactBalances result schema matches SupplierReportScreen PDF row extraction and 5-column alignment` | Contract Test | Asserts `getContactBalances` schema matches supplier report 5-column PDF layout under base currency. |
| `test/services/multi_currency_phase1_test.dart`<br>`3. getPurchasesReport correctly segregates totalsByCurrency with SQLite fixtures and excludes cancelled purchases` | Legacy-Data Test | Asserts legacy foreign-currency purchase documents are preserved in `totalsByCurrency` and not nominally added to base totals, while cancelled purchases are excluded. |
| `test/services/multi_currency_phase1_test.dart`<br>`4. aggregateByCurrency groups COGS and trusted profit per currency and isolates incomplete cost flag` | Legacy-Data Test | Asserts `aggregateByCurrency` isolates foreign sales and flags incomplete cross-currency costs without contaminating base COGS. |
| `test/services/multi_currency_phase1_test.dart`<br>`5. CustomerDetailScreen renders each document tile with its own currency symbol in production UI` | Contract & Legacy UI Test | Asserts document tiles in `CustomerDetailScreen` render their respective currency symbol and accessibility label correctly. |
| `test/services/multi_currency_phase2_stage1_test.dart`<br>`1. getPeriodSummary segregates currencies, excludes cancellations, and avoids nominal addition` | Legacy-Data Test | Asserts `getPeriodSummary` provides scalar figures for base currency while segregating legacy foreign documents in `totalsByCurrency`. |
| `test/services/multi_currency_phase2_stage1_test.dart`<br>`2. getContactBalances isolates debts per currency and never sums cross-currency nominal amounts` | Legacy-Data Test | Asserts `getContactBalances` isolates debts by currency and avoids cross-currency nominal addition. |
| `test/services/multi_currency_phase2_stage1_test.dart`<br>`3. getProductPerformance maintains currency consistency for revenue and COGS, never subtracting across currencies` | Legacy-Data Test | Asserts `getProductPerformance` attributes base-currency revenue and COGS, isolating foreign-currency activity. |
| `test/services/single_base_currency_test.dart`<br>`Tests 1 through 14` | Invariant Contract & Safety Suite | Retained in full: tests currency unlocking/locking lifecycle, permanence, creation guards, draft transitions, payment atomic locking, and migration v21. |
