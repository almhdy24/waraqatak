# Release Notes — Waraqatak 1.1.5-beta+18

## Overview
Waraqatak `1.1.5-beta+18` resolves persistent SnackBars with a centralized auto-dismissing notification system featuring a Telegram-style animated circular countdown, fixes double stock movements when purchase invoices are edited with atomic stock delta calculations, establishes structural architectural invariants (INV-10..INV-13), introduces diagnostic reconciliation detection with a guided safe repair tool (Option A and Option B) reachable from the diagnostic UI with automatic safety backups, and documents the canonical double-entry accounting posting rules specification.

---

## What's New & Fixed

### 1. Centralized 5-Second SnackBar with Animated Countdown (Part 1)
- **Unified Implementation:** Created central `AppSnackBar.show(...)` helper in `lib/widgets/app_snackbar.dart`, replacing all raw `ScaffoldMessenger.showSnackBar` call sites across the application.
- **Telegram-Style Visual Countdown:** When an action button (e.g., Undo) is present, an animated circular progress countdown runs smoothly alongside the action label over the 5-second duration.
- **Accessible & RTL-Safe:** If `MediaQuery.accessibleNavigation` is enabled, the duration automatically extends to 10 seconds. Layout respects RTL Arabic typography and meets accessible touch target requirements (>= 48dp).
- **Robust Dismissal:** Implemented an independent fallback timer (`duration + 300ms`) ensuring SnackBars never get stuck indefinitely even if standard controller callbacks stall. Action callbacks (such as Undo) execute strictly once on tap and immediately dismiss the notification.

### 2. Purchase Edit Double Movement Bug Fix (Part 2)
- **Root Cause Eliminated:** Replaced flawed purchase edit stock logic with atomic delta calculations in `DatabaseHelper._applyDocumentEditStockDeltas`. Metadata edits (supplier, notes, dates, payment methods) now produce exactly zero stock movements.
- **Quantity Edits & Moving Average:** Quantity increases record only the positive delta movement and recalculate moving average cost. Quantity decreases record compensating cancellation movements and validate available stock.
- **Draft & Status Transitions:** Transitioning from draft to issued correctly generates initial stock movements; identical edits are strictly idempotent.

### 3. Hard Invariants Extended (INV-10..INV-13)
- **INV-10:** Document edit stock movement delta calculation must reside strictly in `DatabaseHelper._applyDocumentEditStockDeltas`.
- **INV-11:** Metadata-only document edits must produce zero stock movements.
- **INV-12:** Total net movements for any document must equal the sum of its non-draft line item quantities.
- **INV-13:** Historical document stock repair operations must require explicit confirmation tokens and create automatic safety backups without hard-deleting audit rows.
- Architectural guard tests in `test/guards/architecture_guards_test.dart` and integrity tests in `test/accounting/purchase_edit_integrity_test.dart` enforce these invariants continuously.

### 4. Reconciliation Diagnostics & Guided Safe Repair Tool
- **Diagnostic Detection:** Added checks for `document_movement_mismatch` and `ledger_movement_inventory_mismatch` in `DatabaseDiagnosticService` to identify documents affected by historical duplicate edit movements.
- **Never-Automatic Execution:** Repair logic is strictly barred from running automatically on app startup, database migrations, or background tasks.
- **Dual Repair Semantics:**
  - **Option A (Compensating Cancellation):** Records a compensating cancellation movement (`-surplus`), decrements physical stock, and explicitly informs the user if a P&L loss is recorded on Account 5200.
  - **Option B (Neutralize Duplicate & Adjustment):** Pairs the duplicate purchase movement with an existing user adjustment and marks both as `neutralized`, eliminating phantom P&L losses and restoring true inventory balance without deleting audit rows.
- **UI Reachability:** Reachable directly from `DatabaseDiagnosticScreen` manual review guidance. Users can preview exact affected movement rows, select between Option A and Option B, confirm through `AppConfirmDialog`, execute within an SQLite transaction with an automatic pre-repair backup, and receive immediate snackbar feedback.

### 5. Canonical Double-Entry Accounting Specification (Part 3)
- Published `docs/accounting_spec_addendum.md` specifying canonical posting rules, journal entries, T-accounts, and ledger event flows across:
  - Standard credit and cash invoices (Accounts 1110, 1120, 4100, 5100, 1140).
  - Purchase invoices (Accounts 1140, 2110, 1110).
  - Customer payments and supplier payments (Accounts 1110, 1120, 2110).
  - General and operational expense vouchers (Accounts 5300, 1110).
  - Manual inventory adjustments and stocktake reconciliation variances.

---

## What Did NOT Change
- **Signing & Application ID:** `com.elmahdi.waraqatak` and release keystore configuration remain strictly untouched.
- **Database Schema:** Zero table drops, zero column removals, zero destructive updates, zero DB version bump (v23 preserved).
- **Historical Financial Records:** Stored documents, payments, and movements remain immutable snapshots; historical data is never modified automatically.
- **Play Compliance:** Privacy policy, terms, and third-party dependency compliance fully verified via `tool/check_play_compliance.sh`.

---

## Upgrade Notes
- Fully compatible with the current live API (`api.almhdy24.com`).
- Offline-first capabilities remain 100% operational without network connectivity.
