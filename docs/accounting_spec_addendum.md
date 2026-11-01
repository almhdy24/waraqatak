# Waraqatak Accounting Posting Rules Specification (Addendum)

**Document:** Formal Addendum to `docs/accounting_spec.md`  
**Scope:** Derived Double-Entry General Ledger Engine & Inventory Costing Replay  
**Primary Source:** `lib/services/accounting/ledger.dart`, `lib/services/document_service.dart`, `lib/models/`  
**Status:** Canonical As-Implemented Reference (Read-Only)  

---

## 1. Chart of Accounts & Normal Balances

The derived general ledger (`LedgerBuilder`, `lib/services/accounting/ledger.dart:24-63`) employs a standardized 13-account chart formatted according to standard financial numbering:

| Code | Account Identifier | Localized Title (AR / EN) | Classification | Normal Balance | `forPaymentMethod` Mapping |
|:-----|:-------------------|:--------------------------|:---------------|:---------------|:---------------------------|
| **1110** | `Accounts.cash` | الصندوق (الخزينة) / Cash on Hand | Asset | Debit | `paymentMethod == 'cash'` or `null` |
| **1120** | `Accounts.bank` | البنك والمحافظ / Bank & E-Wallets | Asset | Debit | All non-cash methods (`bank_transfer`, `card`, etc.) |
| **1130** | `Accounts.receivables` | العملاء (الذمم المدينة) / Accounts Receivable | Asset | Debit | — |
| **1140** | `Accounts.inventory` | المخزون السلعي / Merchandise Inventory | Asset | Debit | — |
| **1150** | `Accounts.vatInput` | ضريبة القيمة المضافة المدخلة / Input VAT (Recoverable) | Asset | Debit | — |
| **2110** | `Accounts.payables` | الموردون (الذمم الدائنة) / Accounts Payable | Liability | Credit | — |
| **2120** | `Accounts.vatOutput` | ضريبة القيمة المضافة المخرجة / Output VAT (Payable) | Liability | Credit | — |
| **3100** | `Accounts.openingEquity` | رأس المال الافتتاحي / Opening Balance Equity | Equity | Credit | — |
| **4100** | `Accounts.salesRevenue` | إيرادات المبيعات / Sales Revenue | Revenue | Credit | — |
| **4900** | `Accounts.otherIncome` | إيرادات أخرى / Other Income | Revenue | Credit | — |
| **5100** | `Accounts.cogs` | تكلفة البضاعة المباعة / Cost of Goods Sold (COGS) | Expense | Debit | — |
| **5200** | `Accounts.inventoryAdjustments` | تسويات وفروقات المخزون / Inventory Adjustments | Expense | Debit | — |
| **6100** | `Accounts.operatingExpenses` | المصروفات التشغيلية / Operating Expenses | Expense | Debit | — |

*Source Reference:* `lib/services/accounting/ledger.dart:24-63`.

---

## 2. General Ledger Architecture & Processing Lifecycle

### 2.1 Derived, Immutable Pipeline
1. **Derivation Rule:** The general ledger is strictly transient and derived in-memory on demand via `LedgerBuilder.build(LedgerInput)` (`ledger.dart:156-225`). No journal entries are persisted to SQLite tables.
2. **Exclusion Rule:** Drafts (`DocumentStatus.draft`), quotations, custom templates, and cancelled documents (`DocumentStatus.cancelled`) are filtered out at ingress (`ledger.dart:160-165`). They generate zero initial journal lines.
3. **Deterministic Chronological Sorting:** Entries are stably sorted by `JournalEntry.date`. Entries occurring on the identical millisecond timestamp preserve structural execution order: Parent Document $\to$ Document Settlements $\to$ Inventory Replay / COGS (`ledger.dart:219-224`).

---

## 3. Document Posting Rules

### 3.1 Sales Invoices (`Document.type == 'invoice'`)
*Source Reference:* `lib/services/accounting/ledger.dart:227-240`

