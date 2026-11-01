# Waraqatak Accounting Backbone Architecture & Technical Design

**System:** Waraqatak (ورقتك) Offline-First Mobile Application  
**Document:** Backbone Technical Architecture & Implementation Plan  
**Status:** Approved for Implementation (Branch `feat/accounting-backbone`)  
**Scope:** Replaces derived-on-the-fly ledger with an immutable, persisted double-entry journal, single stock writer, reason-coded stock adjustments, period lock, and continuous reconciliation.  

---

## 1. Executive Summary & Core Invariants

The Waraqatak Accounting Backbone transitions the core accounting engine from an in-memory derived model (`LedgerBuilder.build`) to an **immutable, persisted double-entry general ledger** written atomically inside the exact SQLite database transaction of every business event.

### Non-Negotiable Invariants:
1. **Historical Immutability:** Existing financial documents, stock movements, historical reports, and database tables remain 100% frozen. No historical row is mutated, recalculated, or deleted.
2. **Double-Entry Balance at Write-Time:** Every journal entry consists of balanced debit and credit lines expressed strictly as **integer minor units** (`MoneyUtils.toMinorUnits`). Unbalanced entries cannot be written to SQLite.
3. **Single Transaction Atomicity:** Journal entries are authored by `PostingService` and `JournalWriter` strictly inside the caller's transaction (`DatabaseExecutor txn`). If any document, stock movement, or posting check fails, the entire transaction rolls back.
4. **Append-Only Corrections:** Journal entries cannot be updated or deleted (`UPDATE` and `DELETE` on journal tables are prohibited outside transaction rollback). Revisions and cancellations post explicit reversing journal entries.
5. **Single Stock Writer:** All insertions into `stock_movements` and updates to `products.stock_quantity` / `products.average_cost` route strictly through `StockLedger.record` (or `StockWriter`), enforcing INV-10..13 and posting inventory entries atomically.
6. **Feature Flag Isolation:** Reports switch from derived ledger to persisted journal strictly behind the setting `journal_reports_enabled` (default `false`). Shadow writing (`journal_shadow_write`, default `true`) writes journal rows transparently.
7. **Period Lock:** Setting `books_closed_through` strictly prevents any creation, modification, cancellation, payment, or adjustment dated on or before the lock date.

---

## 2. Implied Chart of Accounts & Posting Rules Table

Derived from real production logic in `lib/services/accounting/ledger.dart:24-63, 158-646`:

| Account Code | Account Name (EN) | Account Name (AR) | Type | Normal Balance | Posting Context |
|:---|:---|:---|:---|:---|:---|
| **1110** | Cash on Hand | الصندوق (الخزينة) | Asset | Debit | Physical cash in till (`forPaymentMethod == 'cash'`) |
| **1120** | Bank & E-Wallets | البنك والمحافظ | Asset | Debit | Bank accounts, digital wallets, cards (`forPaymentMethod != 'cash'`) |
| **1130** | Accounts Receivable | العملاء (الذمم المدينة) | Asset | Debit | Customer receivables, unlinked supplier advance refunds |
| **1140** | Merchandise Inventory | المخزون السلعي | Asset | Debit | Stored physical stock valued at perpetual moving average cost |
| **1150** | VAT Input (Recoverable) | ضريبة القيمة المضافة المدخلة | Asset | Debit | Recoverable VAT on purchases |
| **2110** | Accounts Payable | الموردون (الذمم الدائنة) | Liability | Credit | Supplier payables, unlinked customer advance liabilities |
| **2120** | VAT Output (Payable) | ضريبة القيمة المضافة المخرجة | Liability | Credit | Collected/payable VAT on sales |
| **3100** | Opening Balance Equity | رأس المال الافتتاحي | Equity | Credit | Equity balancing opening stock entries |
| **4100** | Sales Revenue | إيرادات المبيعات | Revenue | Credit | Operating sales revenue net of tax and discounts |
| **4900** | Other Income | إيرادات أخرى | Revenue | Credit | Standalone unlinked payment receipts |
| **5100** | Cost of Goods Sold (COGS) | تكلفة البضاعة المباعة | Expense | Debit | Realized product cost at time of sale |
| **5200** | Inventory Adjustments | تسويات وفروقات المخزون | Expense | Debit | Stock count variance, damage loss, shrinkage |
| **6100** | Operating Expenses | المصروفات التشغيلية | Expense | Debit | Unstocked purchases, standalone expense vouchers |

