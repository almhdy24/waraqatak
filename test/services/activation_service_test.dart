import 'dart:convert';

import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warqatek/services/activation_service.dart';

import 'test_keys.dart';

/// MockClient-backed unit tests for [ActivationService].
///
/// These tests assert the on-the-wire contract (URL, method, headers, exact
/// body shape) and the deterministic [ActivationOutcome] mapping for every
/// HTTP branch. They never persist a real license: the
/// `flutter_secure_storage` method channel is intercepted so writes are
/// no-ops.
void main() {
  const expectedUrl =
      'https://api.almhdy24.com/api/v1/pay/licenses/activate';
  const deviceId = '00000000-0000-4000-8000-000000000000';
  final validKey = legacyLifetimeKey();

  TestWidgetsFlutterBinding.ensureInitialized();

  // ── flutter_secure_storage channel stub ────────────────────────────────────
  // The secure-storage plugin is reached when activate() stores the key on
  // success. We simulate a simple in-memory store so that the write→read-back
  // verification added in Item 3 (storeLicense) works correctly on the host VM.
  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fakeStorage = <String, String>{};
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      switch (call.method) {
        case 'write':
          final key = call.arguments['key']?.toString();
          final value = call.arguments['value']?.toString();
          if (key != null && value != null) fakeStorage[key] = value;
          return null;
        case 'read':
          final key = call.arguments['key']?.toString();
          return key != null ? fakeStorage[key] : null;
        case 'delete':
          final key = call.arguments['key']?.toString();
          if (key != null) fakeStorage.remove(key);
          return null;
        default:
          return null;
      }
    });
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  // Clear fake storage between tests so they remain independent.
  setUp(() => fakeStorage.clear());

  tearDown(ActivationService.debugResetClient);

  // ── on-the-wire contract ──────────────────────────────────────────────────

  test('request targets HTTPS /api/v1/pay/licenses/activate with JSON body',
      () async {
    http.Request? captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'activation_token': 'tok_123'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(
          baseUrl: 'https://api.almhdy24.com',
          timeout: const Duration(seconds: 15),
        ),
        httpClient: mock,
      ),
    );

    final outcome = await ActivationService.activate(validKey, deviceId);
    expect(outcome, ActivationOutcome.success);
    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url.toString(), expectedUrl);
    expect(captured!.url.scheme, 'https');
    expect(captured!.headers['content-type'],
        contains('application/json'));
    expect(captured!.headers['accept'], contains('application/json'));

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['license_key'], validKey);
    expect(body['machine_id'], deviceId);
    expect(body['product'], ActivationService.appSlug);
  });

  // ── outcome mapping ───────────────────────────────────────────────────────

  test('200 → success', () async {
    final mock = MockClient((_) async => http.Response(
          jsonEncode({'activation_token': 'tok'}),
          200,
          headers: {'content-type': 'application/json'},
        ));
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mock,
      ),
    );
    expect(await ActivationService.activate(validKey, deviceId),
        ActivationOutcome.success);
  });

  test('200 with malformed JSON → serverUnreachable (fix: unreadable body is not a confirmed activation)',
      () async {
    final mock = MockClient((_) async => http.Response(
          'not-json-at-all',
          200,
          headers: {'content-type': 'text/plain'},
        ));
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mock,
      ),
    );
    // Previously asserted success (incorrect — a 2xx with unreadable body
    // must never count as a confirmed activation). Fixed in Item 1.
    expect(await ActivationService.activate(validKey, deviceId),
        ActivationOutcome.serverUnreachable);
  });

  test('200 with empty body → serverUnreachable (fix: unreadable body is not a confirmed activation)',
      () async {
    final mock = MockClient((_) async => http.Response(
          '',
          200,
          headers: {'content-type': 'application/json'},
        ));
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mock,
      ),
    );
    // Previously asserted success (incorrect — a 2xx with unreadable body
    // must never count as a confirmed activation). Fixed in Item 1.
    expect(await ActivationService.activate(validKey, deviceId),
        ActivationOutcome.serverUnreachable);
  });

  for (final code in [401, 403, 404, 409, 422, 400, 418]) {
    test('$code → invalid', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({'message': 'nope'}),
            code,
            headers: {'content-type': 'application/json'},
          ));
      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );
      expect(await ActivationService.activate(validKey, deviceId),
          ActivationOutcome.invalid);
    });
  }

  test('429 → tooManyAttempts', () async {
    final mock = MockClient((_) async => http.Response(
          jsonEncode({'message': 'slow down'}),
          429,
          headers: {'content-type': 'application/json'},
        ));
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mock,
      ),
    );
    expect(await ActivationService.activate(validKey, deviceId),
        ActivationOutcome.tooManyAttempts);
  });

  for (final code in [500, 502, 503, 504]) {
    test('$code → serverUnreachable (never shown as invalid key)', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({'message': 'oops'}),
            code,
            headers: {'content-type': 'application/json'},
          ));
      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );
      expect(await ActivationService.activate(validKey, deviceId),
          ActivationOutcome.serverUnreachable);
    });
  }

  test('network failure → serverUnreachable', () async {
    final mock = MockClient((_) async => throw const SocketExceptionLike());
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mock,
      ),
    );
    expect(await ActivationService.activate(validKey, deviceId),
        ActivationOutcome.serverUnreachable);
  });

  test('timeout → serverUnreachable', () async {
    final mock = MockClient((_) async {
      // Never completes within the 1-second configured timeout.
      await Future<void>.delayed(const Duration(seconds: 5));
      return http.Response('', 200);
    });
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(
          baseUrl: 'https://api.almhdy24.com',
          timeout: const Duration(milliseconds: 200),
        ),
        httpClient: mock,
      ),
    );
    expect(await ActivationService.activate(validKey, deviceId),
        ActivationOutcome.serverUnreachable);
  });

  // ── no automatic retries ──────────────────────────────────────────────────

  test('a single activate() issues exactly one HTTP request', () async {
    var count = 0;
    final mock = MockClient((_) async {
      count++;
      return http.Response(
        jsonEncode({'message': 'bad'}),
        422,
        headers: {'content-type': 'application/json'},
      );
    });
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mock,
      ),
    );
    await ActivationService.activate(validKey, deviceId);
    expect(count, 1);
  });

  // ── key normalization ────────────────────────────────────────────────────

  test('empty key short-circuits without hitting the network', () async {
    var hits = 0;
    final mock = MockClient((_) async {
      hits++;
      return http.Response('{}', 200);
    });
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mock,
      ),
    );
    expect(await ActivationService.activate('', deviceId),
        ActivationOutcome.invalid);
    expect(await ActivationService.activate('   \n\t  ', deviceId),
        ActivationOutcome.invalid);
    expect(await ActivationService.activate('\u200B\u200C\uFEFF', deviceId),
        ActivationOutcome.invalid);
    expect(hits, 0);
  });

  for (final bad in ['ABCD-1234', 'not.base64!', 'e30.sig', 'W10.sig']) {
    test('unparseable key "$bad" is invalid without hitting the network',
        () async {
      var hits = 0;
      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: MockClient((_) async {
            hits++;
            return http.Response('{}', 200);
          }),
        ),
      );
      expect(await ActivationService.activate(bad, deviceId),
          ActivationOutcome.invalid);
      expect(hits, 0);
    });
  }

  test('whitespace and zero-width chars are stripped before send', () async {
    http.Request? captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'activation_token': 'tok'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    ActivationService.debugOverrideClient(
      ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mock,
      ),
    );
    final noisy = '  ${validKey.substring(0, 5)}\u200B'
        '${validKey.substring(5, 10)}\n'
        '${validKey.substring(10)}\uFEFF  ';
    await ActivationService.activate(noisy, deviceId);
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['license_key'], validKey);
  });

  // ── direct unit tests on the normalizer ─────────────────────────────────

  group('keyCharacter', () {
    test('accepts every character of a server-issued key', () {
      // Shape of a real key: base64url(payload) '.' base64url(signature).
      const key = 'eyJsaWNlbnNlX2lkIjo0Mn0.Ab-_cD09xYz_-Q';
      final filtered = key
          .split('')
          .where(ActivationService.keyCharacter.hasMatch)
          .join();
      expect(filtered, key);
    });

    test('rejects whitespace and other characters', () {
      for (final c in [' ', '\n', '+', '/', '=', '@']) {
        expect(ActivationService.keyCharacter.hasMatch(c), isFalse,
            reason: 'character "$c"');
      }
    });
  });

  group('normalizeKey', () {
    test('preserves dashes and casing', () {
      expect(ActivationService.normalizeKey('abc-DEF-123'), 'abc-DEF-123');
    });
    test('strips all whitespace variants anywhere in the string', () {
      expect(
          ActivationService.normalizeKey(' A B\tC\nD\rE  '), 'ABCDE');
    });
    test('strips zero-width characters', () {
      expect(
        ActivationService.normalizeKey(
            'A\u200BB\u200CC\u200DD\u2060E\uFEFFF'),
        'ABCDEF',
      );
    });
  });

  // ── Short-key activation & deactivation ───────────────────────────────────

  group('Short-key activation', () {
    test('valid short key activates successfully and sends normalized code',
        () async {
      http.Request? captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'success': true,
            'token': 'tok_short_rsa',
            'license': {
              'product': 'waraqatak',
              'type': 'perpetual',
              'issued_at': '2026-01-01 00:00:00',
              'expires_at': null,
              'max_devices': 1,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      final outcome =
          await ActivationService.activate(validFormattedShortKey(), deviceId);
      expect(outcome, ActivationOutcome.success);
      expect(captured, isNotNull);
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['license_key'], validShortKey());
      expect(body['machine_id'], deviceId);
    });

    test('short key with bad checksum is rejected locally without hitting network',
        () async {
      var hits = 0;
      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: MockClient((_) async {
            hits++;
            return http.Response('{}', 200);
          }),
        ),
      );

      // 'ABCDEFGHJKM0' has incorrect checksum ('5' is expected)
      final outcome =
          await ActivationService.activate('ABCD-EFGH-JKM0', deviceId);
      expect(outcome, ActivationOutcome.invalid);
      expect(hits, 0);
    });

    test('short key with 200 OK but unparseable body does not activate',
        () async {
      final mock = MockClient((_) async => http.Response('not-json', 200));
      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      final outcome =
          await ActivationService.activate(validFormattedShortKey(), deviceId);
      expect(outcome, ActivationOutcome.serverUnreachable);
    });

    test('deactivate sends request and returns true on success', () async {
      http.Request? captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'success': true,
            'code': 'deactivated',
            'active_devices': 0,
            'max_devices': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      final ok = await ActivationService.deactivate(
          validFormattedShortKey(), deviceId);
      expect(ok, isTrue);
      expect(captured, isNotNull);
      expect(captured!.url.path, '/api/v1/pay/licenses/deactivate');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['license_key'], validShortKey());
      expect(body['machine_id'], deviceId);
    });

    test('deactivate catches network failures and returns false', () async {
      final mock = MockClient((_) async => throw const SocketExceptionLike());
      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      final ok = await ActivationService.deactivate(validKey, deviceId);
      expect(ok, isFalse);
    });
  });

  // ── Item 1: long key + captive portal HTML body → serverUnreachable ───────

  group('Item 1 fix: long key with HTML 200 body must not store a license',
      () {
    // Track whether the storage channel write was invoked.
    final writeCalls = <String>[];

    setUp(() {
      writeCalls.clear();
      // Override storage handler to record writes.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (call) async {
        if (call.method == 'write') {
          writeCalls.add(call.arguments['key']?.toString() ?? '');
        }
        return null;
      });
    });

    tearDown(() {
      // Restore the original no-op stub.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (call) async => null);
    });

    test(
        'long key + HTTP 200 with HTML body → serverUnreachable, nothing stored',
        () async {
      // Build a syntactically valid long key: payload with app_slug and
      // a future expires_at, base64url-encoded, then a dot, then a signature.
      final longKey = makeKey({
        'app_slug': ActivationService.appSlug,
        'expires_at': '2099-01-01T00:00:00Z',
      });

      final mock = MockClient((_) async => http.Response(
            '<html>captive portal</html>',
            200,
            headers: {'content-type': 'text/html'},
          ));
      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      final result =
          await ActivationService.activateDetailed(longKey, deviceId);
      expect(result.outcome, ActivationOutcome.serverUnreachable,
          reason:
              'HTML captive-portal body is not a confirmed server activation');
      expect(
          writeCalls.any((k) => k == 'wq_license_key'), isFalse,
          reason: 'wq_license_key must not be written without confirmed server answer');
    });
  });

  // ── B2-2: classifyApiException ───────────────────────────────────────────

  group('classifyApiException', () {
    test('403 revoked → rejected', () {
      expect(
        ActivationService.classifyApiException(403, 'License revoked'),
        LicenseVerifyOutcome.rejected,
      );
    });
    test('404 license_not_found → rejected', () {
      expect(
        ActivationService.classifyApiException(404, 'license_not_found'),
        LicenseVerifyOutcome.rejected,
      );
    });
    test('403 device_mismatch → rejected', () {
      expect(
        ActivationService.classifyApiException(403, 'device_mismatch'),
        LicenseVerifyOutcome.rejected,
      );
    });
    test('410 license expired → expired', () {
      expect(
        ActivationService.classifyApiException(410, 'license expired'),
        LicenseVerifyOutcome.expired,
      );
    });
    test('404 Route not found → unreachable', () {
      expect(
        ActivationService.classifyApiException(404, 'Route not found'),
        LicenseVerifyOutcome.unreachable,
      );
    });
    test('500 revoked → unreachable (5xx ignored)', () {
      expect(
        ActivationService.classifyApiException(500, 'revoked'),
        LicenseVerifyOutcome.unreachable,
      );
    });
    test('403 empty → unreachable', () {
      expect(
        ActivationService.classifyApiException(403, ''),
        LicenseVerifyOutcome.unreachable,
      );
    });
    test('401 revoked → unreachable (401 not in allowed codes)', () {
      expect(
        ActivationService.classifyApiException(401, 'revoked'),
        LicenseVerifyOutcome.unreachable,
      );
    });
  });
}

/// A plain Dart exception that stands in for `dart:io`'s `SocketException`.
/// Using the real class would force this test file to import `dart:io`,
/// which is not available in all test runners.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketExceptionLike';
}
