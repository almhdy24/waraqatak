# Repro Test Writer (A1) Agent Log

**Role:** Repro Test Writer  
**Branch:** `fix/audit-remediation`  

---

### Phase 1: Red Tests Summary & Handoff Report

All 12 Accounting findings and 5 Widget UI findings now have dedicated failing regression tests in `test/regression/` and `test/widgets/`.

#### 1. Accounting Regression Tests (`test/regression/`):
- `audit_acc_01_test.dart`: Fails due to duplicate `JE-PAY` posting and shifted payment date when an invoice with payments is edited.
- `audit_acc_02_test.dart`: Fails because tax-inclusive purchases record gross unit cost in the stock ledger rather than net cost, resulting in depleted Account 1140 and inflated COGS.
- `audit_acc_03_test.dart`: Fails because standalone expense vouchers are omitted from `getPeriodSummary` and `getPaymentReport`.
- `audit_acc_04_test.dart`: Fails because zero-total invoices skip COGS & inventory reduction in GL due to early guard.
- `audit_acc_05_test.dart`: Fails because customer statements drop unallocated payment receipts in the modern path.
- `audit_acc_06_test.dart`: Fails because `deleteDocument` checks `document_id` instead of `receipt_document_id` on vouchers, crashing SQLite on foreign key constraint.
- `audit_acc_07_test.dart`: Fails because shadow posting savepoint exceptions are swallowed and silently disable journal reports.
- `audit_acc_08_test.dart`: Fails because stock adjustment posting hardcodes 2 decimal digits instead of using base currency decimals.
- `audit_acc_09_test.dart`: Fails because standalone payment receipts are credited to Other Income (4900) instead of Customer Advances (2110).
- `audit_acc_10_test.dart`: Fails because manual cost reconciliation updates product average without posting a balancing GL entry to Account 1140.
- `audit_acc_11_test.dart`: Fails because multi-rate tax invoices display global fallback tax rate on PDF.
- `audit_acc_12_test.dart`: Fails because edit quantity reductions restore stock at current average cost instead of sale snapshot cost.

#### 2. UX Widget Tests (`test/widgets/`):
- `audit_ux_01_test.dart`: Fails with RenderFlex overflow in landscape / small viewports (< 550dp) on PIN lock screen.
- `audit_ux_02_test.dart`: Fails because `_editContact` calls `Navigator.pop(context, true)`, prematurely ejecting user from `CustomerDetailScreen`.
- `audit_ux_04_test.dart`: Fails because bulk pricing undo snackbar is immediately overwritten by skipped count snackbar.
- `audit_ux_05_test.dart`: Fails because fixed height `SizedBox(52)` on `HomeScreen` overflows under 1.4x font scaling.
- `audit_ux_07_test.dart`: Fails because record payment sheet lacks in-flight submit lock (`_isSaving = true`).

Every test is bounded by a 30-second timeout.
Production code remains 100% untouched.
Phase 1 is COMPLETE.
