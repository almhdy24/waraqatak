import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/services/activation_service.dart';
import 'package:warqatek/services/license_service.dart';

import 'test_keys.dart';

/// Drives the real [LicenseService] with an injected clock and in-memory
/// storage. The expiry is always compared with max(now, last seen).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final expiry = DateTime.utc(2026, 6, 1, 12);
  late FakeLicenseStorage storage;
  late DateTime now;
  late LicenseService service;

  setUp(() {
    storage = FakeLicenseStorage();
    now = DateTime.utc(2026, 5, 1);
    service = LicenseService.forTesting(storage: storage, clock: () => now);
  });

  Future<EntitlementState> evaluateAt(DateTime at) {
    now = at;
    return service.checkEntitlement(force: true);
  }

  Future<void> store({
    DateTime? expiresAt,
    String? type,
    String key = 'opaque-key',
  }) =>
      service.storeLicense(
        licenseKey: key,
        expiresAt: expiresAt,
        isActive: true,
        licenseType: type,
      );

  group('expiry', () {
    test('future expiry is licensed and keeps the expiry', () async {
      await store(expiresAt: expiry, type: 'monthly');
      final s = await evaluateAt(DateTime.utc(2026, 5, 20));
      expect(s.status, EntitlementStatus.licensed);
      expect(s.licenseExpiresAt, expiry);
      expect(s.isSubscriptionActive, isTrue);
    });

    test('past expiry is licenseExpired and Pro is denied', () async {
      await store(expiresAt: expiry, type: 'monthly');
      final s = await evaluateAt(DateTime.utc(2026, 6, 2));
      expect(s.status, EntitlementStatus.licenseExpired);
      expect(s.isSubscriptionActive, isFalse);
    });

    test('boundary: valid at the expiry instant, expired right after',
        () async {
      await store(expiresAt: expiry, type: 'monthly');
      expect((await evaluateAt(expiry)).status, EntitlementStatus.licensed);
      expect(
          (await evaluateAt(expiry.add(const Duration(milliseconds: 1))))
              .status,
          EntitlementStatus.licenseExpired);
    });

    test('a running session is re-evaluated when forced', () async {
      await store(expiresAt: expiry, type: 'monthly');
      expect((await evaluateAt(DateTime.utc(2026, 5, 31))).status,
          EntitlementStatus.licensed);
      // Cached until forced: a plain check still returns the old state.
      now = DateTime.utc(2026, 6, 2);
      expect((await service.checkEntitlement()).status,
          EntitlementStatus.licensed);
      expect((await service.checkEntitlement(force: true)).status,
          EntitlementStatus.licenseExpired);
    });
  });

  group('null expiry', () {
    test('lifetime type with no expiry stays licensed', () async {
      await store(type: 'lifetime');
      final s = await evaluateAt(DateTime.utc(2030, 1, 1));
      expect(s.status, EntitlementStatus.licensed);
      expect(s.licenseExpiresAt, isNull);
    });

    test('perpetual type with no expiry stays licensed', () async {
      await store(type: 'perpetual');
      final s = await evaluateAt(DateTime.utc(2030, 1, 1));
      expect(s.status, EntitlementStatus.licensed);
      expect(s.licenseExpiresAt, isNull);
    });

    test('limited type with no expiry is expired', () async {
      await store(type: 'monthly');
      expect((await evaluateAt(now)).status, EntitlementStatus.licenseExpired);
    });

    test('install activated before the type was stored keeps working',
        () async {
      // No stored type: the earlier behaviour (no expiry = lifetime) applies.
      await store();
      expect(storage.data['wq_license_type'], '');
      expect((await evaluateAt(now)).status, EntitlementStatus.licensed);
    });

    test('legacy install with no stored type falls back to the key expiry',
        () async {
      final key = makeKey({
        'app_slug': ActivationService.appSlug,
        'expires_at': '2026-01-01T00:00:00+00:00',
      });
      await store(key: key);
      expect((await evaluateAt(now)).status, EntitlementStatus.licenseExpired);
    });

    test('install with no type keys at all (pre-1.1.1 storage) still works',
        () async {
      await store(expiresAt: expiry);
      storage.data.remove('wq_license_type');
      expect((await evaluateAt(now)).status, EntitlementStatus.licensed);
    });
  });

  group('malformed stored expiry', () {
    test('locks Pro instead of granting unlimited access', () async {
      await store(expiresAt: expiry, type: 'monthly');
      storage.data['wq_license_expiry'] = 'not-a-date';
      final s = await evaluateAt(now);
      expect(s.status, EntitlementStatus.licenseExpired);
      expect(s.isSubscriptionActive, isFalse);
    });

    test('locks even for a lifetime type', () async {
      await store(type: 'lifetime');
      storage.data['wq_license_expiry'] = '31/12/2026';
      expect((await evaluateAt(now)).status, EntitlementStatus.licenseExpired);
    });

    test('malformed claims in a legacy key lock Pro', () async {
      final key = makeKey({
        'app_slug': ActivationService.appSlug,
        'expires_at': 'soon',
      });
      await store(key: key);
      expect((await evaluateAt(now)).status, EntitlementStatus.licenseExpired);
    });
  });

  group('clock set backwards', () {
    test('does not revive an expired license', () async {
      await store(expiresAt: expiry, type: 'monthly');
      expect((await evaluateAt(DateTime.utc(2026, 6, 2))).status,
          EntitlementStatus.licenseExpired);
      // User rewinds the clock to before the expiry.
      expect((await evaluateAt(DateTime.utc(2026, 5, 1))).status,
          EntitlementStatus.licenseExpired);
    });

    test('last seen only moves forward', () async {
      await store(expiresAt: expiry, type: 'monthly');
      await evaluateAt(DateTime.utc(2026, 5, 20));
      final seen = storage.data['wq_last_seen'];
      expect(DateTime.parse(seen!), DateTime.utc(2026, 5, 20));
      await evaluateAt(DateTime.utc(2026, 5, 10));
      expect(storage.data['wq_last_seen'], seen);
      await evaluateAt(DateTime.utc(2026, 5, 21));
      expect(DateTime.parse(storage.data['wq_last_seen']!),
          DateTime.utc(2026, 5, 21));
    });

    test('a corrupted last-seen value is ignored', () async {
      await store(expiresAt: expiry, type: 'monthly');
      storage.data['wq_last_seen'] = 'garbage';
      expect((await evaluateAt(DateTime.utc(2026, 5, 20))).status,
          EntitlementStatus.licensed);
      expect(DateTime.tryParse(storage.data['wq_last_seen']!), isNotNull);
    });

    test('clearing the license keeps the last-seen guard', () async {
      await store(expiresAt: expiry, type: 'monthly');
      await evaluateAt(DateTime.utc(2026, 5, 20));
      await service.clearLicense();
      expect(storage.data.containsKey('wq_license_type'), isFalse);
      expect(storage.data.containsKey('wq_last_seen'), isTrue);
    });

    test('stored last_launch is a UTC value ending in Z, clock moved back 3 days -> trial start is advanced by 3 days', () async {
      final initialTrialStart = DateTime.utc(2026, 5, 1, 10);
      storage.data['wq_trial_start'] = initialTrialStart.toIso8601String();
      storage.data['wq_last_launch'] = DateTime.utc(2026, 5, 10, 10).toIso8601String();

      // Clock moved back 3 days from last_launch: May 7 instead of May 10
      final evaluatedNow = DateTime.utc(2026, 5, 7, 10);
      await evaluateAt(evaluatedNow);

      final updatedStart = DateTime.parse(storage.data['wq_trial_start']!);
      expect(updatedStart, initialTrialStart.add(const Duration(days: 3)));
    });

    test('stored last_launch has NO Z, now is 5 hours earlier -> trial start is NOT changed', () async {
      final initialTrialStart = DateTime.utc(2026, 5, 1, 10);
      storage.data['wq_trial_start'] = initialTrialStart.toIso8601String();
      storage.data['wq_last_launch'] = '2026-05-10T12:00:00.000';

      // Now is 5 hours earlier
      final evaluatedNow = DateTime.utc(2026, 5, 10, 7);
      await evaluateAt(evaluatedNow);

      final updatedStart = storage.data['wq_trial_start'];
      expect(updatedStart, initialTrialStart.toIso8601String());
    });
  });

  group('revoked', () {
    test('a revoked status wins over expiry', () async {
      await service.storeLicense(
        licenseKey: 'opaque-key',
        expiresAt: expiry,
        isActive: false,
        licenseType: 'monthly',
      );
      expect((await evaluateAt(now)).status,
          EntitlementStatus.licenseRevoked);
    });
  });

  // ── Trial Persistence After License Removal ───────────────────────────────

  group('Trial persistence after license removal', () {
    test('first-time launch initializes trial with 14 days', () async {
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.trialActive);
      expect(s.trialDaysRemaining, 14);
      expect(storage.data['wq_trial_start'], isNotNull);
    });

    test('activating a license while trial is valid grants licensed status',
        () async {
      // Day 1: trial active
      await evaluateAt(DateTime.utc(2026, 5, 1));
      // Day 3: activate license
      await service.storeLicense(
        licenseKey: validFormattedShortKey(),
        expiresAt: null,
        isActive: true,
        licenseType: 'perpetual',
      );
      final s = await evaluateAt(DateTime.utc(2026, 5, 3));
      expect(s.status, EntitlementStatus.licensed);
    });

    test('removing a key before trial expiry restores remaining trial days',
        () async {
      // Day 0: start trial on May 1
      await evaluateAt(DateTime.utc(2026, 5, 1));
      // Day 2: activate license
      await service.storeLicense(
        licenseKey: validFormattedShortKey(),
        expiresAt: null,
        isActive: true,
        licenseType: 'perpetual',
      );
      expect((await evaluateAt(DateTime.utc(2026, 5, 3))).status,
          EntitlementStatus.licensed);

      // Day 5: user removes license. Trial started on May 1, ends May 15.
      // Remaining at May 5: May 15 - May 5 = 10 days left (inDays + 1 = 11).
      now = DateTime.utc(2026, 5, 5);
      await service.clearLicense();
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.trialActive);
      expect(s.trialDaysRemaining, 11);
    });

    test('removing a key after trial expiry returns trialExpired (no fresh trial)',
        () async {
      // Day 0: start trial on May 1
      await evaluateAt(DateTime.utc(2026, 5, 1));
      // Day 2: activate license
      await service.storeLicense(
        licenseKey: validFormattedShortKey(),
        expiresAt: null,
        isActive: true,
        licenseType: 'perpetual',
      );

      // Day 25: trial window elapsed. User removes license.
      now = DateTime.utc(2026, 5, 26);
      await service.clearLicense();
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.trialExpired);
      expect(s.isSubscriptionActive, isFalse);
    });

    test('activating after trial expired and then removing key stays expired',
        () async {
      // Day 0: start trial on May 1
      await evaluateAt(DateTime.utc(2026, 5, 1));
      // Day 16: trial expired
      expect((await evaluateAt(DateTime.utc(2026, 5, 17))).status,
          EntitlementStatus.trialExpired);

      // User activates timed key
      await service.storeLicense(
        licenseKey: 'timed-key',
        expiresAt: DateTime.utc(2026, 6, 1),
        isActive: true,
        licenseType: 'monthly',
      );
      expect((await evaluateAt(DateTime.utc(2026, 5, 17))).status,
          EntitlementStatus.licensed);

      // User removes key
      await service.clearLicense();
      final s = await evaluateAt(DateTime.utc(2026, 5, 18));
      expect(s.status, EntitlementStatus.trialExpired);
    });

    test('legacy install without wq_trial_start does not grant fresh trial upon removal',
        () async {
      // Suppose an install has a license and last_seen recorded 60 days ago,
      // but no wq_trial_start.
      storage.data['wq_license_key'] = 'legacy-key';
      storage.data['wq_license_type'] = 'lifetime';
      storage.data['wq_license_status'] = 'active';
      storage.data['wq_last_seen'] = DateTime.utc(2026, 1, 1).toIso8601String();

      // Today is May 1 (120 days later)
      now = DateTime.utc(2026, 5, 1);
      await service.clearLicense();
      final s = await service.checkEntitlement(force: true);
      // Historical last_seen is recognized so trial is expired, not granted fresh.
      expect(s.status, EntitlementStatus.trialExpired);
    });

    test('app restarts preserve original trial start timestamp', () async {
      final initialNow = DateTime.utc(2026, 5, 1, 10);
      await evaluateAt(initialNow);
      final originalStart = storage.data['wq_trial_start'];

      // Simulate app restart by creating a new service instance sharing same storage
      final newService = LicenseService.forTesting(
        storage: storage,
        clock: () => DateTime.utc(2026, 5, 4, 10),
      );
      final s = await newService.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.trialActive);
      expect(storage.data['wq_trial_start'], originalStart);
    });
  });

  group('getOrCreateDeviceId with Android ID / UUID migration', () {
    const deviceChannel = MethodChannel('com.elmahdi.waraqatak/device');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(deviceChannel, null);
    });

    test(
      'returns existing stored UUID without overwriting or invoking platform channel',
      () async {
        const existingStoredUuid = '11111111-2222-4333-8444-555555555555';
        storage.data['wq_device_id'] = existingStoredUuid;

        var platformChannelCalled = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(deviceChannel, (call) async {
              platformChannelCalled = true;
              return 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
            });

        final id = await service.getOrCreateDeviceId();

        expect(id, existingStoredUuid);
        expect(storage.data['wq_device_id'], existingStoredUuid);
        expect(
          platformChannelCalled,
          isFalse,
          reason: 'Existing stored ID must be preserved and never overwritten',
        );
      },
    );

    test(
      'derives stable UUID v8 from Android ID hash when no ID is stored',
      () async {
        const dummySha256 =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final expectedUuid = LicenseService.uuidFromHash(dummySha256);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(deviceChannel, (call) async {
              if (call.method == 'stableIdHash') {
                return dummySha256;
              }
              return null;
            });

        final id = await service.getOrCreateDeviceId();

        expect(id, expectedUuid);
        expect(storage.data['wq_device_id'], expectedUuid);
        expect(
          id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
      },
    );

    test(
      'throws StateError and does not generate random UUID when platform channel returns null',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(deviceChannel, (call) async {
              if (call.method == 'stableIdHash') {
                return null;
              }
              return null;
            });

        expect(
          () => service.getOrCreateDeviceId(),
          throwsA(isA<StateError>()),
          reason: 'Must refuse to generate unstable random UUID',
        );
        expect(storage.data['wq_device_id'], isNull);
      },
    );

    test(
      'throws StateError and does not generate random UUID when platform channel returns empty/invalid hash',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(deviceChannel, (call) async {
              return '';
            });

        expect(() => service.getOrCreateDeviceId(), throwsA(isA<StateError>()));
        expect(storage.data['wq_device_id'], isNull);
      },
    );

    test('throws StateError when platform channel throws exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(deviceChannel, (call) async {
            throw PlatformException(
              code: 'UNAVAILABLE',
              message: 'Channel error',
            );
          });

      expect(() => service.getOrCreateDeviceId(), throwsA(isA<StateError>()));
      expect(storage.data['wq_device_id'], isNull);
    });

    test(
      'entitlement compute uses fallback placeholder when device ID is unavailable without crashing',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(deviceChannel, (call) async => null);

        final entitlement = await service.checkEntitlement();
        expect(entitlement.status, EntitlementStatus.trialActive);
        expect(entitlement.deviceId, '00000000-0000-0000-0000-000000000000');
        expect(
          storage.data['wq_device_id'],
          isNull,
          reason:
              'Placeholder must not be written to persistent secure storage',
        );
      },
    );
  });

  // ── Item 2: classifyVerifyError table-driven tests ────────────────────────

  group('ActivationService.classifyVerifyError', () {
    final cases = <(String?, LicenseVerifyOutcome)>[
      ('license_expired', LicenseVerifyOutcome.expired),
      ('Revoked', LicenseVerifyOutcome.rejected),
      ('device_mismatch', LicenseVerifyOutcome.rejected),
      ('license_not_found', LicenseVerifyOutcome.rejected),
      ('rate_limited', LicenseVerifyOutcome.unreachable),
      ('invalid_request', LicenseVerifyOutcome.unreachable),
      ('', LicenseVerifyOutcome.unreachable),
      (null, LicenseVerifyOutcome.unreachable),
    ];
    for (final (input, expected) in cases) {
      test('classifyVerifyError("$input") → $expected', () {
        expect(
          ActivationService.classifyVerifyError(input),
          expected,
        );
      });
    }
  });

  // ── Item 3: storeLicense returns false when write fails ───────────────────

  group('Item 3: storeLicense detects write failures', () {
    test('storage that fails wq_license_key write returns false and leaves no key',
        () async {
      final failingStore = _FailingLicenseStorage('wq_license_key');
      final svc = LicenseService.forTesting(
        storage: failingStore,
        clock: DateTime.now,
      );
      final result = await svc.storeLicense(
        licenseKey: 'test-key-abc',
        expiresAt: null,
        isActive: true,
        licenseType: 'lifetime',
      );
      expect(result, isFalse);
      expect(failingStore.data.containsKey('wq_license_key'), isFalse);
      // licenseKey getter should return null
      expect(await svc.licenseKey, isNull);
    });
  });
}

/// A [LicenseStorage] that always fails [write] for a specific key,
/// simulating a Keystore failure on that key.
class _FailingLicenseStorage implements LicenseStorage {
  final String failKey;
  final Map<String, String> data = {};

  _FailingLicenseStorage(this.failKey);

  @override
  Future<String?> read({required String key}) async => data[key];

  @override
  Future<bool> write({required String key, required String value}) async {
    if (key == failKey) return false;
    data[key] = value;
    return true;
  }

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }
}