- **Date Taken:** `Document.date`
- **Reference Format:** `Document.documentNumber` (e.g. `INV-0001`)
- **Accounts & Amounts:**
  - Net Revenue: $\text{net} = \text{Document.total} - \text{Document.taxAmount}$
  - Debit: `Accounts.receivables` (1130) with `Document.total`
  - Credit: `Accounts.salesRevenue` (4100) with $\text{net}$ (omitted if $\le 10^{-9}$)
  - Credit: `Accounts.vatOutput` (2120) with `Document.taxAmount` (omitted if $\le 10^{-9}$)

```
Example 1: Sales Invoice of 1,150 SDG (1,000 net + 150 VAT, Credit Sale)
  Dr 1130 Accounts Receivable          1,150.00
      Cr 4100 Sales Revenue                     1,000.00
      Cr 2120 Output VAT                          150.00
```

---

### 3.2 Invoice & Purchase Settlements (`_payments` and `_settlement`)
*Source Reference:* `lib/services/accounting/ledger.dart:248-295`

- **Deduplication Priority:**
  1. Payments covered by active linked payment receipts / expense vouchers (`linkedPaid`) are skipped to prevent double counting (`ledger.dart:170-184`).
  2. Remaining unlinked payment records (`DocumentPayment`) are sorted by payment date and posted up to $\text{Document.paid} - \text{linkedPaid}$.
  3. Any residual amount documented in `Document.paid` without a corresponding payment row (historical legacy data) posts on `Document.date` using `Document.paymentMethod`.
- **Sales Invoice Settlement:**
  - Debit: `Accounts.forPaymentMethod(method)` (1110 Cash or 1120 Bank)
  - Credit: `Accounts.receivables` (1130)
- **Purchase Invoice Settlement:**
  - Debit: `Accounts.payables` (2110)
  - Credit: `Accounts.forPaymentMethod(method)` (1110 Cash or 1120 Bank)

```
Example 2: Cash payment of 500 SDG made on invoice INV-0001
  Dr 1110 Cash on Hand                   500.00
      Cr 1130 Accounts Receivable                 500.00
```

---

### 3.3 Purchase Invoices (`Document.type == 'purchase'`)
*Source Reference:* `lib/services/accounting/ledger.dart:297-322`

- **Date Taken:** `Document.date`
- **Reference Format:** `Document.documentNumber` (e.g. `PUR-0001`)
- **Stocked vs Expensed Allocation:**
  - For each line item: if `item.productId != null` and product type is `Product.typeProduct`, its net share is classified as **Stocked**; otherwise, it is classified as **Expensed** (services, office supplies, non-stocked line items) (`ledger.dart:417-425`).
  - Allocated item net: $\text{allocatedNet} = \frac{\text{item.total}}{\text{subtotal}} \times (\text{total} - \text{taxAmount})$.
- **Accounts & Amounts:**
  - Debit: `Accounts.inventory` (1140) with $\sum \text{allocatedNet}_{\text{stocked}}$
  - Debit: `Accounts.operatingExpenses` (6100) with $\sum \text{allocatedNet}_{\text{expensed}}$
  - Debit: `Accounts.vatInput` (1150) with `Document.taxAmount`
  - Credit: `Accounts.payables` (2110) with `Document.total`

```
Example 3: Purchase invoice of 1,200 SDG (800 stocked goods, 200 delivery service expense, 200 VAT)
  Dr 1140 Merchandise Inventory          800.00
  Dr 6100 Operating Expenses             200.00
  Dr 1150 Input VAT                      200.00
      Cr 2110 Accounts Payable                  1,200.00
```

---

### 3.4 Payment Receipts (`Document.type == 'payment_receipt'`)
*Source Reference:* `lib/services/accounting/ledger.dart:324-367`

- **Date Taken:** `Document.date`
- **Reference Format:** `Document.documentNumber` (e.g. `REC-0001`)
- **Debit Account:** `Accounts.forPaymentMethod(d.paymentMethod)` (1110 Cash or 1120 Bank)
- **Credit Account Logic:**
  1. **Active Parent Invoice:** If `relatedDocumentId` references an active, non-cancelled invoice, credits `Accounts.receivables` (1130).
  2. **Cancelled or Draft Parent Invoice:** If parent invoice was cancelled or is draft, the collected cash represents customer funds held on account. Credits `Accounts.payables` (2110) (Customer Credit / Advance Liability).
  3. **Standalone / Unlinked Receipt:** If `relatedDocumentId == null`, credits `Accounts.otherIncome` (4900).

