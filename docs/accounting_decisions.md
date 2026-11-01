# Accounting & Single-Currency Decisions Log

This document records all architectural and mathematical decisions taken autonomously during the single-currency refactor and accounting audit.
Format: Decision | Alternatives considered | Why safest | How to reverse.

---

### Decision 0-1: Canonical Amount Presentation and Accessibility Semantics in `AppAmountText`
- **Decision:** Rather than weakening the test finder in `multi_currency_phase1_test.dart` or flattening `AppAmountText` into an unstyled single `Text` widget, `AppAmountText` was enhanced with:
  1. Canonical getters `formattedAmount`, `resolvedPrefix`, and `fullText`.
  2. A unified `Semantics(container: true, label: resolvedSemantics, excludeSemantics: true)` wrapper around the visual `Row`.
  3. Preservation of caller-specified decimal digits (`decimalDigits: fmt.maximumFractionDigits`) from `CustomerDetailScreen`.
- **Alternatives Considered:**
  1. Weaken test finder to accept any card containing `50,000` and `ج.س` anywhere: Rejected because it hides formatting regressions and does not verify widget cohesion or accessibility.
  2. Replace `Row` with `Text.rich`: Rejected because Flutter inline `TextSpan`s do not support per-span `Directionality` override without `WidgetSpan`, risking digit reversal in RTL layouts.
- **Why Safest:** Preserves RTL typography and tabular numeral alignment while restoring intended zero-decimal presentation for `CustomerDetailScreen` and providing full accessible semantics for screen readers and automated tests.
- **How to Reverse:** Remove `Semantics` wrapper and `decimalDigits` override in `customer_detail_screen.dart`.

### Decision 3-1: Single Base Currency Architecture with Segregated Legacy Presentation
- **Decision:**
  1. The entire application operates strictly on ONE base currency per installation (`businesses.currency_code`), locked upon the first financial transaction.
  2. All document creation workflows (Invoices, Purchases, Quotations, Returns, Payments) enforce the base currency at the service and database layer.
  3. All financial reports, ledger books, customer statements, and dashboard summaries display primary totals in the single base currency. Multi-currency dropdown selectors were removed from `accounting_screen.dart` and `customer_statement_dialog.dart`.
  4. Legacy documents in other currencies (from historical data or restored backups) are preserved untouched in SQLite without destructive rewrite or deletion. They are excluded from base-currency nominal sums to avoid financial distortion, displayed in dedicated read-only sections with per-currency subtotals, and flagged by Database Diagnostics (`code: legacy_foreign_currency_documents`).
- **Alternatives Considered:**
  1. *Convert legacy foreign amounts to base currency using fixed exchange rates:* Rejected because exchange rates fluctuate, historical conversion rates are unknown, and introducing currency conversion was strictly forbidden by the prompt.
  2. *Silently drop or ignore foreign-currency documents from reporting:* Rejected because it violates the zero-data-loss invariant and causes debts to vanish from customer balances.
  3. *Re-write stored foreign documents in SQLite to the base currency:* Rejected because stored documents are immutable historical snapshots.
- **Why Safest:** Completely prevents cross-currency nominal addition errors while guaranteeing 100% data preservation and audit transparency.
- **How to Reverse:** Restore per-document currency selector dropdowns and revert report summaries to multi-currency aggregation maps.

