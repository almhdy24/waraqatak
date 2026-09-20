import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/services/feature_access.dart';

void main() {
  // ── isPro classification ─────────────────────────────────────────────────

  group('FeatureAccess.isPro', () {
    test('purchases is Pro', () => expect(FeatureAccess.isPro(Feature.purchases), isTrue));
    test('inventory is Pro', () => expect(FeatureAccess.isPro(Feature.inventory), isTrue));
    test('advancedReports is Pro', () => expect(FeatureAccess.isPro(Feature.advancedReports), isTrue));
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

    test('allowed with null entitlement (still loading)', () {
      // Null means entitlement not yet loaded — default to allow to avoid
      // false blocks at startup before the cache is warm.
      expect(FeatureAccess.canAccess(Feature.purchases, null), isTrue);
      expect(FeatureAccess.canAccess(Feature.inventory, null), isTrue);
      expect(FeatureAccess.canAccess(Feature.advancedReports, null), isTrue);
    });
  });

  // ── Pending order does not affect feature access ─────────────────────────

  group('FeatureAccess — order state is independent', () {
    test('Pro accessible when trial active with pending order', () {
      final s = EntitlementState(
        status: EntitlementStatus.trialActive,
        deviceId: 'd',
        trialDaysRemaining: 5,
        orderStatus: PendingOrderStatus.pending,
        orderReference: 'ORD-001',
      );
      expect(FeatureAccess.canAccess(Feature.purchases, s), isTrue);
    });

    test('Pro blocked when trial expired even with pending order', () {
      final s = EntitlementState(
        status: EntitlementStatus.trialExpired,
        deviceId: 'd',
        orderStatus: PendingOrderStatus.pending,
        orderReference: 'ORD-001',
      );
      expect(FeatureAccess.canAccess(Feature.inventory, s), isFalse);
    });
  });
}
