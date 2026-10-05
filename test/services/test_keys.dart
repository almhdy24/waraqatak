import 'dart:convert';

import 'package:warqatek/services/activation_service.dart';

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
