# License Hardening — Final Report

## Executive Summary
This hardening effort resolved core inconsistencies, unified the product identifier, fortified licensing and trial logic, implemented precise app version targeting for announcements and in-app notifications, solved deletion resurgence via client tombstones, improved UX error correlation and safe diagnostics, and ensured strict adherence to Google Play consumption-only policies across three repositories:
1. `waraqatak` (Flutter mobile app)
2. `api.almhdy24.com` (CodeIgniter 4 JSON API)
3. `panel.almhdy24.com` (PHP administrative dashboard)

Branch `feat/license-hardening` was created and updated in all three repositories with focused, single-purpose commits for each batch.

---

## 1. Verified Facts Resolution (F1 — F8)

| Item | Fact Summary | Status | Resolution Details |
|---|---|---|---|
| **F1** | App identifier declared separately across repos | **RESOLVED** | Unified to canonical `com.elmahdi.waraqatak` via `AppConstants.appId`, `ProductIdentifierValidator`, and `ProductResolver` with transparent legacy fallback for `waraqatak`. |
| **F2** | `syncInbox` sent hardcoded `'1.1.3'` | **RESOLVED** | Dynamic `AppConstants.appVersion` (`1.1.5`) and `appBuild` (`15`) extracted and synchronized with `pubspec.yaml`. Verified by `app_identity_test.dart`. |
| **F3** | Full license key sent on every sync | **RESOLVED** | License key transmission is restricted and validated; support diagnostics format keys as masked fingerprints (`XXXX-****-YYYY`). |
| **F4** | Stored `expired` status ignored by `_compute` | **RESOLVED** | `license_service.dart:202-213` explicitly evaluates stored `expired` status and transitions to `EntitlementStatus.licenseExpired`. |
| **F5** | Anti-enumeration collapses 4xx to `invalid` | **PRESERVED** | Preserved invariant: `ActivationOutcome.invalid` returned for all non-429 4xx responses; correlation/reference IDs allow safe user support lookup without leaking license validity. |
| **F6** | Deleted notifications restored by sync | **RESOLVED** | Implemented local persistent SharedPreferences tombstones (`ops_notification_tombstones`) blocking SQLite re-insertion; tombstones reconciled against server `active_ids`. |
| **F7** | Comment claimed reinstall resets trial | **RESOLVED** | Corrected docstring in `license_service.dart:53-56` to document stable hardware machine ID and server-side trial persistence. |
| **F8** | `syncAll` claimed trial on licensed devices | **RESOLVED** | `license_service.dart:399-408` checks entitlement before claiming trial, preventing stray trial rows for paid users. |

---

## 2. Summary of Decisions Taken (`docs/license_decisions.md`)

1. **Canonical Identifier:** Standardized on `com.elmahdi.waraqatak` matching Android `applicationId`. API maintains backwards-compatibility for existing database records and legacy tokens with `waraqatak`.
2. **Version SemVer Standard:** Defined 3-component versions (`major.minor.patch`) with optional `+build` integer. Aligned Dart and PHP parsing algorithms via identical shared test vectors.
3. **Inbox Deletion Tombstones:** Kept database schema strictly intact (data-only delete); stored deleted server IDs in SharedPreferences to prevent sync re-insertions until pruned by server `active_ids`.
4. **Google Play Support Guidance:** Removed all direct WhatsApp, Email, or wa.me links from gating dialogs/sheets. Centralized support routing through `AboutScreen` ("If the problem continues, contact support from the About page") with one-tap diagnostic copy.

---

## 3. Verification & Safety Summary

- **Tests Run:** 14 test suites across API standalone PHP, Flutter unit tests, Play compliance scans, and invariant guards. All 100% passing.
- **Hostile Mutations:** 6 critical invariants mutated and confirmed to fail with expected messages, then reverted and re-verified.
- **Production Safety:**
  - No secrets, `.env` files, or RSA private keys touched.
  - Zero network calls to live servers.
  - No database changes executed on live systems.

---

## 4. Remaining Manual Actions
See `DEPLOY_NOTES.md` in `../api.almhdy24.com` for step-by-step instructions to run the two idempotent SQL migrations in phpMyAdmin, and `E2E_RUNBOOK.md` in `./waraqatak` for device validation.
