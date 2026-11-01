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

  /// Modern perpetual license type from api.almhdy24.com.
  static const String perpetualType = 'perpetual';

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
      licenseType != null &&
      licenseType != lifetimeType &&
      licenseType != perpetualType &&
      expiresAt == null;

  /// Whether this key may be activated at [now] for [expectedAppId].
  bool allowsActivation(DateTime now, {required String expectedAppId}) =>
      !malformed &&
      appSlug == expectedAppId &&
      !isExpiredAt(now) &&
      !limitedWithoutExpiry;
}

/// Crockford Base32 short activation key (12 characters, XXXX-XXXX-XXXX).
///
/// Format: 11 random Crockford Base32 characters + 1 modulo-32 checksum character.
/// Normalization: uppercase, strip whitespace/hyphens, map O->0, I->1, L->1.
class ShortLicenseKey {
  ShortLicenseKey._();

  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int keyLength = 12;

  /// Normalizes a user-supplied key:
  /// - Uppercased
  /// - Whitespace, newlines, and hyphens removed
  /// - Common optical confusions mapped: O->0, I->1, L->1
  ///
  /// Returns empty string if the result does not contain exactly 12 Crockford symbols.
  static String normalize(String input) {
    var s = input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    s = s.replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1');
    if (s.length != keyLength) return '';
    for (var i = 0; i < s.length; i++) {
      if (!alphabet.contains(s[i])) return '';
    }
    return s;
  }

  /// Verifies the checksum (character 12 equals the sum of positional values
  /// of the first 11 characters modulo 32).
  static bool verifyChecksum(String normalized) {
    if (normalized.length != keyLength) return false;
    var sum = 0;
    for (var i = 0; i < keyLength - 1; i++) {
      final pos = alphabet.indexOf(normalized[i]);
      if (pos < 0) return false;
      sum += pos;
    }
    final expected = alphabet[sum % 32];
    return normalized[keyLength - 1] == expected;
  }

  /// Formats a 12-char normalized key into XXXX-XXXX-XXXX display format.
  static String format(String normalized) {
    if (normalized.length != keyLength) return normalized;
    return '${normalized.substring(0, 4)}-${normalized.substring(4, 8)}-${normalized.substring(8, 12)}';
  }

  /// Checks if [key] looks like a short key (no dot separator, normalized length is 12).
  static bool isShortKey(String key) {
    if (key.contains('.')) return false;
    final norm = normalize(key);
    return norm.length == keyLength;
  }
}
