# Comprehensive Accounting & Financial System Audit: Waraqatak (ورقتك)

**Auditor:** Senior Accounting Systems & Financial Software Auditor  
**Date:** November 21, 2026  
**System:** Waraqatak (ورقتك) Mobile Offline-First Application  
**Target Document:** `docs/audit/ACCOUNTING_AUDIT.md`  
**Scope:** Core accounting engine, double-entry general ledger, inventory costing & valuation, multi-currency, payment allocation, customer statements, document lifecycle (create/edit/cancel/delete), tax arithmetic, and reporting.  
**Governing Policies & References:**  
- `docs/accounting_backbone_design.md`
- `docs/invariants_units_wholesale.md`
- `docs/single_currency_design.md`
- `docs/inventory_costing_policy.md`
- `docs/cancel-paid-invoice-proposal.md`
- `lib/services/accounting/*`
- `lib/database/database_helper.dart`

---

## 1. Executive Summary Table

All identified findings sorted by severity (Critical &rarr; High &rarr; Medium &rarr; Low):

| ID | Severity | File:Line | Title |
|:---|:---|:---|:---|
| **ACC-01** | **Critical** | `lib/database/database_helper.dart:5322-5353`<br>`lib/services/accounting/posting_service.dart:160-186` | Duplicate Payment Posting & Distorted Effective Dates on Document Edit |
| **ACC-02** | **Critical** | `lib/database/database_helper.dart:4150-4155`<br>`lib/services/accounting/posting_service.dart:280-315` | Tax-Inclusive Purchases Overstate Inventory Cost Basis and Distort Moving Average & COGS |
| **ACC-03** | **Critical** | `lib/database/database_helper.dart:7625-7639`<br>`lib/database/database_helper.dart:7889-7899` | Standalone Expense Vouchers and Payment Receipts Completely Omitted from Dashboard & Payments Report |
| **ACC-04** | **High** | `lib/services/accounting/posting_service.dart:125, 250` | Zero-Total and 100% Discounted Invoices Bypass COGS & Inventory Credit in Journal |
| **ACC-05** | **High** | `lib/services/customer_statement_service.dart:150-200` | Customer Statements Drop Unallocated Payment Receipts in Modern FIFO Path |
| **ACC-06** | **High** | `lib/database/database_helper.dart:5440-5486`<br>`lib/database/database_helper.dart:5693-5708` | Hard Deletion of Allocated Vouchers Crashes SQLite Foreign Key Constraint |
| **ACC-07** | **High** | `lib/services/accounting/journal_writer.dart:129-180` | Silent Failure and Automatic Disable of Journal Reports on Shadow Posting Exceptions |
| **ACC-08** | **Medium** | `lib/services/accounting/stock_ledger.dart:131` | Hardcoded 2-Decimal Precision in Stock Adjustment Shadow Posting Distorts Non-2-Decimal Currencies |
| **ACC-09** | **Medium** | `lib/services/accounting/posting_service.dart:386-387` | Standalone Payment Receipts Credit Other Income (4900) Instead of Customer Advances (2110) |
| **ACC-10** | **Medium** | `lib/services/inventory_costing_service.dart:260-297` | Manual Cost Reconciliation Leaves Inventory Account and Balance Sheet Distorted |
| **ACC-11** | **Low** | `lib/services/document_service.dart:202, 226`<br>`lib/services/pdf/pdf_totals_builder.dart:81-83` | Multi-Rate Tax Invoice Displays Incorrect Document Tax Rate on PDF |
| **ACC-12** | **Low** | `lib/database/database_helper.dart:4599-4615` | Document Item Reduction on Sales Edit Uses Current Average Cost Instead of Sale Snapshot Cost |

---

## 2. Top 5 Issues Causing Wrong Financial Figures or Lost Data

1. **ACC-01 (Duplicate Payment Posting on Edit):** Editing an invoice that has been partially paid via a receipt voucher duplicates the payment in the general ledger. Cash is overstated, receivables are understated, and trial balance parity is broken.
2. **ACC-02 (Tax-Inclusive Purchase Cost Basis Distortion):** Purchases with tax-inclusive pricing record gross (VAT-inclusive) costs into inventory moving average, while the general ledger debits inventory net of tax. This causes Account 1140 to plummet into negative territory upon sale and artificially depresses operating profits.
3. **ACC-03 (Invisible Operating Expenses in Cash Reports):** Standalone expense vouchers (the primary way users record rent, electricity, salaries, and operating expenses) are completely omitted from the Home Screen Dashboard and Payments Report because queries only join invoice/purchase payments.
4. **ACC-04 (Zero-Total / Sample Sales Skip COGS):** Invoices with 100% discount or free promotional items deduct physical inventory from the warehouse but bypass the journal entirely, failing to debit COGS and failing to credit Inventory.
5. **ACC-05 (Unallocated Receipts Missing from Customer Statements):** Any advance or unallocated customer payment receipt is omitted from customer statements under the modern FIFO path, leading customers to dispute statements showing debts they already settled.

---

## 3. Detailed Audit Findings

