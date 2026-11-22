# Waraqatak Remediation Tracker: Audit ACC-01..12 & UX-01..24

**Branch:** `fix/audit-remediation`  
**Coordinator:** Remediation Coordinator (Orchestrator)  
**Last Updated:** November 21, 2026  
**Status:** Phase 0 (Baseline & Triage)  

---

## A) Status Board

| ID | Title | Severity | Phase | Owner Agent | Status | Verified | Test File | Commit | Reviewer Verdict | Notes |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| **ACC-01** | Duplicate Payment Posting on Document Edit | Critical | Phase 2 | A2 (posting-engine) | Done | Confirmed | `test/regression/audit_acc_01_test.dart` | `6cba2b8` | APPROVE | Post upfront payments only if genuine unbacked upfront payment exists; reverseLinkedPayments: false on edit preserves standalone payments |
| **ACC-02** | Tax-Inclusive Purchases Record Gross Unit Cost in Stock Ledger vs. Net in GL | Critical | Phase 3 | A3 (inventory-costing) | Done | Confirmed | `test/regression/audit_acc_02_test.dart` | `e414292` | APPROVE | Stripped recoverable VAT from unitCost before recording into StockLedger; net unit cost stored in stock_movements |
| **ACC-03** | Standalone Expense Vouchers Omitted from Dashboard & Payments Report | Critical | Phase 4 | A4 (reporting-integrity) | Done | Confirmed | `test/regression/audit_acc_03_test.dart` | `e781950` | APPROVE | Standalone vouchers included via UNION ALL in getPaymentReport and 2b in getPeriodSummary without double-counting |
| **ACC-04** | Zero-Total Invoices Bypass COGS & Inventory Reduction in GL | High | Phase 2 | A2 (posting-engine) | Done | Confirmed | `test/regression/audit_acc_04_test.dart` | `66ab987` | APPROVE | Decoupled COGS loop from totalMinor <= 0 guard; COGS and inventory posted correctly for zero-total invoices |
| **ACC-05** | Customer Statements Drop Unallocated Receipts & Advances | High | Phase 4 | A4 (reporting-integrity) | Red-test | Confirmed | `test/regression/audit_acc_05_test.dart` | - | - | Modern path iterates invoices only; unallocated receipts excluded |
| **ACC-06** | Hard Deletion of Allocated Vouchers Crashes SQLite Foreign Key Constraint | High | Phase 4 | A4 (reporting-integrity) | Red-test | Confirmed | `test/regression/audit_acc_06_test.dart` | - | - | Checked `document_id` instead of `receipt_document_id` before deleting |
| **ACC-07** | Silent Shadow-Posting Failure Swallows Errors and Disables Reports | High | Phase 2 | A2 (posting-engine) | Done | Confirmed | `test/regression/audit_acc_07_test.dart` | `f404195` | APPROVE | Shadow errors now rethrow when journal_reports_enabled=true; fallback preserved when false |
| **ACC-08** | Hardcoded 2 Decimals in Stock Adjustments Shadow Posting | Medium | Phase 2 | A2 (posting-engine) | Done | Confirmed | `test/regression/audit_acc_08_test.dart` | `e9a6078` | APPROVE | Dynamic currency decimal lookup added to StockLedger.record and ISO 4217 lookup to Currency.decimalDigitsForCode |
| **ACC-09** | Standalone Payment Receipts Credited to Other Income (4900) | Medium | Phase 2 | A2 (posting-engine) | Done (Posting Closed) | Confirmed | `test/regression/audit_acc_09_test.dart` | `77da0fc` | APPROVE | Credit Account 2130 (Customer Deposits) with contactId; full lifecycle settlement tracked in CUSTOMER-ADVANCE-ALLOCATION |
| **ACC-10** | Manual Cost Reconciliation Leaves Inventory Account Distorted Without GL Entry | Medium | Phase 3 | A3 (inventory-costing) | Done | Confirmed | `test/regression/audit_acc_10_test.dart` | `5cbd21c` | APPROVE | Post Dr 1140 (Inventory) / Cr 3100 (Opening Equity) in JournalWriter for positive reconciled stock |
| **ACC-11** | Multi-Rate Tax Invoice Displays Global Fallback Tax Rate on PDF | Low | Phase 4 | A4 (reporting-integrity) | Red-test | Confirmed | `test/regression/audit_acc_11_test.dart` | - | - | Misleading single tax rate shown on document totals for mixed-rate invoices |
| **ACC-12** | Edit Quantity Reduction Restores Stock at Current Average Cost Instead of Sale Snapshot Cost | Low | Phase 3 | A3 (inventory-costing) | Done | Confirmed | `test/regression/audit_acc_12_test.dart` | `9e51552` | APPROVE | Restores stock at original sale snapshot unit cost from oldItems; preserves snapshot unit cost on persisted items |
| **UX-01** | Unscrollable PIN Lock Screen Overflows in Landscape (< 550dp) | Critical | Phase 5 | A6 (ux-critical) | Red-test | Confirmed | `test/widgets/audit_ux_01_test.dart` | - | - | Unscrollable column with spacer and 324dp keypad overflows in landscape |
| **UX-02** | Editing Contact Prematurely Pops Customer Detail Screen Back to List | High | Phase 5 | A6 (ux-critical) | Red-test | Confirmed | `test/widgets/audit_ux_02_test.dart` | - | - | `Navigator.pop(context, true)` in `_editContact` prematurely exits screen |
| **UX-03** | `TextEditingController` Disposed Before Reading Text in Custom Payment Dialog | Medium | Phase 5 | A6 (ux-critical) | Todo | Partially Confirmed | `test/widgets/payment_methods_screen_test.dart` | - | - | Getter `.text` doesn't throw immediate assert in release, but is an unsafe antipattern. Downgraded to Medium |
| **UX-04** | Immediate SnackBar Overwrite Cancels Undo Affordance on Bulk Price Update | High | Phase 5 | A6 (ux-critical) | Red-test | Confirmed | `test/widgets/audit_ux_04_test.dart` | - | - | Second snackbar immediately replaces and dismisses undo snackbar |
| **UX-05** | Fixed Height `SizedBox(52)` Overflows on Accessibility Font Scaling | High | Phase 5 | A6 (ux-critical) | Red-test | Confirmed | `test/widgets/audit_ux_05_test.dart` | - | - | Height 52 overflows when font scale >= 1.3x |
| **UX-06** | "Enter Activation Key" Workflow Lands on Marketing Page With Input Buried at Bottom | High | Phase 5 | A7 (ux-flows) | Todo | Confirmed | Manual verification | - | - | Missing direct route/scroll to activation key input |
| **UX-07** | Record Payment Sheet Lacks In-Flight Double-Submit Lock & Leaks Raw SQLite Exceptions | High | Phase 5 | A7 (ux-flows) | Red-test | Confirmed | `test/widgets/audit_ux_07_test.dart` | - | - | Double-tap creates duplicate payments; raw exception text shown to user |
| **UX-08** | Misleading Price Error on Currency Validation & Hardcoded English Copy | High | Phase 5 | A7 (ux-flows) | Verifying | Confirmed | Manual verification | - | - | Invalid code/name triggers `refErrInvalidPrice`; English helper string |
| **UX-09** | Technical Dart Class Name in Arabic Copy & Unmirrored Back Arrow in AccessDeniedView | Medium | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Leaks class name and uses non-adaptive arrow |
| **UX-10** | Hardcoded `Icons.chevron_right` in Multi-User Screens Points Backward in RTL | Medium | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Should use `Icons.adaptive.chevron_right` or mirror in RTL |
| **UX-11** | Missing `PopScope` Unsaved Dirty Changes Warning Guards on Setup & Pricing Forms | Medium | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | User can accidentally lose typed data |
| **UX-12** | Currency Names Hardcoded to Arabic (`nameAr`) in Dropdowns Ignoring English Locale | Medium | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Hardcoded `nameAr` instead of localized name |
| **UX-13** | Raw Loading, Empty, and Error State Widgets Bypass Standardized Components | Medium | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Standardize on `AppLoadingView`, `AppEmptyState`, `AppErrorState` |
| **UX-14** | Redundant Duplicate Back-to-Back Confirmation Dialogs in Sensitive Operations | Medium | Phase 5 | A7 (ux-flows) | Verifying | Confirmed | Manual verification | - | - | Confirm dialog followed immediately by SensitiveActionGate reauth dialog |
| **UX-15** | Cancellation Dialog Lacks Explanation of Inventory Return & Journal Reversal | Medium | Phase 5 | A7 (ux-flows) | Verifying | Confirmed | Manual verification | - | - | Unpaid document cancel lacks clear impact explanation |
| **UX-16** | Missing `TextInputType.phone` on Contact Phone Field Forces Standard QWERTY | Medium | Phase 5 | A7 (ux-flows) | Verifying | Confirmed | Manual verification | - | - | Phone field should show telephone keypad |
| **UX-17** | Pricing Tier Choice Chips Undersized Below 48x48dp Touch Target (~24dp Height) | Low | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Fails WCAG minimum touch target size |
| **UX-18** | PDF Accent Color Swatch Pickers Undersized at 40x40dp Touch Target | Low | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Swatches should expand to at least 48x48dp |
| **UX-19** | Icon-Only Password Visibility and Dialog Close Buttons Lack Tooltips & Semantics | Low | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Accessibility screen readers cannot announce button purpose |
| **UX-20** | Asymmetric Padding `EdgeInsets.fromLTRB(14, 12, 8, 12)` Ignores RTL Layout Direction | Low | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Should use `EdgeInsetsDirectional.fromSTEB` |
| **UX-21** | Unread Notifications Badge Counter Omitted from Screen Reader Announcement | Low | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Badge number not announced by TalkBack |
| **UX-22** | Missing `textInputAction: TextInputAction.next` Interrupts Form Flow | Low | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Enter key should advance focus to next input field |
| **UX-23** | Financial Metric KPI Values Truncate With Ellipsis Instead of FittedBox Scale-Down | Low | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Numbers like `1,250,00...` destroy legibility |
| **UX-24** | Sticky Bottom Bar Total Amount Lacks FittedBox Scale-Down on Narrow Screens (< 360dp) | Low | Phase 6 | A8 (rtl-a11y-polish) | Verifying | Confirmed | Manual verification | - | - | Scale down text gracefully on 320dp screens |