```
Example 4: Standalone receipt of 300 SDG received via Bank Transfer
  Dr 1120 Bank & E-Wallets               300.00
      Cr 4900 Other Income                        300.00

Example 5: Receipt of 400 SDG linked to cancelled invoice INV-0099
  Dr 1110 Cash on Hand                   400.00
      Cr 2110 Accounts Payable (Customer Advance) 400.00
```

---

### 3.5 Expense Vouchers (`Document.type == 'expense_voucher'`)
*Source Reference:* `lib/services/accounting/ledger.dart:369-415`

- **Date Taken:** `Document.date`
- **Reference Format:** `Document.documentNumber` (e.g. `VCH-0001`)
- **Credit Account:** `Accounts.forPaymentMethod(d.paymentMethod)` (1110 Cash or 1120 Bank)
- **Debit Account Logic:**
  1. **Active Parent Purchase:** If `relatedDocumentId` references an active purchase, debits `Accounts.payables` (2110).
  2. **Cancelled or Draft Parent Purchase:** If parent purchase was cancelled or draft, the paid cash represents supplier advance recoverable. Debits `Accounts.receivables` (1130) (Supplier Advance / Refund Receivable).
  3. **Standalone / General Expense Voucher:** If `relatedDocumentId == null`, debits `Accounts.operatingExpenses` (6100).

```
Example 6: General operating expense voucher of 150 SDG paid in Cash
  Dr 6100 Operating Expenses             150.00
      Cr 1110 Cash on Hand                        150.00

Example 7: Voucher of 250 SDG linked to cancelled purchase PUR-0088
  Dr 1130 Accounts Receivable (Supplier Advance) 250.00
      Cr 1110 Cash on Hand                        250.00
```

---

## 4. Perpetual Inventory Replay & Cost of Goods Sold (IAS 2)

*Source Reference:* `lib/services/accounting/ledger.dart:427-646`

Inventory accounting is handled via a **perpetual weighted-average running replay** across chronological stock events (`_StockEvent`):

```
Stock Inflow (+qty):
  - Purchases (from DocumentItems of active purchases)
  - Opening stock (from stock_movements where type == 'opening')
  - Stock cancellations / returns (from stock_movements where type == 'cancellation' and qty > 0)
  - Unexplained legacy stock (synthesized before product's first event)

Stock Outflow (-qty):
  - Sales (from DocumentItems of active sales invoices)

Adjustments (+/- qty):
  - Physical stock adjustments (from stock_movements where type == 'adjustment')
```

### 4.1 Running Weighted-Average Cost Resolution
For any event $e$ on product $p$ (`ledger.dart:553-568`):
$$\text{resolvedAvg} = \begin{cases}
\frac{\text{runningValue}}{\text{runningQty}} & \text{if } \text{runningQty} > 10^{-9} \text{ and } \text{runningValue} > 10^{-9} \\
e.\text{unitCost} & \text{else if } e.\text{unitCost} > 0 \\
p.\text{averageCost} & \text{else if } p.\text{costStatus} == \text{'known'} \text{ and } p.\text{averageCost} > 0 \\
p.\text{purchasePrice} & \text{else if } \text{productPricesApply} \text{ and } p.\text{purchasePrice} > 0 \\
0.0 & \text{otherwise}
\end{cases}$$

### 4.2 Inflow Posting: Opening Balance Equity
- **Trigger:** Recorded opening stock movement (`type == 'opening'`) or synthesized unexplained historical balance.
- **Posting:**
  - Debit: `Accounts.inventory` (1140) with $\text{cost} = \text{quantity} \times \text{unitCost}$
  - Credit: `Accounts.openingEquity` (3100) with $\text{cost}$
