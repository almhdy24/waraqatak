# Changelog

All notable changes to the AlmHdy Analytics Flutter SDK will be documented in this file.

## [1.2.0] - 2026-11-15

### Added
- **Centralized Reports & Monitoring Client:** Added `AlmHdyReportsClient` providing type-safe querying of the unified Analytics & Reports backend:
  - `getOverview()`: Executive KPIs (DAU, WAU, MAU, total sessions, events).
  - `getUnifiedMonitoring()`: Crash-free session rates, crash grouping, server errors, and infrastructure health.
  - `getGeographicDistribution()`: Country and regional distribution metrics.
  - `getDeviceIntelligence()`: Device hardware models, OS versions, platforms, and app versions.
  - `getFunnels()`: Commercial funnel conversion tracking and trial conversion metrics.
  - `getFeatures()`: Feature adoption segmentation (high, moderate, low adoption).
  - `getCohorts()`: Weekly user cohort retention tracking.
  - `exportData()`: Full analytics data export in structured JSON or CSV format.
- **Client-Side Deduplication (`event_id`):** Every tracked event now automatically receives a client-generated UUID `event_id` (`ev_...`) enabling idempotent backend deduplication on retries.
- **Hardware & Geographic Dimensions:** `AlmHdyAnalytics.initialize()` now accepts optional `deviceModel`, `country`, and `region` attributes, and `AlmHdyEvent` serializes them for unified backend aggregation.

## [1.1.0] - 2026-11-08

### Added
- **Configurable `maxQueueSize`:** Added `maxQueueSize` parameter to `AlmHdyAnalytics.instance.initialize()` (default: 500 events). Enforces FIFO eviction when offline event volume reaches capacity, pruning the oldest events first and persisting state across application restarts.
- **Automatic `storagePath` Resolution on Mobile:** On Android and iOS targets, omitting `storagePath` now automatically resolves to `${getApplicationSupportDirectory().path}/almhdy_analytics_buffer.json` via `path_provider`. Explicit paths remain fully supported and take precedence.
- **Battery-Saving Timer Pause:** The periodic background flush timer now automatically pauses when the event queue is empty and immediately resumes when a new event is enqueued. Eliminates unnecessary CPU wakeups on battery-constrained devices.
- **Unit Test Suite:** Added unit test coverage across queue eviction, storage path resolution, and timer lifecycle states.

### Changed
- Offline buffer persistence is now executed synchronously during event enqueueing to prevent event loss if network flush fails.
- Bumped SDK version to `1.1.0`.

## [1.0.0] - 2026-11-08

### Added
- Initial release of AlmHdy Analytics Flutter SDK.
- Cross-platform support for Android, iOS, Windows, macOS, Linux.
- Offline buffer persistence in JSON file.
- Automatic batch flushing and session management.
- Zero-PII sanitization and opt-out support.