---

## B) Phase Checklist

### Phase 0: Baseline & Triage
- [x] Create branch `fix/audit-remediation`
- [x] Run `flutter pub get`
- [x] Run `flutter analyze` (0 issues found)
- [x] Run `flutter test` baseline (1,250+ tests passing, 0 analyze warnings)
- [x] Build remediation tracker (`docs/audit/REMEDIATION_TRACKER.md`)
- [x] Re-verify all 36 findings against source code
- [x] DECISION GATE 0: Present triage results and proposed execution plan to user (Approved)

### Phase 1: Red Tests (A1)
- [x] Entry criteria: Gate 0 approved
- [x] Write failing regression test for ACC-07
- [x] Write failing regression test for ACC-01
- [x] Write failing regression test for ACC-04
- [x] Write failing regression test for ACC-08
- [x] Write failing regression test for ACC-09
- [x] Write failing regression test for ACC-02
- [x] Write failing regression test for ACC-10
- [x] Write failing regression test for ACC-12
- [x] Write failing regression test for ACC-03
- [x] Write failing regression test for ACC-05
- [x] Write failing regression test for ACC-06
- [x] Write failing regression test for ACC-11
- [x] Write widget tests for UX-01, UX-02, UX-04, UX-05, UX-07
- [x] Exit criteria: All tests fail for the right assertion reasons (Red-test)

