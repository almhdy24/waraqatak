import 'dart:convert';

/// Claims embedded in a server-issued license key.
///
/// Keys are `base64url(payload).base64url(signature)` where payload is JSON
/// with `app_slug` and `expires_at` (ISO-8601, null for lifetime). The
/// signature is verified by the server on activation; the app only reads the
/// claims to reject keys for other apps or already expired keys, and to store
/// the expiry locally so time-limited licenses end on the device.
class LicenseKeyClaims {
  final String? appSlug;
  final DateTime? expiresAt;

  const LicenseKeyClaims({this.appSlug, this.expiresAt});

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
      return LicenseKeyClaims(
        appSlug: slug is String ? slug : null,
        expiresAt: expires is String ? DateTime.tryParse(expires) : null,
      );
    } catch (_) {
      return null;
    }
  }

  bool isExpiredAt(DateTime now) =>
      expiresAt != null && expiresAt!.isBefore(now);
}
