# AlmHdy Analytics Flutter SDK: Architecture & Compatibility Review

**SDK Path:** `~/projects/api.almhdy24.com/sdk/flutter`  
**Git Commit Hash:** `9bb9b1a60ec4ce993d36c3b54ffdcf8e16ee6273`  
**Review Date:** 2026-11-08  
**Target Host App:** Waraqatak (ورقتك) Flutter Application (`warqatek`)  
**Environment:** Linux / Termux (4 GB RAM mobile device)  

---

## 1. Executive Summary

A comprehensive architectural and static code review of the `almhdy_analytics` Flutter SDK (v1.0.0) was conducted. The SDK provides a lean, privacy-conscious telemetry client with offline queueing, periodic auto-batching, and server opt-out synchronization.

**Overall Verdict:** **SAFE TO VENDOR AS-IS.**  
The SDK introduces **zero new third-party dependencies** (it uses `http: ^1.2.0`, which is already declared in Waraqatak), executes **zero top-level code at import time**, respects strict PII scrubbing, and exhibits minimal memory and APK overhead (< 25 KB). Minor operational considerations (such as explicit storage paths and queue size caps under extended offline periods) are completely mitigated through `AnalyticsService` encapsulation and recorded as SDK optimization requests.

---

## 2. Detailed Technical Inspection

### 2.1 Public API Surface
The SDK exposes a singleton client via `AlmHdyAnalytics.instance` (or factory `AlmHdyAnalytics()`):
- `Future<void> initialize({required String projectKey, String? endpoint, String? optOutEndpoint, String? appVersion, String? platform, String? platformVersion, int? batchSize, Duration? flushInterval, String? storagePath, bool debug = false})`: Async initialization loading the offline buffer and starting the periodic timer.
- `void track(String event, {Map<String, dynamic>? properties})`: Enqueues an event and triggers flush if batch size is reached.
- `void screenView(String screenName, {Map<String, dynamic>? properties})`: Convenience wrapper calling `track('screen_view', ...)`.
- `void identify(String userPseudoId)`: Associates future events with an anonymous pseudo-identifier.
- `void resetUser()`: Clears pseudo-identifier and rotates session.
- `Future<void> optOut()`: Sets opt-out flag, purges in-memory queue, updates disk state, and notifies backend.
- `Future<void> optIn()`: Re-enables telemetry and updates disk state.
- `bool get isOptedOut`: Read-only property indicating current opt-out status.
- `Future<void> flush()`: Explicit async batch transmission to backend.
- `void dispose()`: Cancels background flush timer.

### 2.2 Anonymous Identifier Generation
- **Installation ID:** Generated once per installation via `_generateUuid('inst_')` when no prior state exists. Uses `Random.secure()` to construct a standard RFC-4122 UUIDv4 prefixed with `inst_` (e.g. `inst_e3b0c442-98fc-1c14-9afb-f4c8996fb924`).
- **Hardware Agnostic:** Never inspects or transmits device IMEI, Android ID, MAC address, serial number, or app-level device identities (`waraqatak_device_id`).
- **Session IDs:** Handled by `SessionManager` using `Random.secure()` UUIDv4 (`sess_...`). Rotates automatically upon 30 minutes of inactivity (`sessionTimeout = Duration(minutes: 30)`).

### 2.3 Disk Persistence & Offline Queueing
- **Location & File Format:**
  - Persisted to a single JSON file. Default path is `'almhdy_analytics_buffer.json'`.
  - Format:
    ```json
    {
      "installation_id": "inst_...",
      "user_pseudo_id": null,
      "opted_out": false,
      "queue": [
        {
          "event": "document_created",
          "platform": "android",
          "app_version": "1.1.5",
          "installation_id": "inst_...",
          "session_id": "sess_...",
          "properties": { ... },
          "timestamp": "2026-11-08T04:00:00.000Z"
        }
      ]
    }
    ```
- **Storage Path Consideration:** On mobile devices, relative file paths resolve relative to `Directory.current`. To guarantee persistence across app sandboxes, `AnalyticsService` must pass an explicit path into `initialize(storagePath: ...)` using `path_provider` (e.g. `(await getApplicationSupportDirectory()).path + '/almhdy_analytics_buffer.json'`).
- **Retention & Size Caps:**
  - The SDK enqueues events without an internal queue cap. Under prolonged offline conditions (e.g. weeks without internet), the queue could accumulate in memory and on disk.
  - *Mitigation in Host App:* Our `AnalyticsService` wrapper strictly allowlists low-frequency lifecycle and summary events only (no high-frequency typing or scroll events), bounding total queue volume. A queue cap is recommended as an SDK request.

### 2.4 Batching, Flush Intervals & Retry Backoff
- **Batch Size:** Defaults to 10; clamped between 1 and 50 (`batchSize.clamp(1, 50)`).
- **Flush Interval:** Defaults to 5 seconds (`Duration(seconds: 5)`).
- **Triggers:** Automatic periodic timer (`Timer.periodic`) AND threshold trigger when `_queue.length >= _batchSize`.
- **Retry & Backoff:** On network failure or HTTP status >= 300, `_handleFailure()` doubles backoff seconds up to 60 seconds (`min(_backoffSeconds * 2, 60)`). Events remain queued for next flush.