### ACC-01: Duplicate Payment Posting & Distorted Effective Dates on Document Edit
- **Severity:** Critical
- **File:Line:** `lib/database/database_helper.dart:5322-5353`, `lib/services/accounting/posting_service.dart:160-186`
- **What is wrong:**  
  When an issued document (invoice or purchase) is edited (e.g. adding a line item, changing quantity, or updating recipient information), `updateDocumentWithItems` invokes `JournalWriter.reverseDocument(txn, doc.id!)` followed by `JournalWriter.postDocumentIssued(txn, finalDoc, persistedItems)`.  
  `reverseDocument` reverses the original document's entries (`JE-INV` / `JE-PUR` / `JE-COGS` / `JE-PAY`), but does **NOT** reverse separate `payment_receipt` voucher entries (`JE-REC`), because those entries carry `source_type: 'receipt'` and `source_id: voucher.id`.  
  `JournalWriter.postDocumentIssued` then delegates to `PostingService._postInvoice` / `_postPurchase`, which checks `if (doc.paid > 0)` and unconditionally posts a brand-new `JE-PAY` for the full `doc.paid` amount.  
  Consequently:
  1. Any payment that was previously recorded via a linked `payment_receipt` voucher is now posted **twice**: once in the active `JE-REC` (never reversed), and a second time in the new `JE-PAY` generated by the invoice edit.
  2. Any subsequent payments recorded via `recordPayment` on later dates were reversed by `reverseDocument`, but are now re-posted under `doc.date` (the invoice issuance date), completely wiping out the historical payment date in the journal.
- **Failing Scenario:**
  1. Day 1: Invoice `INV-001` created for 1,000 SDG, paid = 0 SDG.  
     *Journal:* Dr 1130 (Receivables) 1,000 / Cr 4100 (Sales Revenue) 1,000.
  2. Day 10: Customer pays 400 SDG via Receipt Voucher `REC-001`, which is FIFO-allocated to `INV-001`. `INV-001` is updated in `documents` to `paid = 400.0, remaining = 600.0`.  
     *Journal:* `REC-001` posts `JE-REC`: Dr 1110 (Cash) 400 / Cr 1130 (Receivables) 400.
  3. Day 15: Merchant edits `INV-001` to add an item, increasing total from 1,000 to 1,200 SDG (`paid` remains 400 SDG).
  4. In `updateDocumentWithItems`:
     - Line 5333: `JournalWriter.reverseDocument(txn, 1)` reverses `JE-INV` (1,000). `JE-REC` (400) is untouched.
     - Line 5347: `JournalWriter.postDocumentIssued(txn, finalDoc, persistedItems)` is called where `finalDoc.paid = 400.0`.
     - `PostingService._postInvoice` posts a new `JE-INV` for 1,200 SDG, and posts a new `JE-PAY` for 400 SDG dated Day 1!
  5. *Resulting General Ledger Balances:*
     - Account 1110 (Cash): Debited 400 (REC-001) + Debited 400 (INV-001 edit) = **800 SDG** (Real cash in hand = 400 SDG).
     - Account 1130 (Receivables): Debited 1,200 - Credited 400 (REC-001) - Credited 400 (INV-001 edit) = **400 SDG** (Real receivable = 800 SDG).
     - Persisted journal cash is double-counted by 400 SDG.
     - Parity check (`verifyParity`) fails against reference `LedgerBuilder.build` because `LedgerBuilder` explicitly subtracts `linkedPaid` before posting settlement lines (`var left = d.paid - linked;`).
- **Suggested Fix:**
  1. In `PostingService.postDocumentIssued`, accept `List<DocumentPayment> payments` and `double linkedPaid = 0.0`.
  2. Emulate `LedgerBuilder._payments`: only post upfront settlement for `doc.paid - linkedPaid`.
  3. When an invoice is edited, do not re-post subsequent payments as upfront settlements; instead, re-post existing non-voucher `document_payments` rows preserving their original `date`, `paymentMethod`, and `amount`.

---

### ACC-02: Tax-Inclusive Purchases Overstate Inventory Cost Basis and Distort Moving Average & COGS
- **Severity:** Critical
- **File:Line:** `lib/database/database_helper.dart:4150-4155`, `4204-4213`, `7155-7178`, `lib/services/accounting/posting_service.dart:280-315`
- **What is wrong:**  
  When a business operates with tax-inclusive pricing (`pricesIncludeTax = true`, standard in VAT regimes like Saudi Arabia ZATCA), product purchase prices entered by the merchant include VAT.  
  In `DatabaseHelper.insertDocumentWithItems` (line 4152) and `issueDocument` (line 7155), `incomingUnitCost` is calculated directly as:  
  `incomingUnitCost = incomingQty > 0 ? (item.price * item.quantity) / incomingQty : item.price;`  
  This takes the gross, tax-inclusive price and feeds it directly into `InventoryCostingService.calculateNewWeightedAverage`, updating `products.average_cost` and `stock_movements.unit_cost` / `total_cost` with gross costs.  
  However, in `PostingService._postPurchase` (lines 280-315) and according to international accounting standards (IAS 2.11), recoverable taxes are excluded from inventory cost. The journal debits Account 1140 (Merchandise Inventory) strictly for the **net amount excluding tax**, and debits Account 1150 (VAT Input) for the recoverable tax.  
  Consequently:
  1. Physical stock valuation in `stock_movements` exceeds general ledger inventory (Account 1140) by the tax amount, violating Invariant INV-13.
  2. When the products are sold, `PostingService._postInvoice` debits COGS (5100) and credits Inventory (1140) at the gross average cost (e.g. 115 SDG).
  3. After selling all purchased units, Account 1140 ends up with a **negative balance**, and COGS is overstated by the recoverable VAT amount, incorrectly reducing gross and net profit.
