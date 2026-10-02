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
}
