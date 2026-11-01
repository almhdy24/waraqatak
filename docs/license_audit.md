# Batch 0 — Discovery Audit: Licensing, Activation, Trial & In-App Notifications

**Date:** 2026-11-01  
**Repos Audited:**
- APP: `waraqatak` (`lib/`, `packages/elmahdi_pay_flutter/`, `test/`)
- API: `api.almhdy24.com` (CodeIgniter 4 backend)
- PANEL: `panel.almhdy24.com` (Admin PHP Dashboard)

---

## A. Product Identifier Analysis

### 1. Occurrences across Repositories
- **APP (`waraqatak`)**:
  - `lib/core/constants/app_constants.dart:3`: `packageName = 'com.elmahdi.waraqatak'`
  - `lib/core/constants/app_constants.dart:21`: Google Play Store URL with ID `com.elmahdi.waraqatak`
  - `lib/services/activation_service.dart:45`: `static const String appSlug = 'com.elmahdi.waraqatak'`
  - `lib/services/app_ops_service.dart:24`: `static const String appSlug = 'com.elmahdi.waraqatak'`
  - `lib/services/license_service.dart:98`: MethodChannel `'com.elmahdi.waraqatak/device'`
  - `lib/services/app_diagnostics_service.dart:369`: References `AppOpsService.appSlug`
  - `android/app/build.gradle.kts`: `applicationId = "com.elmahdi.waraqatak"`
- **API (`api.almhdy24.com`)**:
  - `app/Database/Seeds/DatabaseSeeder.php:35`: Seeds Waraqatak with `'slug' => 'waraqatak'`
  - `app/Config/AppChannels.php:11`: `'waraqatak' => 'play'`
  - `app/Services/ProductResolver.php:37-38`:
    ```php
    'com.elmahdi.waraqatak' => 'waraqatak',
    'waraqatak'             => 'com.elmahdi.waraqatak',
    ```
  - `app/Models/ProductModel.php:22`: Validation rule `'slug' => 'required|max_length[100]|regex_match[/^[a-z0-9_-]+$/]'` (rejects dots!)
  - `production_migration.sql:106`: Preserves existing products `1: 'com.elmahdi.waraqatak'`, `2: 'cashirak-pos'`
- **PANEL (`panel.almhdy24.com`)**:
  - `views/products.php:48`: HTML5 validation `pattern="[a-z0-9_-]+"` (rejects dots!)
  - `views/licenses.php:63`: Displays `$lic['product_slug']`
  - `views/quick_issue.php:124`: Dropdown uses `$p['slug']`

### 2. Signed Payload Claims
- **Legacy `signed_long` keys**:
  - Issued in `app/Services/LicenseIssuanceService.php:143`:
    `'app_slug' => $product['slug']` (stored as `'waraqatak'` if product slug is `'waraqatak'`).
  - Read in APP `lib/services/license_key.dart:46-51`: parses `json['app_slug']`.
  - Claim check in APP `lib/services/license_key.dart:76-79`:
    `allowsActivation(..., required String expectedAppSlug) => appSlug == expectedAppSlug`.
- **Short keys & activation tokens**:
  - Issued in `app/Services/SigningService.php:82`:
    `'prod' => $productSlug`
  - Token verification in API `app/Services/ActivationService.php:342`:
    `isProductMismatch($expectedProductSlug, $tokenProd)`

### 3. Published Build `1.1.4+13` Behavior
- Tag `v1.1.4+13`:
  - `docs/release-notes-1.1.4+13.md:18`: "Enforced explicit `product: 'waraqatak'` in all activation requests, preventing cross-product key activation."
  - `v1.1.4+13:lib/services/activation_service.dart:166, 235, 255, 271, 289`: Passed hardcoded `product: 'waraqatak'` to `activateLicense`, `deactivateLicense`, `verifyLicense`, `claimTrial`, `checkTrialStatus`.
  - `v1.1.4+13:lib/services/app_ops_service.dart:214`: Passed `product: appSlug` (`'com.elmahdi.waraqatak'`) to `/ops/inbox/sync` and `/ops/config`.
- **Legacy Rule Triggered**: Because build `1.1.4+13` is in the field transmitting `product: 'waraqatak'`, the API MUST support a documented, read-only compatibility mapping in `ProductResolver` that accepts `'waraqatak'` in incoming requests, maps it to canonical `'com.elmahdi.waraqatak'`, but never writes it to the database or newly issued tokens/keys.