- **Failing Scenario:**
  1. Business configuration: VAT = 15%, `taxesEnabled = true`, `pricesIncludeTax = true`. Starting stock = 0.
  2. Purchase 10 units of Product A at 115 SDG gross per unit (Subtotal 1,150 SDG, Tax 150 SDG, Net 1,000 SDG, Total 1,150 SDG).
  3. In `DatabaseHelper`: `incomingUnitCost` is computed as `115.0 SDG`. `products.average_cost` is set to `115.0 SDG`. `stock_movements` row created: 10 units @ 115.0 = 1,150.0 SDG.
  4. In `PostingService._postPurchase`:
     - Dr 1140 (Merchandise Inventory): 1,000.00 SDG
     - Dr 1150 (VAT Input): 150.00 SDG
     - Cr 2110 (Accounts Payable): 1,150.00 SDG
     *(Notice: Inventory ledger has 1,000 SDG, while movements have 1,150 SDG).*
  5. Merchant sells all 10 units at 200 SDG each.
  6. In `PostingService._postInvoice`:
     - COGS entry: Dr 5100 (COGS) 1,150.00 SDG / Cr 1140 (Inventory) 1,150.00 SDG.
  7. *Result in General Ledger:*
     - Account 1140 (Inventory): 1,000.00 Dr - 1,150.00 Cr = **-150.00 SDG (Negative Asset balance!)**.
     - Account 5100 (COGS): **1,150.00 SDG** (Overstated by 150 SDG).
     - Net profit is understated by 150 SDG.
- **Suggested Fix:**
  In `DatabaseHelper.insertDocumentWithItems`, `_applyDocumentEditStockDeltas`, and `issueDocument`, when `doc.type == 'purchase'`, compute `incomingUnitCost` based on the item's net allocated cost after stripping tax (and allocating document discounts), matching `LedgerBuilder._allocatedNet`:
  ```dart
  final isInclusive = business.taxesEnabled && business.pricesIncludeTax;
  final effectiveNetPrice = isInclusive && item.taxRate != null && item.taxRate! > 0
      ? item.price / (1.0 + (item.taxRate! / 100.0))
      : item.price;
  ```

---

### ACC-03: Standalone Expense Vouchers and Payment Receipts Completely Omitted from Dashboard & Payments Report
- **Severity:** Critical
- **File:Line:** `lib/database/database_helper.dart:7625-7639`, `7889-7899`
- **What is wrong:**  
  `DatabaseHelper.getPeriodSummary` (which feeds the Home Screen KPI cards) and `DatabaseHelper.getPaymentReport` (which feeds `PaymentsReportScreen` and its exported PDF) calculate payment totals by joining `document_payments` to `documents`:
  ```sql
  SELECT
    d.currency_code,
    COALESCE(SUM(CASE WHEN d.type = 'invoice'  THEN dp.amount ELSE 0 END), 0) AS paymentsIn,
    COALESCE(SUM(CASE WHEN d.type = 'purchase' THEN dp.amount ELSE 0 END), 0) AS paymentsOut
  FROM document_payments dp
  JOIN documents d ON d.id = dp.document_id
  WHERE d.status != 'cancelled' AND dp.date >= ? AND dp.date <= ?
  GROUP BY d.currency_code
  ```
  `document_payments` rows are **only** created when a payment is attached to a parent invoice or purchase (`dp.document_id`).  
  When a user creates a standalone Expense Voucher (`type = 'expense_voucher'`) for operating expenses (such as rent, utilities, fuel, staff lunch, delivery), or a standalone Payment Receipt (`type = 'payment_receipt'`) for miscellaneous income, **no row is ever inserted into `document_payments`**.  
  Because the query joins `document_payments dp JOIN documents d ON d.id = dp.document_id` where `d.type IN ('invoice', 'purchase')`, **100% of standalone operating expense vouchers are completely absent from `paymentsOut`**, and standalone payment receipts are absent from `paymentsIn`.  
  The business dashboard and payments report falsely state that zero money was paid out.
