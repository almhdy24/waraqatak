import 'dart:convert';

import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warqatek/services/activation_service.dart';
import 'package:warqatek/services/license_key.dart';
import 'package:warqatek/services/license_service.dart';

/// Builds a key in the server's `base64url(payload).base64url(signature)`
/// format. The signature is a placeholder: only the server verifies it.
String makeKey(Map<String, dynamic> payload) {
  String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
  return '${b64(utf8.encode(jsonEncode(payload)))}.${b64([1, 2, 3, 250])}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LicenseKeyClaims.tryParse', () {
    test('reads app_slug and expires_at', () {
      final c = LicenseKeyClaims.tryParse(makeKey({
        'license_id': 7,
        'app_slug': 'com.elmahdi.waraqatak',
        'license_type': 'monthly',
        'expires_at': '2026-11-01T10:00:00+02:00',
      }))!;
      expect(c.appSlug, 'com.elmahdi.waraqatak');
      expect(c.expiresAt, DateTime.utc(2026, 11, 1, 8));
    });

    test('lifetime key has no expiry', () {
      final c = LicenseKeyClaims.tryParse(makeKey({
        'license_id': 7,
        'app_slug': 'com.elmahdi.waraqatak',
        'expires_at': null,
      }))!;
      expect(c.expiresAt, isNull);
      expect(c.isExpiredAt(DateTime.now()), isFalse);
    });

    test('non-signed formats return null', () {
      for (final k in ['ABCD-1234', '', '.', 'abc.', '.abc', 'not_json.sig']) {
        expect(LicenseKeyClaims.tryParse(k), isNull, reason: k);
      }
    });
  });

  group('LicenseService.uuidFromHash', () {
    test('formats a SHA-256 digest as a version-8 UUID', () {
      final id = LicenseService.uuidFromHash('ab' * 32)!;
      expect(id, matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(LicenseService.uuidFromHash('ab' * 32), id);
    });

    test('rejects non-hex input', () {
      expect(LicenseService.uuidFromHash('xyz'), isNull);
    });
  });

  group('ActivationService.activate key claims', () {
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    var requests = 0;

    setUp(() {
      requests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (call) async => null);
      ActivationService.debugOverrideClient(ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: MockClient((_) async {
          requests++;
          return http.Response(
              jsonEncode({'success': true, 'activation_token': 't'}), 200,
              headers: {'content-type': 'application/json'});
        }),
      ));
    });

    tearDown(() {
      ActivationService.debugResetClient();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, null);
    });

    test('key for another app is rejected without a request', () async {
      final key = makeKey({'license_id': 1, 'app_slug': 'com.other.app'});
      expect(await ActivationService.activate(key, 'd'),
          ActivationOutcome.invalid);
      expect(requests, 0);
    });

    test('expired key is rejected without a request', () async {
      final key = makeKey({
        'license_id': 1,
        'app_slug': ActivationService.appSlug,
        'expires_at': '2020-01-01T00:00:00+00:00',
      });
      expect(await ActivationService.activate(key, 'd'),
          ActivationOutcome.invalid);
      expect(requests, 0);
    });

    test('valid key for this app is sent to the server', () async {
      final key = makeKey({
        'license_id': 1,
        'app_slug': ActivationService.appSlug,
        'expires_at': null,
      });
      expect(await ActivationService.activate(key, 'd'),
          ActivationOutcome.success);
      expect(requests, 1);
    });
  });
}
