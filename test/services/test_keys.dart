import 'dart:convert';

import 'package:warqatek/services/activation_service.dart';
import 'package:warqatek/services/license_service.dart';

/// Builds a key in the server's `base64url(payload).base64url(signature)`
/// format. The signature is a placeholder: only the server verifies it.
String makeKey(Map<String, dynamic> payload) {
  String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
  return '${b64(utf8.encode(jsonEncode(payload)))}.${b64([1, 2, 3, 250])}';
}

/// A well-formed key for this app with no expiry (legacy lifetime shape).
String legacyLifetimeKey() => makeKey({
      'license_id': 1,
      'app_slug': ActivationService.appSlug,
      'expires_at': null,
    });

/// A valid 12-char Crockford Base32 key (checksum verified).
String validShortKey() => 'ABCDEFGHJKM5';

/// A formatted valid short key: ABCD-EFGH-JKM5.
String validFormattedShortKey() => 'ABCD-EFGH-JKM5';

/// In-memory [LicenseStorage] for tests. [data] can be read and edited
/// directly to simulate stored or corrupted values.
class FakeLicenseStorage implements LicenseStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key}) async => data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }
}
