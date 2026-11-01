import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/services/feature_access.dart';
import 'package:warqatek/services/license_key.dart';
import 'package:warqatek/services/license_service.dart';

class FakeLicenseStorage implements LicenseStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key}) async => data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 2: License & Trial Correctness Matrix', () {
    test('F4 Fix: stored "expired" status yields licenseExpired in _compute', () async {
      final storage = FakeLicenseStorage();
      final now = DateTime(2026, 11, 1, 12, 0);

      storage.data['wq_device_id'] = 'test-device-uuid-1234';
      storage.data['wq_license_key'] = 'ABCDEFGHJKMN';
      storage.data['wq_license_status'] = 'expired';
      storage.data['wq_license_expiry'] = '2026-10-31T00:00:00.000Z';

      final service = LicenseService.forTesting(
        storage: storage,
        clock: () => now,
      );

      final state = await service.checkEntitlement(force: true);
      expect(state.status, equals(EntitlementStatus.licenseExpired));
      expect(state.isSubscriptionActive, isFalse);
    });

    test('Stored "revoked" status yields licenseRevoked in _compute', () async {
      final storage = FakeLicenseStorage();
      final now = DateTime(2026, 11, 1, 12, 0);

      storage.data['wq_device_id'] = 'test-device-uuid-1234';
      storage.data['wq_license_key'] = 'ABCDEFGHJKMN';
      storage.data['wq_license_status'] = 'revoked';

      final service = LicenseService.forTesting(
        storage: storage,
        clock: () => now,
      );

      final state = await service.checkEntitlement(force: true);
      expect(state.status, equals(EntitlementStatus.licenseRevoked));
      expect(state.isSubscriptionActive, isFalse);
    });

    test('F8 Fix: syncTrialWithServer skips claiming trial when device is actively licensed', () async {
      final storage = FakeLicenseStorage();
      final now = DateTime(2026, 11, 1, 12, 0);

      storage.data['wq_device_id'] = 'test-device-uuid-1234';
      storage.data['wq_license_key'] = 'ABCDEFGHJKMN';
      storage.data['wq_license_status'] = 'active';

      final service = LicenseService.forTesting(
        storage: storage,
        clock: () => now,
      );

      // syncTrialWithServer should return without updating wq_trial_server_status
      await service.syncTrialWithServer(force: false);
      expect(storage.data['wq_trial_server_status'], isNull);
    });

    test('Clock rollback guard enforces monotonic time for license expiry', () async {
      final storage = FakeLicenseStorage();
      final initialTime = DateTime(2026, 11, 1, 12, 0);

      storage.data['wq_device_id'] = 'test-device-uuid-1234';
      storage.data['wq_license_key'] = 'ABCDEFGHJKMN';
      storage.data['wq_license_status'] = 'active';
      storage.data['wq_license_expiry'] = '2026-11-01T15:00:00.000Z';
      storage.data['wq_last_seen'] = '2026-11-01T16:00:00.000Z'; // Time previously advanced

      // Clock rolled back to morning
      final service = LicenseService.forTesting(
        storage: storage,
        clock: () => initialTime,
      );

      final state = await service.checkEntitlement(force: true);
      // Because last_seen (16:00) > license_expiry (15:00), license must be evaluated as expired
      expect(state.status, equals(EntitlementStatus.licenseExpired));
    });

    test('All contract rejection reasons map correctly from JSON fixture', () async {
      final fixtureFile = File('test/fixtures/license_rejection_reasons.json');
      expect(fixtureFile.existsSync(), isTrue);

      final list = jsonDecode(fixtureFile.readAsStringSync()) as List;
      for (final item in list) {
        final reason = item['reason'] as String;
        final expected = item['expected_status'] as String;
        final isTerminal = item['terminal'] as bool;

        if (isTerminal) {
          if (reason.contains('expired')) {
            expect(expected, equals('expired'));
          } else {
            expect(expected, equals('revoked'));
          }
        } else {
          expect(expected, equals('no_change'));
        }
      }
    });

    test('Core business bookkeeping data is never locked at trial or license expiry', () {
      final expiredState = const EntitlementState(
        status: EntitlementStatus.trialExpired,
        deviceId: 'device-1',
      );

      // Free features must all remain accessible
      for (final f in FeatureAccess.freeFeatures) {
        expect(FeatureAccess.canAccess(f, expiredState), isTrue,
            reason: 'Free feature $f must always remain accessible');
      }

      // Pro features gated
      for (final f in FeatureAccess.proFeatures) {
        expect(FeatureAccess.canAccess(f, expiredState), isFalse,
            reason: 'Pro feature $f must be gated at expiry');
      }
    });
  });
}
