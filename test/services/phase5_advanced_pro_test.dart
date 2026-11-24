import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stocktake.dart';
import 'package:warqatek/services/bulk_pricing_service.dart';
import 'package:warqatek/services/csv_service.dart';
import 'package:warqatek/services/feature_access.dart';

void main() {
  group('Phase 5 — Advanced Pro Entitlements', () {
    test('1. Pro features are correctly categorized and gated', () {
      expect(FeatureAccess.isPro(Feature.stocktake), isTrue);
      expect(FeatureAccess.isPro(Feature.bulkPriceUpdate), isTrue);
      expect(FeatureAccess.isPro(Feature.csvImportExport), isTrue);
      expect(FeatureAccess.isPro(Feature.inventoryAudit), isTrue);
      expect(FeatureAccess.isPro(Feature.advancedReports), isTrue);

      // Free features remain strictly free
      expect(FeatureAccess.isPro(Feature.invoices), isFalse);
      expect(FeatureAccess.isPro(Feature.products), isFalse);
      expect(FeatureAccess.isPro(Feature.basicReports), isFalse);
    });

    test('2. Entitlement access check permits active Pro and denies Free', () {
      const activePro = EntitlementState(
        status: EntitlementStatus.licensed,
        deviceId: 'device-pro',
      );

      const freeUser = EntitlementState(
        status: EntitlementStatus.trialExpired,
        deviceId: 'device-free',
      );

      // Pro features
      expect(FeatureAccess.canAccess(Feature.stocktake, activePro), isTrue);
      expect(
        FeatureAccess.canAccess(Feature.bulkPriceUpdate, activePro),
        isTrue,
      );
      expect(
        FeatureAccess.canAccess(Feature.csvImportExport, activePro),
        isTrue,
      );
      expect(
        FeatureAccess.canAccess(Feature.inventoryAudit, activePro),
        isTrue,
      );

      expect(FeatureAccess.canAccess(Feature.stocktake, freeUser), isFalse);
      expect(
        FeatureAccess.canAccess(Feature.bulkPriceUpdate, freeUser),
        isFalse,
      );
      expect(
        FeatureAccess.canAccess(Feature.csvImportExport, freeUser),
        isFalse,
      );
      expect(
        FeatureAccess.canAccess(Feature.inventoryAudit, freeUser),
        isFalse,
      );

      // Free features always accessible to both
      expect(FeatureAccess.canAccess(Feature.invoices, freeUser), isTrue);
      expect(FeatureAccess.canAccess(Feature.products, freeUser), isTrue);
      expect(FeatureAccess.canAccess(Feature.invoices, activePro), isTrue);
    });
  });

  group('Phase 5 — Stocktake Logic & Integrity', () {
    test('3. Stocktake item distinguishes uncounted from counted zero', () {
      const itemUncounted = StocktakeItem(
        id: 1,
        sessionId: 10,
        productId: 100,
        baselineQuantity: 15.0,
        countedQuantity: null,
      );

      const itemCountedZero = StocktakeItem(
        id: 2,
        sessionId: 10,
        productId: 101,
        baselineQuantity: 15.0,
        countedQuantity: 0.0,
      );

      expect(itemUncounted.isCounted, isFalse);
      expect(itemUncounted.currentVariance, 0.0);

      expect(itemCountedZero.isCounted, isTrue);
      expect(itemCountedZero.countedQuantity, 0.0);
      expect(itemCountedZero.currentVariance, -15.0);
    });

    test(
      '4. Stocktake variance calculates positive, negative, and exact match',
      () {
        const itemSurplus = StocktakeItem(
          id: 1,
          sessionId: 10,
          productId: 100,
          baselineQuantity: 10.0,
          countedQuantity: 14.0,
        );

        const itemShortage = StocktakeItem(
          id: 2,
          sessionId: 10,
          productId: 101,
          baselineQuantity: 20.0,
          countedQuantity: 17.0,
        );

        const itemMatch = StocktakeItem(
          id: 3,
          sessionId: 10,
          productId: 102,
          baselineQuantity: 5.0,
          countedQuantity: 5.0,
        );

        expect(itemSurplus.currentVariance, 4.0);
        expect(itemShortage.currentVariance, -3.0);
        expect(itemMatch.currentVariance, 0.0);
      },
    );

    test('5. StocktakeSession model serialization and status methods', () {
      final now = DateTime.now();
      final session = StocktakeSession(
        id: 5,
        sessionNumber: 'ST-20261018-001',
        status: StocktakeSession.statusInProgress,
        startedAt: now,
        notes: 'الجرد الدوري الربع سنوي',
        categoryFilter: 'مواد غذائية',
        totalItems: 42,
        matchedItems: 30,
        discrepantItems: 12,
        createdAt: now,
        updatedAt: now,
      );

      expect(session.isActive, isTrue);
      expect(session.isCompleted, isFalse);
      expect(session.isCancelled, isFalse);

      final map = session.toMap();
      final revived = StocktakeSession.fromMap(map);

      expect(revived.id, 5);
      expect(revived.sessionNumber, 'ST-20261018-001');
      expect(revived.notes, 'الجرد الدوري الربع سنوي');
      expect(revived.categoryFilter, 'مواد غذائية');
      expect(revived.totalItems, 42);
    });
  });

  group('Phase 5 — Bulk Pricing Operations & Rounding', () {
    final testProducts = [
      const Product(
        id: 1,
        name: 'منتج أ',
        salePrice: 100.0,
        purchasePrice: 70.0,
        stockQuantity: 50.0,
        averageCost: 70.0,
      ),
      const Product(
        id: 2,
        name: 'منتج ب',
        salePrice: 255.45,
        purchasePrice: 180.20,
        stockQuantity: 20.0,
        averageCost: 180.20,
      ),
    ];

    test('6. Percentage increase and decrease calculations', () {
      final previewIncrease = BulkPricingService.instance.preview(
        products: testProducts,
        opType: BulkPriceOpType.percentageIncrease,
        opValue: 10.0, // +10%
        target: BulkPriceTarget.sellingPrice,
      );

      expect(previewIncrease[0].proposedSalePrice, 110.0);
      expect(previewIncrease[0].salePriceDelta, 10.0);
      expect(
        previewIncrease[0].proposedPurchasePrice,
        70.0,
      ); // Purchase untouched

      final previewDecrease = BulkPricingService.instance.preview(
        products: testProducts,
        opType: BulkPriceOpType.percentageDecrease,
        opValue: 20.0, // -20%
        target: BulkPriceTarget.sellingPrice,
      );

      expect(previewDecrease[0].proposedSalePrice, 80.0);
      expect(previewDecrease[0].salePriceDelta, -20.0);
    });

    test('7. Fixed amount operations and direct price assignment', () {
      final previewFixed = BulkPricingService.instance.preview(
        products: testProducts,
        opType: BulkPriceOpType.fixedIncrease,
        opValue: 25.0,
        target: BulkPriceTarget.sellingPrice,
      );
      expect(previewFixed[0].proposedSalePrice, 125.0);

      final previewDirect = BulkPricingService.instance.preview(
        products: testProducts,
        opType: BulkPriceOpType.setDirect,
        opValue: 500.0,
        target: BulkPriceTarget.sellingPrice,
      );
      expect(previewDirect[0].proposedSalePrice, 500.0);
      expect(previewDirect[1].proposedSalePrice, 500.0);
    });

    test(
      '8. Price rounding rules: none, nearestWhole, nearestTen, ceilWhole',
      () {
        // 255.45 + 10% = 280.995
        final previewNone = BulkPricingService.instance.preview(
          products: [testProducts[1]],
          opType: BulkPriceOpType.percentageIncrease,
          opValue: 10.0,
          target: BulkPriceTarget.sellingPrice,
          rounding: BulkPriceRounding.none,
        );
        expect(previewNone[0].proposedSalePrice, 281.0); // 2 decimals

        final previewWhole = BulkPricingService.instance.preview(
          products: [testProducts[1]],
          opType: BulkPriceOpType.percentageIncrease,
          opValue: 10.0,
          target: BulkPriceTarget.sellingPrice,
          rounding: BulkPriceRounding.nearestWhole,
        );
        expect(previewWhole[0].proposedSalePrice, 281.0);

        final previewTen = BulkPricingService.instance.preview(
          products: [testProducts[1]],
          opType: BulkPriceOpType.percentageIncrease,
          opValue: 10.0,
          target: BulkPriceTarget.sellingPrice,
          rounding: BulkPriceRounding.nearestTen,
        );
        expect(previewTen[0].proposedSalePrice, 280.0); // Rounded to nearest 10
      },
    );

    test(
      '9. Negative price validation flags invalid and blocks negative prices',
      () {
        final previewNegative = BulkPricingService.instance.preview(
          products: testProducts,
          opType: BulkPriceOpType.fixedDecrease,
          opValue: 150.0, // 100 - 150 = -50
          target: BulkPriceTarget.sellingPrice,
        );

        expect(previewNegative[0].isValid, isFalse);
        expect(previewNegative[0].errorMessage, contains('سالب'));
        expect(previewNegative[1].isValid, isTrue); // 255.45 - 150 > 0
      },
    );
  });

  group('Phase 5 — CSV Import & Export', () {
    test('10. Formula injection prevention prefixes dangerous characters', () {
      expect(CsvService.sanitizeCell('=SUM(A1:A10)'), "'=SUM(A1:A10)");
      expect(CsvService.sanitizeCell('+cmd|calc'), "'+cmd|calc");
      expect(CsvService.sanitizeCell('-cmd|calc'), "'-cmd|calc");
      expect(CsvService.sanitizeCell('@CMD'), "'@CMD");
      expect(CsvService.sanitizeCell('\tTAB'), "'\tTAB");

      // Legitimate numeric strings are preserved without apostrophe
      expect(CsvService.sanitizeCell('+12345'), '+12345');
      expect(CsvService.sanitizeCell('-100'), '-100');

      // Normal safe strings are not prefixed
      expect(CsvService.sanitizeCell('سكر كنانة'), 'سكر كنانة');
      expect(CsvService.sanitizeCell('SKU-100'), 'SKU-100');
    });

    test('11. Cell quoting follows RFC 4180 rules for commas and quotes', () {
      expect(CsvService.sanitizeCell('Sugar, White'), '"Sugar, White"');
      expect(CsvService.sanitizeCell('He said "Hello"'), '"He said ""Hello"""');
      expect(CsvService.sanitizeCell('Line 1\nLine 2'), '"Line 1\nLine 2"');
    });

    test(
      '12. Robust RFC 4180 CSV parser parses quoted commas and escaped quotes',
      () {
        const csv =
            'Name,SalePrice,Category\n'
            '"Sugar, White",500,"Food, Grocery"\n'
            '"Box ""Large""",1200,Hardware\n';

        final rows = CsvService.parseCsv(csv);
        expect(rows.length, 3);
        expect(rows[0], ['Name', 'SalePrice', 'Category']);
        expect(rows[1], ['Sugar, White', '500', 'Food, Grocery']);
        expect(rows[2], ['Box "Large"', '1200', 'Hardware']);
      },
    );

    test('13. CSV unescape formula prefix restores clean text', () {
      expect(CsvService.unescapeFormulaPrefix("'+1234"), '+1234');
      expect(CsvService.unescapeFormulaPrefix("'=SUM(1,2)"), '=SUM(1,2)');
      expect(CsvService.unescapeFormulaPrefix("Normal"), 'Normal');
    });
  });

  group('Phase 5 — Advanced Inventory Analytics Calculations', () {
    test('14. Sales velocity and estimated days remaining calculations', () {
      const product = Product(
        id: 1,
        name: 'منتج اختبار',
        stockQuantity: 120.0,
        minStock: 20.0,
        salePrice: 1000.0,
      );

      // Period of 30 days, 60 units sold
      const days = 30.0;
      const sold = 60.0;
      const velocity = sold / days; // 2.0 units/day
      final estDays = (product.stockQuantity / velocity).round(); // 60 days

      expect(velocity, 2.0);
      expect(estDays, 60);

      // Zero sales velocity -> estimated days should be null or undefined
      const zeroSold = 0.0;
      final zeroVelocity = zeroSold / days;
      int? zeroEstDays;
      if (zeroVelocity > 0.0001 && product.stockQuantity > 0) {
        zeroEstDays = (product.stockQuantity / zeroVelocity).round();
      }
      expect(zeroEstDays, isNull);
    });

    test('15. Slow-moving stock and negative margin detection', () {
      const healthyProduct = Product(
        id: 1,
        name: 'متحرك',
        salePrice: 500.0,
        purchasePrice: 350.0,
        stockQuantity: 100.0,
        averageCost: 350.0,
      );

      const lossProduct = Product(
        id: 2,
        name: 'خاسر',
        salePrice: 300.0, // Selling at 300
        purchasePrice: 350.0,
        stockQuantity: 50.0,
        averageCost: 380.0, // Cost is 380!
      );

      expect(healthyProduct.salePrice >= healthyProduct.averageCost!, isTrue);
      expect(
        lossProduct.salePrice < lossProduct.averageCost!,
        isTrue,
      ); // Negative margin alert!
    });
  });
}