---

## B. License Pipeline End-to-End

### 1. Stages
1. **Issue:** Admin creates license via `POST /api/v1/admin/licenses` or quick issue. For `signed_long`, signs payload with RSA-2048/SHA-256. For short keys, generates 12-char Crockford Base32 key with mod-32 checksum.
2. **Delivery:** Offline transmission to user.
3. **Activate:** User submits key. App calls `ActivationService.activate()` -> `POST /api/v1/pay/licenses/activate`.
   - API verifies key, hardware `machine_id` (4-128 chars), and product.
   - For `signed_long`: issues legacy activation token `{license_id, app_slug, machine_id, activated_at, expires_at}`.
   - For short: issues token `{v:1, lid, prod, did, iat, exp, typ}`.
4. **Store:** App writes `wq_license_key`, `wq_license_expiry`, `wq_license_status` (`'active'`), `wq_license_type`, `wq_activation_token` to EncryptedSharedPreferences via `LicenseStorage`.
5. **Offline Check:** `LicenseService.checkEntitlement()` executes `_compute()`:
   - Reads storage keys. Checks monotonic clock guard (`_effectiveNow`).
   - If `wq_license_status == 'revoked'`, returns `licenseRevoked`.
   - **Defect F4:** If `wq_license_status == 'expired'`, `_compute()` fails to check it and falls through!
6. **Verify:** App calls `LicenseService.verifyLicenseOnline()` -> `POST /api/v1/pay/licenses/verify`.
   - API verifies signature, token expiry, product match, database status, and device registration.
7. **Expiry & Revoke:**
   - On server rejection, API returns 401 with `error` string.

### 2. Server Reason vs. App Reaction Matrix

| Server Reason (`error` in JSON) | API HTTP Code | App Action Today (`verifyLicenseOnline`) | Correct? | Risk / Assessment |
|---|---|---|---|---|
| `license_expired` | 401 | Writes `_kLicenseStatus = 'expired'`, triggers `onLicenseExpired()` | **No** (Defect F4: `_compute` ignores stored 'expired') | User still gets Pro offline if local key has no expiry |
| `license_revoked` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Immediately disables Pro features |
| `license_refunded` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Correct fail-closed |
| `license_flagged` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Correct fail-closed |
| `device_not_registered` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Device was unlinked in admin panel |
| `device_revoked` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Specific device revoked |
| `device_deactivated` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Device was deactivated |
| `device_mismatch` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Token transferred to other hardware |
| `product_mismatch` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Cross-product attack |
| `license_not_found` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Key deleted from database |
| `invalid_signature_or_payload` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Tampered token |
| `invalid_machine_id` | 401 | Writes `_kLicenseStatus = 'revoked'`, triggers `onLicenseRevoked()` | **Yes** | Malformed client hardware ID |
| `429 Too Many Requests` | 429 | `ActivationService.verifyLicenseOnline` catches and returns `null` | **Yes** | Preserves existing offline entitlement |
| `5xx Server Error` | 500/503 | Catches and returns `null` | **Yes** | Preserves existing offline entitlement |

*Paying user revocation risk:* If `verifyLicenseOnline()` encounters transient server issues returning non-401 (e.g. 500, timeouts), it safely preserves offline access. Terminal 401 responses explicitly revoke or expire.

---

## C. Trial System Analysis

1. **Ownership & Start:**
   - Client starts local clock via `LicenseService._getOrInitTrialStart()` upon first initialization.
   - Server claims authoritative trial via `AppTrialModel::claimOrGetTrial()` with `UNIQUE(product_id, machine_id)`.
2. **Reinstallation:**
   - EncryptedSharedPreferences are wiped on app uninstall.
   - Machine ID is computed from `Settings.Secure.ANDROID_ID` hashed with SHA-256 (`LicenseService.getOrCreateDeviceId()`).
   - Server lookup finds the existing record by `(product_id, machine_id)` and returns the original start/expiry timestamps. Fresh trial is **not** granted.
   - **Defect F7:** Class comment in `lib/services/license_service.dart:53-56` erroneously asserts reinstall gives a fresh trial.
3. **Clock-Rollback Guard:**
   - In `lib/services/license_service.dart:154-171`: `_effectiveNow()` persists `wq_last_seen`. If current device time `< last_seen`, `_effectiveNow` evaluates to `last_seen`.