- **Failing Scenario:**
  1. During November, a grocery shop records 0 purchase invoices, but pays 150,000 SDG for monthly warehouse rent and 25,000 SDG for electricity via two Expense Vouchers (`expense_voucher`).
  2. Cash sales invoices total 200,000 SDG cash collected.
  3. Shopkeeper checks Dashboard (`HomeScreen`):
     - Payments In: 200,000 SDG
     - Payments Out: **0.0 SDG**!
     - Displayed net cash position: +200,000 SDG.
  4. Shopkeeper checks Payments Report (`PaymentsReportScreen`):
     - Total Payments Out: **0.0 SDG**! The rent and electricity vouchers do not appear in the list.
  5. In General Ledger (`LedgerService.load`):
     - Cash on Hand (1110): 200,000 Dr - 175,000 Cr = 25,000 SDG.
     - Operating Expenses (6100): 175,000 SDG Dr.
  6. Discrepancy between dashboard/payments report and general ledger: **175,000 SDG**.
- **Suggested Fix:**
  In both `getPeriodSummary` and `getPaymentReport`, query standalone documents of type `payment_receipt` and `expense_voucher` that have no parent document or active allocation, and union/aggregate them into `paymentsIn` and `paymentsOut`:
  ```sql
  -- Standalone vouchers contribution:
  SELECT
    currency_code,
    COALESCE(SUM(CASE WHEN type = 'payment_receipt' AND (related_document_id IS NULL) THEN total ELSE 0 END), 0) as standaloneIn,
    COALESCE(SUM(CASE WHEN type = 'expense_voucher' AND (related_document_id IS NULL) THEN total ELSE 0 END), 0) as standaloneOut
  FROM documents
  WHERE status != 'cancelled' AND type IN ('payment_receipt', 'expense_voucher')
    AND id NOT IN (SELECT DISTINCT receipt_document_id FROM document_payments WHERE receipt_document_id IS NOT NULL)
    AND date >= ? AND date <= ?
  GROUP BY currency_code;
  ```

---

### ACC-04: Zero-Total and 100% Discounted Invoices Bypass COGS & Inventory Credit in Journal
- **Severity:** High
- **File:Line:** `lib/services/accounting/posting_service.dart:125, 250`
- **What is wrong:**  
  In `PostingService._postInvoice`, line 125 contains the following guard:
  ```dart
  final totalMinor = MoneyUtils.toMinorUnits(doc.total, decimalDigits);
  final taxMinor = MoneyUtils.toMinorUnits(doc.taxAmount, decimalDigits);
  final netMinor = totalMinor - taxMinor;

  if (totalMinor <= 0) return;
  ```
  This early `return` is placed **before** the Cost of Goods Sold loop (lines 188-233).  
  When an invoice is issued with a 100% discount, promotional giveaway, or zero total:
  - `DatabaseHelper.insertDocumentWithItems` deducts physical inventory from `products.stock_quantity` and inserts a `type = 'sale'` movement into `stock_movements`.
  - But `_postInvoice` exits immediately at line 125, generating **zero journal entries**.
  - `JE-COGS` is never posted: Account 5100 (COGS) is never debited, and Account 1140 (Merchandise Inventory) is never credited.
  - Physical inventory has left the warehouse, but the general ledger balance of Account 1140 remains uncredited, causing permanent drift between physical stock valuation and general ledger asset value.
- **Failing Scenario:**
  1. Business has 10 units of an item with average cost 40 SDG (Inventory Asset = 400 SDG).
  2. Merchant gives 2 units as free marketing samples to a VIP client, entering an invoice for 2 units @ 100 SDG with 200 SDG discount (`doc.total = 0.0 SDG`).
  3. In `DatabaseHelper`: 2 units are deducted. Stock is now 8 units. Physical valuation = 8 * 40 = 320 SDG.
  4. In `PostingService._postInvoice`: `totalMinor = 0`, returns immediately.
  5. *General Ledger:* Account 1140 remains at 400 SDG! Account 5100 has 0 SDG.
  6. Inventory in the general ledger is permanently overstated by 80 SDG.
- **Suggested Fix:**
  Separate the COGS posting logic from the revenue posting logic in `PostingService._postInvoice`. Only guard the receivables/revenue lines with `totalMinor > 0`, and allow the COGS loop to execute whenever `items` contains stocked products with positive base quantities and known unit costs:
  ```dart
  if (totalMinor > 0) {
    // Post Receivables, Revenue, Tax, and Upfront Settlement
  }
  // COGS evaluation must always execute independently of totalMinor:
  if (cogsLines.isNotEmpty) {
    out.add(JournalEntryDraft(...));
  }
  ```

---

### ACC-05: Customer Statements Drop Unallocated Payment Receipts in Modern FIFO Path
- **Severity:** High
- **File:Line:** `lib/services/customer_statement_service.dart:150-200`
- **What is wrong:**  
  In `CustomerStatementService.generateStatement`, when payments exist in the database, `hasPaymentRows` is set to `true`.  
  Inside the `if (hasPaymentRows)` block (lines 151-281), the generator iterates strictly over `eligibleInvoices`. For each invoice, it emits:
  1. Invoice debit
  2. Upfront payment credit
  3. Receipt allocations linked to that invoice
  4. Reversals
  
  The method has **no loop over payment receipts that are unallocated** (e.g. advance receipts paid when no open invoice existed, or excess payments not tied to any invoice).  
  As a result, unallocated payment receipts are completely dropped from the customer statement. The customer's opening, period, and closing balances show they owe money that they have already paid.
