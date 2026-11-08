# AlmHdy Analytics: Architecture, Integration & Operation Guide

**Target Host App:** Waraqatak (ورقتك) Flutter Application (`warqatek`)  
**Package:** `almhdy_analytics` (v1.0.0 vendored in `packages/almhdy_analytics/`)  
**Architecture Date:** 2026-11-08  
**Branch:** `feat/analytics`  

---

## 1. Architectural Principles

Waraqatak is an offline-first commercial paperwork automation application designed with sovereign privacy principles. Telemetry integration conforms strictly to the following architectural rules:

1. **Zero Database-Layer Interaction:**
   Analytics code is completely decoupled from SQLite database code. `DatabaseHelper` and all files under `lib/database/` are forbidden from importing or invoking `AnalyticsService` (enforced by `test/guards/analytics_guards_test.dart`). All emissions occur in the service and UI presentation layers *after* successful database transactions commit.
2. **Strict Allowlist & Discretization (Bucketing):**
   Events, property keys, and acceptable values are strictly allowlisted. Free-text strings, monetary amounts, costs, item prices, customer names, phone numbers, and raw identifiers are rejected at runtime and statically guarded. Numerical metrics (e.g. item count, user count) are discretized into coarse buckets (`'1'`, `'2-5'`, `'6-20'`, `'21+'`).
3. **Fail-Safe & Non-Blocking Execution:**
   Every analytics call is fire-and-forget, wrapped in defensive `try/catch` boundaries with errors silently swallowed in release mode. Initialization executes after the first frame (`addPostFrameCallback`) without impacting splash timing. Network disconnects and backend timeouts have zero impact on application responsiveness.
4. **Isolated Dependency Entry Point:**
   Only `lib/services/analytics/analytics_service.dart` is permitted to import `package:almhdy_analytics`. All application surfaces consume the singleton `AnalyticsService.instance`.
5. **Multi-User State Awareness:**
   When multi-user mode is active and the application terminal is locked (e.g. `PinLockScreen`), all event emissions are immediately dropped to prevent leaking locked-state telemetry.

---

## 2. Event Catalog & Taxonomy

| Event (`AnalyticsEvent`) | Name | Allowed Properties | Description |
|---|---|---|---|
| `appOpened` | `app_opened` | `language`: `ar` \| `en`<br>`theme`: `light` \| `dark` \| `system`<br>`multi_user`: bool | Dispatched after app shell mounts |
| `screenViewed` | `screen_viewed` | `screen`: `home`, `invoices`, `products`, `customers`, `suppliers`, `reports`, `settings`, `sales_report`, `product_report`, `inventory_report`, `advanced_inventory`, `purchases_report`, `accounting`, `statement`, `roles`, `users`, `audit_trail`, `license`, `backup`, `database_diagnostic` | Navigation tab or major report opened |
| `documentCreated` | `document_created` | `type`: `invoice` \| `purchase` \| `quotation` \| `receipt` \| `expense` \| `custom`<br>`has_payment`: bool<br>`item_count_bucket`: `1` \| `2-5` \| `6-20` \| `21+` | Document committed to database |
| `documentCancelled` | `document_cancelled` | `type`: `invoice` \| `purchase` \| `quotation` \| `receipt` \| `expense` \| `custom` | Document cancellation completed |
| `paymentRecorded` | `payment_recorded` | `method_category`: `cash` \| `bank` \| `mobile` \| `other` | Payment receipt or FIFO allocation posted |
| `productSaved` | `product_saved` | `is_new`: bool | Product catalog entry created or updated |
| `contactSaved` | `contact_saved` | `kind`: `customer` \| `supplier`<br>`is_new`: bool | Contact record created or updated |
| `stocktakeFinalized`| `stocktake_finalized`| *(None)* | Stocktake reconciliation finalized |
| `reportOpened` | `report_opened` | `report`: `sales`, `products`, `inventory`, `advanced_inventory`, `purchases`, `accounting`, `statement`, `tax` | Report screen opened |
| `pdfShared` | `pdf_shared` | `kind`: `document` \| `report` \| `statement` | PDF exported or shared via OS share sheet |
| `csvExported` | `csv_exported` | `kind`: `products` \| `other` | CSV catalog exported |
| `csvImported` | `csv_imported` | `kind`: `products` \| `other`<br>`ok`: bool | CSV catalog import executed |
| `backupCreated` | `backup_created` | `destination`: `local` \| `drive` \| `user_chosen`<br>`encrypted`: bool | Backup file created |
| `backupRestored` | `backup_restored` | `ok`: bool | Backup database restored |
| `paywallViewed` | `paywall_viewed` | `feature`: `multi_user` \| `cloud_backup` \| `advanced_reports` \| `bulk_pricing` \| `general` | Pro upgrade modal or paywall presented |
| `activationStarted` | `activation_started` | *(None)* | User submitted an activation key |
| `activationResult` | `activation_result` | `ok`: bool<br>`reason`: `success`, `network_error`, `invalid_key`, `expired`, `device_limit`, `revoked`, `unknown` | Activation response evaluated |
| `multiUserEnabled` | `multi_user_enabled` | `user_count_bucket`: `1` \| `2-3` \| `4-10` \| `11+` | Multi-user setup wizard completed |
| `migrationResult` | `migration_result` | `from_version`: int<br>`to_version`: int<br>`ok`: bool | Database schema upgrade executed |
| `errorCaught` | `error_caught` | `area`: `backup`, `restore`, `activation`, `export`, `sync`, `migration`<br>`kind`: `network`, `io`, `format`, `crypto`, `timeout`, `state`, `unknown` | Handled edge-case failure in core flows |

