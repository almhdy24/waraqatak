/// Configuration constants and defaults for AlmHdy Analytics telemetry.
class AnalyticsConfig {
  AnalyticsConfig._();

  /// Hard-coded project key for AlmHdy Analytics telemetry ingestion.
  ///
  /// This is a WRITE-ONLY ingestion key that can be revoked, paused, or
  /// rotated from the server dashboard at any time. It is NOT a secret and grants
  /// no administrative access, read capabilities, or access to sensitive user data.
  static const String defaultProjectKey =
      'ak_live_ad67e998e5cbed8e9ec242fe0792f291';
}