- **Failing Scenario:**
  1. Customer owes 500 SDG on invoice `INV-1`.
  2. Customer makes a payment of 800 SDG via receipt voucher `REC-1`.
  3. `INV-1` is marked paid (500 SDG allocated). The remaining 300 SDG sits on `REC-1` as unallocated customer funds.
  4. Customer requests an official statement of account.
  5. `CustomerStatementService.generateStatement` executes the `if (hasPaymentRows)` block:
     - Emits `INV-1` debit 500 SDG.
     - Emits `REC-1` credit 500 SDG (allocated portion).
     - Loops end.
  6. The 300 SDG unallocated credit is completely missing from the statement.
  7. Statement closing balance reports 0.0 SDG instead of -300.00 SDG (credit balance owed to customer).
- **Suggested Fix:**
  In `CustomerStatementService.generateStatement`, after processing `eligibleInvoices`, find all `payment_receipt` documents belonging to the contact whose total has not been fully consumed by the processed allocation rows, and emit them as independent credit entries (`StatementEntryType.receipt` with `relatedDocumentId: null`).

---

### ACC-06: Hard Deletion of Allocated Vouchers Crashes SQLite Foreign Key Constraint
- **Severity:** High
- **File:Line:** `lib/database/database_helper.dart:5440-5486`, `5693-5708`
- **What is wrong:**  
  `DatabaseHelper.deleteDocument` contains deletion guards that prevent deleting invoices or purchases with payment history (lines 5474-5485).  
  However, these guards are explicitly conditioned on `if (doc.type == 'invoice' || doc.type == 'purchase')`.  
  If `deleteDocument` is invoked on a `payment_receipt` or `expense_voucher`:
  - It bypasses all checks.
  - It does not invoke `_reverseReceiptPayment` to restore the parent document's `remaining` balance.
  - At line 5707, it executes `txn.delete('documents', where: 'id = ?', whereArgs: [id])`.
  - Because `document_payments.receipt_document_id` references `documents(id)` without `ON DELETE CASCADE` (line 498), SQLite throws a `FOREIGN KEY constraint failed` exception under `PRAGMA foreign_keys = ON`.
- **Failing Scenario:**
  1. Create invoice `INV-01` for 300 SDG.
  2. Create payment receipt `REC-01` for 300 SDG, which allocates against `INV-01`.
  3. User attempts to delete `REC-01` via `deleteDocument(REC-01.id)`.
  4. SQLite throws `DatabaseException: FOREIGN KEY constraint failed (code 787)`.
- **Suggested Fix:**
  1. In `deleteDocument`, disallow hard-deleting allocated vouchers:
     ```dart
     if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
       final hasAlloc = await hasActiveAllocations(id, txn: txn);
       if (hasAlloc) {
         throw StateError('Cannot delete allocated voucher. Please cancel it instead.');
       }
     }
     ```
  2. Direct the user to `cancelDocument`, which cleanly invokes `_reverseReceiptPayment` and updates parent balances.

---

### ACC-07: Silent Failure and Automatic Disable of Journal Reports on Shadow Posting Exceptions
- **Severity:** High
- **File:Line:** `lib/services/accounting/journal_writer.dart:129-180`
- **What is wrong:**  
  In `JournalWriter._runIsolatedShadow`, all shadow operations (document issued, payment recorded, document reversed, stock adjusted) run inside a SQLite savepoint (`SAVEPOINT sp_shadow_...`).  
  When an unhandled exception occurs (such as `StateError('Unbalanced journal entry')` or constraint violation):
  - If `e is! PeriodClosedException`, the catch block rolls back only the savepoint (`ROLLBACK TO SAVEPOINT`), writes an audit log, sets `journal_reports_enabled = 'false'`, and returns `fallback` (empty list or null).
  - The error is **swallowed** and not rethrown.
  - The outer caller transaction proceeds and commits to SQLite!
  - The source invoice/payment is persisted, physical stock is updated, but **zero general ledger rows are written**.
  - If `journal_reports_enabled` was active, it is silently turned off without the user's knowledge, reverting reports to the derived ledger.
- **Failing Scenario:**
  1. A minor rounding discrepancy causes an invoice journal entry to fail the strict balance assertion in `JournalWriter.write`.
  2. `_runIsolatedShadow` catches the `StateError`, rolls back the savepoint, and returns `[]`.
  3. `DatabaseHelper.insertDocumentWithItems` continues, commits the transaction, and returns the new document ID.
  4. The invoice exists and is marked `issued`, but has no corresponding journal entries in `journal_entries` or `journal_lines`.
  5. The general ledger is incomplete and permanently out of sync with documents.
- **Suggested Fix:**
  If the system is running with persisted journal reports (`isJournalReportsEnabled == true`), `_runIsolatedShadow` must rethrow all exceptions so the entire database transaction rolls back atomically:
  ```dart
  if (reportsEnabled || e is PeriodClosedException) {
    rethrow;
  }
  ```

---

