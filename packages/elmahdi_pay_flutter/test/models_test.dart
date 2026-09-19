import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentMethod.fromJson', () {
    test('parses minimal nested object (no timestamps)', () {
      final pm = PaymentMethod.fromJson({
        'id': 1,
        'name': 'Bank Transfer',
        'currency': 'SDG',
      });
      expect(pm.id, 1);
      expect(pm.name, 'Bank Transfer');
      expect(pm.currency, 'SDG');
      expect(pm.instructions, isNull);
      expect(pm.createdAt, isNull);
    });

    test('parses full public response', () {
      final pm = PaymentMethod.fromJson({
        'id': 2,
        'name': 'Cash',
        'currency': 'USD',
        'instructions': 'Call us',
        'created_at': '2026-09-01 10:00:00',
        'updated_at': '2026-09-01 10:00:00',
      });
      expect(pm.instructions, 'Call us');
      expect(pm.createdAt, isNotNull);
    });
  });

  group('PaySettings.fromJson', () {
    test('parses exchange rate', () {
      final s = PaySettings.fromJson({
        'success': true,
        'data': {'usd_to_sdg_rate': 650.5},
      });
      expect(s.usdToSdgRate, 650.5);
    });

    test('handles null rate', () {
      final s = PaySettings.fromJson({
        'success': true,
        'data': {'usd_to_sdg_rate': null},
      });
      expect(s.usdToSdgRate, isNull);
    });
  });

  group('Order.fromJson', () {
    final base = {
      'reference': 'ORD-ABC12345',
      'app_slug': 'myapp',
      'buyer_name': 'Ali',
      'amount': '25.00',
      'currency': 'USD',
      'payment_method': null,
      'status': 'pending',
      'created_at': '2026-09-19 08:00:00',
      'updated_at': '2026-09-19 08:00:00',
      'license': null,
      'admin_note': null,
    };

    test('parses pending order', () {
      final order = Order.fromJson({'data': base});
      expect(order.reference, 'ORD-ABC12345');
      expect(order.status, OrderStatus.pending);
      expect(order.license, isNull);
      expect(order.adminNote, isNull);
    });

    test('amount parsed from string (PHP PDO DECIMAL)', () {
      final order = Order.fromJson({'data': base});
      expect(order.amount, 25.0);
    });

    test('amount parsed from num', () {
      final order = Order.fromJson({'data': {...base, 'amount': 25.0}});
      expect(order.amount, 25.0);
    });

    test('parses approved order — license populated', () {
      final order = Order.fromJson({
        'data': {
          ...base,
          'status': 'approved',
          'license': {
            'id': 1,
            'order_id': 10,
            'app_slug': 'myapp',
            'license_key': 'SIG-KEY',
            'status': 'active',
            'issued_at': '2026-09-19 09:00:00',
            'expires_at': null,
            'max_devices': 3,
            'created_at': '2026-09-19 09:00:00',
          },
        },
      });
      expect(order.status, OrderStatus.approved);
      expect(order.license, isNotNull);
      expect(order.license!.maxDevices, 3);
    });

    test('parses rejected order — adminNote populated', () {
      final order = Order.fromJson({
        'data': {...base, 'status': 'rejected', 'admin_note': 'Receipt unclear'},
      });
      expect(order.status, OrderStatus.rejected);
      expect(order.adminNote, 'Receipt unclear');
    });

    test('parses nested PaymentMethod', () {
      final order = Order.fromJson({
        'data': {
          ...base,
          'payment_method': {'id': 1, 'name': 'Bank', 'currency': 'SDG'},
        },
      });
      expect(order.paymentMethod?.name, 'Bank');
    });
  });

  group('License.fromJson', () {
    final json = {
      'id': 5,
      'order_id': 42,
      'app_slug': 'myapp',
      'license_key': 'SIGNED_KEY',
      'status': 'active',
      'issued_at': '2026-09-19 10:00:00',
      'expires_at': null,
      'max_devices': 2,
      'created_at': '2026-09-19 10:00:00',
    };

    test('parses active license, isExpired=false with no expiry', () {
      final lic = License.fromJson(json);
      expect(lic.status, LicenseStatus.active);
      expect(lic.isExpired, isFalse);
    });

    test('isExpired=true when expiresAt is in the past', () {
      final lic = License.fromJson({...json, 'expires_at': '2020-01-01 00:00:00'});
      expect(lic.isExpired, isTrue);
    });

    test('isExpired=false when expiresAt is in the future', () {
      final lic = License.fromJson({...json, 'expires_at': '2099-01-01 00:00:00'});
      expect(lic.isExpired, isFalse);
    });
  });

  group('LicenseActivation.fromJson', () {
    test('parses active activation', () {
      final a = LicenseActivation.fromJson({
        'id': 1,
        'license_id': 5,
        'device_id': 'device-abc',
        'device_label': 'My Phone',
        'status': 'active',
        'activated_at': '2026-09-19 10:00:00',
        'last_seen_at': '2026-09-19 11:00:00',
        'deactivated_at': null,
      });
      expect(a.status, ActivationStatus.active);
      expect(a.deviceLabel, 'My Phone');
      expect(a.deactivatedAt, isNull);
    });
  });

  group('ActivateLicenseResult.fromJson', () {
    final activationJson = {
      'id': 1,
      'license_id': 5,
      'device_id': 'device-abc',
      'device_label': null,
      'status': 'active',
      'activated_at': '2026-09-19 10:00:00',
      'last_seen_at': '2026-09-19 10:00:00',
      'deactivated_at': null,
    };

    test('fresh activation — reactivated=false', () {
      final r = ActivateLicenseResult.fromJson({
        'success': true,
        'data': activationJson,
      });
      expect(r.reactivated, isFalse);
    });

    test('re-activation — reactivated=true', () {
      final r = ActivateLicenseResult.fromJson({
        'success': true,
        'reactivated': true,
        'data': activationJson,
      });
      expect(r.reactivated, isTrue);
    });
  });

  group('CreateOrderResult.fromJson', () {
    test('non-idempotent result', () {
      final r = CreateOrderResult.fromJson({
        'success': true,
        'data': {
          'reference': 'ORD-NEW11111',
          'status': 'pending',
          'payment_method': null,
        },
      });
      expect(r.reference, 'ORD-NEW11111');
      expect(r.idempotent, isFalse);
    });

    test('idempotent result', () {
      final r = CreateOrderResult.fromJson({
        'success': true,
        'idempotent': true,
        'data': {
          'reference': 'ORD-EXIST222',
          'status': 'pending',
          'payment_method': null,
        },
      });
      expect(r.idempotent, isTrue);
    });
  });

  group('CreateOrderRequest', () {
    test('hasFile=false without bytes', () {
      const req = CreateOrderRequest(
        appSlug: 'app',
        paymentMethodId: 1,
        buyerName: 'Ali',
        buyerContact: 'ali@example.com',
        amount: 25,
        currency: 'USD',
      );
      expect(req.hasFile, isFalse);
    });

    test('toJson excludes optional nulls', () {
      const req = CreateOrderRequest(
        appSlug: 'app',
        paymentMethodId: 1,
        buyerName: 'Ali',
        buyerContact: 'ali@example.com',
        amount: 25,
        currency: 'USD',
      );
      final json = req.toJson();
      expect(json.containsKey('proof_note'), isFalse);
      expect(json.containsKey('idempotency_key'), isFalse);
    });
  });

  group('enums', () {
    test('OrderStatus roundtrip', () {
      for (final s in ['pending', 'approved', 'rejected']) {
        expect(OrderStatus.fromString(s).toString(), s);
      }
    });

    test('LicenseStatus roundtrip', () {
      for (final s in ['active', 'revoked']) {
        expect(LicenseStatus.fromString(s).toString(), s);
      }
    });

    test('ActivationStatus roundtrip', () {
      for (final s in ['active', 'deactivated']) {
        expect(ActivationStatus.fromString(s).toString(), s);
      }
    });

    test('unknown value throws ArgumentError', () {
      expect(() => OrderStatus.fromString('invalid'), throwsArgumentError);
      expect(() => LicenseStatus.fromString('invalid'), throwsArgumentError);
      expect(() => ActivationStatus.fromString('invalid'), throwsArgumentError);
    });
  });

  group('ElmahdiPayClient.generateIdempotencyKey', () {
    test('returns 64 lowercase hex chars', () {
      final key = ElmahdiPayClient.generateIdempotencyKey();
      expect(key.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
    });

    test('generates unique keys', () {
      final keys = List.generate(20, (_) => ElmahdiPayClient.generateIdempotencyKey());
      expect(keys.toSet().length, 20);
    });
  });
}