4. **Data Safety at Expiry:**
   - Core accounting/bookkeeping functions (invoices, receipts, quotations, customer list, product catalog, PDF export, backup/restore) are in `FeatureAccess.freeFeatures` and are **never** locked or disabled.
   - Pro features (purchases, stocktake, bulk price updates, CSV import/export) gate access to new operations but never delete existing SQLite data.

---

## D. Notifications System Analysis

1. **`InboxController::sync` Contract:**
   - `readInput()`: Parses raw JSON without strict schema validation, tolerating unknown keys such as `app_build`.
   - Filters:
     - `product`: Matches via `ProductResolver`.
     - `machine_id`: Matches device.
     - `target_audience`: Derives from license key lookup (`active_license`, `expired_license`) or `client_reported_status` (`trial`), defaulting to `'all'`.
     - `min_app_version` / `max_app_version`: Handled via PHP `version_compare()`, which fails semver build tags.
     - `published_at` <= now, `expires_at` > now or NULL, `status = 'published'`, `deleted_at IS NULL`.
   - Response: Returns up to 50 active notifications, but does **not** return a complete set of active IDs for reconciliation (`active_ids`).
2. **Delivery & Read Tracking:**
   - `AppNotificationDeliveryModel::recordDeliveries`: Inserts `(notification_id, machine_id, delivered_at)`.
   - `AppNotificationDeliveryModel::markRead`: Updates `read_at`.
3. **Targeting Columns Present:**
   - `app_notifications` currently has: `id`, `product_id`, `title`, `body`, `category`, `action_url`, `target_audience`, `min_app_version`, `max_app_version`, `published_at`, `expires_at`, `is_active`, `status`, `idempotency_key`, `deleted_at`, `created_by`, `created_at`, `updated_at`.
   - Missing for Batch 3: `language` (all|ar|en), `severity` (info|warning|critical), `dismissible` (0/1), `action` (enum), `priority` (int).
4. **App Inbox & Sync:**
   - **Defect F2:** `app_ops_service.dart:216` hardcodes `'app_version': '1.1.3'`.
   - **Finding F3:** `app_ops_service.dart:221` transmits `license_key` plaintext on every inbox sync.
   - **Defect F6:** Deleting a notification in SQLite (`cached_notifications`) is undone on next sync because `InboxController::sync` re-delivers it unless tombstoned.
   - `min_supported_version` in Remote Config: Received in `AppOpsService.allowedConfigKeys` but not evaluated against runtime version.

---

## E. Support & Diagnostics Analysis

1. **About Screen:**
   - Exposes: App version (`PackageInfo`), Play Store rating link, WhatsApp support launcher, email launcher, Facebook page link, developer website.
   - Links to About: Currently only from `SettingsScreen:493`. Not linked from `LockedFeatureScreen`, `LicenseScreen`, or `ActivationScreen`.
2. **SDK & Correlation ID:**
   - The CI4 API generates UUIDv4 correlation IDs (`CorrelationFilter.php`) returned in HTTP header `X-Correlation-ID` and body `correlation_id`.
   - `packages/elmahdi_pay_flutter`: Neither `ElmahdiPayApiException` nor `ActivateLicenseResult` captures or exposes `correlation_id`.

---

## F. Entitlement & Licensing State Machine

| State | Detection Condition | Current UI / Copy | Defect / UX Gap |
|---|---|---|---|
| **No License (New)** | `wq_license_key == null`, trial within 14 days | Trial active banner / status badge | Clear |
| **Trial Active** | `trialDaysRemaining > 0` | "Trial active — X days left" | Clear |
| **Trial Expired** | `trialDaysRemaining <= 0` | "Trial expired", Pro features locked | Needs direct About support link & clear upgrade guidance |
| **Licensed (Active)** | Stored key valid, server status active | "License active", type displayed | Clean |
| **Expiring Soon** | Expiry within 7 days | In-app notification / banner | Needs clear renewal guidance without IAP/store link violation |
| **License Expired** | Server verify returns `license_expired` or local expiry passed | Server says expired, but F4 causes `_compute` to ignore it | **F4:** User retains Pro access offline |
| **License Revoked** | Server verify returns `license_revoked`, `refunded`, etc. | "License revoked" banner | Lacks reference ID and About support launcher |
| **Wrong Product** | Server verify returns `product_mismatch` or payload `app_slug` mismatch | Collapsed into generic "invalid" | Safe anti-enumeration, but needs support reference ID |
| **Device Limit Reached** | API activate returns 401/403 with `device_limit_reached` | Collapsed to `ActivationOutcome.invalid` | Needs clear error message indicating device limit |
| **Clock Tampered** | `now < _kLastSeen` | Monotonic clock pushes effective now forward | Transparent, no crash |
| **Offline Unverifiable** | Network fails during `verifyLicenseOnline()` | Existing stored entitlement maintained | Works as intended |
| **Server Error (5xx)** | Server returns 500/503 during activation | Maps to `ActivationOutcome.serverUnreachable` | Works as intended |