### Phase 2: Ledger Safety (A2, Sequential)
- [x] Entry criteria: Phase 1 complete
- [x] Fix ACC-07 (Shadow posting savepoint failure)
- [x] Fix ACC-01 (Duplicate payment posting on edit)
- [x] Fix ACC-04 (Zero-total invoice COGS posting)
- [x] Fix ACC-08 (Stock adjustment currency decimal digits)
- [x] DECISION GATE 2: Account for unallocated customer advances (ACC-09)
- [x] Fix ACC-09
- [x] Independent Reviewer (A9) APPROVE
- [x] Exit criteria: All Phase 2 tests green; INV-14..18 green; parity check green

### Phase 3: Costing & Valuation (A3, Sequential)
- [x] Entry criteria: Phase 2 merged
- [x] DECISION GATE 3: Tax-inclusive purchase non-recoverable tax & existing product average cost
- [x] Fix ACC-02 (Net unit cost for tax-inclusive purchases)
- [x] Fix ACC-10 (GL entry for cost reconciliation)
- [x] Fix ACC-12 (Snapshot unit cost for sale reduction)
- [x] Independent Reviewer (A9) APPROVE
- [x] Exit criteria: Stock valuation vs. GL reconciliation green across tax-inclusive, tax-exclusive, and no-tax