---

## 3. How to Add an Event Safely

To add a new event or modify properties without breaking privacy invariants:

1. **Update Enum:** Add the event to `enum AnalyticsEvent` in `lib/services/analytics/analytics_service.dart`.
2. **Define Property Allowlist:** In `AnalyticsService._validateKeyAndValue()`, declare the strict set of permitted property names and value types.
3. **Verify Forbidden Keys:** Ensure NO sensitive keys (`amount`, `price`, `cost`, `total`, `name`, `phone`, `license`, `user`, etc.) are included.
4. **Implement Discretization:** For any numeric count, provide a coarse bucket helper (do not send raw integers).
5. **Add Guard Test:** Update `test/guards/analytics_guards_test.dart` to include the event name in `allowedEventNames`.
6. **Add Unit Test:** Add a test case in `test/services/analytics_instrumentation_test.dart`.

---

## 4. Building with Environment Defines

The project key is supplied at build time via `--dart-define` so no live secrets exist in version control:

```bash
# Production Android APK build
flutter build apk --release \
  --dart-define=ALMHDY_ANALYTICS_KEY=ak_live_xxxxxxxxxxxxxxxxxxxxxxxx

# Production App Bundle
flutter build appbundle --release \
  --dart-define=ALMHDY_ANALYTICS_KEY=ak_live_xxxxxxxxxxxxxxxxxxxxxxxx
```

### Debug & Testing Behavior:
- If `ALMHDY_ANALYTICS_KEY` is omitted or empty, `AnalyticsService.initialize()` disables the subsystem completely. No SDK initialization occurs, no timers run, and no network traffic is generated.
- In `kDebugMode`, telemetry is disabled unless `--dart-define=ALMHDY_ANALYTICS_KEY=...` is explicitly passed.

---

## 5. Verifying Ingestion in the Dashboard

1. Build or run the app with a valid test/live project key.
2. Perform key actions (e.g. create a document, view reports, or create a backup).
3. Log in to the AlmHdy Analytics dashboard:
   `https://panel.almhdy24.com/analytics` or `https://analytics.almhdy24.com`.
4. Open the **Live Activity** tab. Events appear within 5–10 seconds (default client flush interval: 5 seconds).

---

## 6. Privacy & Opt-Out Guarantees

- **Default-On with In-App Opt-Out:** In accordance with standard productivity applications, anonymous operational telemetry is enabled by default. Users can disable tracking anytime in **Settings > Support & Info > Anonymous usage statistics**.
- **Role-Based Control:** The settings toggle is protected by `PermissionGate(permission: PermissionRegistry.settingsManage)` to prevent unauthorized employees from disabling operational metrics.
- **Immediate Purge:** Toggling opt-out immediately clears the local memory queue, updates the disk buffer, and invokes the backend opt-out API (`POST /api/v1/analytics/opt-out`).

---

## 7. Release Checklist

Before releasing a build with analytics enabled:
- [ ] Project created in `api.almhdy24.com` dashboard and live API key issued (`ak_live_...`).
- [ ] Privacy policy paragraph updated on `https://almhdy24.com/privacy` (using [PRIVACY_TEXT.md](file:///data/data/com.termux/files/home/projects/waraqatak/docs/analytics/PRIVACY_TEXT.md)).
- [ ] Release build compiled with `--dart-define=ALMHDY_ANALYTICS_KEY=ak_live_...`.
- [ ] Test release APK on test device to verify zero network errors and smooth offline buffering.
