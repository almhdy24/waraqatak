# UX Skipped Items

Items that were skipped due to requiring business logic changes, schema modifications, or touching forbidden files as required by the strict constraints.

---

### 1. Live Exchange Rate Converter in Multi-Currency Forms
- **Item:** Real-time fetching of FX conversion rates in multi-currency invoice and expense flows.
- **Why Skipped:** Requires network access, external API dependencies, and modifications to currency locking rules (`DocumentService`, multi-currency isolation). Waraqatak is offline-first.
- **What Would Be Needed:** An offline rate snapshot table with explicit user override, plus user approval for changes to currency isolation logic.

### 2. Custom Document Numbering Format Designer
- **Item:** Drag-and-drop prefix/suffix pattern editor for invoices, receipts, and quotations.
- **Why Skipped:** Document numbering logic is part of the forbidden business logic constraints to ensure audit integrity and sequence uniqueness.
- **What Would Be Needed:** Schema migration to store format templates in business settings and an update to the numbering sequence generator.

### 3. Quick Undo for Soft-Deleted or Cancelled Invoices
- **Item:** Immediate "Undo" SnackBar action after cancelling an invoice.
- **Why Skipped:** In an accounting system with weighted-average inventory costing (IAS 2) and general ledger double entries, cancellation triggers stock movement reversals and payment ledger adjustments. A superficial "undo" would corrupt the audit trail without a formal re-posting engine.
- **What Would Be Needed:** An explicit re-issue / copy workflow (which is already provided via "Duplicate Document").

### 4. Inline Direct Stock Adjustment in Document Item Form
- **Item:** Editing product on-hand quantity directly within invoice or purchase line item editors.
- **Why Skipped:** Violates strict inventory costing constraints (`stock_movements`, weighted average cost, and `DocumentService.resolveItemPrice`). Stock movements must flow through official transactions or formal stock adjustments.
- **What Would Be Needed:** Dedicated modal launching the existing `StockAdjustment` service dialog.
