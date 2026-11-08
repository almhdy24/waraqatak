# Analytics Progress
Last updated: 2026-11-08
Branch: feat/analytics

## Batches
| # | Title | Status (TODO/IN_PROGRESS/DONE/BLOCKED) | Commit | Tests run | Notes |
|---|-------|---|---|---|---|
| 1 | SDK review (read-only) and compatibility | DONE | d1dee9e | Static inspection, git inspection | Comprehensive review in docs/analytics/SDK_REVIEW.md. Verdict: SAFE TO VENDOR AS-IS. Zero new packages. |
| 2 | Vendoring and plumbing | DONE | 7826732 | analytics_service_test (10 passed), analyze (0 issues) | Vendored packages/almhdy_analytics, AnalyticsService singleton, allowlist validation, unawaited post-frame init in splash |
| 3 | Instrumentation | TODO | - | - | - |
| 4 | Settings toggle, disclosure, privacy | TODO | - | - | - |
| 5 | Guards, docs, final verification | TODO | - | - | - |

## DECISIONS
- A1: SDK is vendored (unchanged) into `packages/almhdy_analytics` with `VENDORED_FROM.txt`. (Batch 1/2)
- A2: Single entry point `AnalyticsService` with strict allowlist of events, keys, and values. (Batch 2)
- A3: Key via `--dart-define=ALMHDY_ANALYTICS_KEY=...`; empty key or debug build without define = disabled. (Batch 2)
- A4: Init after first frame, unawaited, all failures silently swallowed. (Batch 2)
- A5: Default ON with Settings opt-out (product choice for user review). (Batch 4)
- A6: No DB-layer or in-transaction calls; migration result recorded in SharedPreferences on startup and sent on next init. (Batch 3)
- A7: No identifiers from the app (device id, license key, user credentials, business details) ever sent. (Batch 2/3)
- A8: Branch `feat/analytics` created from `feat/multi-user` because `feat/multi-user` was not yet merged to `main`. (Batch 1)

## SDK REQUESTS (changes needed in the SDK or server, not done here)
1. Configurable `maxQueueSize` (e.g. 500 events) with FIFO eviction when offline buffer reaches cap.
2. Automatic default `storagePath` resolution using `getApplicationSupportDirectory()` on Flutter mobile targets when omitted.
3. Pause periodic `_flushTimer` when `_queue.isEmpty` to avoid CPU wakeups on battery-constrained devices.

## OPEN ISSUES
(None)

## FILES CHANGED
### Batch 1:
- docs/analytics/SDK_REVIEW.md
- docs/analytics/PROGRESS.md

### Batch 2:
- packages/almhdy_analytics/ (vendored from ~/projects/api.almhdy24.com/sdk/flutter)
- packages/almhdy_analytics/VENDORED_FROM.txt
- pubspec.yaml
- pubspec.lock
- lib/services/analytics/analytics_service.dart
- lib/screens/splash_screen.dart
- test/services/analytics_service_test.dart

## RESUME NOTE
Batch 2 completed. SDK vendored into packages/almhdy_analytics/ with relative path dependency. AnalyticsService singleton created with strict allowlist and fake sink capability for testing. Splash screen wired to initialize analytics unawaited after the first frame. 10 tests passed and 0 analyze issues. Proceeding to Batch 3: Instrumentation.
