# Fix Decisions Log

Log format:
- **Decision:** What choice was made
- **Context:** Background
- **Alternatives Considered:** What other options existed
- **Why Safest:** Justification for the chosen option
- **How to Reverse:** Steps to revert if needed

---

### Decision 1: Extend SnackBar Duration to 10s Under Accessible Navigation with Action
- **Decision:** When `MediaQuery.accessibleNavigation` is `true` and an interactive action exists on the SnackBar, the display duration is set to 10 seconds (`AppSnackBar.accessibleDuration = Duration(seconds: 10)`); otherwise, standard duration is 5 seconds.
- **Context:** Flutter's default behavior with `SnackBarAction` is to set `persist: true`, which left SnackBars permanently on screen. When auto-dismissing, users of TalkBack / VoiceOver or assistive navigation need sufficient time to perceive the message and reach the action button before dismissal.
- **Alternatives Considered:**
  1. Keep 5 seconds for all users regardless of accessibility flags: Risks users with assistive technology missing the undo action.
  2. Indefinite persistence when `accessibleNavigation` is true: Would re-introduce the original bug of SnackBars never disappearing.
  3. Extended duration to 10s: Follows WCAG 2.2 guideline 2.2.1 (Timing Adjustable) for transient feedback without leaving permanent UI clutter.
- **Why Safest:** Provides ample interaction window for screen reader focus traversal while strictly guaranteeing dismissal.
- **How to Reverse:** In `lib/widgets/app_snackbar.dart`, change `(accessibleNavigation && hasAction) ? accessibleDuration : defaultDuration` to always return `defaultDuration`.



---

### Decision 2: Single Delta Routine for Stock Movements on Document Edits
- **Decision:** On edit of any issued document (`updateDocumentWithItems`), stock updates route strictly through `_applyDocumentEditStockDeltas`, which computes signed per-product quantity and cost deltas against the old document items. Metadata-only edits produce zero movements and zero ledger changes.
- **Context:** Previously, `updateDocumentWithItems` re-inserted stock movements for all line items when `newIsIssued` was true, causing duplicate movements (+100 then +100 again) when an issued purchase was edited.
- **Alternatives Considered:**
  1. Delete all old stock movements and re-insert: Unsafe. Deleting movements destroys audit history and breaks foreign key linkages or ledger reconciliation.
  2. Compute delta movements: Safe and minimal. Only records the net change (if any), perfectly preserving audit history.
- **Why Safest:** Enforces strict idempotency (editing with identical items produces zero movements), prevents double counting, and respects the moving average inventory costing policy.
- **How to Reverse:** Revert changes in `lib/database/database_helper.dart` in `_applyDocumentEditStockDeltas` and `updateDocumentWithItems`.

---

### Decision 3: Movement Neutralization for Guided Historical Repair
- **Decision:** In `DatabaseRepairService`, provide a guided safe repair tool for historical duplicate movements:
  - Option A: Neutralize surplus movement by inserting a compensating cancellation movement (`type: 'cancellation'`), bringing net movements for the document in line with its line items.
  - Option B: For documents where the user had already performed a manual stock adjustment to offset the duplicate movement (reproducing the PURCHASE-0001 scenario), pair the duplicate movement with the compensating adjustment and mark both as `type: 'neutralized'` (`[NEUTRALIZED-OPTION-B]`).
- **Context:** Hard-deleting stock movements from SQLite is prohibited because historical audit trails must remain intact. Marking records as `neutralized` excludes them from ledger loss calculations while retaining complete audit records in the database.
- **Alternatives Considered:**
  1. `DELETE FROM stock_movements WHERE id = ...`: Violates invariant of immutable audit trails.
  2. Movement neutralization without deletion: Preserves historical records, removes phantom loss from ledger, and restores balance sheet accuracy.
- **Why Safest:** Guarantees auditability, requires user confirmation token (`CONFIRM-REPAIR-...`), creates safety backup first, executes atomically in a transaction, and leaves the audit log documented.
- **How to Reverse:** The safety backup created before repair can be restored via `BackupService.restoreBackup`, or the `neutralized` flag can be reverted back to `purchase` / `adjustment`.
