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
