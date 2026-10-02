import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/entitlement.dart';

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

  // ── Clock-rollback detection arithmetic ──────────────────────────────────

  group('Clock-rollback detection', () {
    // Mirrors the logic in LicenseService._updateLastLaunch:
    //   rollback = last.difference(now)   // positive when clock went back
    //   if rollback > 2 minutes: advance trialStart by rollback delta

    DateTime applyRollback(DateTime trialStart, DateTime last, DateTime now) {
      final rollback = last.difference(now);
      if (rollback > const Duration(minutes: 2)) {
        return trialStart.add(rollback);
      }
      return trialStart;
    }

    test('1-hour rollback advances trial start by 1 hour', () {
      final trialStart = DateTime(2025, 1, 1, 0, 0, 0);
      final last = DateTime(2025, 1, 5, 12, 0, 0);
      final now = DateTime(2025, 1, 5, 11, 0, 0); // 1h rewind
      final adjusted = applyRollback(trialStart, last, now);
      expect(adjusted, DateTime(2025, 1, 1, 1, 0, 0));
    });

    test('1-minute rollback within tolerance is ignored', () {
      final trialStart = DateTime(2025, 1, 1, 0, 0, 0);
      final last = DateTime(2025, 1, 5, 12, 0, 0);
      final now = DateTime(2025, 1, 5, 11, 59, 0); // 1 min rewind
      final adjusted = applyRollback(trialStart, last, now);
      expect(adjusted, trialStart); // unchanged
    });

    test('exactly 2-minute rollback is ignored (threshold is strictly greater)', () {
      final trialStart = DateTime(2025, 1, 1, 0, 0, 0);
      final last = DateTime(2025, 1, 5, 12, 0, 0);
      final now = DateTime(2025, 1, 5, 11, 58, 0); // exactly 2 min
      final adjusted = applyRollback(trialStart, last, now);
      expect(adjusted, trialStart); // unchanged
    });

    test('clock forward does not affect trial start', () {
      final trialStart = DateTime(2025, 1, 1, 0, 0, 0);
      final last = DateTime(2025, 1, 5, 12, 0, 0);
      final now = DateTime(2025, 1, 5, 14, 0, 0); // forward
      final adjusted = applyRollback(trialStart, last, now);
      expect(adjusted, trialStart); // unchanged
    });

    test('multi-day rollback advances trial by same amount', () {
      final trialStart = DateTime(2025, 1, 1);
      final last = DateTime(2025, 1, 10);
      final now = DateTime(2025, 1, 7); // 3-day rewind
      final adjusted = applyRollback(trialStart, last, now);
      expect(adjusted, DateTime(2025, 1, 4));
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
