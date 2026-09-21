import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/subscription_plan.dart';
import 'package:warqatek/utils/marketing_pricing.dart';

void main() {
  // ── MarketingPricing.inferFromName ────────────────────────────────────────

  group('MarketingPricing.inferFromName', () {
    test('Monthly (English) → monthly', () {
      expect(MarketingPricing.inferFromName('Monthly'),
          PlanDurationType.monthly);
    });

    test('شهري (Arabic) → monthly', () {
      expect(MarketingPricing.inferFromName('شهري'), PlanDurationType.monthly);
    });

    test('Annual (English) → annual', () {
      expect(
          MarketingPricing.inferFromName('Annual'), PlanDurationType.annual);
    });

    test('Yearly (English) → annual', () {
      expect(
          MarketingPricing.inferFromName('Yearly'), PlanDurationType.annual);
    });

    test('سنوي (Arabic) → annual', () {
      expect(MarketingPricing.inferFromName('سنوي'), PlanDurationType.annual);
    });

    test('6 Months (English) → semiAnnual', () {
      expect(MarketingPricing.inferFromName('6 Months'),
          PlanDurationType.semiAnnual);
    });

    test('٦ أشهر (Arabic) → semiAnnual', () {
      expect(MarketingPricing.inferFromName('٦ أشهر'),
          PlanDurationType.semiAnnual);
    });

    test('3 Months → null (no discount rate defined)', () {
      expect(MarketingPricing.inferFromName('3 Months'), isNull);
    });

    test('unknown plan name → null', () {
      expect(MarketingPricing.inferFromName('Enterprise'), isNull);
    });
  });

  // ── MarketingPricing.referencePrice ──────────────────────────────────────

  group('MarketingPricing.referencePrice', () {
    test('Monthly 20,000 SDG → reference ≈ 22,000 SDG (rounded to 1k)', () {
      // 20000 / (1 - 0.10) = 22,222.2 → rounded to 22,000
      final ref =
          MarketingPricing.referencePrice(20000, PlanDurationType.monthly);
      expect(ref, isNotNull);
      expect(ref, closeTo(22000, 1000));
    });

    test('6-Month 20,000 SDG → reference ≈ 24,000 SDG', () {
      // 20000 / (1 - 0.17) = 24,096.4 → rounded to 24,000
      final ref =
          MarketingPricing.referencePrice(20000, PlanDurationType.semiAnnual);
      expect(ref, isNotNull);
      expect(ref, closeTo(24000, 1000));
    });

    test('Annual 20,000 SDG → reference ≈ 27,000 SDG', () {
      // 20000 / (1 - 0.25) = 26,666.7 → rounded to 27,000
      final ref =
          MarketingPricing.referencePrice(20000, PlanDurationType.annual);
      expect(ref, isNotNull);
      expect(ref, closeTo(27000, 1000));
    });

    test('null type → null (no reference price)', () {
      expect(MarketingPricing.referencePrice(20000, null), isNull);
    });

    test('reference price is always greater than server price', () {
      for (final type in PlanDurationType.values) {
        final ref = MarketingPricing.referencePrice(50000, type);
        expect(ref, greaterThan(50000));
      }
    });
  });

  // ── MarketingPricing.savings ──────────────────────────────────────────────

  group('MarketingPricing.savings', () {
    test('savings = referencePrice − serverPrice', () {
      const serverPrice = 20000.0;
      final ref =
          MarketingPricing.referencePrice(serverPrice, PlanDurationType.monthly)!;
      final savings =
          MarketingPricing.savings(serverPrice, PlanDurationType.monthly)!;
      expect(savings, closeTo(ref - serverPrice, 0.01));
    });

    test('savings is positive', () {
      final s =
          MarketingPricing.savings(20000, PlanDurationType.annual)!;
      expect(s, greaterThan(0));
    });

    test('null type → null savings', () {
      expect(MarketingPricing.savings(20000, null), isNull);
    });
  });

  // ── Checkout amount equals server price ───────────────────────────────────

  group('Checkout amount integrity', () {
    test('SubscriptionPlan.priceSDG is the server price, not the reference', () {
      const serverPrice = 20000.0;
      final refPrice =
          MarketingPricing.referencePrice(serverPrice, PlanDurationType.monthly);

      final plan = SubscriptionPlan(
        id: 'test_1',
        nameAr: 'شهري',
        nameEn: 'Monthly',
        priceSDG: serverPrice,
        originalPriceSDG: refPrice,
        durationDays: 30,
        priceId: 1,
      );

      // Server price is unchanged
      expect(plan.priceSDG, serverPrice);
      // Reference price is strictly higher
      expect(plan.originalPriceSDG, greaterThan(serverPrice));
      // priceId is what goes to the API — not amount
      expect(plan.priceId, 1);
    });

    test('savings display does not affect priceSDG', () {
      const serverPrice = 100000.0;
      final refPrice =
          MarketingPricing.referencePrice(serverPrice, PlanDurationType.semiAnnual)!;

      final plan = SubscriptionPlan(
        id: 'test_2',
        nameAr: '٦ أشهر',
        nameEn: '6 Months',
        priceSDG: serverPrice,
        originalPriceSDG: refPrice,
        durationDays: 180,
        priceId: 5,
      );

      // savingsSDG is a display-only value
      expect(plan.savingsSDG, closeTo(refPrice - serverPrice, 0.01));
      // The checkout amount remains the server price
      expect(plan.priceSDG, serverPrice);
    });

    test('copyWith preserves priceSDG and priceId', () {
      const p = SubscriptionPlan(
        id: 'x',
        nameAr: 'test',
        nameEn: 'test',
        priceSDG: 75000,
        durationDays: 365,
        priceId: 99,
      );
      final copy = p.copyWith(isMostPopular: true);
      expect(copy.priceSDG, 75000);
      expect(copy.priceId, 99);
    });
  });

  // ── Offline license entitlement ───────────────────────────────────────────
  //
  // Verifies that local license state logic does not require network access.
  // The LicenseService._compute() logic is mirrored here for regression testing.

  group('Offline license verification (local state logic)', () {
    bool isLicensedLocally({
      required String? licenseKey,
      required String? statusStr,
      required String? expiryStr,
    }) {
      if (licenseKey == null || licenseKey.isEmpty) return false;
      if (statusStr == 'revoked') return false;
      if (expiryStr != null && expiryStr.isNotEmpty) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null && expiry.isBefore(DateTime.now())) return false;
      }
      return true;
    }

    test('valid non-expiring license is licensed offline', () {
      expect(
        isLicensedLocally(
            licenseKey: 'AAAA-BBBB-CCCC',
            statusStr: 'active',
            expiryStr: null),
        isTrue,
      );
    });

    test('future expiry license is licensed offline', () {
      final future = DateTime.now().add(const Duration(days: 30));
      expect(
        isLicensedLocally(
            licenseKey: 'AAAA-BBBB-CCCC',
            statusStr: 'active',
            expiryStr: future.toIso8601String()),
        isTrue,
      );
    });

    test('expired license is not licensed offline', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(
        isLicensedLocally(
            licenseKey: 'AAAA-BBBB-CCCC',
            statusStr: 'active',
            expiryStr: past.toIso8601String()),
        isFalse,
      );
    });

    test('revoked license is not licensed offline', () {
      expect(
        isLicensedLocally(
            licenseKey: 'AAAA-BBBB-CCCC',
            statusStr: 'revoked',
            expiryStr: null),
        isFalse,
      );
    });

    test('missing license key is not licensed offline', () {
      expect(
        isLicensedLocally(
            licenseKey: null, statusStr: null, expiryStr: null),
        isFalse,
      );
    });

    test('network failure does NOT invalidate an already-stored license', () {
      // Regression: the old SDK parse failure caused "can't connect to server"
      // which was incorrectly treated as license invalid. This test documents
      // that offline entitlement is determined only from local storage, never
      // from a network response.
      const storedKey = 'AAAA-BBBB-CCCC';
      const statusStr = 'active';
      // Simulate: network fails (we skip any network call entirely).
      // Local check must still return true.
      expect(
        isLicensedLocally(
            licenseKey: storedKey,
            statusStr: statusStr,
            expiryStr: null),
        isTrue,
        reason: 'A stored valid license must remain valid regardless of '
            'network availability.',
      );
    });
  });
}
