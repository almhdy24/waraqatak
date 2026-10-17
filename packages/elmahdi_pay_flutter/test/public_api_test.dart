import 'dart:convert';

import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

ElmahdiPayClient _client(MockClient mock) => ElmahdiPayClient(
      ElmahdiPayConfig(baseUrl: 'https://pay.example.com'),
      httpClient: mock,
    );

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('activateLicense', () {
    const request = ActivateLicenseRequest(
      licenseKey: 'KEY-123',
      machineId: 'machine-abc',
    );

    test('sends only license_key and machine_id in the body', () async {
      String? body;
      String? path;
      final client = _client(MockClient((req) async {
        body = req.body;
        path = req.url.path;
        return _json(
          {'success': true, 'data': {'activation_token': 'TOK'}},
          status: 201,
        );
      }));
      await client.public.activateLicense(request);

      expect(path, '/pay/licenses/activate');
      final sent = jsonDecode(body!) as Map<String, dynamic>;
      expect(sent.keys.toSet(), {'license_key', 'machine_id'});
      expect(sent['license_key'], 'KEY-123');
      expect(sent['machine_id'], 'machine-abc');
    });

    test('returns activation token on 201', () async {
      final client = _client(MockClient((_) async => _json(
            {'success': true, 'data': {'activation_token': 'SIGNED'}},
            status: 201,
          )));
      final result = await client.public.activateLicense(request);
      expect(result.activationToken, 'SIGNED');
    });

    test('returns token and license metadata for short key on 200', () async {
      final client = _client(MockClient((_) async => _json(
            {
              'success': true,
              'token': 'SHORT_TOKEN',
              'license': {
                'product': 'waraqatak',
                'type': 'perpetual',
                'issued_at': '2026-01-01 00:00:00',
                'expires_at': null,
                'max_devices': 2,
              },
            },
            status: 200,
          )));
      final result = await client.public.activateLicense(request);
      expect(result.token, 'SHORT_TOKEN');
      expect(result.effectiveToken, 'SHORT_TOKEN');
      expect(result.license, isNotNull);
      expect(result.license!.product, 'waraqatak');
      expect(result.license!.type, 'perpetual');
      expect(result.license!.expiresAt, isNull);
      expect(result.license!.maxDevices, 2);
    });

    test('throws ElmahdiPayForbiddenException on 403', () {
      final client = _client(MockClient((_) async =>
          _json({'success': false, 'message': 'Revoked'}, status: 403)));
      expect(
        () => client.public.activateLicense(request),
        throwsA(isA<ElmahdiPayForbiddenException>()),
      );
    });

    test('throws ElmahdiPayNotFoundException on 404', () {
      final client = _client(MockClient((_) async =>
          _json({'success': false, 'message': 'Not found'}, status: 404)));
      expect(
        () => client.public.activateLicense(request),
        throwsA(isA<ElmahdiPayNotFoundException>()),
      );
    });

    test('throws ElmahdiPayAlreadyActivatedException on 409', () {
      final client = _client(MockClient((_) async => _json(
            {'success': false, 'message': 'Already activated'},
            status: 409,
          )));
      expect(
        () => client.public.activateLicense(request),
        throwsA(isA<ElmahdiPayAlreadyActivatedException>()),
      );
    });

    test('throws ElmahdiPayValidationException on 422', () {
      final client = _client(MockClient((_) async => _json(
            {'success': false, 'message': 'Invalid signature'},
            status: 422,
          )));
      expect(
        () => client.public.activateLicense(request),
        throwsA(isA<ElmahdiPayValidationException>()),
      );
    });

    test('throws ElmahdiPayNetworkException when transport fails', () {
      final client = _client(MockClient((_) => throw Exception('offline')));
      expect(
        () => client.public.activateLicense(request),
        throwsA(isA<ElmahdiPayNetworkException>()),
      );
    });
  });

  group('deactivateLicense', () {
    const deactRequest = DeactivateLicenseRequest(
      licenseKey: 'KEY-123',
      machineId: 'machine-abc',
      reason: 'user_removed',
    );

    test('sends POST /pay/licenses/deactivate and parses response', () async {
      String? path;
      final client = _client(MockClient((req) async {
        path = req.url.path;
        return _json({
          'success': true,
          'message': 'Device deactivated',
          'code': 'deactivated',
          'active_devices': 0,
          'max_devices': 1,
        });
      }));
      final res = await client.public.deactivateLicense(deactRequest);
      expect(path, '/pay/licenses/deactivate');
      expect(res.success, isTrue);
      expect(res.code, 'deactivated');
      expect(res.activeDevices, 0);
      expect(res.maxDevices, 1);
    });
  });

  group('verifyLicense', () {
    const verifyRequest = VerifyLicenseRequest(
      tokenOrKey: 'KEY-OR-TOKEN',
      machineId: 'machine-abc',
    );

    test('sends POST /pay/licenses/verify and parses response', () async {
      String? path;
      final client = _client(MockClient((req) async {
        path = req.url.path;
        return _json({
          'success': true,
          'valid': true,
          'data': {'status': 'active'},
        });
      }));
      final res = await client.public.verifyLicense(verifyRequest);
      expect(path, '/pay/licenses/verify');
      expect(res.success, isTrue);
      expect(res.valid, isTrue);
      expect(res.data?['status'], 'active');
    });
  });
}