### ACC-08: Hardcoded 2-Decimal Precision in Stock Adjustment Shadow Posting Distorts Non-2-Decimal Currencies
- **Severity:** Medium
- **File:Line:** `lib/services/accounting/stock_ledger.dart:131`
- **What is wrong:**  
  In `StockLedger.record` (line 131), when shadow-posting manual stock adjustments and opening balances, `decimalDigits` is hardcoded as `2`:
  ```dart
  final draft = PostingService.postStockAdjusted(
    productId: productId,
    quantity: deltaQuantity,
    unitCost: unitCost ?? 0.0,
    reason: effectiveReason,
    decimalDigits: 2, // <--- Hardcoded!
    date: movementDate,
    ...
  );
  ```
  If the business base currency is a 3-decimal currency (e.g. KWD, BHD, OMR, JOD, TND) or a 0-decimal currency (e.g. JPY, KRW), converting amounts to minor units using 2 decimals distorts values by factors of 10 or 100.
- **Failing Scenario:**
  1. Business currency is KWD (3 decimal places, 1 KWD = 1,000 fils).
  2. A stock count loss is recorded: 10 units @ 0.125 KWD = 1.250 KWD.
  3. `MoneyUtils.toMinorUnits(1.250, 2)` produces `125` minor units instead of `1250`.
  4. In `journal_lines`: debit 125, credit 125.
  5. When loaded back via `LedgerService.load` with KWD decimals (3): `MoneyUtils.fromMinorUnits(125, 3)` = **0.125 KWD** instead of **1.250 KWD**!
  6. Inventory adjustment expense in the general ledger is understated by 90%.
- **Suggested Fix:**
  Retrieve the base currency decimal digits dynamically from `txn`:
  ```dart
  final bRows = await txn.query('businesses', columns: ['currency_code'], limit: 1);
  final baseCode = bRows.isNotEmpty ? bRows.first['currency_code'] as String? : 'SDG';
  final decimals = Currency.decimalDigitsForCode(baseCode);
  ```

---

### ACC-09: Standalone Payment Receipts Credit Other Income (4900) Instead of Customer Advances (2110)
- **Severity:** Medium
- **File:Line:** `lib/services/accounting/posting_service.dart:386-387`
- **What is wrong:**  
  In `PostingService._postReceipt`, when a payment receipt has no parent document and is not allocated (`parentDoc == null && !isAllocated`):
  `creditAccountCode = Accounts.otherIncome.code;`  
  If a customer makes an unallocated advance payment or on-account deposit, this rule credits revenue/income (`4900 Other Income`) immediately upon receipt of cash, rather than crediting a liability account (`2110 Accounts Payable / Customer Advance Liability`) or contra-receivable (`1130`).  
  When an invoice is issued for this customer in a subsequent period, revenue (`4100 Sales Revenue`) is recognized again, double-counting earnings.
- **Failing Scenario:**
  1. On December 28, a customer deposits 5,000 SDG cash advance for goods to be manufactured in January.
  2. Receipt voucher created with no allocated invoice.
  3. `PostingService._postReceipt` posts: Dr 1110 (Cash) 5,000 / Cr 4900 (Other Income) 5,000.
  4. December P&L shows 5,000 SDG revenue.
  5. In January, the goods are delivered and an invoice for 5,000 SDG is issued.
  6. `PostingService._postInvoice` posts: Dr 1130 (Receivables) 5,000 / Cr 4100 (Sales Revenue) 5,000.
  7. Total revenue reported across Dec-Jan: 10,000 SDG (should be 5,000 SDG).
- **Suggested Fix:**
  If the receipt has a customer `contactId`, credit `Accounts.payables` (Customer Advance Liability) or `Accounts.receivables` (Unallocated Customer Credit), and only credit `Accounts.otherIncome` if `contactId == null`.

---

### ACC-10: Manual Cost Reconciliation Leaves Inventory Account and Balance Sheet Distorted
- **Severity:** Medium
- **File:Line:** `lib/services/inventory_costing_service.dart:260-297`
- **What is wrong:**  
  `InventoryCostingService.reconcileProductCost` allows setting an audited cost basis for products that had unknown costs (e.g. unvalued opening inventory). It updates `products.average_cost` and logs an audit event.  
  However, it inserts **zero rows into `stock_movements`** and **zero entries into `journal_entries`**.  
  If the product already has 50 units on hand, establishing a cost basis of 100 SDG adds 5,000 SDG of value to the physical inventory without bringing that asset onto the general ledger balance sheet (Dr 1140 Inventory / Cr 3100 Opening Balance Equity).  
  When those 50 units are subsequently sold, `PostingService._postInvoice` debits COGS for 5,000 SDG and credits Inventory for 5,000 SDG, driving Account 1140 into a negative balance.
- **Failing Scenario:**
  1. Product created with 20 units of opening stock, price omitted (`average_cost = null`, stock = 20).
  2. Accountant reconciles cost: sets average cost to 50 SDG/unit.
  3. `reconcileProductCost` runs: updates `products.average_cost = 50.0`. Physical stock value = 1,000 SDG.
  4. General ledger Account 1140 has 0 SDG.
  5. 20 units sold. `_postInvoice` posts: Dr COGS 1,000 / Cr Inventory (1140) 1,000.
  6. Account 1140 balance becomes **-1,000 SDG**.
