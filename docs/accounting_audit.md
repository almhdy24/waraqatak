# Waraqatak Accounting & Single-Currency Audit Report

**Audit Target:** Waraqatak (ورقتك) Flutter / SQLite Business Accounting System  
**Audit Scope:** Currency Architecture, Monetary Mathematics, Double-Entry Ledger, Financial Reporting, and Data Integrity  
**Repository Branch:** `feat/single-currency-accounting-audit`  
**Execution Environment:** Termux / aarch64 Android Linux  
**Evidence Standard:** Absolute source-code line citations, verified commands, and SQLite schema invariants  

---

## 1. Executive Summary

This audit examines the accounting core, monetary arithmetic, currency management, and transactional integrity of Waraqatak. The system operates on an offline-first SQLite database architecture designed for small and medium businesses. 

Key audit conclusions:
1. **Single-Currency Foundation:** The business model already enforces a single base currency (`businesses.currency_code`) which is locked permanently upon first financial transaction or stock movement (`businesses.currency_locked_at`). All UI document creation flows (`InvoiceScreen`, `PurchaseScreen`, `QuickSaleScreen`, `DocumentService`) inherit the business base currency without offering per-document currency pickers. Legacy multi-currency documents only exist in historical databases or restored backups, where reports historically isolated them into segregated nominal groups.
2. **Monetary Precision:** The system implements a robust half-up integer minor-unit arithmetic foundation via [`MoneyUtils`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/utils/money_utils.dart), with epsilon-compensated rounding ($1\times 10^{-9}$) and Hamilton-Hare Largest-Remainder proportional discount allocation.
3. **Double-Entry Ledger:** An explicit, IAS-compliant derived double-entry journal exists in [`lib/services/accounting/ledger.dart`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/accounting/ledger.dart) implementing a 13-account chart of accounts. Every journal entry strictly balances ($Debits = Credits$).
4. **Data Integrity:** All multi-table write operations are strictly enclosed within SQLite `db.transaction(...)` boundaries. Foreign key enforcement (`PRAGMA foreign_keys = ON`) is activated in database initialization. Document numbers are serialized under transactional exclusive locks.
5. **Identified Defects:** Several edge cases exist where floating-point accumulation prior to rounding or missing diagnostic checks could permit inconsistencies or historical reporting confusion. These are cataloged with reproducible scenarios in Section E.

---

## 2. Section A: Currency Architecture

### 2.1 Currency Model & Storage
- **`Currency` Model (`lib/models/currency.dart:1-67`):** Defines supported currencies (`SDG`, `SAR`, `AED`, `EGP`, `USD`), their Arabic/English names, symbols, and canonical `decimalDigits` (default: 2).
- **`businesses` Table (`lib/database/database_helper.dart:182, 195`):**
  - Column `currency_code TEXT DEFAULT 'SDG'` stores the company's base currency.
  - Column `currency_locked_at TEXT` (introduced in schema migration v21, line 1051) stores the ISO 8601 timestamp when financial activity permanently locked the currency.
- **`documents` Table (`lib/database/database_helper.dart:315`):**
  - Column `currency_code TEXT DEFAULT 'SDG'` snapshots the currency of each document.
- **`document_payments` Table (`lib/database/database_helper.dart:362-375`):**
  - Does NOT have an independent `currency_code` column; payments inherit the currency of the parent document referenced by `document_id`.

### 2.2 Base Currency Lock Mechanism
- **Lock Enforcement (`lib/database/database_helper.dart:1130-1160`):**
  - Method `lockBusinessCurrencyIfUnlocked(txn)` executes automatically whenever documents or stock movements are inserted or updated.
  - If `currency_locked_at` is null, it stamps `DateTime.now().toIso8601String()`.
