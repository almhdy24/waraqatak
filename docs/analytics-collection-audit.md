# Analytics & Error Reporting Collection Audit

**Date:** 2026-11-08  
**Scope:** Investigation of current usage analytics and error reporting mechanisms in Waraqatak before splitting into dual default-on channels with a one-time first-run notice.

---

## 1. Executive Summary

Today, usage analytics and error reporting exist in the codebase as **two completely separate, unlinked mechanisms**:
1. **Usage Analytics:** Handled by `AnalyticsService` using the vendored AlmHdy Analytics Flutter SDK. It defaults to **ON** (`true`), persists under `'analytics_enabled'`, is gated by `PermissionGate(permission: PermissionRegistry.settingsManage)` in Settings, and suppresses tracking when the multi-user screen is locked.
2. **Error / Diagnostic Reporting:** Handled by `AppDiagnosticsService` using a local SQLite table (`diagnostic_reports`) and syncing via `AppOpsService`. It defaults to **OFF** (`false`), persists under `'ops_diagnostic_consent_granted'`, is **not** gated by `settings.manage` in Settings, and requires both local user opt-in and a remote configuration flag (`enable_diagnostics`) to send anything.

In addition, `AnalyticsService` has an allowlisted `AnalyticsEvent.errorCaught` event used in a single location (`lib/services/backup_service.dart`) for handled backup exceptions, which currently routes through the general usage analytics pipeline.

---

## 2. Detailed Findings with File and Line References

### A. Current Error Reporting Hooks & Infrastructure

- **Global Uncaught Errors:**
  - **`lib/main.dart` lines 26–33:** `FlutterError.onError` is hooked to print via `FlutterError.presentError(details)` and log to developer console via `developer.log('FlutterError', ...)`.
  - **`lib/main.dart` lines 35–38:** `PlatformDispatcher.instance.onError` is hooked to log via `developer.log('PlatformDispatcher', ...)`.
  - **`lib/main.dart` lines 22–76:** `runZonedGuarded` wraps the entire `main()` app startup. In its error handler (lines 68–75):
    ```dart
    (error, stack) {
      developer.log('Uncaught zone error', error: error, stackTrace: stack);
      AppDiagnosticsService.instance.recordError(
        error,
        stack,
        operation: 'unhandled_exception',
      );
    }
    ```
- **AppDiagnosticsService Hooks:**
  - **`lib/services/app_diagnostics_service.dart` lines 72–97:** `_installErrorHooks()` wraps both `FlutterError.onError` and `PlatformDispatcher.instance.onError`, forwarding to `recordError(details.exception, details.stack, operation: 'unhandled_exception')` while preserving prior handlers.
  - Initialized in `lib/main.dart` line 54 via `await AppDiagnosticsService.instance.init()`.
- **Handled Error Events in AnalyticsService:**
  - **`lib/services/analytics/analytics_service.dart` line 30:** `errorCaught('error_caught')` is defined in `enum AnalyticsEvent`.
  - **`lib/services/analytics/analytics_service.dart` lines 169–185 & 450–454:** Strict allowlist validation limits `errorCaught` properties to `area` (`backup`, `restore`, `activation`, `export`, `sync`, `migration`) and `kind` (`network`, `io`, `format`, `crypto`, `timeout`, `state`, `unknown`).
  - **`lib/services/backup_service.dart` line 466:** Dispatches `AnalyticsEvent.errorCaught` upon backup failure.

---

### B. Shared vs. Independent State & Call Paths

| Attribute | Usage Analytics (`AnalyticsService`) | Error / Diagnostic Reporting (`AppDiagnosticsService`) |
|---|---|---|
| **Underlying Subsystem** | AlmHdy Analytics SDK (`packages/almhdy_analytics`) | Custom SQLite table `diagnostic_reports` + `AppOpsService` |
| **Settings / Preference Key** | `analytics_enabled` (`_kConsentKey`) | `ops_diagnostic_consent_granted` (`kConsentPrefKey`) |
| **Default State** | **ON** (`true`) | **OFF** (`false`) |
| **Queue / Storage** | Memory queue + local JSON buffer file (`almhdy_analytics_buffer.json`) | SQLite database table `diagnostic_reports` (max 50 rows) |
| **Ingestion Key Requirement** | Requires write-only `AnalyticsConfig.defaultProjectKey` | Requires `AppOpsService` backend authentication |
| **Multi-User Lock Screen** | Dropped when `SessionManager.instance.isLocked == true` | Not checked (stores to SQLite regardless of lock state) |
| **Settings UI Gate** | Gated by `PermissionGate(settings.manage)` | Ungated in `SettingsScreen` |