- **Suggested Fix:**
  In `reconcileProductCost`, if `stock > 0`, insert an opening stock or revaluation movement via `StockLedger.record` with `type = StockMovement.typeOpening` and `reason = 'cost_reconciliation'`, triggering a journal entry: Dr 1140 (Inventory) / Cr 3100 (Opening Equity).

---

### ACC-11: Multi-Rate Tax Invoice Displays Incorrect Document Tax Rate on PDF
- **Severity:** Low
- **File:Line:** `lib/services/document_service.dart:202, 226`, `lib/services/pdf/pdf_totals_builder.dart:81-83`
- **What is wrong:**  
  When a document contains items with different tax rates (e.g. Item 1 @ 15%, Item 2 @ 0%), `DocumentService.createDocument` sets `doc.taxRate = effectiveTaxRate` (the business default rate, e.g. 15%).  
  On the PDF, `PdfTotalsBuilder` displays:  
  `Tax (15%): [totalTax]`  
  Because `totalTax` is the sum of taxes from both items, the printed tax rate label does not match the mathematical ratio of tax to subtotal, causing customer confusion.
- **Suggested Fix:**
  If items have heterogeneous tax rates, store `doc.taxRate = 0` or compute an effective blended rate, or update `PdfTotalsBuilder` to omit the rate percentage when items have varying rates.

---

### ACC-12: Document Item Reduction on Sales Edit Uses Current Average Cost Instead of Sale Snapshot Cost
- **Severity:** Low
- **File:Line:** `lib/database/database_helper.dart:4599-4615`
- **What is wrong:**  
  In `DatabaseHelper._applyDocumentEditStockDeltas`, when an issued sales invoice is edited to reduce an item's quantity (partial return), line 4614 creates a cancellation stock movement with:  
  `unitCost: isCostKnown ? avgCost : null`  
  Here `avgCost` is the product's **current** average cost. If subsequent purchases arrived at different unit prices between the sale and the edit, the returned units are added back into inventory at the current average cost rather than the snapshot cost at which they were originally relieved.
- **Suggested Fix:**
  Read `oldItem['unit_cost']` from the snapshot in `oldItems` and use that original snapshot cost for the cancellation movement.

---

## 4. Top 10 Recommended Fixes with Effort Estimates

| Priority | Finding ID | Effort | Summary of Recommended Action |
|:---:|:---:|:---:|:---|
| **1** | **ACC-01** | **M** | Pass existing payments and linked voucher amounts to `PostingService.postDocumentIssued` on edits; deduct `linkedPaid` from upfront settlement to prevent duplicate payment posting. |
| **2** | **ACC-02** | **M** | Strip recoverable tax and allocate document discounts when computing `incomingUnitCost` on purchases in `DatabaseHelper.insertDocumentWithItems` and `issueDocument` under tax-inclusive pricing. |
| **3** | **ACC-03** | **M** | Update `DatabaseHelper.getPeriodSummary` and `getPaymentReport` to include standalone `expense_voucher` and `payment_receipt` documents. |
| **4** | **ACC-04** | **S** | In `PostingService._postInvoice`, decouple the COGS posting loop from `if (totalMinor <= 0) return`, ensuring samples and 100% discounted goods record COGS and credit inventory. |
| **5** | **ACC-05** | **M** | In `CustomerStatementService.generateStatement`, iterate over unallocated customer receipts in the modern path and emit them as credit entries. |
| **6** | **ACC-06** | **S** | In `DatabaseHelper.deleteDocument`, block deleting allocated payment receipts/vouchers with an explicit error, guiding users to `cancelDocument`. |
| **7** | **ACC-07** | **S** | In `JournalWriter._runIsolatedShadow`, rethrow exceptions when `isJournalReportsEnabled == true` so business transactions roll back atomically on posting failures. |
| **8** | **ACC-08** | **S** | In `StockLedger.record`, replace hardcoded `decimalDigits: 2` with dynamic decimal lookup for the business base currency. |
| **9** | **ACC-09** | **S** | In `PostingService._postReceipt`, credit Accounts Payable (2110) or Accounts Receivable (1130) instead of Other Income (4900) when a receipt has an associated contact. |
| **10** | **ACC-10** | **M** | In `InventoryCostingService.reconcileProductCost`, post an opening stock entry in `StockLedger` (Dr 1140 Inventory / Cr 3100 Opening Equity) when cost is reconciled for existing physical stock. |

*Effort Legend: S = Small (< 0.5 day), M = Medium (1-2 days), L = Large (> 3 days).*

---

## 5. "Looks Correct" — Audited & Verified Sound Areas

The following components were audited in detail and found to be robust, secure, and compliant with accounting invariants:

1. **Double-Entry Balance Verification at Write Time (`JournalWriter.write`):**
   Every persisted journal entry is strictly validated at integer minor-unit precision (`draft.isBalanced`). Unbalanced entries cannot be written to SQLite tables.
