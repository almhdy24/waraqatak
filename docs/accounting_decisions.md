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