### Authoritative Posting Rules Table (Mapped to Code)

| Event / Document Type | Debit Accounts & Minor Units | Credit Accounts & Minor Units | Effective Date | Source File & Line |
|:---|:---|:---|:---|:---|
| **Sales Invoice Issued** (`invoice`) | `1130` (Receivables) = `doc.total` | `4100` (Sales Revenue) = `doc.total - doc.taxAmount`<br>`2120` (VAT Output) = `doc.taxAmount` | `doc.date` | `ledger.dart:227-240` |
| **Invoice Upfront Payment** (at issue) | `1110` / `1120` (Cash/Bank) = `doc.paid` | `1130` (Receivables) = `doc.paid` | `doc.date` | `ledger.dart:248-288` |
| **Cost of Goods Sold** (per sale line) | `5100` (COGS) = `item.quantity * item.unitCost` | `1140` (Inventory) = `item.quantity * item.unitCost` | `doc.date` | `ledger.dart:633-644` |
| **Purchase Issued** (`purchase`) | `1140` (Inventory) = `sum(stockedNet)`<br>`6100` (Expenses) = `sum(expensedNet)`<br>`1150` (VAT Input) = `doc.taxAmount` | `2110` (Payables) = `doc.total` | `doc.date` | `ledger.dart:297-322` |
| **Purchase Upfront Payment** (at issue) | `2110` (Payables) = `doc.paid` | `1110` / `1120` (Cash/Bank) = `doc.paid` | `doc.date` | `ledger.dart:248-288` |
| **Payment Receipt** (Active Invoice) | `1110` / `1120` (Cash/Bank) = `payment.amount` | `1130` (Receivables) = `payment.amount` | `payment.date` | `ledger.dart:324-345` |
| **Payment Receipt** (Cancelled Invoice) | `1110` / `1120` (Cash/Bank) = `receipt.total` | `2110` (Payables / Customer Advance) = `receipt.total` | `receipt.date` | `ledger.dart:338-344` |
| **Payment Receipt** (Standalone / Other) | `1110` / `1120` (Cash/Bank) = `receipt.total` | `4900` (Other Income) = `receipt.total` | `receipt.date` | `ledger.dart:342-362` |
| **Expense Voucher** (Active Purchase) | `2110` (Payables) = `voucher.total` | `1110` / `1120` (Cash/Bank) = `voucher.total` | `voucher.date` | `ledger.dart:384-386` |
| **Expense Voucher** (Cancelled Purchase) | `1130` (Receivables / Supplier Advance) = `voucher.total` | `1110` / `1120` (Cash/Bank) = `voucher.total` | `voucher.date` | `ledger.dart:386-389` |
| **Expense Voucher** (Standalone / Expense) | `6100` (Operating Expenses) = `voucher.total` | `1110` / `1120` (Cash/Bank) = `voucher.total` | `voucher.date` | `ledger.dart:390-410` |
| **Stock Opening Balance** | `1140` (Inventory) = `quantity * unitCost` | `3100` (Opening Equity) = `quantity * unitCost` | `movement.date` | `ledger.dart:574-582` |
| **Stock Count Gain** (`count_gain`) | `1140` (Inventory) = `quantity * avgCost` | `5200` (Adjustments) = `quantity * avgCost` | `movement.date` | `ledger.dart:620-624` |
| **Stock Count Loss** (`count_loss`, `damage`, `expiry`) | `5200` (Adjustments) = `abs(quantity) * avgCost` | `1140` (Inventory) = `abs(quantity) * avgCost` | `movement.date` | `ledger.dart:625-628` |
| **Stock Adjustment** (`entry_correction`) | Reversal of referenced movement/document inventory and offset accounts | Reversal offset accounts | `movement.date` | D5 Design Requirement |
| **Document Revised** (Non-metadata) | Reversal of prior entries for doc + New entries with incremented revision | Reciprocal of prior lines + New lines | `doc.date` | D2 Design Requirement |
| **Document Cancelled** | Exact opposite of original entry lines | Reciprocal of original lines | `original.effective_date` (posted_at: `now`) | D3 Design Requirement |