2. **Double-Entry Journal Immutability (INV-15):**
   `journal_entries` and `journal_lines` are never mutated (`UPDATE` and `DELETE` outside savepoint rollback are strictly prohibited). Cancellations and edits use append-only reversals carrying `reverses_entry_id` and the original `effective_date`.
3. **Accounting Period Lock Enforcement (INV-17):**
   `assertPeriodOpen` is invoked across all mutation entry points (`insertDocumentWithItems`, `updateDocumentWithItems`, `cancelDocument`, `deleteDocument`, `recordPayment`, `finalizeStocktakeSession`, `onStockAdjusted`). Closed periods cannot be back-dated or modified.
4. **Base Currency Lock & Segregation:**
   `businesses.currency_locked_at` permanently locks the business base currency on first transaction. Multi-currency documents are cleanly segregated and never nominally summed with base currency totals.
5. **Reference Pricing Catalog Isolation:**
   Updating reference exchange rates dynamically reprices catalog selling prices without mutating historical invoices, historical stock movements, or average cost snapshots.
6. **FIFO Payment Allocation Guard (`PaymentAllocator.planFifo`):**
   Strictly prevents overpayment beyond total outstanding debt at minor-unit precision and distributes receipts strictly oldest-first.
7. **Single Stock Writer Guard (INV-16):**
   All physical stock modifications route through `StockLedger.record`, preventing unauthorized table writes or orphaned stock movements.
8. **CSV Product Import Safety:**
   CSV import sets opening stock to 0.0 for new products and does not modify stock quantities for existing products, preventing unposted inventory mutations.
9. **Backup & Restore Journal Safety:**
   `BackupService.restoreFromJsonMap` executes a pre-restore safety backup, forces `journal_reports_enabled = false` post-restore, sanitizes schema columns, and triggers an idempotent backfill with parity verification for legacy backups.
10. **Granular Permissions Gate:**
    Role-based permissions in `PermissionRegistry` are enforced before any document creation, repricing, cancellation, refund, period locking, or export.

---

## 6. Test Coverage & Gap Analysis

### Current Test Suites Audited:
- `test/invariants/accounting_backbone_invariants_test.dart` (INV-14..18)
- `test/invariants/units_wholesale_invariants_test.dart` (INV-1..13)
- `test/invariants/cancel_paid_invoice_test.dart`
- `test/guards/single_stock_writer_guard_test.dart`
- `test/guards/architecture_guards_test.dart`
- `test/guards/single_currency_guard_test.dart`

### Specific Test Gaps & Proposed Concrete Regression Tests:

1. **Gap 1 (Invoice Edit with Payment Receipt Allocation — ACC-01):**
   - *Test:* Create an invoice for 1,000 SDG; allocate a 400 SDG payment receipt; edit invoice total to 1,200 SDG.
   - *Assertion:* Verify total debit to Account 1110 (Cash) in `journal_lines` equals exactly 400 SDG, not 800 SDG. Verify `verifyParity` passes.
2. **Gap 2 (Tax-Inclusive Purchase Moving Average — ACC-02):**
   - *Test:* With `pricesIncludeTax = true` and VAT = 15%, record a purchase of 10 units @ 115 SDG.
   - *Assertion:* Assert `product.averageCost` equals 100.0 SDG (net of tax), and `stock_movements.total_cost` equals 1,000 SDG. Sell 10 units and assert Account 1140 (Inventory) balance is 0.0 SDG (not -150 SDG).
3. **Gap 3 (Standalone Operating Expense Vouchers in Reports — ACC-03):**
   - *Test:* Record a standalone expense voucher of 25,000 SDG for electricity.
   - *Assertion:* Assert `DatabaseHelper.getPeriodSummary` returns `paymentsOut == 25000.0`, and `getPaymentReport` includes the voucher.
4. **Gap 4 (Zero-Total Invoice COGS Posting — ACC-04):**
   - *Test:* Issue an invoice with 100% discount (`doc.total == 0.0`) for an item with known average cost.
   - *Assertion:* Assert a `JE-COGS` entry is written to `journal_entries` debiting Account 5100 and crediting Account 1140.
5. **Gap 5 (Unallocated Payment Receipt in Customer Statement — ACC-05):**
   - *Test:* Record an unallocated payment receipt of 500 SDG for Customer A.
   - *Assertion:* Generate statement via `CustomerStatementService.generateStatement`. Assert entries include the 500 SDG receipt and closing balance reflects -500 SDG.
6. **Gap 6 (Delete Allocated Voucher Exception Handling — ACC-06):**
   - *Test:* Attempt `deleteDocument` on an allocated payment receipt.
   - *Assertion:* Expect `StateError` rather than an uncaught SQLite foreign key exception.
7. **Gap 7 (Stock Adjustment in 3-Decimal Currency — ACC-08):**
   - *Test:* Setup base currency as KWD (3 decimals). Record stock count gain of 1.250 KWD.
   - *Assertion:* Assert `journal_lines.debit_minor` equals 1250 (not 125).

---
*End of Audit Report.*
