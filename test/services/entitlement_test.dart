import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/models/subscription_plan.dart';

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

  // ── Order state is independent of subscription entitlement ───────────────

  group('Order state vs subscription state', () {
    test('trialActive with pending order is still active', () {
      final s = EntitlementState(
        status: EntitlementStatus.trialActive,
        deviceId: 'd',
        trialDaysRemaining: 5,
        orderStatus: PendingOrderStatus.pending,
        orderReference: 'ORD-001',
      );
      expect(s.isSubscriptionActive, isTrue);
      expect(s.orderStatus, PendingOrderStatus.pending);
    });

    test('trialExpired with pending order is still not active', () {
      final s = EntitlementState(
        status: EntitlementStatus.trialExpired,
        deviceId: 'd',
        orderStatus: PendingOrderStatus.pending,
        orderReference: 'ORD-001',
      );
      expect(s.isSubscriptionActive, isFalse);
      expect(s.orderStatus, PendingOrderStatus.pending);
    });

    test('licensed with rejected order is still active', () {
      final s = EntitlementState(
        status: EntitlementStatus.licensed,
        deviceId: 'd',
        orderStatus: PendingOrderStatus.rejected,
        orderReference: 'ORD-001',
        rejectionNote: 'Unclear proof',
      );
      expect(s.isSubscriptionActive, isTrue);
      expect(s.orderStatus, PendingOrderStatus.rejected);
      expect(s.rejectionNote, 'Unclear proof');
    });

    test('no order by default', () {
      final s = EntitlementState(
          status: EntitlementStatus.trialActive, deviceId: 'd', trialDaysRemaining: 3);
      expect(s.orderStatus, PendingOrderStatus.none);
      expect(s.orderReference, isNull);
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

  // ── SubscriptionPlan calculations ────────────────────────────────────────

  group('SubscriptionPlan', () {
    test('monthly plan has no discount', () {
      const p = SubscriptionPlan(
          id: 'monthly', nameAr: 'شهري', nameEn: 'Monthly',
          priceSDG: 20000, durationDays: 30);
      expect(p.hasDiscount, isFalse);
      expect(p.savingsSDG, isNull);
    });

    test('annual plan has discount', () {
      const p = SubscriptionPlan(
          id: 'annual', nameAr: 'سنوي', nameEn: 'Annual',
          priceSDG: 180000, originalPriceSDG: 240000, durationDays: 365);
      expect(p.hasDiscount, isTrue);
      expect(p.savingsSDG, 60000);
    });

    test('monthly equivalent for annual plan', () {
      const p = SubscriptionPlan(
          id: 'annual', nameAr: 'سنوي', nameEn: 'Annual',
          priceSDG: 180000, durationDays: 365);
      // 180000 / (365/30) ≈ 14794.5
      expect(p.monthlyEquivalentSDG, closeTo(14794.5, 1.0));
    });

    test('monthly plan monthly equivalent equals its price', () {
      const p = SubscriptionPlan(
          id: 'monthly', nameAr: 'شهري', nameEn: 'Monthly',
          priceSDG: 20000, durationDays: 30);
      expect(p.monthlyEquivalentSDG, closeTo(20000, 0.01));
    });

    test('catalogue has 4 plans', () {
      expect(SubscriptionPlan.plans.length, 4);
    });

    test('catalogue plan ids are unique', () {
      final ids = SubscriptionPlan.plans.map((p) => p.id).toSet();
      expect(ids.length, SubscriptionPlan.plans.length);
    });

    test('all catalogue plans have positive price and duration', () {
      for (final p in SubscriptionPlan.plans) {
        expect(p.priceSDG, greaterThan(0));
        expect(p.durationDays, greaterThan(0));
      }
    });
  });

  // ── Renewal date math ────────────────────────────────────────────────────
  //
  // The server computes renewal expiry as max(currentExpiry, now) + planDays.
  // These tests document and verify the expected pure-math behaviour.

  group('Renewal date math', () {
    DateTime computeNewExpiry(DateTime? currentExpiry, DateTime now, int planDays) {
      final base = (currentExpiry != null && currentExpiry.isAfter(now))
          ? currentExpiry
          : now;
      return base.add(Duration(days: planDays));
    }

    test('renewal with future expiry extends from that expiry', () {
      final now = DateTime(2025, 6, 1);
      final currentExpiry = DateTime(2025, 7, 1); // 30 days in future
      final newExpiry = computeNewExpiry(currentExpiry, now, 30);
      expect(newExpiry, DateTime(2025, 7, 31)); // extends from July 1
    });

    test('renewal with past expiry extends from now', () {
      final now = DateTime(2025, 6, 1);
      final currentExpiry = DateTime(2025, 5, 1); // expired
      final newExpiry = computeNewExpiry(currentExpiry, now, 30);
      expect(newExpiry, DateTime(2025, 7, 1)); // extends from today
    });

    test('renewal with null expiry (never-expires license) extends from now', () {
      final now = DateTime(2025, 6, 1);
      final newExpiry = computeNewExpiry(null, now, 90);
      expect(newExpiry, DateTime(2025, 8, 30));
    });

    test('same-day renewal extends from now not from today-midnight', () {
      final now = DateTime(2025, 6, 1, 14, 30); // afternoon
      final currentExpiry = DateTime(2025, 6, 1, 8, 0); // expired this morning
      final newExpiry = computeNewExpiry(currentExpiry, now, 30);
      // expires < now so base = now
      expect(newExpiry, now.add(const Duration(days: 30)));
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
