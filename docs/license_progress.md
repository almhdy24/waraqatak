# License Hardening Progress

| Batch | Description | Status | APP Commit | API Commit | PANEL Commit | Checks Run |
|---|---|---|---|---|---|---|
| Batch 0 | Discovery Audit | COMPLETED | `8ba4df8` | N/A | N/A | Full audit of 3 repos, Play compliance check |
| Batch 1 | Identifier Unification | COMPLETED | `dc411b6` | `09a1aeb` | `2b00c2b` | app_identity_test, standalone test_product_identifier, play compliance |
| Batch 2 | License & Trial Correctness | COMPLETED | `8a2fff1` | `8911bf7` | N/A | license_correctness_matrix_test, standalone test_license_rejection_matrix |
| Batch 3 | Notification Targeting | COMPLETED | `f0d54eb` | `4c2d176` | `7d5331a` | version_matcher_test (2), test_version_matcher (16), test_notification_targeting (6) |
| Batch 4 | App Notifications | COMPLETED | `01a947c` | N/A | N/A | app_notifications_test (5), app_identity_test (4), play compliance |
| Batch 5 | Activation / License / Trial UX | IN_PROGRESS | - | - | - | - |
| Batch 6 | Final Verification & Docs | PENDING | - | - | - | - |

---

## Detailed Batch Logs

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
