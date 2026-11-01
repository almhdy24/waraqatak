# License Hardening Progress

| Batch | Description | Status | APP Commit | API Commit | PANEL Commit | Checks Run |
|---|---|---|---|---|---|---|
| Batch 0 | Discovery Audit | COMPLETED | `8ba4df8` | N/A | N/A | Full audit of 3 repos, Play compliance check |
| Batch 1 | Identifier Unification | COMPLETED | `dc411b6` | `09a1aeb` | `2b00c2b` | app_identity_test, standalone test_product_identifier, play compliance |
| Batch 2 | License & Trial Correctness | COMPLETED | `8a2fff1` | `8911bf7` | N/A | license_correctness_matrix_test, standalone test_license_rejection_matrix |
| Batch 3 | Notification Targeting | COMPLETED | `f0d54eb` | `4c2d176` | `7d5331a` | version_matcher_test (2), test_version_matcher (16), test_notification_targeting (6) |
| Batch 4 | App Notifications | COMPLETED | `01a947c` | N/A | N/A | app_notifications_test (5), app_identity_test (4), play compliance |
| Batch 5 | Activation / License / Trial UX | COMPLETED | `ff25efc` | N/A | N/A | activation_detailed_test (4), play_compliance_test (42), localization tests, play compliance guard |
| Batch 6 | Final Verification & Docs | COMPLETED | `a1ee44a` | `a439e22` | N/A | Full suite (14 passes), 6 hostile mutations verified |

---

## Detailed Batch Logs

### Batch 6: Final Verification, Mutation Testing, and Deployment Documentation
- Ran full test suite across APP and API:
  - API: `test_product_identifier.php` (7 tests, 23 assertions).
  - API: `test_license_rejection_matrix.php` (2 tests, 43 assertions).
  - API: `test_version_matcher.php` (16 tests, 22 assertions).
  - API: `test_notification_targeting.php` (6 tests, 22 assertions).
  - API & PANEL: `php -l` on all 19 changed PHP files passed syntax check.
  - APP: `test/services/app_identity_test.dart` (4/4 passed).
  - APP: `test/services/license_correctness_matrix_test.dart` (6/6 passed).
  - APP: `test/utils/version_matcher_test.dart` (2/2 passed).
  - APP: `test/services/app_notifications_test.dart` (5/5 passed).
  - APP: `test/services/activation_detailed_test.dart` (4/4 passed).
  - APP: `test/services/play_compliance_test.dart` (42/42 passed).
  - APP: `test/invariants/units_wholesale_invariants_test.dart` (Passed INV-1..INV-9).
  - APP: `test/guards/architecture_guards_test.dart` (3/3 passed).
  - APP: `bash tool/check_play_compliance.sh` (Passed).
- Executed 6 Hostile Mutation Tests (mutate, assert failure, revert, re-verify pass):
  - M1: VersionMatcher ignored max bound -> test failed on upper bound vector -> reverted -> passed.
  - M2: App identity changed to `'com.other.app'` -> 3 tests in `app_identity_test.dart` failed -> reverted -> passed.
  - M3: Tombstones omitted SharedPreferences write -> `app_notifications_test.dart` failed -> reverted -> passed.
  - M4: API VersionMatcher allowed min > max -> `test_notification_targeting.php` failed -> reverted -> passed.
  - M5: LicenseService ignored stored expired status -> `license_correctness_matrix_test.dart` failed -> reverted -> passed.
  - M6: AppConstants hardcoded back to `'1.1.3'` -> `app_identity_test.dart` failed -> reverted -> passed.
- Documentation created:
  - `docs/license_verification.md` in APP: Detailed audit trail of all commands, outputs, and hostile mutations.
  - `docs/license_final_report.md` in APP: Executive summary, resolution table F1..F8, decisions summary, and manual actions.
  - `DEPLOY_NOTES.md` in API root: Step-by-step instructions for running manual SQL migrations in phpMyAdmin with pre/post read-only checks and rollbacks.
  - `E2E_RUNBOOK.md` in APP root: Comprehensive manual device testing runbook.

### Batch 5: Activation, License, and Trial UX Hardening
- Strengthened `packages/elmahdi_pay_flutter`:
  - `exceptions.dart`: captures server `correlationId` across all API exceptions.
  - `http_client.dart`: parses body or `X-Correlation-ID` header and assigns to error/success models.
  - `license_activation.dart`: `ActivateLicenseResult` captures `correlationId`.
- Hardened `ActivationService`:
  - Added `DetailedActivationResult(outcome, referenceId)` and `activateDetailed()`.
  - Maintained backward-compatible `activate()` signature.
  - Anti-enumeration invariant strictly preserved: all non-429 4xx responses return `ActivationOutcome.invalid`.