---

## G. Test Coverage & Audit Gaps

1. **APP (`test/services/`)**:
   - `activation_service_test.dart`: Covers offline, 429, 500, network exception, 401 anti-enumeration.
   - `license_service_test.dart`: Covers trial countdown, clock rollback, perpetual license, revoked license. **GAP:** No test for stored `expired` status in `_compute()`.
   - `app_ops_test.dart`: Tests remote config key allowlist, pending read queuing. **GAP:** No test for `syncInbox` payload versions or tombstones.
   - `play_compliance_test.dart`: Passes all 4 passes.
2. **API (`tests/Feature/`)**:
   - `DeviceManagementTest.php`: Tests activation, device limits, multi-device licenses.
   - `TrialManagementTest.php`: Tests trial claiming, idempotency, device conversion.
   - `OpsNotificationLifecycleTest.php`: Tests publish, archive, sync.
   - **GAP:** Standalone unit tests for version matching without framework boot.
3. **PANEL (`tests/`)**:
   - `OpsTest.php`, `ActionDispatchTest.php`, `HelpersTest.php`: Validate basic helpers.

---

## H. Backward Compatibility & Field App Matrix

- **App Version 1.1.4+13 in the field:**
  - Relies on API endpoints: `/api/v1/pay/licenses/activate`, `/pay/licenses/verify`, `/pay/trial/claim`.
  - Transmits `product: 'waraqatak'`.
  - Must be accepted transparently by API via read-only compatibility alias.
- **App Version 1.1.5-alpha+15 (current in-development):**
  - Transmits `product: 'com.elmahdi.waraqatak'`.

---

## Prioritized Defect & Gap List

### Critical
1. **[F4] License Expiry Ignored in `_compute()` (`lib/services/license_service.dart:192`):** Storing `'expired'` in `_kLicenseStatus` has no effect on offline computation; users retain active entitlement if the key had no local expiry or lifetime type.
2. **[F2] Hardcoded App Version `'1.1.3'` (`lib/services/app_ops_service.dart:216`):** Version targeting for notifications and diagnostics is broken for all users.
3. **[Batch 1] Product Identifier Inconsistency:** API `products.slug` is `'waraqatak'` while canonical app ID is `'com.elmahdi.waraqatak'`. Product model and panel regex reject dots.

### High
4. **[F6] Notification Deletion Reversion (`lib/database/database_helper.dart`):** Deleted cached notifications re-appear upon subsequent sync because there are no deletion tombstones.
5. **[F8] Unnecessary Trial Claims for Licensed Devices (`lib/services/app_ops_service.dart:272`):** `syncAll` calls `syncTrialWithServer` even when the device is actively licensed.
6. **[Batch 3] Semver Build Tag Version Incompatibility:** CI4 `version_compare` does not parse Semver build tags (e.g. `+16`). Need shared `VersionMatcher`.
7. **[Batch 5] Correlation ID Dropped in SDK (`packages/elmahdi_pay_flutter`):** Errors lack correlation IDs for customer support.

### Medium
8. **[F7] Inaccurate `LicenseService` Class Comment (`lib/services/license_service.dart:53`):** Claims reinstalls give fresh trials.
9. **[Batch 3] Arbitrary URL Security in Notifications:** Notifications currently allow arbitrary HTTPS URLs.
10. **[Batch 5] Missing About Links from Gating Screens:** Users cannot easily reach support from locked feature or license screens.

### Low
11. **[F3] License Key Sent on Inbox Sync:** Key transmitted in plaintext payload during inbox sync.