- *Source Reference:* `ledger.dart:574-588`.

```
Example 8: Opening stock of 50 units @ 20 SDG
  Dr 1140 Merchandise Inventory        1,000.00
      Cr 3100 Opening Balance Equity            1,000.00
```

### 4.3 Outflow Posting: Cost of Sales (COGS)
- **Trigger:** Active Sales Invoice with stocked line items.
- **Posting:**
  - Cost allocated: $\text{cost} = \text{effectiveBaseQuantity} \times \text{resolvedAvg}$.
  - Debit: `Accounts.cogs` (5100) with $\text{cost}$
  - Credit: `Accounts.inventory` (1140) with $\text{cost}$
- *Source Reference:* `ledger.dart:633-644`.

```
Example 9: Sale of 10 units with running average cost of 20 SDG
  Dr 5100 Cost of Goods Sold (COGS)      200.00
      Cr 1140 Merchandise Inventory               200.00
```

### 4.4 Stock Adjustment Posting (Gain vs Loss)
- **Trigger:** `StockMovement.type == 'adjustment'` (`ledger.dart:619-632`).
- **Inventory Gain ($\text{quantity} > 0$):**
  - Debit: `Accounts.inventory` (1140) with $\text{cost} = \text{quantity} \times \text{resolvedAvg}$
  - Credit: `Accounts.inventoryAdjustments` (5200) with $\text{cost}$
- **Inventory Loss / Shrinkage ($\text{quantity} < 0$):**
  - Debit: `Accounts.inventoryAdjustments` (5200) with $\text{cost} = |\text{quantity}| \times \text{resolvedAvg}$
  - Credit: `Accounts.inventory` (1140) with $\text{cost}$

```
Example 10: Inventory physical count shortage of 5 units @ 20 SDG
  Dr 5200 Inventory Adjustments          100.00
      Cr 1140 Merchandise Inventory               100.00
```

---

## 5. Discounts & Taxation Mechanics

### 5.1 Line-Level vs Document-Level Discounts
1. **Line-Level Discount:** Deducted at source during line item construction (`item.price * item.quantity`).
2. **Document-Level Discount (`Document.discount`):**
   - In financial statements, sales revenue is recorded **net of all discounts**:
     $$\text{netRevenue} = \text{Document.total} - \text{Document.taxAmount}$$
   - For purchase invoices, discounts reduce the allocated cost basis of inventory:
     $$\text{allocatedNet}_i = \frac{\text{item}_i.\text{total}}{\text{subtotal}} \times (\text{total} - \text{taxAmount})$$
     $$\text{effectiveUnitCost}_i = \frac{\text{allocatedNet}_i}{\text{effectiveBaseQuantity}_i}$$
   - *Source Reference:* `ledger.dart:422-425, 442-446`.

### 5.2 Inclusive vs Exclusive Taxation
1. **Tax Exclusive (Standard):** Line items do not include tax. Subtotal reflects pre-tax amounts. $\text{taxAmount} = \text{round}((\text{subtotal} - \text{discount}) \times \text{taxRate})$.
2. **Tax Inclusive (`pricesIncludeTax == true`):** Line totals include VAT. Document subtotal and tax amounts are back-calculated:
   $$\text{taxAmount} = \text{round}\left(\text{gross} - \frac{\text{gross}}{1 + \text{taxRate}}\right)$$
   Regardless of pricing presentation, the ledger posts the exact pre-tax net to `Accounts.salesRevenue` (4100) / `Accounts.inventory` (1140) and the tax portion to Output VAT (2120) / Input VAT (1150).

---

## 6. Concrete Edge Cases Handled in Engine Code

### 6.1 Uncosted Sales (Missing COGS Disclosure)
- **Problem:** When an item is sold before any purchase or opening cost is established, assigning speculative cost misrepresents books, while omitting the entry hides that cost was unrecorded.
- **Engine Handling:** When $\text{cost} \le 10^{-9}$, an explicit zero-line entry is recorded with `isCostMissing = true` (`ledger.dart:598-615`).
- **Reporting Disclosure:** `IncomeStatement.hasIncompleteCostOfSales` evaluates to `true`, and `trustedGrossProfit` / `trustedNetProfit` return `null` (`ledger.dart:706-712`), forcing disclosure on financial reports.

