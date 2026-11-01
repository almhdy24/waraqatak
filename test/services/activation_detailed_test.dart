import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/core/constants/app_constants.dart';
import 'package:warqatek/services/activation_service.dart';
import 'package:warqatek/services/license_key.dart';
import 'package:warqatek/utils/support_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'wq_device_id': 'mock_test_device_machine_id',
    });
  });

  tearDown(() {
    ActivationService.debugResetClient();
  });

  group('Batch 5: Activation Detailed & Diagnostics', () {
    test('Short license key inline Crockford normalization and checksum verification', () {
      // Valid Crockford test key with valid checksum
      // Positional sum modulo 32
      const rawInput = ' 2345-6789-abcd ';
      final normalized = ShortLicenseKey.normalize(rawInput);
      expect(normalized.length, 12);
      expect(normalized, equals('23456789ABCD'));

      // Confusion mapping O->0, I->1, L->1
      const confusedInput = 'oiL5-6789-abcd';
      final mapped = ShortLicenseKey.normalize(confusedInput);
      expect(mapped.startsWith('0115'), isTrue);

      // Invalid checksum detection
      expect(ShortLicenseKey.verifyChecksum('00000000000Z'), isFalse);
    });

    test('SupportDiagnostics masks secrets properly and formats diagnostic text', () async {
      expect(SupportDiagnostics.maskKey(null), equals('none'));
      expect(SupportDiagnostics.maskKey(''), equals('none'));
      expect(SupportDiagnostics.maskKey('ABCD'), equals('****'));
      expect(SupportDiagnostics.maskKey('ABCD-EFGH-JKMN'), equals('AB****MN'));

      final summary = await SupportDiagnostics.generateSummary(
        referenceId: 'req_test_ref_123',
        rawKey: 'ABCD-EFGH-JKMN',
      );

      expect(summary, contains('App ID: ${AppConstants.appId}'));
      expect(summary, contains('Reference ID: req_test_ref_123'));
      expect(summary, contains('Key: AB****MN'));
      expect(summary, isNot(contains('EFGH'))); // Ensure middle secret is not leaked
    });

    test('activateDetailed captures correlation_id from server error responses', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          '{"success":false,"error":"invalid_license","message":"Key not found","correlation_id":"corr_fail_999"}',
          404,
          headers: {
            'content-type': 'application/json',
            'x-correlation-id': 'corr_fail_999',
          },
        );
      });

      final sdk = ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mockHttpClient,
      );
      ActivationService.debugOverrideClient(sdk);

      // Generate a valid Crockford checksum key so format passes
      const validChars = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
      var sum = 0;
      for (var i = 0; i < 11; i++) {
        sum += ShortLicenseKey.alphabet.indexOf(validChars[i]);
      }
      final checkChar = ShortLicenseKey.alphabet[sum % 32];
      final validKey = '${validChars.substring(0, 11)}$checkChar';

      final res = await ActivationService.activateDetailed(validKey, 'test_machine_1');
      expect(res.outcome, equals(ActivationOutcome.invalid));
      expect(res.referenceId, equals('corr_fail_999'));

      // Backward compatible activate() returns outcome
      final outcome = await ActivationService.activate(validKey, 'test_machine_1');
      expect(outcome, equals(ActivationOutcome.invalid));
    });

    test('activateDetailed captures correlation_id on successful activation', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          '{"success":true,"data":{"token":"act_token_123","license":{"product":"com.elmahdi.waraqatak","type":"perpetual"}},"correlation_id":"corr_success_101"}',
          200,
          headers: {
            'content-type': 'application/json',
            'x-correlation-id': 'corr_success_101',
          },
        );
      });

      final sdk = ElmahdiPayClient(
        ElmahdiPayConfig(baseUrl: 'https://api.almhdy24.com'),
        httpClient: mockHttpClient,
      );
      ActivationService.debugOverrideClient(sdk);

      const validChars = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
      var sum = 0;
      for (var i = 0; i < 11; i++) {
        sum += ShortLicenseKey.alphabet.indexOf(validChars[i]);
      }
      final checkChar = ShortLicenseKey.alphabet[sum % 32];
      final validKey = '${validChars.substring(0, 11)}$checkChar';

      final res = await ActivationService.activateDetailed(validKey, 'test_machine_1');
      expect(res.outcome, equals(ActivationOutcome.success));
      expect(res.referenceId, equals('corr_success_101'));
    });
  });
}
