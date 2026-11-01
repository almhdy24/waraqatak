import 'dart:convert';

import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/services/activation_service.dart';
import 'package:warqatek/services/license_service.dart';

import 'test_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLicenseStorage storage;
  late DateTime now;
  late LicenseService service;

  setUp(() {
    storage = FakeLicenseStorage();
    now = DateTime.utc(2026, 10, 25, 12, 0, 0);
    service = LicenseService.forTesting(storage: storage, clock: () => now);
  });

  tearDown(() {
    ActivationService.debugResetClient();
  });

  group('Server-authoritative Trial Enforcement', () {
    test('Server-reported active trial governs entitlement', () async {
      storage.data['wq_device_id'] = 'test-device-uuid';
      storage.data['wq_trial_server_status'] = 'active';
      storage.data['wq_trial_server_expiry'] =
          DateTime.utc(2026, 11, 8, 12, 0, 0).toIso8601String();

      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.trialActive);
      expect(s.trialDaysRemaining, 14);
    });

    test('Server-reported expired trial immediately blocks Pro access', () async {
      storage.data['wq_device_id'] = 'test-device-uuid';
      storage.data['wq_trial_server_status'] = 'expired';
      storage.data['wq_trial_server_expiry'] =
          DateTime.utc(2026, 10, 20, 12, 0, 0).toIso8601String();

      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.trialExpired);
    });

    test('Server expiry in past automatically transitions status to trialExpired',
        () async {
      storage.data['wq_device_id'] = 'test-device-uuid';
      storage.data['wq_trial_server_status'] = 'active';
      // Server expiry was yesterday
      storage.data['wq_trial_server_expiry'] =
          DateTime.utc(2026, 10, 24, 12, 0, 0).toIso8601String();

      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.trialExpired);
      expect(storage.data['wq_trial_server_status'], 'expired');
    });

    test('syncTrialWithServer claims trial and records server timestamps',
        () async {
      storage.data['wq_device_id'] = 'test-claim-uuid';

      final mock = MockClient((request) async {
        if (request.url.path.contains('/trial/claim')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'eligible': true,
              'trial': {
                'status': 'active',
                'started_at': '2026-10-25T12:00:00Z',
                'expires_at': '2026-11-08T12:00:00Z',
                'days_remaining': 14,
                'server_time': '2026-10-25T12:00:00Z',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      await service.syncTrialWithServer(force: true);

      expect(storage.data['wq_trial_server_status'], 'active');
      expect(storage.data['wq_trial_server_expiry'], '2026-11-08T12:00:00.000Z');
      expect(storage.data['wq_trial_server_start'], '2026-10-25T12:00:00.000Z');

      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.trialActive);
    });
  });

  group('Server-authoritative Online License Verification', () {
    test('Server revocation immediately marks license revoked (fail-closed)',
        () async {
      storage.data['wq_device_id'] = 'test-lic-uuid';
      storage.data['wq_license_key'] = 'ABCD-EFGH-JKM5';
      storage.data['wq_license_type'] = 'perpetual';
      storage.data['wq_license_status'] = 'active';

      final mock = MockClient((request) async {
        if (request.url.path.contains('/licenses/verify')) {
          return http.Response(
            jsonEncode({
              'success': false,
              'valid': false,
              'error': 'device_revoked',
              'message': 'Device revoked by administrator',
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      await service.verifyLicenseOnline();

      expect(storage.data['wq_license_status'], 'revoked');
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.licenseRevoked);
    });

    test('Temporary server network error preserves legitimate offline license',
        () async {
      storage.data['wq_device_id'] = 'test-lic-uuid';
      storage.data['wq_license_key'] = 'ABCD-EFGH-JKM5';
      storage.data['wq_license_type'] = 'perpetual';
      storage.data['wq_license_status'] = 'active';

      final mock = MockClient((request) async {
        // Server 503 outage
        return http.Response('Server Unavailable', 503);
      });

      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      await service.verifyLicenseOnline();

      // Crucial: Legitimate paying customer is NOT locked out when network fails
      expect(storage.data['wq_license_status'], 'active');
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.licensed);
    });

    test(
        'Server rejection with device_not_registered marks license revoked (fail closed)',
        () async {
      storage.data['wq_device_id'] = 'test-lic-unregistered-uuid';
      storage.data['wq_license_key'] = 'ABCD-EFGH-JKM5';
      storage.data['wq_license_type'] = 'perpetual';
      storage.data['wq_license_status'] = 'active';

      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'valid': false,
            'error': 'device_not_registered',
            'message': 'Device not associated with this license',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      await service.verifyLicenseOnline();

      expect(storage.data['wq_license_status'], 'revoked');
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.licenseRevoked);
    });

    test('Server rejection with license_expired marks license expired',
        () async {
      storage.data['wq_device_id'] = 'test-lic-exp-uuid';
      storage.data['wq_license_key'] = 'ABCD-EFGH-JKM5';
      storage.data['wq_license_type'] = 'timed';
      storage.data['wq_license_status'] = 'active';

      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'valid': false,
            'error': 'license_expired',
            'message': 'License period has elapsed',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      await service.verifyLicenseOnline();

      expect(storage.data['wq_license_status'], 'expired');
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.licenseExpired);
    });

    test(
        'App restart online verification with valid token preserves active status and sends canonical appSlug',
        () async {
      storage.data['wq_device_id'] = 'test-lic-valid-uuid';
      storage.data['wq_license_key'] = 'ABCD-EFGH-JKM5';
      storage.data['wq_activation_token'] = 'signed.token.valid';
      storage.data['wq_license_type'] = 'perpetual';
      storage.data['wq_license_status'] = 'active';

      http.Request? captured;
      final mock = MockClient((request) async {
        if (request.url.path.contains('/pay/licenses/verify')) {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'valid': true,
              'data': {
                'license_id': 1,
                'product': 'com.elmahdi.waraqatak',
                'status': 'active',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      // Simulates app restart startup verification
      await service.verifyLicenseOnline();

      expect(captured, isNotNull);
      final reqBody = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(reqBody['product'], 'com.elmahdi.waraqatak');
      expect(reqBody['token'], 'signed.token.valid');
      expect(reqBody['machine_id'], 'test-lic-valid-uuid');

      // Crucial: Valid license MUST remain active across app restarts
      expect(storage.data['wq_license_status'], 'active');
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.licensed);
    });

    test('Device mismatch on verification revokes entitlement (fail closed)',
        () async {
      storage.data['wq_device_id'] = 'cloned-device-uuid';
      storage.data['wq_license_key'] = 'ABCD-EFGH-JKM5';
      storage.data['wq_activation_token'] = 'signed.token.valid';
      storage.data['wq_license_status'] = 'active';

      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'valid': false,
            'error': 'device_mismatch',
            'message': 'Token bound to different device',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      ActivationService.debugOverrideClient(
        ElmahdiPayClient(
          ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
          httpClient: mock,
        ),
      );

      await service.verifyLicenseOnline();

      expect(storage.data['wq_license_status'], 'revoked');
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.licenseRevoked);
    });
  });

  group('Device Model Information Metadata', () {
    test('getDeviceModel returns cached or fallback model without crashing',
        () async {
      storage.data['wq_device_model_cache'] = 'Samsung Galaxy A16';
      final model = await service.getDeviceModel();
      expect(model, 'Samsung Galaxy A16');
    });
  });
}