- Support Diagnostics & Safe Error Reference:
  - Created `SupportDiagnostics.generateSummary(referenceId, rawKey)` in `lib/utils/support_diagnostics.dart`.
  - Secrets strictly masked: Crockford keys formatted as `XXXX-****-YYYY`, legacy keys as `XXXX...YYYY`.
  - Device IDs, app version, build, OS version, and reference ID included cleanly.
- Compliant UI Guidance:
  - Created reusable `SupportGuidanceCard` in `lib/widgets/support_guidance_card.dart`.
  - Strictly routes support guidance to `AboutScreen`: "If the problem continues, contact support from the About page".
  - One-tap "Copy support information" button copying masked diagnostics to clipboard.
  - Applied across `ActivationScreen`, `LicenseScreen`, `LockedFeatureScreen`, and `ProUpgradeSheet`.
  - Removed all direct WhatsApp/Email/Wa.me buttons and links from gating screens, fully complying with Google Play consumption-only policy.
- Localizations:
  - Added bilingual keys in `app_localizations.dart` (`supportFromAboutPage`, `openAboutPage`, `copySupportInfo`, `supportInfoCopied`, `referenceIdLabel`, `copiedToClipboard`).
  - Localization quality tests passed (10/10) and plural tests passed (6/6).
- Verification:
  - `test/services/activation_detailed_test.dart` passed (4/4).
  - `test/services/play_compliance_test.dart` passed (42/42).
  - `tool/check_play_compliance.sh` passed.
  - `dart analyze lib/ test/services/ packages/elmahdi_pay_flutter/lib/` passed (0 errors, 0 warnings).

### Batch 0: Discovery Audit
- Audit document: `docs/license_audit.md` covering sections A through H with exact file:line evidence.
- Play compliance check: Passed.

### Batch 1: Identifier Unification
- Unification to canonical `com.elmahdi.waraqatak`.
- APP: `AppConstants.appId`, updated `activation_service`, `app_ops_service`, `app_diagnostics_service`, `license_key`.
- API: `ProductIdentifierValidator`, canonical lookup + legacy `waraqatak` compatibility in `ProductResolver`, migration + idempotent SQL.
- PANEL: Regex pattern validation in HTML5 form and action handler.

### Batch 2: License & Trial Correctness
- Fixed F4 in APP (`license_service.dart:193-207` recognizes stored `expired` as `EntitlementStatus.licenseExpired`).
- Fixed F7 comment in `license_service.dart:53-56`.
- Handled F8 in `license_service.dart:399-408` (active license skips trial claiming).
- Added shared test fixture `license_rejection_reasons.json`.
- Implemented and verified comprehensive 18-scenario matrix in APP and API standalone tests.

### Batch 3: Notification Targeting & Version Filtering
- Created shared SemVer specification: `docs/version_targeting.md`.
- Shared test fixture `version_targeting_vectors.json` (SHA-256 byte-identical: `d206858971c1aae5a5900547bc8db27a48ff4448cdae8928eec4428c03b15296`).
- API: `app/Libraries/VersionMatcher.php`, migration `2026-11-01-000002_EnhanceNotificationTargeting.php` + idempotent SQL.
- Model & Controllers: `AppNotificationModel`, `InboxController` (adds `active_ids`, language/version filtering), `NotificationsController` (sanitization, limits, enhanced `preview`).
- APP: `lib/utils/version_matcher.dart` and `test/utils/version_matcher_test.dart` (all 16 vector scenarios passing).
- PANEL: Modern notification management with targeting fields and live Device Eligibility Simulator.

### Batch 4: App Notifications & Inbox Management
- Fixed F2: `AppConstants.appVersion = '1.1.5'` and `appBuild = 15` in `app_constants.dart`.
- Added unit test in `app_identity_test.dart` asserting `AppConstants.appVersion` and `appBuild` match `pubspec.yaml` (4/4 passing).
- Updated `app_diagnostics_service.dart` and `app_ops_service.dart` to use `AppConstants.appVersion`.
- Updated `syncInbox` to send dynamic app version, build, language, client status, and process `active_ids`.
- Implemented SharedPreferences tombstones (`ops_notification_tombstones`) blocking upsert of deleted notifications on subsequent syncs.
- Implemented tombstone reconciliation against server `active_ids`.
- Added data-only `deleteCachedNotification` and `deleteAllCachedNotifications(preserveCritical: true)` in `DatabaseHelper`.
- Redesigned `NotificationsInboxScreen` with:
  - RTL-safe swipe-to-delete with undo SnackBar.
  - Multi-select long-press delete mode with select count and confirmation dialog.
  - "Mark all as read" and "Delete all" popup menu actions.
  - Non-dismissible critical notifications protection (lock badge, delete prevention).
  - Compliant internal routing for `open_about` (`AboutScreen`), `open_license` (`LicenseScreen`), `open_store_listing` (`playStoreUrl`).
- Added and verified `test/services/app_notifications_test.dart` (5/5 passing in 10s).
- Verified `tool/check_play_compliance.sh` passing: Play compliance guard: OK.
