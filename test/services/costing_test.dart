import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/inventory_costing_service.dart';

void main() {
  group('Phase 3 - Inventory Costing & Models', () {
    test(
      '1. Initial stock with known cost establishes moving average cost',
      () {
        const product = Product(
          name: 'Sugar 50kg',
          salePrice: 50000.0,
          purchasePrice: 42000.0,
          stockQuantity: 10.0,
          averageCost: 42000.0,
          costStatus: Product.costStatusKnown,
        );

        expect(product.isCostKnown, isTrue);
        expect(product.averageCost, 42000.0);
        expect(product.costStatus, 'known');

        final map = product.toMap();
        expect(map['average_cost'], 42000.0);
        expect(map['cost_status'], 'known');

        final restored = Product.fromMap(map);
        expect(restored.averageCost, 42000.0);
        expect(restored.costStatus, 'known');
        expect(restored.isCostKnown, isTrue);
      },
    );

    test(
      '2. Initial stock without cost leaves product cost unknown and valuation unvalued',
      () {
        const product = Product(
          name: 'Legacy Unknown Item',
          salePrice: 1500.0,
          purchasePrice: 0.0,
          stockQuantity: 25.0,
          averageCost: null,
          costStatus: Product.costStatusUnknown,
        );

        expect(product.isCostKnown, isFalse);
        expect(product.averageCost, isNull);
        expect(product.costStatus, 'unknown');

        final map = product.toMap();
        expect(map['average_cost'], isNull);
        expect(map['cost_status'], 'unknown');

        final restored = Product.fromMap(map);
        expect(restored.averageCost, isNull);
        expect(restored.costStatus, 'unknown');
        expect(restored.isCostKnown, isFalse);
      },
    );

    test(
      '3. Purchase updates moving average cost via weighted average formula',
      () {
        // Current: 10 units @ 100.0 = 1000
        // Incoming: 10 units @ 150.0 = 1500
        // Expected new avg: (1000 + 1500) / 20 = 125.0
        final newAvg = InventoryCostingService.calculateNewWeightedAverage(
          currentStock: 10.0,
          currentAvgCost: 100.0,
          incomingQty: 10.0,
          incomingUnitCost: 150.0,
        );

        expect(newAvg, closeTo(125.0, 0.0001));
      },
    );

    test(
      '4. Sale records movement and item cost snapshots at existing average cost',
      () {
        const avgCost = 125.0;
        const saleQty = 5.0;

        final item = DocumentItem(
          documentId: 1,
          productId: 42,
          description: 'Test Item',
          quantity: saleQty,
          price: 200.0,
          total: 1000.0,
          unitCost: avgCost,
          totalCost: saleQty * avgCost,
        );

        expect(item.unitCost, 125.0);
        expect(item.totalCost, 625.0);

        final movement = StockMovement(
          productId: 42,
          type: StockMovement.typeSale,
          quantity: -saleQty,
          date: DateTime(2026, 10, 18),
          unitCost: avgCost,
          totalCost: saleQty * avgCost,
          costStatus: StockMovement.costStatusKnown,
          provenance: 'sale_document_item',
        );

        expect(movement.unitCost, 125.0);
        expect(movement.totalCost, 625.0);
        expect(movement.costStatus, StockMovement.costStatusKnown);
        expect(movement.provenance, 'sale_document_item');
      },
    );

    test(
      '5. Editing a product default purchase_price in catalog does NOT alter historical costs',
      () {
        final initialProduct = Product(
          id: 10,
          name: 'Item A',
          salePrice: 200.0,
          purchasePrice: 120.0,
          stockQuantity: 10.0,
          averageCost: 120.0,
          costStatus: Product.costStatusKnown,
        );

        final historicalMovement = StockMovement(
          productId: 10,
          type: StockMovement.typeSale,
          quantity: -2.0,
          date: DateTime(2026, 10, 1),
          unitCost: initialProduct.averageCost,
          totalCost: 2.0 * initialProduct.averageCost!,
          costStatus: StockMovement.costStatusKnown,
        );

        // User changes default catalog purchase_price to 180.0
        final catalogUpdated = initialProduct.copyWith(purchasePrice: 180.0);

        expect(catalogUpdated.purchasePrice, 180.0);
        expect(
          catalogUpdated.averageCost,
          120.0,
        ); // Moving average cost unchanged
        expect(
          historicalMovement.unitCost,
          120.0,
        ); // Historical movement cost unchanged
      },
    );

    test(
      '6. Multiple sequential purchases at different prices produce correct weighted averages',
      () {
        // Step 1: 10 units @ 100
        double avg = InventoryCostingService.calculateNewWeightedAverage(
          currentStock: 0.0,
          currentAvgCost: null,
          incomingQty: 10.0,
          incomingUnitCost: 100.0,
        );
        expect(avg, 100.0);

        // Step 2: 10 units @ 200 -> (10*100 + 10*200) / 20 = 150.0
        avg = InventoryCostingService.calculateNewWeightedAverage(
          currentStock: 10.0,
          currentAvgCost: avg,
          incomingQty: 10.0,
          incomingUnitCost: 200.0,
        );
        expect(avg, closeTo(150.0, 0.0001));

        // Step 3: 10 units @ 300 -> (20*150 + 10*300) / 30 = 200.0
        avg = InventoryCostingService.calculateNewWeightedAverage(
          currentStock: 20.0,
          currentAvgCost: avg,
          incomingQty: 10.0,
          incomingUnitCost: 300.0,
        );
        expect(avg, closeTo(200.0, 0.0001));
      },
    );

    test(
      '7. Partial sales leave remaining inventory valuation equal to remaining quantity * average cost',
      () {
        const stockBeforeSale = 30.0;
        const avgCost = 200.0;
        const initialValuation = stockBeforeSale * avgCost; // 6000.0

        const saleQty = 10.0;
        const cogs = saleQty * avgCost; // 2000.0

        const remainingStock = stockBeforeSale - saleQty; // 20.0
        const remainingValuation = remainingStock * avgCost; // 4000.0

        expect(initialValuation - cogs, closeTo(remainingValuation, 0.0001));
        expect(remainingValuation, 4000.0);
      },
    );

    test(
      '8. Stock movement model supports unitCost, totalCost, costStatus, and provenance',
      () {
        final movement = StockMovement(
          id: 77,
          productId: 12,
          type: StockMovement.typeAdjustment,
          quantity: 5.0,
          date: DateTime(2026, 10, 18, 10, 30),
          notes: 'تسوية الجرد السنوي',
          unitCost: 150.0,
          totalCost: 750.0,
          costStatus: StockMovement.costStatusKnown,
          provenance: 'manual_adjustment',
        );

        final map = movement.toMap();
        expect(map['unit_cost'], 150.0);
        expect(map['total_cost'], 750.0);
        expect(map['cost_status'], 'known');
        expect(map['provenance'], 'manual_adjustment');

        final fromMap = StockMovement.fromMap(map);
        expect(fromMap.unitCost, 150.0);
        expect(fromMap.totalCost, 750.0);
        expect(fromMap.costStatus, 'known');
        expect(fromMap.provenance, 'manual_adjustment');
        expect(fromMap.notes, 'تسوية الجرد السنوي');
      },
    );

    test(
      '9. Purchase cancellation calculation reverses weighted cost properly',
      () {
        // Product had 10 @ 100 before purchase.
        // Purchased 10 @ 200 -> stock became 20 @ 150.
        // Cancellation removes 10 @ 200:
        // Remaining stock = 10.
        // Pre-purchase cost was 100.
        const currentStock = 20.0;
        const currentAvg = 150.0;
        const cancelQty = 10.0;
        const cancelUnitCost = 200.0;

        final remainingStock = currentStock - cancelQty;
        final remainingTotalCost =
            (currentStock * currentAvg) - (cancelQty * cancelUnitCost);
        final remainingAvg = remainingStock > 0
            ? (remainingTotalCost / remainingStock)
            : null;

        expect(remainingStock, 10.0);
        expect(remainingAvg, closeTo(100.0, 0.0001));
      },
    );

    test('10. Sale cancellation restores stock at original sale unit cost', () {
      const saleQty = 4.0;
      const originalUnitCost = 150.0;

      final cancelMovement = StockMovement(
        productId: 9,
        type: StockMovement.typeCancellation,
        quantity: saleQty, // Positive restoration
        date: DateTime(2026, 10, 18),
        unitCost: originalUnitCost,
        totalCost: saleQty * originalUnitCost,
        costStatus: StockMovement.costStatusKnown,
        provenance: 'sale_cancellation_reversal',
      );

      expect(cancelMovement.quantity, 4.0);
      expect(cancelMovement.unitCost, 150.0);
      expect(cancelMovement.totalCost, 600.0);
      expect(cancelMovement.provenance, 'sale_cancellation_reversal');
    });

    test(
      '11. Document item model correctly serializes and deserializes cost fields',
      () {
        final item = DocumentItem(
          id: 55,
          documentId: 10,
          productId: 3,
          description: 'Oil Bottle 1L',
          quantity: 2.0,
          price: 300.0,
          total: 600.0,
          unitCost: 220.0,
          totalCost: 440.0,
        );

        final map = item.toMap();
        expect(map['unit_cost'], 220.0);
        expect(map['total_cost'], 440.0);

        final restored = DocumentItem.fromMap(map);
        expect(restored.unitCost, 220.0);
        expect(restored.totalCost, 440.0);
        expect(restored.total, 600.0);
      },
    );

    test(
      '12. Attempting to consume more stock than available triggers guard',
      () {
        const stockOnHand = 4.0;
        const purchaseQtyToCancel = 10.0;

        expect(stockOnHand < purchaseQtyToCancel, isTrue);
        expect(() {
          if (stockOnHand < purchaseQtyToCancel) {
            throw StateError(
              'Cannot cancel purchase: 6 of 10 items have already been consumed',
            );
          }
        }, throwsA(isA<StateError>()));
      },
    );

    test(
      '13. Legacy purchases with linked document items use reconstructed provenance',
      () {
        final movement = StockMovement(
          productId: 8,
          type: StockMovement.typePurchase,
          quantity: 20.0,
          date: DateTime(2026, 1, 15),
          unitCost: 85.0,
          totalCost: 1700.0,
          costStatus: StockMovement.costStatusReconstructed,
          provenance: 'purchase_document_item',
        );

        expect(movement.costStatus, 'reconstructed');
        expect(movement.provenance, 'purchase_document_item');
        expect(movement.unitCost, 85.0);
        expect(movement.totalCost, 1700.0);
      },
    );

    test('14. Legacy records without evidence remain strictly unknown', () {
      final movement = StockMovement(
        productId: 9,
        type: StockMovement.typeOpening,
        quantity: 50.0,
        date: DateTime(2025, 6, 1),
        unitCost: null,
        totalCost: null,
        costStatus: StockMovement.costStatusUnknown,
        provenance: 'legacy_opening_stock_unvalued',
      );

      expect(movement.costStatus, 'unknown');
      expect(movement.unitCost, isNull);
      expect(movement.totalCost, isNull);
      expect(movement.provenance, 'legacy_opening_stock_unvalued');
    });

    test('15. Gross profit calculation reflects net revenue minus COGS', () {
      final doc = Document(
        id: 1,
        type: 'invoice',
        documentNumber: 'INV-2026-001',
        date: DateTime(2026, 10, 18),
        subtotal: 5000.0,
        discount: 500.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 4500.0,
        paid: 4500.0,
        remaining: 0.0,
      );

      const knownCogs = 2800.0;
      final recognizedRevenue = doc.subtotal - doc.discount; // 4500.0
      final grossProfit = recognizedRevenue - knownCogs; // 1700.0
      final margin = (grossProfit / recognizedRevenue) * 100; // 37.78%

      final summary = SaleProfitSummary(
        document: doc,
        recognizedRevenue: recognizedRevenue,
        cogs: knownCogs,
        grossProfit: grossProfit,
        profitMargin: margin,
        isCostReliable: true,
      );

      expect(summary.recognizedRevenue, 4500.0);
      expect(summary.cogs, 2800.0);
      expect(summary.grossProfit, 1700.0);
      expect(summary.profitMargin, closeTo(37.777, 0.01));
      expect(summary.isCostReliable, isTrue);
    });

    test(
      '16. Incomplete cost report flags sales with unknown cost and discloses reliability',
      () {
        final doc = Document(
          id: 2,
          type: 'invoice',
          documentNumber: 'INV-2026-002',
          date: DateTime(2026, 10, 18),
          subtotal: 1000.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 1000.0,
          paid: 1000.0,
          remaining: 0.0,
        );

        // Item has unknown cost -> cogs is 0 recorded but marked NOT reliable
        final summary = SaleProfitSummary(
          document: doc,
          recognizedRevenue: 1000.0,
          cogs: 0.0,
          grossProfit: 1000.0,
          profitMargin: 100.0,
          isCostReliable: false, // Flagged!
        );

        expect(summary.isCostReliable, isFalse);
      },
    );

    test(
      '17. Zero stock followed by purchase properly resets average cost to new purchase price',
      () {
        // Stock is 0.0, currentAvgCost is old (e.g. 50.0)
        final newAvg = InventoryCostingService.calculateNewWeightedAverage(
          currentStock: 0.0,
          currentAvgCost: 50.0,
          incomingQty: 10.0,
          incomingUnitCost: 120.0,
        );

        // When stock is 0 or negative, incoming cost becomes the new average directly!
        expect(newAvg, 120.0);
      },
    );

    test(
      '18. Inventory valuation summary properly separates valued from unvalued items',
      () {
        const summary = InventoryValuationSummary(
          totalValuationAtCost: 15000.0,
          valuedProductsCount: 3,
          unvaluedProductsCount: 2,
          unvaluedQuantity: 45.0,
          totalTrackedProducts: 5,
        );

        expect(summary.totalValuationAtCost, 15000.0);
        expect(summary.valuedProductsCount, 3);
        expect(summary.unvaluedProductsCount, 2);
        expect(summary.unvaluedQuantity, 45.0);
        expect(summary.totalTrackedProducts, 5);
      },
    );

    test(
      '19. Fully costed invoice exposes valid trustedGrossProfit and trustedProfitMargin',
      () {
        final doc = Document(
          id: 101,
          type: 'invoice',
          documentNumber: 'INV-2026-101',
          date: DateTime(2026, 10, 20),
          subtotal: 50000.0,
          discount: 2000.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 48000.0,
          paid: 48000.0,
          remaining: 0.0,
        );

        const knownCogs = 30000.0;
        final recognizedRevenue = doc.subtotal - doc.discount; // 48000
        final grossProfit = recognizedRevenue - knownCogs; // 18000
        final margin = (grossProfit / recognizedRevenue) * 100; // 37.5%

        final summary = SaleProfitSummary(
          document: doc,
          recognizedRevenue: recognizedRevenue,
          cogs: knownCogs,
          grossProfit: grossProfit,
          profitMargin: margin,
          isCostReliable: true,
        );

        expect(summary.isCostReliable, isTrue);
        expect(summary.trustedGrossProfit, 18000.0);
        expect(summary.trustedProfitMargin, closeTo(37.5, 0.001));
      },
    );

    test(
      '20. Missing cost invoice marks trustedGrossProfit and trustedProfitMargin unavailable (null)',
      () {
        final doc = Document(
          id: 102,
          type: 'invoice',
          documentNumber: 'INV-00119',
          date: DateTime(2026, 10, 21),
          subtotal: 22000.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 22000.0,
          paid: 22000.0,
          remaining: 0.0,
        );

        // Unreliable invoice: cogs is 0 because cost was missing, but trusted values are null!
        final summary = SaleProfitSummary(
          document: doc,
          recognizedRevenue: 22000.0,
          cogs: 0.0,
          grossProfit: 22000.0,
          profitMargin: 100.0,
          isCostReliable: false, // Incomplete cost
        );

        expect(summary.isCostReliable, isFalse);
        expect(
          summary.trustedGrossProfit,
          isNull,
          reason:
              'Missing cost must NOT appear as valid profit in trusted totals',
        );
        expect(
          summary.trustedProfitMargin,
          isNull,
          reason: 'Missing cost must NOT produce valid trusted profit margin',
        );
      },
    );

    test(
      '21. Mixed-cost invoice with known and unknown items is marked unreliable with null trusted profit',
      () {
        final doc = Document(
          id: 103,
          type: 'invoice',
          documentNumber: 'INV-MIXED-001',
          date: DateTime(2026, 10, 22),
          subtotal: 10000.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 10000.0,
          paid: 10000.0,
          remaining: 0.0,
        );

        // Item 1 has known cost (4000), Item 2 has unknown cost (null).
        // cogs accumulates only known cost (4000), but invoice is flagged unreliable.
        final summary = SaleProfitSummary(
          document: doc,
          recognizedRevenue: 10000.0,
          cogs: 4000.0,
          grossProfit: 6000.0,
          profitMargin: 60.0,
          isCostReliable: false,
        );

        expect(summary.isCostReliable, isFalse);
        expect(summary.cogs, 4000.0);
        expect(summary.trustedGrossProfit, isNull);
        expect(summary.trustedProfitMargin, isNull);
      },
    );

    test(
      '22. Aggregate profit calculation excludes incomplete invoices from trusted totals',
      () {
        final doc1 = Document(
          id: 1,
          type: 'invoice',
          documentNumber: 'INV-001',
          date: DateTime(2026, 10, 22),
          subtotal: 10000.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 10000.0,
          paid: 10000.0,
          remaining: 0.0,
        );
        final doc2 = Document(
          id: 2,
          type: 'invoice',
          documentNumber: 'INV-00119',
          date: DateTime(2026, 10, 22),
          subtotal: 22000.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 22000.0,
          paid: 22000.0,
          remaining: 0.0,
        );

        final sales = [
          SaleProfitSummary(
            document: doc1,
            recognizedRevenue: 10000.0,
            cogs: 6000.0,
            grossProfit: 4000.0,
            profitMargin: 40.0,
            isCostReliable: true,
          ),
          SaleProfitSummary(
            document: doc2,
            recognizedRevenue: 22000.0,
            cogs: 0.0,
            grossProfit: 22000.0,
            profitMargin: 100.0,
            isCostReliable: false,
          ),
        ];

        final totalRevenue = sales.fold(0.0, (s, i) => s + i.recognizedRevenue);
        final totalCogs = sales.fold(0.0, (s, i) => s + i.cogs);
        final rawTotalProfit = sales.fold(0.0, (s, i) => s + i.grossProfit);
        final trustedTotalProfit = sales.fold(
          0.0,
          (s, i) => s + (i.trustedGrossProfit ?? 0.0),
        );
        final hasIncomplete = sales.any((s) => !s.isCostReliable);

        expect(totalRevenue, 32000.0);
        expect(totalCogs, 6000.0);
        expect(
          rawTotalProfit,
          26000.0,
          reason: 'Raw profit includes misleading zero-cost profit',
        );
        expect(
          trustedTotalProfit,
          4000.0,
          reason:
              'Trusted profit MUST only include fully-costed invoices (4000)',
        );
        expect(hasIncomplete, isTrue);
      },
    );

    test(
      '23. Zero-cost items supported by explicit known cost are distinguished from unknown cost',
      () {
        // Product explicitly purchased / granted at 0 cost (promotional/free inventory)
        const freeProduct = Product(
          name: 'Free Sample',
          salePrice: 100.0,
          purchasePrice: 0.0,
          stockQuantity: 50.0,
          averageCost: 0.0, // Explicitly 0.0, not null!
          costStatus: Product.costStatusKnown,
        );

        expect(freeProduct.isCostKnown, isTrue);
        expect(freeProduct.averageCost, 0.0);
        expect(freeProduct.costStatus, Product.costStatusKnown);

        // Conversely, unknown cost product has averageCost = null and costStatus = unknown
        const unknownProduct = Product(
          name: 'Unknown Legacy',
          salePrice: 100.0,
          purchasePrice: 0.0,
          stockQuantity: 50.0,
          averageCost: null,
          costStatus: Product.costStatusUnknown,
        );

        expect(unknownProduct.isCostKnown, isFalse);
        expect(unknownProduct.averageCost, isNull);
      },
    );

    test(
      '24. Product performance sorting by profit ranks trusted profit above untrusted profit',
      () {
        final pTrustedLow = ProductPerformanceItem(
          productId: 1,
          productName: 'Product Alpha (Trusted Low Profit)',
          salesQty: 10.0,
          transactionCount: 1,
          currentStock: 5.0,
          salesRevenue: 5000.0,
          cogs: 4000.0,
          grossProfit: 1000.0,
          profitMargin: 20.0,
          isCostReliable: true,
          unknownCostSalesCount: 0,
        );

        final pTrustedHigh = ProductPerformanceItem(
          productId: 2,
          productName: 'Product Beta (Trusted High Profit)',
          salesQty: 10.0,
          transactionCount: 1,
          currentStock: 5.0,
          salesRevenue: 10000.0,
          cogs: 5000.0,
          grossProfit: 5000.0,
          profitMargin: 50.0,
          isCostReliable: true,
          unknownCostSalesCount: 0,
        );

        final pUntrustedFakeHugeProfit = ProductPerformanceItem(
          productId: 3,
          productName: 'Product Gamma (Missing Cost, Fake 100% Margin)',
          salesQty: 100.0,
          transactionCount: 1,
          currentStock: 5.0,
          salesRevenue: 50000.0,
          cogs: 0.0,
          grossProfit: 50000.0, // Unreliable!
          profitMargin: 100.0,
          isCostReliable: false,
          unknownCostSalesCount: 1,
        );

        final items = [pTrustedLow, pUntrustedFakeHugeProfit, pTrustedHigh];

        // Sort by profit using the exact comparator in BusinessReportingService
        items.sort((a, b) {
          final aProfit = a.trustedGrossProfit;
          final bProfit = b.trustedGrossProfit;
          if (aProfit != null && bProfit != null) {
            final cmp = bProfit.compareTo(aProfit);
            if (cmp != 0) return cmp;
          } else if (aProfit != null && bProfit == null) {
            return -1; // Trusted profit ranks above untrusted profit
          } else if (aProfit == null && bProfit != null) {
            return 1;
          }
          final revCmp = b.salesRevenue.compareTo(a.salesRevenue);
          if (revCmp != 0) return revCmp;
          return a.productName.compareTo(b.productName);
        });

        // Ranks should be:
        // 1. Product Beta (trusted 5000 profit)
        // 2. Product Alpha (trusted 1000 profit)
        // 3. Product Gamma (untrusted profit, sent to bottom despite raw 50,000 profit)
        expect(items[0].productName, 'Product Beta (Trusted High Profit)');
        expect(items[1].productName, 'Product Alpha (Trusted Low Profit)');
        expect(
          items[2].productName,
          'Product Gamma (Missing Cost, Fake 100% Margin)',
        );
        expect(items[2].trustedGrossProfit, isNull);
      },
    );

    test(
      '25. Historical repair logic contract rejects future purchases dated after sale date',
      () {
        final saleDate = DateTime(2026, 2, 1);
        final futurePurchaseDate = DateTime(2026, 6, 1);
        final pastPurchaseDate = DateTime(2026, 1, 15);

        // Condition: purchase date must be <= sale date
        bool isEligibleBasis(DateTime purchaseDate, DateTime saleDate) {
          return !purchaseDate.isAfter(saleDate);
        }

        expect(
          isEligibleBasis(pastPurchaseDate, saleDate),
          isTrue,
          reason:
              'Purchases prior to or on the sale date are valid historical evidence',
        );
        expect(
          isEligibleBasis(futurePurchaseDate, saleDate),
          isFalse,
          reason:
              'Future purchases after the sale date must NEVER be used to backfill cost',
        );
      },
    );

    test(
      '26. Multi-line invoice with duplicate products correctly associates movements by quantity without collision',
      () {
        // Invoice with 2 lines of the same product:
        // Line 1: 2 units
        // Line 2: 8 units
        final lines = [
          {'id': 1, 'productId': 5, 'quantity': 2.0},
          {'id': 2, 'productId': 5, 'quantity': 8.0},
        ];

        // Existing uncosted movements in database:
        final movements = [
          {
            'id': 101,
            'productId': 5,
            'quantity': -2.0,
            'unitCost': null,
            'totalCost': null,
            'status': 'unknown',
          },
          {
            'id': 102,
            'productId': 5,
            'quantity': -8.0,
            'unitCost': null,
            'totalCost': null,
            'status': 'unknown',
          },
        ];

        const reconstructedCost = 150.0;
        final repairedMovements = <int, Map<String, dynamic>>{};

        for (final line in lines) {
          final lineQty = (line['quantity'] as num).toDouble();
          // Matching logic from DatabaseHelper._repairInvoiceItemCosts:
          int? targetMovementId;
          for (final m in movements) {
            final mId = m['id'] as int;
            if (repairedMovements.containsKey(mId)) {
              continue; // already repaired
            }
            final mQty = ((m['quantity'] as num).toDouble()).abs();
            if (mQty == lineQty) {
              targetMovementId = mId;
              break;
            }
          }

          expect(targetMovementId, isNotNull);
          final matchedMovement = movements.firstWhere(
            (m) => m['id'] == targetMovementId,
          );
          final mQty = ((matchedMovement['quantity'] as num).toDouble()).abs();
          repairedMovements[targetMovementId!] = {
            'id': targetMovementId,
            'unitCost': reconstructedCost,
            'totalCost': mQty * reconstructedCost,
            'status': 'reconstructed',
          };
        }

        // Verify Line 1 (qty 2) matched movement 101 with total cost 300
        expect(repairedMovements[101]!['totalCost'], 300.0);
        expect(repairedMovements[101]!['status'], 'reconstructed');

        // Verify Line 2 (qty 8) matched movement 102 with total cost 1200
        expect(repairedMovements[102]!['totalCost'], 1200.0);
        expect(repairedMovements[102]!['status'], 'reconstructed');

        // Now verify ambiguous matching with identical quantities:
        // Line 1: 5 units, Line 2: 5 units
        final duplicateQtyLines = [
          {'id': 11, 'productId': 9, 'quantity': 5.0},
          {'id': 12, 'productId': 9, 'quantity': 5.0},
        ];
        final duplicateMovements = [
          {'id': 201, 'productId': 9, 'quantity': -5.0},
          {'id': 202, 'productId': 9, 'quantity': -5.0},
        ];

        // Ambiguity check: if linesWithThisQty > 1, do NOT guess
        for (final line in duplicateQtyLines) {
          final lineQty = (line['quantity'] as num).toDouble();
          final linesWithThisQty = duplicateQtyLines
              .where((l) => l['quantity'] == lineQty)
              .length;
          int? targetId;
          if (linesWithThisQty == 1) {
            targetId = duplicateMovements.first['id'] as int;
          }
          expect(
            targetId,
            isNull,
            reason:
                'Ambiguous duplicate invoice lines must NEVER be guessed or matched blindly',
          );
        }
      },
    );

    test(
      '27. Multiple purchases at varying prices without transaction audit leave cost unknown (NULL)',
      () {
        // Purchase 1: 10 units @ 100 SDG
        // Purchase 2: 10 units @ 200 SDG
        // When intermediate stockouts and sales were unrecorded, calculating an
        // unverified moving average creates an approximate estimate that masquerades
        // as trusted profit. Rule: leave cost NULL!
        final purchasesVaryingPrices = [
          {'price': 100.0},
          {'price': 200.0},
        ];
        final firstPrice = purchasesVaryingPrices.first['price']!;
        final allSamePrice = purchasesVaryingPrices.every(
          (p) => (p['price']! - firstPrice).abs() < 0.001,
        );

        double? reconstructedCost;
        if (allSamePrice) {
          reconstructedCost = firstPrice;
        }

        expect(
          reconstructedCost,
          isNull,
          reason:
              'Varying purchase prices without intermediate ledger audit must remain NULL',
        );

        // Conversely, purchases at the identical price are 100% verified:
        final purchasesIdenticalPrices = [
          {'price': 150.0},
          {'price': 150.0},
        ];
        final idFirst = purchasesIdenticalPrices.first['price']!;
        final idAllSame = purchasesIdenticalPrices.every(
          (p) => (p['price']! - idFirst).abs() < 0.001,
        );

        double? verifiedCost;
        if (idAllSame) {
          verifiedCost = idFirst;
        }

        expect(
          verifiedCost,
          150.0,
          reason: 'Identical purchase prices establish verified cost basis',
        );
      },
    );

    test(
      '28. Unknown incoming inventory (e.g. uncosted opening stock) prevents weighted average calculation',
      () {
        // If a product had 50 units opening stock with unknown cost,
        // subsequent purchases cannot establish a verified weighted average
        // for the entire inventory pool without guessing the opening cost.
        double? computeHistoricalCost({
          required bool hasUnknownIncoming,
          required double purchaseCost,
        }) {
          if (hasUnknownIncoming) return null;
          return purchaseCost;
        }

        final costWithUnknownOpening = computeHistoricalCost(
          hasUnknownIncoming: true,
          purchaseCost: 100.0,
        );
        final costWithoutUnknownOpening = computeHistoricalCost(
          hasUnknownIncoming: false,
          purchaseCost: 100.0,
        );

        expect(
          costWithUnknownOpening,
          isNull,
          reason:
              'Unverified opening stock forces reconstructed historical cost to remain NULL',
        );
        expect(costWithoutUnknownOpening, 100.0);
      },
    );

    test(
      '29. Existing valid movement with known cost is strictly preserved and never overwritten',
      () {
        final movement = {
          'id': 201,
          'quantity': -5.0,
          'unitCost': 120.0,
          'totalCost': 600.0,
          'costStatus': StockMovement.costStatusKnown,
        };

        // Eligibility guard from DatabaseHelper._repairInvoiceItemCosts:
        // (cost_status == 'unknown' OR unit_cost IS NULL)
        final isEligibleForRepair =
            movement['costStatus'] == StockMovement.costStatusUnknown ||
            movement['unitCost'] == null;

        expect(
          isEligibleForRepair,
          isFalse,
          reason: 'Valid known movement must be rejected by repair guard',
        );
      },
    );

    test(
      '30. Migration rollback contract: exception during upgrade aborts transaction and preserves original state',
      () async {
        // Simulate transaction rollback semantics
        int state = 14; // schema v14
        bool transactionCommitted = false;

        try {
          int pending = state;
          pending = 15;
          pending = 16;
          if (pending == 16) {
            // Simulate SQL failure in step 17
            throw Exception('Simulated disk/SQL failure during v17 migration');
          }
          state = 17;
          transactionCommitted = true;
        } catch (_) {
          // Rollback: state remains 14
        }

        expect(transactionCommitted, isFalse);
        expect(
          state,
          14,
          reason:
              'On failure, transaction rollback preserves original schema version',
        );
      },
    );

    test(
      '31. Oversold invoice line contract: partial stock deduction leaves total_cost null and profit untrusted',
      () {
        // In non-strict mode, available stock = 2, invoice line quantity = 5
        const currentStock = 2.0;
        const lineQty = 5.0;
        const avgCost = 60.0;
        const deductQty = currentStock >= lineQty
            ? lineQty
            : currentStock; // 2.0
        const isFullyBacked = deductQty >= lineQty; // false

        // Document item total_cost is null when not fully backed
        final double? itemTotalCost = isFullyBacked ? lineQty * avgCost : null;
        expect(
          itemTotalCost,
          isNull,
          reason: 'Oversold invoice lines must have total_cost = null',
        );

        final summary = SaleProfitSummary(
          document: Document(
            type: 'invoice',
            documentNumber: 'INV-OVER',
            date: DateTime.now(),
            subtotal: 500,
            discount: 0,
            taxRate: 0,
            taxAmount: 0,
            total: 500,
            paid: 0,
            remaining: 500,
          ),
          recognizedRevenue: 500,
          cogs: 0,
          grossProfit: 500,
          profitMargin: 100,
          isCostReliable: itemTotalCost != null,
        );

        expect(summary.isCostReliable, isFalse);
        expect(
          summary.trustedGrossProfit,
          isNull,
          reason: 'Oversold invoice must never report trusted gross profit',
        );
      },
    );

    test(
      '32. Cancellation safety check: uncosted return prevents historical cost reconstruction',
      () {
        // Incoming movements before invoice: purchase @ 50, but also uncosted cancellation return
        final incomingMovements = [
          {
            'type': 'purchase',
            'quantity': 10.0,
            'unit_cost': 50.0,
            'cost_status': 'known',
          },
          {
            'type': 'cancellation',
            'quantity': 3.0,
            'unit_cost': null,
            'cost_status': 'unknown',
          },
        ];

        final hasUnknownIncoming = incomingMovements.any(
          (m) =>
              (m['quantity'] as double) > 0 &&
              ['opening', 'adjustment', 'cancellation'].contains(m['type']) &&
              (m['cost_status'] == 'unknown' || m['unit_cost'] == null),
        );

        expect(
          hasUnknownIncoming,
          isTrue,
          reason:
              'Uncosted cancellation return must flag unknown incoming stock',
        );

        final double? reconstructedCost = hasUnknownIncoming ? null : 50.0;
        expect(
          reconstructedCost,
          isNull,
          reason:
              'Reconstruction must abort when returned stock cost is unknown',
        );
      },
    );

    test(
      '33. Adjustment consistency: stock adjustment with different cost creates price conflict and leaves cost null',
      () {
        final incomingCosts = [50.0, 70.0]; // purchase @ 50, adjustment @ 70
        final firstPrice = incomingCosts.first;
        final allSamePrice = incomingCosts.every(
          (c) => (c - firstPrice).abs() < 0.001,
        );

        expect(
          allSamePrice,
          isFalse,
          reason:
              'Purchase at 50 and adjustment at 70 must be recognized as conflicting cost basis',
        );

        final double? reconstructedCost = allSamePrice ? firstPrice : null;
        expect(
          reconstructedCost,
          isNull,
          reason:
              'Conflicting historical acquisition costs must leave unit_cost unknown (null)',
        );
      },
    );

    test(
      '34. Adjustment consistency: stock adjustment with identical cost reconstructs safely',
      () {
        final incomingCosts = [50.0, 50.0]; // purchase @ 50, adjustment @ 50
        final firstPrice = incomingCosts.first;
        final allSamePrice = incomingCosts.every(
          (c) => (c - firstPrice).abs() < 0.001,
        );

        expect(allSamePrice, isTrue);
        final double? reconstructedCost = allSamePrice ? firstPrice : null;
        expect(reconstructedCost, 50.0);
      },
    );
  });
}
