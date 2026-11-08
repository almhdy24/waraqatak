# Changelog

All notable changes to the Waraqatak (ورقتك) project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0-beta.1] - 2026-11-08

> **Note:** This is a pre-release beta build (`1.2.0-beta.1+23`) for testing telemetry, error reporting, and privacy controls prior to production rollout.

### Added
- **AlmHdy Analytics Integration (v1.1.0 SDK):**
  - Offline-first telemetry using the upgraded AlmHdy Analytics Flutter SDK with configurable queue sizing (default: 500 events) and idle flush timer pause/resume.
  - Hard-coded write-only project ingestion key (`ak_live_ad67e998e5cbed8e9ec242fe0792f291`), removing the `--dart-define` key requirement while keeping the key injectable and empty by default in unit tests.
- **Dual Telemetry Channels & Independent Settings Toggles:**
  - Separated anonymous usage statistics and anonymous error reports into two distinct channels with independent toggles in Settings.
  - Legacy opt-out migration preserving prior opt-outs across both channels.
  - Channel isolation: opting out of either channel clears its enqueued events immediately without affecting the other channel.
  - Permission-gated management under `settings.manage` (hidden or view-only for restricted roles).
- **First-Run Privacy Notice:**
  - One-time non-blocking privacy notice dialog displayed on first launch after multi-user unlock.
  - Clear explanation of anonymous telemetry with direct one-tap navigation to Settings to customize preferences.
  - Notice status is persisted locally and never displayed again across updates.
- **Privacy-Preserving Error Sanitizer:**
  - Comprehensive `ErrorSanitizer` redacting phone numbers, email addresses, financial amounts in all supported currencies, customer identifiers, auth tokens, license keys, and local file system paths.
  - Fingerprint deduplication and session capping (max 20 errors per session).
  - Global error reporting integration hooking `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded` with non-blocking, fail-safe chaining.
- **Strict Invariant Protections:**
  - Multi-user lock-screen suppression (no events or error reports emitted while locked).
  - Silent failure on server rejections without crashing the app or disrupting offline workflows.