- **Modification Guard (`lib/database/database_helper.dart:1939-1946`):**
  - In `DatabaseHelper.updateBusiness`:
    ```dart
    if (current.currencyCode != b.currencyCode) {
      if (await isCurrencyLocked(txn: txn)) {
        throw StateError(
            'Business currency is permanent and cannot be modified after '
            'financial transactions or stock movements are recorded.');
      }
    }
    ```
- **UI Locking (`lib/screens/business_setup_screen.dart:58-64, 435-455`):**
  - When `_isCurrencyLocked == true`, the currency dropdown is disabled (`onChanged: null`), displayed with a lock icon and helper text: *"Business currency is locked after first financial activity"*.

### 2.3 Document Creation & Invariant Guarantees
- **UI Creation Paths:**
  - `InvoiceScreen` (`lib/screens/invoice_screen.dart:185, 352`): Does not present any currency selector. Total calculation and amount displays strictly bind to `_business?.currencyCode` and `_business?.currencySymbol`.
  - `PurchaseScreen` (`lib/screens/purchase_screen.dart:156, 286`): Binds strictly to `_business?.currencyCode`.
  - `QuickSaleScreen` (`lib/screens/quick_sale_screen.dart:99, 468`): Binds strictly to `_business?.currencyCode`.
- **Service Enforcement (`lib/services/document_service.dart:108, 203`):**
  - `createDocument` assigns `currencyCode: business.currencyCode`.
- **Database Hard Invariants (`lib/database/database_helper.dart`):**
  - `insertDocument` (`line 2656-2660`): `if (doc.currencyCode != baseCurrency) throw StateError('Document currency (${doc.currencyCode}) must match business base currency ($baseCurrency).');`
  - `finalizeDraft` (`line 2972-2976`): Prohibits finalizing a draft whose currency differs from `baseCurrency`.
  - `convertQuotationToInvoice` (`line 4628-4633`): Prohibits converting a quotation with legacy currency to an invoice in another currency.
  - `duplicateDocument` (`line 4971-4976`): Prohibits duplicating a legacy document in a foreign currency.

### 2.4 Legacy Multi-Currency Handling
- **Backup Ingestion (`lib/services/backup_service.dart:241-280`):**
  - Restoring an old backup JSON directly inserts documents with their historical `currency_code`.
- **Read-Time Nominal Segregation:**
  - `DatabaseHelper.getPeriodSummary` (`lines 5194-5250`): Groups period sales, purchases, payments, and outstanding balances by `currency_code` into `totalsByCurrency`. Amounts in different currencies are NEVER summed together.
  - `CustomerDetailScreen` (`lib/screens/customer_detail_screen.dart:74-85, 429-470`): Reads `getContactOutstandingByCurrency`. When multiple currencies exist, displays separate chips for each currency rather than summing them.
  - `SalesReportScreen` (`lib/screens/reports/sales_report_screen.dart:32-40`): Groups sales documents by currency.
  - `CustomerStatementService` (`lib/services/customer_statement_service.dart:60-90`): Generates statements strictly filtered to a single target currency.

---

## 3. Section B: Money Math & Precision

### 3.1 `MoneyUtils` Audit (`lib/utils/money_utils.dart:1-158`)
- **Rounding Mode:** Standard half-up financial rounding (round half away from zero).
  $$\text{result} = \frac{\text{round}((\text{amount} + \text{sign}(\text{amount}) \times 10^{-9}) \times 10^{\text{precision}})}{10^{\text{precision}}}$$
- **Epsilon Adjustment:** $1\times 10^{-9}$ compensation prevents IEEE 754 floating-point under-representation (e.g. $1.005$ represented as $1.00499999999999989$) from rounding down prematurely.
- **Minor-Unit Conversions:** `toMinorUnits` and `fromMinorUnits` convert between `double` and `int` (cents/piastres/halalas) using integer precision.
- **Overpayment Guard:** `MoneyUtils.isOverpayment(payment, remaining, [decimalDigits])` performs comparison in integer minor units, preventing false positives from floating-point noise.
- **Proportional Apportionment:** `MoneyUtils.allocateDocumentDiscount` implements the **Hamilton-Hare Largest-Remainder Method** using `BigInt` exact arithmetic. The sum of allocated line discounts strictly equals the document discount down to the smallest integer minor unit.