### 6.2 Cancelled Documents with Active Payments
- **Problem:** A user issues an invoice, records a cash receipt, and later cancels the invoice.
- **Engine Handling:** The receipt remains valid (cash is physically in the till). In `LedgerBuilder._receipt`, the credit destination switches automatically from `Accounts.receivables` to `Accounts.payables` (`ledger.dart:340-345`), representing a liability owed back to the customer.

### 6.3 Negative Stock Replay & Overselling
- **Problem:** Goods are sold before the purchase invoice is formally keyed into the system.
- **Engine Handling:** The running replay allows quantity to drop below zero. When a purchase subsequently arrives at a later timestamp, the incoming cost re-evaluates the running valuation without breaking mathematical continuity (`ledger.dart:543-570`).

### 6.4 Cross-Currency Product Price Isolation
- **Rule:** When generating books for an active currency, catalog prices are only referenced if `LedgerInput.productPricesApply` is `true`. If the product belongs to a different currency context, unpriced inventory is costed at zero to prevent cross-currency distortion (`ledger.dart:141-145, 513-528`).

---

## 7. Codebase Audit Clarifications (Backbone Foundation)

### 7.1 Returns & Credit Notes Audit
- **Question:** Are there return / credit-note document entities?
- **Finding:** No. The database schema and model enum only support 5 document types: `invoice`, `purchase`, `quotation`, `payment_receipt`, and `expense_voucher`. Returns are handled exclusively through:
  1. Document cancellation (`cancelDocument` or `cancelDocumentWithSettlementDialog`) with reason tracking in `audit_log`.
  2. Inventory adjustments with appropriate reason codes (e.g. `damage_loss`, `entry_correction`).

### 7.2 Document Hard Deletion vs Cancellation
- **Question:** Can issued documents be hard-deleted given that `stock_movements` has `ON DELETE SET NULL`?
- **Finding:** 
  1. Documents with any payment history (`paid > 0` or rows in `document_payments`) cannot be hard-deleted; `DatabaseHelper.deleteDocument` explicitly throws `StateError`, requiring cancellation instead.
  2. Documents with active linked receipts or expense vouchers cannot be hard-deleted.
  3. Unpaid issued documents can be hard-deleted only if stock reversal is valid (stock available). In that case, `deleteDocument` explicitly issues `DELETE FROM stock_movements WHERE reference_document_id = ?` within the transaction before deleting the document row, preventing orphaned movements.
  4. With the introduction of the immutable journal, hard-deleting an issued document that has journal entries is strictly prohibited or must require append-only cancellation reversal.

### 7.3 Real-World Document Lifecycle Behaviors
- **Purchase Payments:** Recording a payment on a purchase automatically creates a linked `expense_voucher` document and an insert into `document_payments` with `payment_origin = 'receipt'` and `receipt_document_id = voucher.id`.
- **Receipts:** Standalone receipts credit `4900 (Other Income)`. Receipts linked to cancelled invoices credit `2110 (Accounts Payable / Customer Advance)`. Receipts linked to active invoices credit `1130 (Accounts Receivable)`.
- **Vouchers:** Standalone vouchers debit `6100 (Operating Expenses)`. Vouchers linked to cancelled purchases debit `1130 (Accounts Receivable / Supplier Advance)`. Vouchers linked to active purchases debit `2110 (Accounts Payable)`.
- **Cancellations:** In the derived ledger, cancelled documents are omitted from the query. In the persisted double-entry journal, cancellations post an explicit reversal entry dated at the original entry's effective date (`posted_at` set to current timestamp, `reverses_entry_id` pointing to the original entry), ensuring period parity with the derived reports.
- **Opening Balances:** Currently represented in inventory by `StockMovement.typeOpening` (and pre-movement unexplained stock), posting Dr 1140 / Cr 3100.