---

## 3. Event Catalogue & Single Stock Writer Routing

### 3.1 Event Catalogue
The `PostingService` accepts strongly typed domain events:
1. `DocumentIssuedEvent(Document doc, List<DocumentItem> items, List<DocumentPayment> payments)`
2. `DocumentRevisedEvent(Document oldDoc, Document newDoc, List<DocumentItem> newItems, List<DocumentPayment> newPayments, bool isMetadataOnly)`
3. `DocumentCancelledEvent(Document doc)`
4. `PaymentRecordedEvent(DocumentPayment payment, Document parentDoc, Document? receiptDoc)`
5. `PaymentCancelledEvent(DocumentPayment payment, Document parentDoc, int receiptId)`
6. `StockAdjustedEvent(StockMovement movement, String reason, int? targetMovementId)`
7. `StocktakeAppliedEvent(StocktakeSession session, List<StockMovement> movements)`
8. `OpeningStockRecordedEvent(StockMovement movement)`

### 3.2 Inventory Writer Routing (All Calls Route to `StockLedger`)
Currently, stock writes occur in:
1. `DatabaseHelper.insertDocumentWithItems` (lines 2828, 2869, 2916):
   - Sale: decrements `products.stock_quantity`, inserts `stock_movements` (type: sale).
   - Purchase: increments `products.stock_quantity`, recalculates `average_cost`, inserts `stock_movements` (type: purchase).
2. `DatabaseHelper._applyDocumentEditStockDeltas` (lines 3050-3300):
   - Calculates line item deltas, adjusts `stock_quantity`, updates `average_cost`, inserts sale/purchase/cancellation movements.
3. `DatabaseHelper.cancelDocument` (lines 4371-4470):
   - Reverts stock, recalculates average cost if purchase, inserts cancellation movements.
4. `DatabaseHelper.deleteDocument` (lines 4114-4170):
   - Reverts stock on hard-deletion of unpaid document, removes movements.
5. `InventoryCostingService.onStockAdjusted` (lines 230-256):
   - Adjusts `stock_quantity`, inserts adjustment movement.
6. `DatabaseHelper.finalizeStocktakeSession` (lines 6512-6533):
   - Adjusts `stock_quantity`, inserts adjustment movement with provenance `stocktake`.
7. `DatabaseRepairService.repairDuplicatePurchaseMovement` (lines 1398-1455):
   - Inserts neutralizing movement or marks neutralized.

**Routing Architecture:**
All the above calls will delegate to `StockLedger.record(txn, ...)`:
- Validates INV-10 (document net parity) and INV-11 (physical balance integrity).
- Atomically updates `products.stock_quantity` and `products.average_cost`.
- Inserts `stock_movements` with optional `reason` column.
- Automatically invokes `PostingService` to record corresponding journal entries in the caller's transaction.

---

## 4. Database Schema, Migrations & Backup Plan

### 4.1 New Tables (Additive, DB Version Bump: 18 -> 19)

