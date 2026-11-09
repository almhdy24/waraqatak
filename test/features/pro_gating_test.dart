import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/core/feature_gate.dart';
import 'package:warqatek/features/reference_currency/reference_currency_feature.dart';
import 'package:warqatek/features/wholesale/wholesale_feature.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/product_unit.dart';
import 'package:warqatek/models/reference_pricing_types.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/feature_access.dart';

void main() {
  setUp(() {
    FeatureGate.resetForTesting();
  });

  tearDown(() {
    FeatureGate.resetForTesting();
  });

  group('FeatureGate entitlement evaluation', () {
    test('Null entitlement fails closed (Free mode)', () {
      FeatureGate.setEntitlement(null);
      expect(FeatureGate.isAvailable(Feature.referenceCurrency), isFalse);
      expect(FeatureGate.isAvailable(Feature.wholesalePricing), isFalse);
      expect(FeatureGate.isReferenceCurrencyEnabled, isFalse);
      expect(FeatureGate.isWholesalePricingEnabled, isFalse);
    });

    test('Trial expired entitlement is Free mode', () {
      FeatureGate.setEntitlement(
        const EntitlementState(
          status: EntitlementStatus.trialExpired,
          deviceId: 'dev-1',
          trialDaysRemaining: 0,
        ),
      );
      expect(FeatureGate.isReferenceCurrencyEnabled, isFalse);
      expect(FeatureGate.isWholesalePricingEnabled, isFalse);
    });

    test('License expired entitlement is Free mode', () {
      FeatureGate.setEntitlement(
        const EntitlementState(
          status: EntitlementStatus.licenseExpired,
          deviceId: 'dev-1',
        ),
      );
      expect(FeatureGate.isReferenceCurrencyEnabled, isFalse);
      expect(FeatureGate.isWholesalePricingEnabled, isFalse);
    });

    test('License revoked entitlement is Free mode', () {
      FeatureGate.setEntitlement(
        const EntitlementState(
          status: EntitlementStatus.licenseRevoked,
          deviceId: 'dev-1',
        ),
      );
      expect(FeatureGate.isReferenceCurrencyEnabled, isFalse);
      expect(FeatureGate.isWholesalePricingEnabled, isFalse);
    });

    test('Active trial entitles Pro features', () {
      FeatureGate.setEntitlement(
        const EntitlementState(
          status: EntitlementStatus.trialActive,
          deviceId: 'dev-1',
          trialDaysRemaining: 14,
        ),
      );
      expect(FeatureGate.isReferenceCurrencyEnabled, isTrue);
      expect(FeatureGate.isWholesalePricingEnabled, isTrue);
    });

    test('Licensed status entitles Pro features', () {
      FeatureGate.setEntitlement(
        const EntitlementState(
          status: EntitlementStatus.licensed,
          deviceId: 'dev-1',
        ),
      );
      expect(FeatureGate.isReferenceCurrencyEnabled, isTrue);
      expect(FeatureGate.isWholesalePricingEnabled, isTrue);
    });
  });

  group('WholesaleFeature module isolation and gating', () {
    final businessWithWholesale = Business(
      id: 1,
      name: 'Test Shop',
      ownerName: 'Owner',
      phone: '123456',
      address: 'Market St',
      currencyCode: 'YER',
      wholesalePricingEnabled: true,
    );

    final businessWithoutWholesale = Business(
      id: 1,
      name: 'Test Shop',
      ownerName: 'Owner',
      phone: '123456',
      address: 'Market St',
      currencyCode: 'YER',
      wholesalePricingEnabled: false,
    );

    test('Free mode: Wholesale is locked regardless of business settings', () {
      FeatureGate.setOverrideForTesting(false);

      expect(WholesaleFeature.isAvailable, isFalse);
      expect(
        WholesaleFeature.isEnabledForBusiness(businessWithWholesale),
        isFalse,
      );
      expect(
        WholesaleFeature.isEnabledForBusiness(businessWithoutWholesale),
        isFalse,
      );
      expect(WholesaleFeature.isEnabledForBusiness(null), isFalse);
      expect(WholesaleFeature.isWholesaleActive(true), isFalse);
      expect(WholesaleFeature.isWholesaleActive(false), isFalse);

      // Resolves to retail even if wholesale requested
      expect(
        WholesaleFeature.resolveCategory(
          requestedCategory: WholesaleFeature.categoryWholesale,
          wholesalePricingEnabled: true,
        ),
        equals(WholesaleFeature.categoryRetail),
      );
    });

    test('Pro mode: Wholesale follows business configuration', () {
      FeatureGate.setOverrideForTesting(true);

      expect(WholesaleFeature.isAvailable, isTrue);
      expect(
        WholesaleFeature.isEnabledForBusiness(businessWithWholesale),
        isTrue,
      );
      expect(
        WholesaleFeature.isEnabledForBusiness(businessWithoutWholesale),
        isFalse,
      );
      expect(WholesaleFeature.isEnabledForBusiness(null), isFalse);
      expect(WholesaleFeature.isWholesaleActive(true), isTrue);
      expect(WholesaleFeature.isWholesaleActive(false), isFalse);

      expect(
        WholesaleFeature.resolveCategory(
          requestedCategory: WholesaleFeature.categoryWholesale,
          wholesalePricingEnabled: true,
        ),
        equals(WholesaleFeature.categoryWholesale),
      );
      expect(
        WholesaleFeature.resolveCategory(
          requestedCategory: WholesaleFeature.categoryRetail,
          wholesalePricingEnabled: true,
        ),
        equals(WholesaleFeature.categoryRetail),
      );
      expect(
        WholesaleFeature.resolveCategory(
          requestedCategory: WholesaleFeature.categoryWholesale,
          wholesalePricingEnabled: false,
        ),
        equals(WholesaleFeature.categoryRetail),
      );
    });

    test(
      'Pricing resolution in Free mode falls back strictly to retail price',
      () {
        FeatureGate.setOverrideForTesting(false);

        final product = Product(
          id: 1,
          name: 'Sugar 50kg',
          salePrice: 40000.0,
          wholesalePrice: 35000.0,
          wholesaleMinQuantity: 5.0,
        );

        final unit = ProductUnit(
          id: 1,
          productId: 1,
          unitName: 'Bag',
          conversionFactor: 1.0,
          salePrice: 40000.0,
          wholesalePrice: 35000.0,
        );

        // In Free mode, screens evaluate wholesalePricingEnabled via WholesaleFeature.isEnabledForBusiness
        final effectiveWholesale = WholesaleFeature.isEnabledForBusiness(
          businessWithWholesale,
        );
        expect(effectiveWholesale, isFalse);

        final price = DocumentService.resolveLinePrice(
          product: product,
          availableUnits: [unit],
          quantity: 10.0,
          saleUnit: 'Bag',
          unitConversionFactor: 1.0,
          pricingCategory: WholesaleFeature.categoryRetail,
          targetCategory: WholesaleFeature.categoryWholesale,
          wholesalePricingEnabled: effectiveWholesale,
        );

        // Must be retail price (40,000) not wholesale price (35,000)
        expect(price, equals(40000.0));
      },
    );
  });

  group('ReferenceCurrencyFeature module isolation and gating', () {
    test(
      'Free mode: ReferenceCurrency is locked and asserts fail safely',
      () async {
        FeatureGate.setOverrideForTesting(false);

        expect(ReferenceCurrencyFeature.isAvailable, isFalse);

        // Query methods return empty/false without throwing
        final rates = await ReferenceCurrencyFeature.getRates();
        expect(rates, isEmpty);

        final hasRates = await ReferenceCurrencyFeature.hasRates();
        expect(hasRates, isFalse);

        final rounding = await ReferenceCurrencyFeature.getRounding();
        expect(rounding, equals(0));

        // Assert throws proFeatureRequired exception
        expect(
          () => ReferenceCurrencyFeature.assertAvailable(),
          throwsA(
            isA<ReferencePricingException>().having(
              (ReferencePricingException e) => e.code,
              'code',
              ReferencePricingError.proFeatureRequired,
            ),
          ),
        );

        // Mutations throw proFeatureRequired without executing
        expect(
          () => ReferenceCurrencyFeature.updateRateAndReprice('USD', 550.0),
          throwsA(
            isA<ReferencePricingException>().having(
              (ReferencePricingException e) => e.code,
              'code',
              ReferencePricingError.proFeatureRequired,
            ),
          ),
        );

        expect(
          () => ReferenceCurrencyFeature.recalculateAll(),
          throwsA(
            isA<ReferencePricingException>().having(
              (ReferencePricingException e) => e.code,
              'code',
              ReferencePricingError.proFeatureRequired,
            ),
          ),
        );

        expect(
          () => ReferenceCurrencyFeature.setRounding(10),
          throwsA(
            isA<ReferencePricingException>().having(
              (ReferencePricingException e) => e.code,
              'code',
              ReferencePricingError.proFeatureRequired,
            ),
          ),
        );
      },
    );

    test('Pro mode: ReferenceCurrencyFeature is available', () {
      FeatureGate.setOverrideForTesting(true);

      expect(ReferenceCurrencyFeature.isAvailable, isTrue);
      // assertAvailable does not throw
      expect(() => ReferenceCurrencyFeature.assertAvailable(), returnsNormally);
    });
  });

  group('Downgrade & Upgrade lifecycle transitions', () {
    test('Downgrade preserves catalog data while disabling features', () {
      // 1. User starts as Pro
      FeatureGate.setOverrideForTesting(true);
      expect(WholesaleFeature.isAvailable, isTrue);
      expect(ReferenceCurrencyFeature.isAvailable, isTrue);

      // Product created in Pro with reference currency and wholesale pricing
      final product = Product(
        id: 42,
        name: 'Cooking Oil 20L',
        salePrice: 25000.0,
        wholesalePrice: 22000.0,
        wholesaleMinQuantity: 3.0,
        priceCurrency: 'USD',
        referenceSalePrice: 45.0,
        referenceWholesalePrice: 40.0,
        referencePurchasePrice: 35.0,
      );

      // 2. User downgrades to Free (subscription expires)
      FeatureGate.setOverrideForTesting(false);
      expect(WholesaleFeature.isAvailable, isFalse);
      expect(ReferenceCurrencyFeature.isAvailable, isFalse);

      // In Free mode:
      // - Stored fields in product model are preserved (not deleted)
      expect(product.priceCurrency, equals('USD'));
      expect(product.referenceSalePrice, equals(45.0));
      expect(product.wholesalePrice, equals(22000.0));

      // - Sales resolve strictly to retail price (25,000)
      final salePrice = DocumentService.resolveLinePrice(
        product: product,
        quantity: 10.0,
        pricingCategory: WholesaleFeature.categoryRetail,
        targetCategory: WholesaleFeature.categoryWholesale,
        wholesalePricingEnabled: WholesaleFeature.isWholesaleActive(true),
      );
      expect(salePrice, equals(25000.0));

      // 3. User re-activates Pro (license renewed)
      FeatureGate.setOverrideForTesting(true);
      expect(WholesaleFeature.isAvailable, isTrue);
      expect(ReferenceCurrencyFeature.isAvailable, isTrue);

      // Now wholesale resolution immediately works again
      final proSalePrice = DocumentService.resolveLinePrice(
        product: product,
        quantity: 10.0,
        pricingCategory: WholesaleFeature.categoryWholesale,
        targetCategory: WholesaleFeature.categoryWholesale,
        wholesalePricingEnabled: WholesaleFeature.isWholesaleActive(true),
      );
      expect(proSalePrice, equals(22000.0));
    });
  });
}
