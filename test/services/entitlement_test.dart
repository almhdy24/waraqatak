import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/services/license_service.dart';

import 'test_keys.dart';

void main() {
  // ── EntitlementState.isSubscriptionActive ────────────────────────────────

  group('EntitlementState.isSubscriptionActive', () {
    test('trialActive grants access', () {
      final s = EntitlementState(
          status: EntitlementStatus.trialActive, deviceId: 'd', trialDaysRemaining: 7);
      expect(s.isSubscriptionActive, isTrue);
    });

    test('licensed grants access', () {
      final s = EntitlementState(
          status: EntitlementStatus.licensed, deviceId: 'd');
      expect(s.isSubscriptionActive, isTrue);
    });

    test('trialExpired denies access', () {
      final s = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      expect(s.isSubscriptionActive, isFalse);
    });

    test('licenseExpired denies access', () {
      final s = EntitlementState(
          status: EntitlementStatus.licenseExpired, deviceId: 'd');
      expect(s.isSubscriptionActive, isFalse);
    });

    test('licenseRevoked denies access', () {
      final s = EntitlementState(
          status: EntitlementStatus.licenseRevoked, deviceId: 'd');
      expect(s.isSubscriptionActive, isFalse);
    });
  });

  // ── Trial days remaining arithmetic ──────────────────────────────────────

  group('Trial days remaining', () {
    const trialDays = 14;

    DateTime trialEnd(DateTime start) => start.add(const Duration(days: trialDays));

    int remaining(DateTime start, DateTime now) {
      final remaining = trialEnd(start).difference(now);
      return remaining.isNegative ? -1 : remaining.inDays + 1;
    }

    test('14 days remaining at the very start', () {
      final start = DateTime(2025, 1, 1, 10, 0, 0);
      final now = DateTime(2025, 1, 1, 10, 0, 1);
      expect(remaining(start, now), 14);
    });

    test('1 day remaining on the last day', () {
      final start = DateTime(2025, 1, 1);
      final lastDay = DateTime(2025, 1, 14, 23, 59, 0);
      expect(remaining(start, lastDay), 1);
    });

    test('trial expires one second past the 14-day mark', () {
      final start = DateTime(2025, 1, 1, 10, 0, 0);
      final expired = start.add(const Duration(days: 14, seconds: 1));
      expect(remaining(start, expired), -1);
    });

    test('mid-trial: day 7 shows 8 remaining', () {
      final start = DateTime(2025, 6, 1, 8, 0);
      final day7 = DateTime(2025, 6, 7, 12, 0);
      expect(remaining(start, day7), greaterThanOrEqualTo(7));
      expect(remaining(start, day7), lessThanOrEqualTo(9));
    });
  });

  // ── Trial clock-rollback (real service, injected clock) ──────────────────

  group('LicenseService trial clock-rollback', () {
    late FakeLicenseStorage storage;
    late DateTime now;
    late LicenseService service;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      storage = FakeLicenseStorage();
      now = DateTime.utc(2025, 1, 1);
      service = LicenseService.forTesting(storage: storage, clock: () => now);
    });

    DateTime trialStart() => DateTime.parse(storage.data['wq_trial_start']!);

    Future<void> tick(DateTime at) async {
      now = at;
      await service.checkEntitlement(force: true);
    }

    // Starts the trial on Jan 1 and records [last] as the last launch.
    Future<void> launchedAt(DateTime last) async {
      await tick(DateTime.utc(2025, 1, 1));
      await tick(last);
    }

    test('first run starts the trial', () async {
      final s = await service.checkEntitlement(force: true);
      expect(s.status, EntitlementStatus.trialActive);
      expect(trialStart(), DateTime.utc(2025, 1, 1));
    });

    // The next two tests record the current behaviour of the trial guard:
    // a rollback beyond the tolerance moves wq_trial_start by the delta.
    test('1-hour rollback moves trial start by 1 hour', () async {
      await launchedAt(DateTime.utc(2025, 1, 5, 12));
      await tick(DateTime.utc(2025, 1, 5, 11));
      expect(trialStart(), DateTime.utc(2025, 1, 1, 1));
    });

    test('multi-day rollback moves trial start by the same amount', () async {
      await launchedAt(DateTime.utc(2025, 1, 10));
      await tick(DateTime.utc(2025, 1, 7));
      expect(trialStart(), DateTime.utc(2025, 1, 4));
    });

    test('1-minute rollback within tolerance is ignored', () async {
      await launchedAt(DateTime.utc(2025, 1, 5, 12));
      await tick(DateTime.utc(2025, 1, 5, 11, 59));
      expect(trialStart(), DateTime.utc(2025, 1, 1));
    });

    test('exactly 2-minute rollback is ignored (threshold is strict)',
        () async {
      await launchedAt(DateTime.utc(2025, 1, 5, 12));
      await tick(DateTime.utc(2025, 1, 5, 11, 58));
      expect(trialStart(), DateTime.utc(2025, 1, 1));
    });

    test('clock forward does not affect trial start', () async {
      await launchedAt(DateTime.utc(2025, 1, 5, 12));
      await tick(DateTime.utc(2025, 1, 5, 14));
      expect(trialStart(), DateTime.utc(2025, 1, 1));
    });
  });

  // ── Edge cases ───────────────────────────────────────────────────────────

  group('EntitlementState edge cases', () {
    test('null licenseExpiresAt means license never expires locally', () {
      final s = EntitlementState(
          status: EntitlementStatus.licensed, deviceId: 'd');
      expect(s.licenseExpiresAt, isNull);
      expect(s.isSubscriptionActive, isTrue);
    });

    test('deviceId is preserved across states', () {
      const id = 'abc-123-uuid';
      for (final status in EntitlementStatus.values) {
        final s = EntitlementState(status: status, deviceId: id);
        expect(s.deviceId, id);
      }
    });

    test('default trialDaysRemaining is 0', () {
      final s = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      expect(s.trialDaysRemaining, 0);
    });

    test('trialDaysRemaining is preserved', () {
      final s = EntitlementState(
          status: EntitlementStatus.trialActive,
          deviceId: 'd',
          trialDaysRemaining: 11);
      expect(s.trialDaysRemaining, 11);
    });
  });
}