---

### C. Controls & Flags Analysis

1. **Opt-Out Toggle in Settings:**
   - In `lib/screens/settings_screen.dart` lines 540–603, under the **Support & Info** section:
     - Toggle 1: "Diagnostic Error Sharing" (`l10n.diagnosticSharingTitle`) bound to `_diagnosticConsent` and `AppDiagnosticsService.instance.setConsent(val)`.
     - Toggle 2: "Anonymous usage statistics" (`l10n.analyticsConsentTitle`) bound to `_analyticsConsent` and `AnalyticsService.instance.setEnabled(val)`.
2. **Permission Gate:**
   - The usage analytics toggle is wrapped in `PermissionGate(permission: PermissionRegistry.settingsManage)` (`lib/screens/settings_screen.dart` lines 583–603).
   - The diagnostic sharing toggle is outside this gate (lines 540–582).
3. **Empty Key Behavior:**
   - In `lib/services/analytics/analytics_service.dart` lines 301–304, if `AnalyticsConfig.projectKey` is empty (such as during unit tests), `AnalyticsService.initialize()` disables tracking completely.
   - `AppDiagnosticsService` does not check `AnalyticsConfig.projectKey`.
4. **Lock Screen Suppression:**
   - In `lib/services/analytics/analytics_service.dart` lines 476–479, if `SessionManager.instance.isLocked` is `true`, `track()` immediately aborts.

---

### D. What a User Stops When Toggling Off

- **Turning off "Anonymous usage statistics" (`analytics_enabled = false`):**
  - Invokes `AnalyticsService.instance.setEnabled(false)`.
  - Sets `_isEnabled = false` and calls `_sink.optOut()`.
  - Clears all queued usage events and drops future calls to `AnalyticsService.instance.track(...)`.
  - **Does NOT** stop `AppDiagnosticsService` from capturing crashes or errors (though that was default OFF anyway).
- **Turning off "Diagnostic Error Sharing" (`ops_diagnostic_consent_granted = false`):**
  - Invokes `AppDiagnosticsService.instance.setConsent(false)`.
  - Deletes all pending diagnostic reports from SQLite table `diagnostic_reports`.
  - **Does NOT** stop `AnalyticsService` usage events or `AnalyticsEvent.errorCaught` in backup flows.

---

## 3. Architecture Adaptation for Items 1 to 10

To meet the requirements without duplicating code:

1. **Unify Error Reporting under AlmHdy Telemetry Channel Architecture:**
   - Retain two distinct, independent channels:
     - **Channel A: Usage Analytics** (toggled by `analytics_enabled`, default ON).
     - **Channel B: Error Reporting** (toggled by `error_reporting_enabled`, default ON).
   - **Legacy Migration:** If a user previously opted out of usage analytics (`analytics_enabled == false`), migrate so BOTH `analytics_enabled` and `error_reporting_enabled` are `false`. If a user previously opted into `ops_diagnostic_consent_granted`, respect their consent.
2. **Dedicated Error Reporting Channel & Sanitizer:**
   - Reuse the battle-tested, deep redaction patterns from `AppDiagnosticsService` (`sanitizeMessage`, `sanitizeStackTrace`, `sanitizeExceptionType`, `sanitizeOsVersion`) which already redact PII, phone numbers, emails, monetary amounts, and user file paths.
   - Route crash and unhandled exception reports through an independent error reporter into AlmHdy Analytics SDK (e.g. event `error_report`), subject to the Error Reports toggle.
   - Cap session errors (max 20 per session) and deduplicate repeated identical errors.
3. **Hooking Global Handlers:**
   - Hook `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded` to forward to the sanitized error reporting pipeline while strictly chaining to previous handlers and never throwing.
4. **First-Start One-Time Notice:**
   - Display a non-blocking modal or banner on first app start (after multi-user unlock if multi-user is active).
   - Flag `'analytics_first_run_notice_shown'` persisted in `SharedPreferences`.
   - Direct button/action opening Settings Support section.
   - Full RTL and Arabic localization via `AppLocalizations`.
