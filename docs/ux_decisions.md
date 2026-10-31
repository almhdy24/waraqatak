# UX Design & Implementation Decisions

Record of all autonomous decisions made during the UX implementation batches.

Format per decision:
- **Decision:** What was chosen
- **Alternatives:** What other choices were considered
- **Why Safest:** Why this choice preserves existing behavior best
- **How to Reverse:** Steps to revert if needed

---

### Decision 1 (Batch 1): Accessible Button Minimum Touch Target (48dp)
- **Decision:** Configured `elevatedButtonTheme`, `filledButtonTheme`, `outlinedButtonTheme`, and `textButtonTheme` with `minimumSize: const Size(..., 48)` using `AppDesignTokens.minTouchTarget`.
- **Alternatives:** Leaving buttons at 44dp height (fails WCAG touch target guideline of 48x48dp) or wrapping every button manually with `SizedBox(height: 48)`.
- **Why Safest:** Setting component themes at the `ThemeData` level ensures all Material 3 buttons adhere to accessibility standards without modifying screen build methods or layout hierarchy.
- **How to Reverse:** In `lib/theme.dart`, revert button `minimumSize` back to `const Size(64, 44)` and remove `textButtonTheme`.

### Decision 2 (Batch 1): Dynamic Semantic Status Colors with Dark Mode Tokens
- **Decision:** Added dual light/dark tokens (`successDark`, `dangerDark`, `warningDark`, `infoDark`, `neutralMutedDark`) and contextual helper methods (`AppDesignTokens.semanticSuccess(context)`, etc.) that dynamically evaluate theme brightness.
- **Alternatives:** Hardcoding light colors everywhere or forcing all screens to manually check `Theme.of(context).brightness`.
- **Why Safest:** Preserves original light palette constants untouched while providing accessible (>4.5:1 contrast) dark mode variants through safe helper methods.
- **How to Reverse:** Remove dark tokens and helper methods from `lib/widgets/app_design_tokens.dart`.

### Decision 3 (Batch 2): In-Place Extension of StatusBadge with AppStatusBadge Alias
- **Decision:** Extended the existing `StatusBadge` to support semantic icons alongside status labels, and provided `typedef AppStatusBadge = StatusBadge;`.
- **Alternatives:** Creating an entirely separate `AppStatusBadge` widget and leaving existing `StatusBadge` invocations text-only.
- **Why Safest:** Preserves the exact existing constructor `StatusBadge({super.key, required this.status})` so zero existing callsites break, while immediately solving finding D-5 (color-only status indicators) across every document list.
- **How to Reverse:** Revert `lib/widgets/status_badge.dart` to the original 43-line implementation.

### Decision 4 (Batch 3): Unified Directional Icons and Amount Alignment
- **Decision:** Replaced scattered inline ternaries (`l10n.isArabic ? Icons.chevron_left : Icons.chevron_right`) across 10 screens with `AppIcons.chevronForward(context)` and `AppIcons.arrowBack(context)`, and standardized amounts via `AppAmountText`.
- **Alternatives:** Keeping screen-by-screen ternaries and raw string interpolations.
- **Why Safest:** Consistently mirrors all navigation gestures and arrows for RTL Arabic and LTR English, avoiding bugs where Western chevrons point backwards in Arabic.
- **How to Reverse:** Revert touched screens to inline ternaries.

### Decision 5 (Batch 4): Sticky Bottom Totals Bar and PopScope Navigation Guard
- **Decision:** Added sticky `bottomNavigationBar` totals bars on `InvoiceScreen`, `PurchaseScreen`, and `QuotationScreen` with primary action buttons and live `AppAmountText` total; added `PopScope` unsaved dirty guards and line deletion confirmations.
- **Alternatives:** Requiring users to scroll through lengthy item lists to reach the save button and totals card at the very bottom.
- **Why Safest:** Retains the full scrollable form and existing totals card inside the body while exposing the sticky totals and save actions at the viewport bottom for quick thumb access. Uses `_isDirty` checks before popping so existing save/issue flow parameters remain completely untouched.
- **How to Reverse:** Remove `bottomNavigationBar` and `PopScope` wrapper, restoring the full-width buttons inside the list.

### Decision 6 (Batch 5): Dynamic POS Grid Height and PopScope Cart Guard
- **Decision:** Computed dynamic `mainAxisExtent` based on `MediaQuery.textScalerOf(context)` in `QuickSaleScreen`'s product grid, enlarged `_QtyStepper` touch targets to >= 44x44dp, and added `PopScope` to prompt confirmation before discarding an active cart.
- **Alternatives:** Keeping fixed 112dp tile height (clips on large accessibility font scales) and letting back gesture discard cart silently.
- **Why Safest:** Dynamically adapts grid tiles to user font preferences without altering grid column sizing (`maxCrossAxisExtent: 190`), and prevents accidental loss of in-progress cashier cart sessions.
- **How to Reverse:** Revert `_productPicker`, `_QtyStepper`, and `build` in `lib/screens/quick_sale_screen.dart`.

### Decision 7 (Batch 6): Unsaved Form Protection and Contact Phone/Email Tap Affordance
- **Decision:** Added comprehensive `_isDirty` checkers and `PopScope` navigation guards on `ProductFormScreen` and `ContactFormScreen`, replaced raw delete dialogs with `AppConfirmDialog`, added tap-to-call/email in `CustomerDetailScreen` using `UrlLauncherUtils`, and standardized list error/loading views across products and customers screens.
- **Alternatives:** Letting users lose typed product details or contact edits on accidental swipe-to-back, and keeping phone/email as non-interactive static text.
- **Why Safest:** Preserves every database and service call parameter exactly as written, while preventing catastrophic data entry loss on mobile gestures and making customer contact details immediately actionable.
- **How to Reverse:** Revert `_isDirty`, `PopScope`, and `_InfoChip.onTap` in `lib/screens/product_form_screen.dart`, `lib/screens/contact_form_screen.dart`, and `lib/screens/customer_detail_screen.dart`.

### Decision 8 (Batch 7): Horizontally Scrollable Ledger Tables and Semantic Movement Indicators
- **Decision:** Constrained `_TrialBalanceView` within a horizontal `SingleChildScrollView` with 440dp target width to prevent tabular clipping on narrow mobile viewports; resolved debit/credit colors using dynamic semantic tokens; unified report error/loading views with `AppErrorState` and `AppLoadingView`.
- **Alternatives:** Letting narrow phone screens truncate account codes or squish debit/credit numbers.
- **Why Safest:** Preserves every ledger calculation, query, and aggregation rule untouched, while providing readable tabular figures across all screen form factors.
- **How to Reverse:** Remove `SingleChildScrollView` from `_TrialBalanceView` in `lib/screens/reports/accounting_screen.dart`.
