# Release Notes — Waraqatak 1.1.5+19

## Overview
Waraqatak `1.1.5+19` introduces the comprehensive **Accounting Backbone**, replacing "derived-on-the-fly ledger" as the single source of truth with an immutable, persisted double-entry journal system. Every business event (sale, purchase, edit, cancel, delete, payment, receipt, voucher, stock adjustment) is synchronously shadow-posted inside the exact same SQLite transaction. The release establishes an authoritative single stock movement writer (`StockLedger.record`), reason-coded stock adjustments with audit traceability, an accounting period lock (`books_closed_through`) preventing backdated tampering, an 8-point automated reconciliation engine in diagnostics, and hard architectural invariants (INV-14..INV-18).

---

## What's New in 1.1.5+19

### 1. Persisted Immutable Double-Entry Journal (D1, D2, D3)
- **Database Schema v25:** Additive tables `accounts`, `journal_entries`, `journal_lines`, and `app_settings`, plus additive columns on `stock_movements` (`reason`, `target_movement_id`).
- **Mathematical Balance Enforcement:** Integer minor units (`MoneyUtils.toMinorUnits`) guarantee zero floating-point drift. `JournalWriter.write` rejects unbalanced drafts prior to database writes.
- **Strict Immutability & Append-Only Reversals:** Direct updates and deletions of journal entries and lines are strictly barred. Edits and cancellations post paired reversal entries dated to the original transaction date.

### 2. Single Authoritative Stock Writer (D4 & INV-16)
- **`StockLedger.record(txn, ...)`:** Centralized authoritative gatekeeper for physical stock movements and moving average cost calculation.
- **Static Guard Suite:** Guard tests in `test/guards/single_stock_writer_guard_test.dart` statically prevent unauthorized direct inserts into `stock_movements` anywhere across `lib/`.

### 3. Reason-Coded Stock Adjustments (D5)
- Standardized reason taxonomy:
  - `opening_stock` (Dr 1140 / Cr 3100)
  - `count_gain` / `count_loss` (5200)
  - `damage_loss` / `expiry_loss` (5200)
  - `entry_correction` (reverses prior movement without P&L impact)
  - `other` (strictly requires notes)
- Interactive reason selector and note validation integrated into the stock adjustment dialog in `InventoryScreen`.

### 4. Accounting Period Lock (D6 & INV-17)
- **`books_closed_through` Enforcement:** Pre-write transaction gate blocks document issuance, editing, cancellation, deletion, payment, voucher, or stock adjustment dated on or before the close date.
- **UI Management:** Financial Settings screen features an Accounting Period Lock card allowing merchants to set or clear the closed-through date with an explanatory `AppConfirmDialog`.

### 5. Automated 8-Point Continuous Reconciliation Engine (D7)
- Integrated into `DatabaseDiagnosticService` and `DatabaseRepairService` under `DiagnosticCategory.accountingReconciliation`:
  1. Journal Entry Balance Integrity
  2. Total Trial Balance Zero-Sum Integrity
  3. Source Document Net Financial Parity
  4. Inventory Account (1140) vs Stock Movements Valuation Parity
  5. Accounts Receivable (1130) vs Issued Unpaid Invoices Parity
  6. Accounts Payable (2110) vs Issued Unpaid Purchases Parity
  7. Physical Product Stock vs Stock Movements Parity
  8. Orphaned Journal Lines Detection
- All findings are strictly read-only (`requiresManualReview: true`) and never perform automated mutation without user oversight.

### 6. Parity Oracle & Zero-Drift Report Switch (D8 & INV-18)
- Idempotent `JournalBackfillService` migrates historical data with exact minor-unit parity, automatically triggered on startup and after legacy backup restores.
- Report source switch remains **`journal_reports_enabled = false` (OFF)** by default in production code, safeguarding historical report consistency while shadow writing populates the persisted books in the background.

### 7. Hard Architectural Invariants (INV-14..INV-18)
- **INV-14:** Double-Entry Balance Invariance (writes enforce exact minor unit balance).
- **INV-15:** Journal Immutability & Append-Only Corrections.
- **INV-16:** Single Stock Writer Authoritativeness (`StockLedger.record`).
- **INV-17:** Accounting Period Lock Gate (`books_closed_through`).
- **INV-18:** Persisted-to-Derived Parity Invariance (zero tolerance on base monetary accounts).
- Enforced continuously by `test/invariants/accounting_backbone_invariants_test.dart`.

---

## Upgrade & Safety Guarantees
- **Historical Numbers Frozen:** Backfill preserves legacy report figures exactly, flagged with `origin = 'legacy_backfill'`.
- **Zero Schema Destruction:** 100% additive migrations; legacy backups restore cleanly and backfill automatically.
- **Report Stability:** Default report source remains the battle-tested derived ledger until manually switched by the user.
