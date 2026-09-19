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
  group('getPaymentMethods', () {
    test('returns list on 200', () async {
      final client = _client(MockClient((_) async => _json({
            'success': true,
            'data': [
              {'id': 1, 'name': 'Bank Transfer', 'currency': 'SDG'},
              {'id': 2, 'name': 'Cash', 'currency': 'USD'},
            ],
          })));
      final methods = await client.public.getPaymentMethods();
      expect(methods.length, 2);
      expect(methods.first.name, 'Bank Transfer');
    });

    test('throws ElmahdiPayNetworkException on connection failure', () {
      final client = _client(MockClient((_) => throw Exception('offline')));
      expect(
        () => client.public.getPaymentMethods(),
        throwsA(isA<ElmahdiPayNetworkException>()),
      );
    });
  });

  group('getSettings', () {
    test('returns rate', () async {
      final client = _client(MockClient((_) async => _json({
            'success': true,
            'data': {'usd_to_sdg_rate': 650.5},
          })));
      final s = await client.public.getSettings();
      expect(s.usdToSdgRate, 650.5);
    });

    test('handles null rate', () async {
      final client = _client(MockClient((_) async => _json({
            'success': true,
            'data': {'usd_to_sdg_rate': null},
          })));
      final s = await client.public.getSettings();
      expect(s.usdToSdgRate, isNull);
    });
  });

  group('createOrder', () {
    const baseRequest = CreateOrderRequest(
      appSlug: 'com.example.myapp',
      paymentMethodId: 1,
      buyerName: 'Ali',
      buyerContact: 'ali@example.com',
      amount: 25.0,
      currency: 'USD',
    );

    final pendingResponse = {
      'success': true,
      'data': {
        'reference': 'ORD-NEWORDER',
        'status': 'pending',
        'payment_method': null,
      },
    };

    test('returns CreateOrderResult on 201', () async {
      final client = _client(MockClient(
          (_) async => _json(pendingResponse, status: 201)));
      final result = await client.public.createOrder(baseRequest);
      expect(result.reference, 'ORD-NEWORDER');
      expect(result.status, OrderStatus.pending);
      expect(result.idempotent, isFalse);
    });

    test('idempotent=true on server cache hit', () async {
      final client = _client(MockClient((_) async => _json({
            'success': true,
            'idempotent': true,
            'data': {
              'reference': 'ORD-EXISTING',
              'status': 'pending',
              'payment_method': null,
            },
          })));
      final key = ElmahdiPayClient.generateIdempotencyKey();
      final result = await client.public.createOrder(
        CreateOrderRequest(
          appSlug: 'com.example.myapp',
          paymentMethodId: 1,
          buyerName: 'Ali',
          buyerContact: 'ali@example.com',
          amount: 25.0,
          currency: 'USD',
          idempotencyKey: key,
        ),
      );
      expect(result.idempotent, isTrue);
      expect(result.reference, 'ORD-EXISTING');
    });

    test('sends JSON when no file', () async {
      String? contentType;
      final client = _client(MockClient((request) async {
        contentType = request.headers['content-type'];
        return _json(pendingResponse, status: 201);
      }));
      await client.public.createOrder(baseRequest);
      expect(contentType, contains('application/json'));
    });

    test('throws ElmahdiPayRateLimitException on 429', () {
      final client = _client(MockClient((_) async =>
          _json({'success': false, 'message': 'Too many requests'}, status: 429)));
      expect(
        () => client.public.createOrder(baseRequest),
        throwsA(isA<ElmahdiPayRateLimitException>()),
      );
    });

    test('throws ElmahdiPayValidationException on 422 with errors map', () async {
      final client = _client(MockClient((_) async => _json(
            {
              'success': false,
              'message': 'Validation failed',
              'errors': {'amount': 'must be positive'},
            },
            status: 422,
          )));
      try {
        await client.public.createOrder(baseRequest);
        fail('expected exception');
      } on ElmahdiPayValidationException catch (e) {
        expect(e.errors, containsPair('amount', 'must be positive'));
      }
    });
  });

  group('getOrder', () {
    test('returns Order on 200', () async {
      final client = _client(MockClient((_) async => _json({
            'success': true,
            'data': {
              'reference': 'ORD-ABC12345',
              'app_slug': 'myapp',
              'buyer_name': 'Ali',
              'amount': 25,
              'currency': 'USD',
              'payment_method': null,
              'status': 'pending',
              'created_at': '2026-09-19 08:00:00',
              'updated_at': '2026-09-19 08:00:00',
              'license': null,
              'admin_note': null,
            },
          })));
      final order = await client.public.getOrder('ORD-ABC12345');
      expect(order.reference, 'ORD-ABC12345');
      expect(order.status, OrderStatus.pending);
    });

    test('includes reference in request URL', () async {
      String? url;
      final client = _client(MockClient((request) async {
        url = request.url.toString();
        return _json({
          'success': true,
          'data': {
            'reference': 'ORD-XYZ99999',
            'app_slug': 'app',
            'buyer_name': 'X',
            'amount': 10,
            'currency': 'USD',
            'payment_method': null,
            'status': 'pending',
            'created_at': '2026-09-19 08:00:00',
            'updated_at': '2026-09-19 08:00:00',
            'license': null,
            'admin_note': null,
          },
        });
      }));
      await client.public.getOrder('ORD-XYZ99999');
      expect(url, contains('/pay/orders/ORD-XYZ99999'));
    });

    test('throws ElmahdiPayNotFoundException on 404', () {
      final client = _client(MockClient((_) async =>
          _json({'success': false, 'message': 'Not found'}, status: 404)));
      expect(
        () => client.public.getOrder('ORD-MISSING'),
        throwsA(isA<ElmahdiPayNotFoundException>()),
      );
    });

    test('approved order has license', () async {
      final client = _client(MockClient((_) async => _json({
            'success': true,
            'data': {
              'reference': 'ORD-DONE1234',
              'app_slug': 'myapp',
              'buyer_name': 'Ali',
              'amount': 25,
              'currency': 'USD',
              'payment_method': null,
              'status': 'approved',
              'created_at': '2026-09-19 08:00:00',
              'updated_at': '2026-09-19 09:00:00',
              'admin_note': null,
              'license': {
                'id': 1,
                'order_id': 5,
                'app_slug': 'myapp',
                'license_key': 'SIGNED',
                'status': 'active',
                'issued_at': '2026-09-19 09:00:00',
                'expires_at': null,
                'max_devices': 3,
                'created_at': '2026-09-19 09:00:00',
              },
            },
          })));
      final order = await client.public.getOrder('ORD-DONE1234');
      expect(order.status, OrderStatus.approved);
      expect(order.license?.licenseKey, 'SIGNED');
    });
  });

  group('activateLicense', () {
    const request = ActivateLicenseRequest(
      licenseKey: 'SIGNED_KEY',
      deviceId: 'device-abc',
      deviceLabel: 'My Phone',
    );

    final activationData = {
      'id': 1,
      'license_id': 5,
      'device_id': 'device-abc',
      'device_label': 'My Phone',
      'status': 'active',
      'activated_at': '2026-09-19 10:00:00',
      'last_seen_at': '2026-09-19 10:00:00',
      'deactivated_at': null,
    };

    test('returns result on 201', () async {
      final client = _client(MockClient(
          (_) async => _json({'success': true, 'data': activationData}, status: 201)));
      final result = await client.public.activateLicense(request);
      expect(result.activation.deviceId, 'device-abc');
      expect(result.reactivated, isFalse);
    });

    test('reactivated=true on 200', () async {
      final client = _client(MockClient((_) async => _json({
            'success': true,
            'reactivated': true,
            'data': activationData,
          })));
      final result = await client.public.activateLicense(request);
      expect(result.reactivated, isTrue);
    });

    test('throws ElmahdiPayForbiddenException with device counts at limit', () async {
      final client = _client(MockClient((_) async => _json(
            {
              'success': false,
              'message': 'Device limit reached',
              'max_devices': 3,
              'active': 3,
            },
            status: 403,
          )));
      try {
        await client.public.activateLicense(request);
        fail('expected exception');
      } on ElmahdiPayForbiddenException catch (e) {
        expect(e.maxDevices, 3);
        expect(e.activeDevices, 3);
      }
    });

    test('throws ElmahdiPayNotFoundException for unknown license', () {
      final client = _client(MockClient((_) async =>
          _json({'success': false, 'message': 'Not found'}, status: 404)));
      expect(
        () => client.public.activateLicense(request),
        throwsA(isA<ElmahdiPayNotFoundException>()),
      );
    });

    test('throws ElmahdiPayValidationException for bad license key', () {
      final client = _client(MockClient((_) async => _json(
            {'success': false, 'message': 'Invalid license signature'},
            status: 422,
          )));
      expect(
        () => client.public.activateLicense(request),
        throwsA(isA<ElmahdiPayValidationException>()),
      );
    });
  });
}
