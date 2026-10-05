import 'dart:convert';

/// Claims embedded in a server-issued license key.
///
/// Keys are `base64url(payload).base64url(signature)` where payload is JSON
/// with `app_slug`, `expires_at` (ISO-8601, null for lifetime) and, on newer
/// keys, `license_type`. The signature is verified by the server on
/// activation; the app only reads the claims to reject keys for other apps,
/// already expired keys and time-limited keys without an expiry, and to store
/// the expiry locally so time-limited licenses end on the device.
class LicenseKeyClaims {
  /// `license_type` value of a key that never expires.
  static const String lifetimeType = 'lifetime';

  final String? appSlug;
  final DateTime? expiresAt;

  /// `license_type` claim, or null for legacy keys that do not carry one.
  final String? licenseType;

  /// True when `expires_at` or `license_type` is present but unusable (for
  /// example an unparseable date). Such a key must not be activated.
  final bool malformed;

  const LicenseKeyClaims({
    this.appSlug,
    this.expiresAt,
    this.licenseType,
    this.malformed = false,
  });

  /// Parses the payload of [key], or returns null when the key is not in the
  /// signed `payload.signature` format.
  static LicenseKeyClaims? tryParse(String key) {
    final dot = key.indexOf('.');
    if (dot <= 0 || dot == key.length - 1) return null;
    try {
      final segment = key.substring(0, dot);
      final json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segment))),
      );
      if (json is! Map<String, dynamic>) return null;
      final slug = json['app_slug'];
      final expires = json['expires_at'];
      final type = json['license_type'];
      final expiresAt = expires is String ? DateTime.tryParse(expires) : null;
      return LicenseKeyClaims(
        appSlug: slug is String ? slug : null,
        expiresAt: expiresAt,
        licenseType: type is String ? type.trim().toLowerCase() : null,
        malformed: (expires != null && expiresAt == null) ||
            (type != null && type is! String),
      );
    } catch (_) {
      return null;
    }
  }

  bool isExpiredAt(DateTime now) =>
      expiresAt != null && expiresAt!.isBefore(now);

  /// True for a key that declares a limited license type but carries no
  /// expiry. A server issuance mistake of this kind would otherwise give
  /// unlimited access, so such keys are refused. Legacy keys without a
  /// `license_type` are not affected.
  bool get limitedWithoutExpiry =>
      licenseType != null && licenseType != lifetimeType && expiresAt == null;

  /// Whether this key may be activated at [now] for [expectedAppSlug].
  bool allowsActivation(DateTime now, {required String expectedAppSlug}) =>
      !malformed &&
      appSlug == expectedAppSlug &&
      !isExpiredAt(now) &&
      !limitedWithoutExpiry;
}
