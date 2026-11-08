import 'dart:io';

/// Configuration constants and injection points for AlmHdy Analytics telemetry.
class AnalyticsConfig {
  AnalyticsConfig._();

  /// Hard-coded project key for AlmHdy Analytics telemetry ingestion.
  ///
  /// This is a WRITE-ONLY ingestion key that can be revoked, paused, or
  /// rotated from the server dashboard at any time. It is NOT a secret and grants
  /// no administrative access, read capabilities, or access to sensitive user data.
  static const String defaultProjectKey =
      'ak_live_ad67e998e5cbed8e9ec242fe0792f291';

  static String? _injectedKey;

  /// Returns the active project key.
  ///
  /// If an explicit key was injected via [injectKey], it is returned.
  /// Otherwise, when running inside unit tests (`FLUTTER_TEST` environment variable),
  /// returns `''` (empty string) so analytics stays disabled in unit tests by default.
  /// In normal runtime environments, returns [defaultProjectKey].
  static String get projectKey {
    if (_injectedKey != null) {
      return _injectedKey!;
    }
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return '';
      }
    } catch (_) {}
    return defaultProjectKey;
  }

  /// Injects a custom key (or empty string `''` to disable telemetry in tests).
  static void injectKey(String? key) {
    _injectedKey = key;
  }

  /// Resets any injected test key back to null.
  static void reset() {
    _injectedKey = null;
  }
}