### Phase 4: Reporting & Integrity (A4, Sequential)
- [x] Entry criteria: Phase 3 merged
- [x] Fix ACC-03 (Standalone vouchers in dashboard and payment reports)
- [ ] Fix ACC-05 (Unallocated receipts on customer statements)
- [ ] Fix ACC-06 (Pre-delete allocation check for vouchers)
- [ ] Fix ACC-11 (PDF tax rate label for mixed-rate invoices)
- [ ] Independent Reviewer (A9) APPROVE
- [ ] Exit criteria: Reports reconcile with General Ledger

### Phase 5: UX Critical & High (A5 then A6 & A7)
- [ ] Entry criteria: Phase 4 merged
- [ ] A5: Add new localization keys in batch
- [ ] A6: Fix UX-01, UX-02, UX-03, UX-04, UX-05
- [ ] A7: Fix UX-06, UX-07, UX-08, UX-14, UX-15, UX-16
- [ ] Independent Reviewer (A9) APPROVE
- [ ] Exit criteria: Widget tests green; manual verification checklist verified

### Phase 6: UX Medium & Low (A5 then A8)
- [ ] Entry criteria: Phase 5 merged
- [ ] A5: Add remaining localization keys
- [ ] A8: Fix UX-09, UX-10, UX-11, UX-12, UX-13, UX-17..24
- [ ] Independent Reviewer (A9) APPROVE
- [ ] Exit criteria: RTL and 48dp touch targets verified

### Phase 7: Existing-Data Repair (A10, Gated)
- [ ] Entry criteria: Phase 6 complete
- [ ] DECISION GATE 7: Proposal for repairing existing affected historical records
- [ ] Dry-run idempotent repair tool
- [ ] Exit criteria: Historical parity validated

### Phase 8: Final Verification & Release Notes (Coordinator + A9)
- [ ] Entry criteria: Phase 7 complete
- [ ] Full `flutter analyze` & `flutter test`
- [ ] Update `CHANGELOG.md` & docs
- [ ] Final Arabic report to user

---

## C) Decision Log

| Date | Gate | Topic | Proposed Options | User Decision | Notes |
|:---|:---|:---|:---|:---|:---|
| 2026-11-21 | Gate 0 | Triage results & proposed phase order | Approval to proceed with Phases 1..8 | Approved by user | Phase 1 started |
| 2026-11-22 | Gate 2 | ACC-09: Unallocated customer advances account | Option A: Credit 2110 (Payables/Customer Advances)<br>Option B: New Account 2130 (Customer Deposits)<br>Option C: Credit 1130 (Receivables) | Approved Option B: Adopt Account 2130 (Customer Deposits – دفعات مقدمة من العملاء) under Current Liabilities | Unallocated receipts without invoice credit 2130 with contactId; never to 4900 or 2110 |
| 2026-11-22 | Gate 3 | ACC-02: Non-recoverable tax & existing product cost | Option A: Recoverable VAT only<br>Option B: Capitalize non-recoverable VAT, deduct recoverable VAT | Approved Option B (Deduct recoverable VAT from unit cost; capitalize only if taxesEnabled is false or tax non-recoverable) | When taxesEnabled=true and pricesIncludeTax=true with recoverable VAT, incoming unit cost must be net of tax |
| - | Gate 7 | Phase 7 Data Repair | Opt-in script vs. automatic migration | Pending Gate 7 | Before touching historical data |

---

## D) File Ownership Matrix & Concurrency Controls

