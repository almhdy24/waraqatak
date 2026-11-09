# Changelog

All notable changes to the AlmHdy Analytics Flutter SDK will be documented in this file.

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
