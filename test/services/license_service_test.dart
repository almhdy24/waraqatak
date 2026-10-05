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
      storage.data['wq_license_expiry'] = '2026-13-45';
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
}