### 3.2 Document Totals Calculation Flow
Calculations originate strictly in `DocumentService.calculateInvoiceTotals` (`lib/services/document_service.dart:672-693`):
1. **Item Total:** $\text{line\_total} = \text{round}(\text{quantity} \times \text{unit\_price}, \text{decimalDigits})$.
2. **Subtotal:** $\text{subtotal} = \text{round}(\sum \text{line\_total}, \text{decimalDigits})$.
3. **Discount:** $\text{canonicalDiscount} = \text{round}(\text{discount}, \text{decimalDigits})$. Guarded by $0 \le \text{discount} \le \text{subtotal}$.
4. **Tax Calculation (`_calculateTaxMultiRate`):**
   - Discount ratio: $R = \frac{\text{subtotal} - \text{discount}}{\text{subtotal}}$.
   - For each line item:
     - After discount: $\text{netLine} = \text{line\_total} \times R$.
     - If `pricesIncludeTax == true`: $\text{lineTax} = \text{netLine} \times \frac{\text{rate}}{100 + \text{rate}}$.
     - If `pricesIncludeTax == false`: $\text{lineTax} = \text{netLine} \times \frac{\text{rate}}{100}$.
   - Total tax: $\text{taxAmount} = \text{round}(\sum \text{lineTax}, \text{decimalDigits})$.
5. **Document Total:**
   - If `pricesIncludeTax == true`: $\text{total} = \text{round}(\text{subtotal} - \text{discount}, \text{decimalDigits})$.
   - If `pricesIncludeTax == false`: $\text{total} = \text{round}(\text{subtotal} - \text{discount} + \text{taxAmount}, \text{decimalDigits})$.
6. **Paid & Remaining:**
   - $\text{paid} = \text{round}(\text{paidInput}, \text{decimalDigits})$. Guarded by $0 \le \text{paid} \le \text{total}$.
   - $\text{remaining} = \text{fromMinorUnits}(\max(0, \text{toMinorUnits}(\text{total}) - \text{toMinorUnits}(\text{paid})))$.

### 3.3 UI vs Service vs PDF Parity
- **UI Parity:** `InvoiceScreen`, `PurchaseScreen`, `QuotationScreen`, and `PosCart` all call `DocumentService.calculateInvoiceTotals` directly. There is zero redundant or diverging math in UI screens.
- **Database Row:** Database stores snapshot columns (`subtotal`, `discount`, `tax_rate`, `tax_amount`, `total`, `paid`, `remaining`).
- **PDF Builder (`PdfTotalsBuilder`):** Reads the exact database snapshot columns. It does NOT recompute or alter totals.

### 3.4 Floating Point Risks Identified
1. **Unrounded Line Item Totals in `DocumentItemInput`:** In `lib/services/document_service.dart:41`, `double get total => MoneyUtils.round(quantity * price);` uses hardcoded default 2 decimals. For 0-decimal or 3-decimal currencies, line totals could round to 2 decimals rather than the currency's canonical scale.
2. **Tax Sum Accumulation:** In `_calculateTaxMultiRate` (`line 712-715`), line taxes are summed as raw `double`s before a final single `MoneyUtils.round`. While standard in proportional tax calculations, large invoices with 100+ lines could experience fractional piastre drift compared to individual item tax invoices.

---

## 4. Section C: Accounting Model

