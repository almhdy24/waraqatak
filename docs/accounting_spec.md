# Waraqatak Accounting & Single-Currency Formal Specification

**System:** Waraqatak (ورقتك) Business Accounting Engine  
**Status:** As-Implemented Formal Specification  
**Architecture:** Offline-First SQLite with Derived Double-Entry General Ledger  

---

## 1. Currency Specification

### 1.1 Invariant: Single Installation Base Currency
1. An installation operates strictly under ONE base currency defined in `businesses.currency_code`.
2. Once any financial document or stock movement is recorded, the base currency is locked permanently (`businesses.currency_locked_at` is stamped). Any subsequent attempt to alter `businesses.currency_code` throws a fatal `StateError`.
3. All new documents created via UI screens (`InvoiceScreen`, `PurchaseScreen`, `QuickSaleScreen`) or service methods (`DocumentService.createDocument`) inherit the business base currency.
4. Database insertion guards (`DatabaseHelper.insertDocument`, `finalizeDraft`, `convertQuotationToInvoice`, `duplicateDocument`) reject any document whose `currency_code` does not match the active base currency.

### 1.2 Legacy Document Invariant
1. Historical documents stored with a non-base currency (e.g. from legacy versions or backup imports) remain strictly immutable snapshots.
2. Legacy documents in non-base currencies are NEVER nominally added to, subtracted from, or converted into the base currency.
3. System diagnostics flag any non-base currency documents as legacy artifacts.

---

## 2. Monetary Math Specification

### 2.1 Precision & Rounding Standard
1. **Half-Up Rounding:** All monetary rounding must follow half-up rounding (round half away from zero) to the canonical scale of the currency (default 2 decimal places, or 0 for zero-decimal currencies).
2. **Epsilon Compensation:** IEEE 754 floating-point under-representation is compensated using a $1\times 10^{-9}$ directional epsilon before executing `roundToDouble()` or `round()`.
3. **Minor Units:** Currency comparisons, remaining balances, and overpayment validations are performed strictly at integer minor-unit scale ($amount \times 10^{\text{precision}}$).
4. **Zero Representation:** Any monetary quantity whose absolute minor-unit value is zero is normalized to positive `0.0`.

### 2.2 Proportional Discount Allocation Standard
1. Document-level discounts are apportioned across line items using the **Hamilton-Hare Largest-Remainder Method** (as implemented in `MoneyUtils.allocateDocumentDiscount`).
2. Exactness guarantee:
   $$\sum_{i=1}^{n} \text{allocatedDiscount}_i = \min(\text{docDiscount}, \text{subtotal}) \quad \text{strictly in minor units}$$
3. Determinism guarantee: Any identical set of line amounts and document discount produces an identical minor-unit distribution across all platforms.

---

## 3. Document Lifecycle & Totals Calculation

### 3.1 Item Calculation
- For each item $i$:
  $$\text{line\_total}_i = \text{round}(\text{quantity}_i \times \text{unit\_price}_i, \text{decimalDigits})$$
  $$\text{effective\_base\_quantity}_i = \text{quantity}_i \times \text{unit\_conversion\_factor}_i$$

### 3.2 Subtotal
$$\text{subtotal} = \text{round}\left(\sum_{i=1}^{n} \text{line\_total}_i, \text{decimalDigits}\right)$$

### 3.3 Tax Calculation
1. **Discount Ratio:**
   $$R = \begin{cases} 
   \frac{\text{subtotal} - \text{discount}}{\text{subtotal}} & \text{if } \text{subtotal} > 0 \\
   0 & \text{otherwise}
   \end{cases}$$
2. **Net Line After Discount:** $\text{netLine}_i = \text{line\_total}_i \times R$.
3. **Line Tax:**
   - Inclusive Mode (`pricesIncludeTax == true`):
     $$\text{tax}_i = \text{netLine}_i \times \frac{\text{rate}_i}{100 + \text{rate}_i}$$
   - Exclusive Mode (`pricesIncludeTax == false`):
     $$\text{tax}_i = \text{netLine}_i \times \frac{\text{rate}_i}{100}$$
4. **Document Tax Amount:**
   $$\text{taxAmount} = \text{round}\left(\sum_{i=1}^{n} \text{tax}_i, \text{decimalDigits}\right)$$

### 3.4 Document Total
- Inclusive Mode:
  $$\text{total} = \text{round}(\text{subtotal} - \text{discount}, \text{decimalDigits})$$
- Exclusive Mode:
  $$\text{total} = \text{round}(\text{subtotal} - \text{discount} + \text{taxAmount}, \text{decimalDigits})$$