```sql
-- Chart of accounts
CREATE TABLE accounts (
  code TEXT PRIMARY KEY,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  type TEXT NOT NULL,
  normal_side TEXT NOT NULL,
  is_system INTEGER NOT NULL DEFAULT 1
);

-- Immutable journal headers
CREATE TABLE journal_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_no TEXT NOT NULL UNIQUE,
  effective_date TEXT NOT NULL,
  posted_at TEXT NOT NULL,
  source_type TEXT NOT NULL,
  source_id INTEGER,
  revision INTEGER NOT NULL DEFAULT 1,
  memo TEXT,
  reverses_entry_id INTEGER REFERENCES journal_entries(id),
  origin TEXT NOT NULL DEFAULT 'live'
);

CREATE INDEX idx_journal_entries_date ON journal_entries(effective_date);
CREATE INDEX idx_journal_entries_source ON journal_entries(source_type, source_id);
CREATE INDEX idx_journal_entries_origin ON journal_entries(origin);

-- Immutable journal lines (balanced integer minor units)
CREATE TABLE journal_lines (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_id INTEGER NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
  account_code TEXT NOT NULL REFERENCES accounts(code),
  debit_minor INTEGER NOT NULL DEFAULT 0,
  credit_minor INTEGER NOT NULL DEFAULT 0,
  product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
  contact_id INTEGER REFERENCES contacts(id) ON DELETE SET NULL
);

CREATE INDEX idx_journal_lines_entry ON journal_lines(entry_id);
CREATE INDEX idx_journal_lines_account ON journal_lines(account_code);
CREATE INDEX idx_journal_lines_product ON journal_lines(product_id);
CREATE INDEX idx_journal_lines_contact ON journal_lines(contact_id);

-- Additive column to stock_movements
ALTER TABLE stock_movements ADD COLUMN reason TEXT;
ALTER TABLE stock_movements ADD COLUMN target_movement_id INTEGER REFERENCES stock_movements(id);
```

### 4.2 Settings Rows
- `journal_shadow_write`: `'true'` (default ON, shadow writes to journal).
- `journal_reports_enabled`: `'false'` (default OFF, guarded report switch).
- `books_closed_through`: `null` (period lock date, `YYYY-MM-DD`).

### 4.3 Backup & Restore Strategy
- **BackupService Export:** Includes `accounts`, `journal_entries`, and `journal_lines` in backup JSON.
- **BackupService Restore:**
  - If backup contains journal tables (new backup): restores them directly, sanitizing schema against active columns.
  - If backup does NOT contain journal tables (old legacy backup): restores old tables, initializes accounts, and triggers the idempotent backfill asynchronously on restore completion.
  - Verifies continuous parity after restore.

---

## 5. Parity Oracle, Reconciliation & Risk Rollback Plan

### 5.1 Parity Oracle (`LedgerBuilder` Reference)
`LedgerBuilder` remains in the codebase as the reference specification.
- Zero tolerance (0 minor unit difference) on:
  - `1110` (Cash)
  - `1120` (Bank)
  - `1130` (Receivables)
  - `2110` (Payables)
  - `2120` (VAT Output)
  - `1150` (VAT Input)
  - `4100` (Sales Revenue)
- Parity report tracks any minor unit rounding difference on COGS / inventory adjustments.
- Foreign-currency documents are isolated from base journal exactly as in `LedgerService.load`.

### 5.2 Continuous Reconciliation Service
Exposes read-only checks to `DatabaseDiagnosticService` and invariant tests:
1. Every journal entry balances (`sum(debit_minor) == sum(credit_minor)`).
2. Overall journal balances.
3. Inventory balance per journal (`1140`) equals inventory valuation from `stock_movements`.
4. Accounts receivable (`1130`) equals sum of remaining balance on active issued sales invoices.
5. Accounts payable (`2110`) equals sum of remaining balance on active issued purchase invoices.
6. `products.stock_quantity` equals sum of movements in `stock_movements` (INV-11).
7. Zero orphan journal lines or entries.
8. Persisted journal vs. Derived ledger parity status.

### 5.3 Risks & Rollback Plan
- **Risk:** Database write performance overhead in low-RAM Termux.  
  *Mitigation:* Single transaction with batch line insertions and indexed foreign keys.
- **Risk:** Edge-case mismatch during backfill on historical databases.  
  *Mitigation:* Backfill runs in a single transaction; if parity check fails, the transaction is completely rolled back, leaving zero journal rows, recording diagnostic findings, and leaving the app running on the derived ledger without data corruption.
- **Risk:** Accidental modification of existing reports.  
  *Mitigation:* `journal_reports_enabled` flag defaults to `false`. Reports only read journal tables when the user explicitly flips the switch in Database Diagnostics after parity verification passes.