| Agent | Owned Files | Concurrency Restriction |
|:---|:---|:---|
| **Coordinator** | `docs/audit/REMEDIATION_TRACKER.md`, Git branches, merges | Sole editor of sections A–E |
| **A1 (repro-test-writer)** | `test/regression/*`, `test/widgets/*` | Only writes under `test/` |
| **A2 (posting-engine)** | `lib/services/accounting/*`, `lib/database/database_helper.dart` (posting/edit) | **SERIALIZED** (must not edit database_helper concurrently with A3 or A4) |
| **A3 (inventory-costing)** | `lib/services/inventory_costing_service.dart`, `lib/services/inventory_service.dart`, `lib/database/database_helper.dart` (stock/cost) | **SERIALIZED** (runs only after Phase 2 is merged) |
| **A4 (reporting-integrity)**| `lib/services/customer_statement_service.dart`, `lib/services/pdf/pdf_totals_builder.dart`, `lib/database/database_helper.dart` (reports/delete) | **SERIALIZED** (runs only after Phase 3 is merged) |
| **A5 (l10n-owner)** | `lib/localization/app_localizations.dart` | **SOLE WRITER** for localization |
| **A6 (ux-critical)** | `lib/screens/access/pin_lock_screen.dart`, `lib/screens/customer_detail_screen.dart`, `lib/screens/payment_methods_screen.dart`, `lib/screens/bulk_pricing_screen.dart`, `lib/screens/home_screen.dart` | Disjoint from A7; parallel allowed |
| **A7 (ux-flows)** | `lib/screens/activation_screen.dart`, `lib/screens/document_detail_screen.dart`, `lib/screens/exchange_rates_screen.dart`, `lib/screens/settings_screen.dart`, `lib/screens/google_drive_backup_screen.dart`, `lib/screens/period_closing_screen.dart`, `lib/screens/edit_document_screen.dart` | Disjoint from A6; parallel allowed |
| **A8 (rtl-a11y-polish)** | `lib/widgets/*`, `lib/screens/access/*`, `lib/screens/reports/*`, `lib/screens/inventory_screen.dart` | Phase 6 |
| **A9 (independent-reviewer)**| Read-only on all files | Reviews PR diffs independently |
| **A10 (data-repair)** | `lib/services/accounting/repair/*` | Phase 7 only |

---

## E) Risk Register

| Risk ID | Description | Impact | Mitigation |
|:---|:---|:---|:---|
| **RSK-01** | Merge conflicts on 8,700-line `database_helper.dart` | High | Strict serialization of A2, A3, and A4 with full branch merges between phases |
| **RSK-02** | ACC-03 double-counting allocated vouchers in cash flow | Critical | Verified during triage: only select standalone vouchers not linked in `document_payments` |
| **RSK-03** | Breaking accounting parity invariant (INV-18) | Critical | Run `test/invariants/accounting_backbone_invariants_test.dart` after every commit |
| **RSK-04** | Accidental string regressions or untranslated keys | Medium | A5 is the sole owner of `app_localizations.dart`; run `no_hardcoded_strings_test.dart` |
| **RSK-05** | Flaky backup/restore test timeout under heavy Termux I/O | Low | Identified pre-existing timeout in `backup_restore_db_test.dart` during baseline |

---

## F) Agent Log Index

- Coordinator Log: `docs/audit/agent_logs/coordinator.md`
- A1 Log: `docs/audit/agent_logs/repro-test-writer.md`
- A2 Log: `docs/audit/agent_logs/posting-engine.md`
- A3 Log: `docs/audit/agent_logs/inventory-costing.md`
- A4 Log: `docs/audit/agent_logs/reporting-integrity.md`
- A5 Log: `docs/audit/agent_logs/l10n-owner.md`
- A6 Log: `docs/audit/agent_logs/ux-critical.md`
- A7 Log: `docs/audit/agent_logs/ux-flows.md`
- A8 Log: `docs/audit/agent_logs/rtl-a11y-polish.md`
- A9 Log: `docs/audit/agent_logs/independent-reviewer.md`
- A10 Log: `docs/audit/agent_logs/data-repair.md`

---

## G) Tracked Architectural Features & Backlog

| Feature Key | Title | Target Phase | Status | Description |
|:---|:---|:---|:---|:---|
| **CUSTOMER-ADVANCE-ALLOCATION** | Complete Customer Advance Lifecycle & Invoice Allocation | Backlog / Post-Remediation | OPEN / NOT IMPLEMENTED | Allocation of existing unallocated customer advances (Account 2130) to subsequently issued invoices. Scope: partial/multiple allocations, balanced settlement entries (`Dr 2130 / Cr 1130`), customer ownership validation, available balance validation, immutable reversal support, contactId audit preservation, and ledger parity. |