### 3.5 Paid, Remaining & Status
1. $\text{paid}$ is clamped such that $0 \le \text{toMinorUnits}(\text{paid}) \le \text{toMinorUnits}(\text{total})$.
2. $\text{remaining} = \text{fromMinorUnits}(\max(0, \text{toMinorUnits}(\text{total}) - \text{toMinorUnits}(\text{paid})))$.
3. Document status:
   - If $\text{paid} = 0 \implies \text{status} = \text{issued}$.
   - If $0 < \text{paid} < \text{total} \implies \text{status} = \text{partially\_paid}$.
   - If $\text{paid} \ge \text{total} \implies \text{status} = \text{paid}$.

---

## 4. Double-Entry General Ledger Specification

### 4.1 Implied Chart of Accounts
```
1110 Cash (Till)                   [Asset]
1120 Bank & E-Wallets              [Asset]
1130 Accounts Receivable           [Asset]
1140 Inventory                     [Asset]
1150 VAT Input                     [Asset]
2110 Accounts Payable              [Liability]
2120 VAT Output                    [Liability]
3100 Opening Balance Equity        [Equity]
4100 Sales Revenue                 [Revenue]
4900 Other Income                  [Revenue]
5100 Cost of Goods Sold (COGS)     [Expense]
5200 Inventory Adjustments         [Expense]
6100 Operating Expenses            [Expense]
```

### 4.2 Derived Journal Posting Rules
1. **Sales Invoice Issued:**
   - $\text{Debit } 1130 \text{ (Receivables)} = \text{total}$
   - $\text{Credit } 4100 \text{ (Sales Revenue)} = \text{total} - \text{taxAmount}$
   - $\text{Credit } 2120 \text{ (VAT Output)} = \text{taxAmount}$
   - If $\text{paid} > 0$:
     - $\text{Debit } 1110 / 1120 \text{ (Cash/Bank)} = \text{paid}$
     - $\text{Credit } 1130 \text{ (Receivables)} = \text{paid}$
2. **Purchase Invoice Issued:**
   - $\text{Debit } 1140 \text{ (Inventory)} / 6100 \text{ (Expense)} = \text{total} - \text{taxAmount}$
   - $\text{Debit } 1150 \text{ (VAT Input)} = \text{taxAmount}$
   - $\text{Credit } 2110 \text{ (Payables)} = \text{total}$
3. **Cost of Goods Sold (Perpetual Moving Weighted-Average):**
   - For every sale item with known cost basis:
     - $\text{Debit } 5100 \text{ (COGS)} = \text{quantity} \times \text{movingAverageUnitCost}$
     - $\text{Credit } 1140 \text{ (Inventory)} = \text{quantity} \times \text{movingAverageUnitCost}$
4. **Stock Adjustments:**
   - Positive adjustment: $\text{Dr } 1140 \text{ (Inventory)} / \text{Cr } 5200 \text{ (Adjustments)}$
   - Negative adjustment: $\text{Dr } 5200 \text{ (Adjustments)} / \text{Cr } 1140 \text{ (Inventory)}$

---

## 5. Core Accounting Identities

Every valid state of the database and reporting layer MUST satisfy:

1. **Invoicing Identity:**
   $$\text{Subtotal} - \text{Discount} + (\text{Tax if exclusive}) = \text{Total}$$
2. **Receivables Identity:**
   $$\text{Total Invoiced} - \text{Total Payments Received} = \text{Outstanding Receivables}$$
3. **Inventory Conservation Identity:**
   $$\text{Stock}_{\text{end}} = \text{Stock}_{\text{start}} + \sum Q_{\text{purchases}} - \sum Q_{\text{sales}} + \sum Q_{\text{adjustments}} + \sum Q_{\text{cancellations}}$$
4. **General Ledger Balance Identity:**
   $$\sum \text{Debits} = \sum \text{Credits} \quad \text{across every journal entry and trial balance}$$
5. **Balance Sheet Fundamental Identity:**
   $$\text{Assets} = \text{Liabilities} + \text{Equity} + \text{Retained Earnings}$$
6. **Customer Statement Identity:**
   $$\text{Closing Balance} = \text{Opening Balance} + \sum \text{Invoiced Charges} - \sum \text{Payment Credits}$$

---

## 6. Data Integrity & Concurrency Guarantees

1. **Transaction Atomicity:** All multi-row updates, document state transitions, and inventory movements MUST execute within `db.transaction(...)`. A crash or battery loss mid-operation rolls back completely with zero orphaned records.
2. **Strict Foreign Keys:** SQLite `PRAGMA foreign_keys = ON` is enforced. Deleting a document cascades cleanly to its line items and payment child rows.
3. **Sequential Document Numbering:** Document counters are locked and incremented within the document insertion transaction, ensuring gapless, strictly monotonic document numbers with zero race conditions.
4. **Snapshot Preservation:** Stored document records and line items are snapshots. Catalog price adjustments, product renaming, or business setting modifications NEVER alter past documents or stock movement costs.
