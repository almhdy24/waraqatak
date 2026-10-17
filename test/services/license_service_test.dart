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
}
