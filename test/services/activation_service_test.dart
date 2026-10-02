import 'dart:convert';

import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warqatek/services/activation_service.dart';

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

  TestWidgetsFlutterBinding.ensureInitialized();

  // ── flutter_secure_storage channel stub ────────────────────────────────────
  // The secure-storage plugin is reached when activate() stores the key on
  // success. We swallow every call so the test runs on the host VM without
  // Android plugins. Reads return null to simulate first-run storage.
  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

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

    final outcome = await ActivationService.activate('ABCD-1234', deviceId);
    expect(outcome, ActivationOutcome.success);
    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url.toString(), expectedUrl);
    expect(captured!.url.scheme, 'https');
    expect(captured!.headers['content-type'],
        contains('application/json'));
    expect(captured!.headers['accept'], contains('application/json'));

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body.keys.toSet(), {'license_key', 'machine_id'});
    expect(body['license_key'], 'ABCD-1234');
    expect(body['machine_id'], deviceId);
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
    expect(await ActivationService.activate('K', deviceId),
        ActivationOutcome.success);
  });

  test('200 with malformed JSON → success (never crashes)', () async {
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
    expect(await ActivationService.activate('K', deviceId),
        ActivationOutcome.success);
  });

  test('200 with empty body → success (never crashes)', () async {
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
    expect(await ActivationService.activate('K', deviceId),
        ActivationOutcome.success);
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
      expect(await ActivationService.activate('K', deviceId),
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
    expect(await ActivationService.activate('K', deviceId),
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
      expect(await ActivationService.activate('K', deviceId),
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
    expect(await ActivationService.activate('K', deviceId),
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
    expect(await ActivationService.activate('K', deviceId),
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
    await ActivationService.activate('K', deviceId);
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
    const noisy = '  AB\u200BCD-\n12\u200C34\uFEFF  ';
    await ActivationService.activate(noisy, deviceId);
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['license_key'], 'ABCD-1234');
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
}

/// A plain Dart exception that stands in for `dart:io`'s `SocketException`.
/// Using the real class would force this test file to import `dart:io`,
/// which is not available in all test runners.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketExceptionLike';
}