### 4.1 Chart of Accounts
The application defines a formal, standardized Chart of Accounts in [`lib/services/accounting/ledger.dart:25-50`](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/accounting/ledger.dart#L25-L50):

| Code | Account Name | Type | Normal Balance | Purpose |
|---|---|---|---|---|
| `1110` | Cash (Till) | Asset | Debit | Physical cash drawer |
| `1120` | Bank & E-Wallets | Asset | Debit | Bank accounts, Bankak, OKash, Mada, Cards |
| `1130` | Accounts Receivable | Asset | Debit | Customer unpaid invoice balances |
| `1140` | Inventory | Asset | Debit | Stock on hand at weighted-average cost |
| `1150` | VAT Input (Recoverable) | Asset | Debit | Purchase tax paid |
| `2110` | Accounts Payable | Liability | Credit | Unpaid supplier purchase invoices |
| `2120` | VAT Output (Payable) | Liability | Credit | Sales tax collected from customers |
| `3100` | Opening Balance Equity | Equity | Credit | Initial business equity / opening stock |
| `4100` | Sales Revenue | Revenue | Credit | Net revenue from goods and services |
| `4900` | Other Income | Revenue | Credit | Unlinked receipts / miscellaneous income |
| `5100` | Cost of Goods Sold (COGS) | Expense | Debit | Cost basis of inventory sold |
| `5200` | Inventory Adjustments | Expense | Debit | Inventory gains/losses from stock counts |
| `6100` | Operating Expenses | Expense | Debit | Expenses, non-stocked purchases, service bills |

### 4.2 Derived Ledger Engine
- **Immutability & Derivation:** The ledger is 100% *derived* from documents, stock movements, and payment records. No synthetic ledger rows are written to disk, guaranteeing the books can never desynchronize from transaction records.
- **Balance Invariant:** Every `JournalEntry` contains balanced `JournalLine`s where $\sum \text{Debits} = \sum \text{Credits}$.
- **Draft & Cancellation Filtering:** Drafts, quotations, custom documents, and cancelled invoices post zero entries. Cancelling an invoice immediately nullifies its accounting effect without orphaned ledger rows.

### 4.3 Audit of Accounting Identities
1. **$\text{Total Invoiced} = \text{Total Sales} - \text{Discounts} + \text{Tax}$:** Verified in `DocumentService.calculateInvoiceTotals`. Holds exactly.
2. **$\text{Accounts Receivable} = \text{Total Invoiced} - \text{Total Paid}$:** Verified in `DocumentService.calculateRemaining` and `DatabaseHelper.recordPayment`. Holds at integer minor-unit precision.
3. **$\text{Ending Stock} = \text{Starting Stock} + \text{Purchases} - \text{Sales} \pm \text{Adjustments}$:** Verified in `DatabaseHelper._assertSaleStockAvailable` and `_recordStockMovement`. Tested comprehensively in `inventory_integrity_db_test.dart`.
4. **$\sum \text{Debits} = \sum \text{Credits}$:** Verified in `LedgerBuilder`. Tested in `ledger_test.dart` and `TrialBalance.isBalanced`.
5. **Customer Statement Running Balance:** Verified in `CustomerStatementService.generateStatement`. Starting balance + debits (invoices) - credits (payments/receipts) = closing balance.

---

## 5. Section D: Data Integrity & Fault Tolerance

### 5.1 Transaction Boundaries
Every database mutation involving multiple tables or counters is wrapped in an atomic `db.transaction(...)`:
- `insertDocument` (`database_helper.dart:2651`): Inserts document, items, stock movements, payment row, linked receipt, updates product stock, and increments counter within a single transaction.
- `cancelDocument` (`database_helper.dart:4346`): Reverts stock, cancels linked receipts, and writes audit log within a single transaction.
- `recordPayment` (`database_helper.dart:4420`): Inserts receipt, updates parent document `paid` and `remaining`, inserts payment log, and updates counter atomically.
- `restoreFromJsonMap` (`backup_service.dart:241`): Restores the entire database atomically within a transaction.

### 5.2 Unique Document Numbering
- **Mechanism (`database_helper.dart:5055-5072`):** `_getNextDocumentNumber(txn, type)` reads `document_counters` under the active transaction, increments `next_number`, and generates formatted codes (e.g. `INV-00001`).
- **Concurrency Safety:** Because SQLite transactions lock the database in serializable/exclusive mode during writes, race conditions cannot produce duplicate document numbers.

### 5.3 Foreign Key Enforcement
- **Configuration (`database_helper.dart:45`):** `onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON')`.
- **Cascade Actions:**
  - `document_items`: `FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE`.
  - `document_payments`: `FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE`.
  - `stock_movements`: `FOREIGN KEY (reference_document_id) REFERENCES documents(id) ON DELETE SET NULL`.

### 5.4 Database Diagnostics & Repair Analysis
- **`DatabaseDiagnosticService` (`lib/services/database_diagnostic_service.dart`):**
  - Detects orphaned line items, orphaned payments, and orphaned stock movements.
  - Detects arithmetic inconsistencies in document totals and balances.
  - Detects document status mismatches against paid amounts.
  - Detects discrepancies between product stock and recorded movement history.
  - Detects negative stock balances.
  - Detects missing/unknown inventory cost records.
  - Detects duplicate document numbers.
- **Diagnostic Gap Identified:** The diagnostic service does NOT inspect document currency codes against `businesses.currency_code`. If a database contains legacy foreign-currency documents, diagnostics report 0 issues.

---

## 6. Section E: Prioritized Defect List

| Defect ID | Severity | File & Line | Description & Scenario | Expected vs Actual |
|---|---|---|---|---|
| **BUG-01** | **High** | `lib/services/document_service.dart:41` | `DocumentItemInput.total` hardcodes 2 decimal places (`MoneyUtils.round(quantity * price)`), ignoring currency precision for 0-decimal currencies (e.g. integer SDG) or 3-decimal currencies. | **Expected:** Item totals should round according to currency scale.<br>**Actual:** Always rounds to 2 decimals. |
| **BUG-02** | **High** | `lib/services/database_diagnostic_service.dart:40-70` | Missing currency diagnostic check. If a database contains foreign-currency documents from legacy imports, diagnostics do not report them. | **Expected:** Diagnostics should report count of foreign-currency documents.<br>**Actual:** Silently ignored. |
| **BUG-03** | **Medium** | `lib/services/accounting/ledger.dart:413` | Floating point division in `_allocatedNet`: `it.total / d.subtotal * (d.total - d.taxAmount)` does not use Hamilton-Hare integer minor-unit apportionment, which could cause slight fractional piastre drift compared to `MoneyUtils.allocateDocumentDiscount`. | **Expected:** Apportionment uses exact minor-unit largest-remainder algorithm.<br>**Actual:** Uses naive floating-point ratio. |
| **BUG-04** | **Medium** | `lib/screens/reports/payments_report_screen.dart:59-75` | Payments report maintains an internal `totalsByCurrency` map that aggregates payments by nominal currency code rather than strictly filtering to base currency. | **Expected:** Single base currency presentation.<br>**Actual:** Nominal multi-currency aggregation map. |
| **BUG-05** | **Low** | `lib/services/pdf/pdf_totals_builder.dart:13` | `PdfTotalsBuilder` uses hardcoded `NumberFormat('#,##0.00')` for all printable PDF totals regardless of whether currency is zero-decimal. | **Expected:** Formatter honors currency's `decimalDigits`.<br>**Actual:** Always prints two decimals. |

---

## 7. Audit Conclusion & Roadmap

The application's underlying transactional and accounting design is clean, resilient, and well-guarded. The transition to single-currency operation (Phase 3) requires:
1. Eliminating multi-currency aggregation maps in report screens.
2. Adding single-currency structural guards.
3. Adding a currency consistency diagnostic check in `DatabaseDiagnosticService`.
4. Standardizing item-level rounding to honor business currency precision.