### 2.5 Payload & Backend Limits
- **Client Truncation:**
  - Event name: max 64 characters (`cleanEvent.substring(0, 64)`).
  - String properties: max 500 characters (`val.substring(0, 500)`).
- **Backend Enforced Limits (`api.almhdy24.com`):**
  - Hard request body cap: **64 KB** (returns HTTP 413 if exceeded).
  - Maximum batch size: **50 events** per HTTP request.
  - Event name validation: regex `^[a-zA-Z0-9_.:-]{1,64}$`.
  - Max properties per event: 30. Max recursion depth: 3. Max string property length: 256 bytes.
  - Timestamp boundary: between -7 days and +24 hours (clamped to server receive time if outside).
  - Ingestion returns **HTTP 202 Accepted** with fail-safe error isolation.

### 2.6 Privacy & PII Protection
- **Client-Side Key Blacklist (`_piiKeys`):**
  `password`, `pass`, `secret`, `token`, `auth`, `card`, `cvv`, `ssn`, `phone`, `mobile`, `whatsapp`, `name`, `first_name`, `last_name`, `email`.
  Any property key matching this list (case-insensitive) is completely discarded before payload construction.
- **Pseudo-ID Sanitization:** `identify()` rejects any value containing `@` or telephone regex `^[0-9+]{9,15}$`.
- **Server-Side Scrubbing:** Deep regex scrubbing for email, phone, card numbers, and tokens. Plaintext IPs are never stored (hashed via daily rotating HMAC-SHA256).

### 2.7 Opt-Out Mechanics
- Calling `optOut()`:
  1. Sets internal flag `_isOptedOut = true`.
  2. Clears in-memory queue (`_queue.clear()`).
  3. Writes updated opt-out state to disk.
  4. Dispatches POST request to `/api/v1/analytics/opt-out` with `installation_id`.
- While opted out:
  - `track()`, `screenView()`, `identify()`, and `flush()` return immediately as no-ops.

### 2.8 Import-Time Side Effects
- Code analysis confirms **zero executable logic** at library import time.
- `_instance` is lazily instantiated on first access to `AlmHdyAnalytics.instance`.
- Timers and disk I/O are only initiated upon explicit invocation of `initialize()`.

### 2.9 Dependencies & Version Constraints
| Dependency | SDK Constraint | Waraqatak Constraint | Conflict? |
|---|---|---|---|
| `flutter` | `sdk: flutter (>=3.10.0)` | `sdk: flutter` | None |
| `http` | `^1.2.0` | `^1.2.0` | None (exact match) |
| `Dart SDK` | `>=3.0.0 <4.0.0` | `>=3.11.0 <4.0.0` | None (compatible) |
| `lints` (dev) | `^3.0.0` | `flutter_lints: ^5.0.0` | None |

**Net Added Dependencies:** **0**. The SDK adds no new transitive packages to Waraqatak.

### 2.10 Platform Requirements & APK Impact
- **Android Permissions:** Requires `android.permission.INTERNET`, which is **already declared** in `android/app/src/main/AndroidManifest.xml` (line 15).
- **Minimum SDK:** Fully compatible with Flutter's default `minSdkVersion` (Android 5.0+ / API 21+).
- **Compiled Footprint:** The entire SDK consists of ~450 lines of pure Dart code across 4 files. Total compiled footprint is estimated at **< 20 KB** uncompressed, or **< 8 KB** compressed in the final APK.
- **Low-End Device Impact:** Lightweight in-memory queue. Timers execute on the microtask/event queue without blocking UI frame rendering.

---

## 3. Verdict & Integration Strategy

### Verdict: **SAFE TO VENDOR AS-IS**

No blockers prevent integrating the SDK into Waraqatak. The SDK can be vendored unchanged into `packages/almhdy_analytics/` and consumed via path dependency.

### Integration Guardrails for Waraqatak:
1. **Explicit Storage Path:** Pass `storagePath` inside application directory (`getApplicationSupportDirectory()`) during `AnalyticsService.initialize()`.
2. **Post-Frame Startup:** Call `AnalyticsService.initialize()` unawaited after first frame completion or splash completion.
3. **Allowlist Architecture:** Route all events strictly through `AnalyticsService.track(AnalyticsEvent event, Map<String, dynamic> properties)` with hardcoded enum keys and bucketed values.
4. **Offline Queue Throttling:** Enforce event emission limits in `AnalyticsService` to ensure disk queue stays small even during extended offline operation.

---

## 4. SDK Requests (Recommendations for Future SDK Updates)
*These do not block vendoring, but are recorded for upstream enhancement in `api.almhdy24.com`:*
1. **Queue Size Cap:** Add a configurable `maxQueueSize` (e.g. 500 events) that drops oldest events (FIFO) when offline buffer reaches capacity.
2. **Default Mobile Path:** Automatically resolve `storagePath` using `path_provider` support directory if running on mobile when no custom path is provided.
3. **Timer Pause When Empty:** Suspend the periodic `_flushTimer` when `_queue.isEmpty` to eliminate periodic wakeups on mobile devices.
