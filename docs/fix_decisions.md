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


