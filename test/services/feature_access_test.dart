import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/services/feature_access.dart';

void main() {
  // ── isPro classification ─────────────────────────────────────────────────

  group('FeatureAccess.isPro', () {
    test('purchases is Pro', () => expect(FeatureAccess.isPro(Feature.purchases), isTrue));
    test('inventory is Pro', () => expect(FeatureAccess.isPro(Feature.inventory), isTrue));
    test('advancedReports is Pro', () => expect(FeatureAccess.isPro(Feature.advancedReports), isTrue));
    test('referenceCurrency is Pro', () => expect(FeatureAccess.isPro(Feature.referenceCurrency), isTrue));
    test('wholesalePricing is Pro', () => expect(FeatureAccess.isPro(Feature.wholesalePricing), isTrue));
    test('digitalSeals is Pro', () => expect(FeatureAccess.isPro(Feature.digitalSeals), isTrue));
    test('invoices is Free', () => expect(FeatureAccess.isPro(Feature.invoices), isFalse));
    test('quotations is Free', () => expect(FeatureAccess.isPro(Feature.quotations), isFalse));
    test('vouchers is Free', () => expect(FeatureAccess.isPro(Feature.vouchers), isFalse));
    test('customDocuments is Free', () => expect(FeatureAccess.isPro(Feature.customDocuments), isFalse));
    test('customers is Free', () => expect(FeatureAccess.isPro(Feature.customers), isFalse));
    test('products is Free', () => expect(FeatureAccess.isPro(Feature.products), isFalse));
    test('barcode is Free', () => expect(FeatureAccess.isPro(Feature.barcode), isFalse));
    test('basicReports is Free', () => expect(FeatureAccess.isPro(Feature.basicReports), isFalse));
    test('backupRestore is Free', () => expect(FeatureAccess.isPro(Feature.backupRestore), isFalse));
  });

  // ── Free features — always accessible ───────────────────────────────────

  group('FeatureAccess.canAccess — Free features', () {
    final freeFeatures = [
      Feature.invoices, Feature.quotations, Feature.vouchers,
      Feature.customDocuments, Feature.customers, Feature.products,
      Feature.barcode, Feature.basicReports, Feature.backupRestore,
    ];

    test('all Free features accessible during active trial', () {
      final s = EntitlementState(
          status: EntitlementStatus.trialActive, deviceId: 'd', trialDaysRemaining: 7);
      for (final f in freeFeatures) {
        expect(FeatureAccess.canAccess(f, s), isTrue, reason: '$f should be free');
      }
    });

    test('all Free features accessible when trial expired', () {
      final s = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      for (final f in freeFeatures) {
        expect(FeatureAccess.canAccess(f, s), isTrue, reason: '$f should remain free after trial');
      }
    });

    test('all Free features accessible when licensed', () {
      final s = EntitlementState(status: EntitlementStatus.licensed, deviceId: 'd');
      for (final f in freeFeatures) {
        expect(FeatureAccess.canAccess(f, s), isTrue);
      }
    });

    test('all Free features accessible when license expired', () {
      final s = EntitlementState(
          status: EntitlementStatus.licenseExpired, deviceId: 'd');
      for (final f in freeFeatures) {
        expect(FeatureAccess.canAccess(f, s), isTrue);
      }
    });

    test('all Free features accessible with null entitlement (loading)', () {
      for (final f in freeFeatures) {
        expect(FeatureAccess.canAccess(f, null), isTrue);
      }
    });
  });

  // ── Pro features — gated by subscription ────────────────────────────────

  group('FeatureAccess.canAccess — Pro features', () {
    test('accessible during active trial', () {
      final s = EntitlementState(
          status: EntitlementStatus.trialActive, deviceId: 'd', trialDaysRemaining: 3);
      expect(FeatureAccess.canAccess(Feature.purchases, s), isTrue);
      expect(FeatureAccess.canAccess(Feature.inventory, s), isTrue);
      expect(FeatureAccess.canAccess(Feature.advancedReports, s), isTrue);
    });

    test('accessible when licensed', () {
      final s = EntitlementState(status: EntitlementStatus.licensed, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.purchases, s), isTrue);
      expect(FeatureAccess.canAccess(Feature.inventory, s), isTrue);
      expect(FeatureAccess.canAccess(Feature.advancedReports, s), isTrue);
    });

    test('blocked when trial expired', () {
      final s = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.purchases, s), isFalse);
      expect(FeatureAccess.canAccess(Feature.inventory, s), isFalse);
      expect(FeatureAccess.canAccess(Feature.advancedReports, s), isFalse);
    });

    test('blocked when license expired', () {
      final s = EntitlementState(
          status: EntitlementStatus.licenseExpired, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.purchases, s), isFalse);
      expect(FeatureAccess.canAccess(Feature.inventory, s), isFalse);
      expect(FeatureAccess.canAccess(Feature.advancedReports, s), isFalse);
    });

    test('blocked when license revoked', () {
      final s = EntitlementState(
          status: EntitlementStatus.licenseRevoked, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.purchases, s), isFalse);
      expect(FeatureAccess.canAccess(Feature.inventory, s), isFalse);
    });

    test('blocked with null entitlement (fail closed)', () {
      // Null means entitlement not available or still loading — fail closed for Pro.
      expect(FeatureAccess.canAccess(Feature.purchases, null), isFalse);
      expect(FeatureAccess.canAccess(Feature.inventory, null), isFalse);
      expect(FeatureAccess.canAccess(Feature.advancedReports, null), isFalse);
    });
  });

  // ── Screen action feature gating regressions ──────────────────────────────

  group('Screen action feature gating', () {
    test('supplier purchase action is gated by Feature.purchases', () {
      final licensed = EntitlementState(
          status: EntitlementStatus.licensed, deviceId: 'd');
      final trial = EntitlementState(
          status: EntitlementStatus.trialActive,
          deviceId: 'd',
          trialDaysRemaining: 5);
      expect(FeatureAccess.canAccess(Feature.purchases, licensed), isTrue);
      expect(FeatureAccess.canAccess(Feature.purchases, trial), isTrue);

      final expired = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      final revoked = EntitlementState(
          status: EntitlementStatus.licenseRevoked, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.purchases, expired), isFalse);
      expect(FeatureAccess.canAccess(Feature.purchases, revoked), isFalse);
      expect(FeatureAccess.canAccess(Feature.purchases, null), isFalse);
    });

    test('products warehouse action is gated by Feature.inventory', () {
      final licensed = EntitlementState(
          status: EntitlementStatus.licensed, deviceId: 'd');
      final trial = EntitlementState(
          status: EntitlementStatus.trialActive,
          deviceId: 'd',
          trialDaysRemaining: 5);
      expect(FeatureAccess.canAccess(Feature.inventory, licensed), isTrue);
      expect(FeatureAccess.canAccess(Feature.inventory, trial), isTrue);

      final expired = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      final revoked = EntitlementState(
          status: EntitlementStatus.licenseRevoked, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.inventory, expired), isFalse);
      expect(FeatureAccess.canAccess(Feature.inventory, revoked), isFalse);
      expect(FeatureAccess.canAccess(Feature.inventory, null), isFalse);
    });

    test('referenceCurrency is gated for Pro users only', () {
      final licensed = EntitlementState(
          status: EntitlementStatus.licensed, deviceId: 'd');
      final trial = EntitlementState(
          status: EntitlementStatus.trialActive,
          deviceId: 'd',
          trialDaysRemaining: 5);
      expect(FeatureAccess.canAccess(Feature.referenceCurrency, licensed), isTrue);
      expect(FeatureAccess.canAccess(Feature.referenceCurrency, trial), isTrue);

      final expired = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      final revoked = EntitlementState(
          status: EntitlementStatus.licenseRevoked, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.referenceCurrency, expired), isFalse);
      expect(FeatureAccess.canAccess(Feature.referenceCurrency, revoked), isFalse);
      expect(FeatureAccess.canAccess(Feature.referenceCurrency, null), isFalse);
    });

    test('wholesalePricing is gated for Pro users only', () {
      final licensed = EntitlementState(
          status: EntitlementStatus.licensed, deviceId: 'd');
      final trial = EntitlementState(
          status: EntitlementStatus.trialActive,
          deviceId: 'd',
          trialDaysRemaining: 5);
      expect(FeatureAccess.canAccess(Feature.wholesalePricing, licensed), isTrue);
      expect(FeatureAccess.canAccess(Feature.wholesalePricing, trial), isTrue);

      final expired = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      final revoked = EntitlementState(
          status: EntitlementStatus.licenseRevoked, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.wholesalePricing, expired), isFalse);
      expect(FeatureAccess.canAccess(Feature.wholesalePricing, revoked), isFalse);
      expect(FeatureAccess.canAccess(Feature.wholesalePricing, null), isFalse);
    });

    test('digitalSeals is gated for Pro users only', () {
      final licensed = EntitlementState(
          status: EntitlementStatus.licensed, deviceId: 'd');
      final trial = EntitlementState(
          status: EntitlementStatus.trialActive,
          deviceId: 'd',
          trialDaysRemaining: 5);
      expect(FeatureAccess.canAccess(Feature.digitalSeals, licensed), isTrue);
      expect(FeatureAccess.canAccess(Feature.digitalSeals, trial), isTrue);

      final expired = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      final revoked = EntitlementState(
          status: EntitlementStatus.licenseRevoked, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.digitalSeals, expired), isFalse);
      expect(FeatureAccess.canAccess(Feature.digitalSeals, revoked), isFalse);
      expect(FeatureAccess.canAccess(Feature.digitalSeals, null), isFalse);
    });

    test('regular customer invoice action uses Feature.invoices (always free)', () {
      final expired = EntitlementState(
          status: EntitlementStatus.trialExpired, deviceId: 'd');
      final revoked = EntitlementState(
          status: EntitlementStatus.licenseRevoked, deviceId: 'd');
      expect(FeatureAccess.canAccess(Feature.invoices, expired), isTrue);
      expect(FeatureAccess.canAccess(Feature.invoices, revoked), isTrue);
      expect(FeatureAccess.canAccess(Feature.invoices, null), isTrue);
    });
  });
}
