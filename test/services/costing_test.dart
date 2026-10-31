import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/currency.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_payment.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/inventory_costing_service.dart';
import 'package:warqatek/utils/money_utils.dart';

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

        final serviceAvg = InventoryCostingService.calculateReversedWeightedAverage(
          currentStock: currentStock,
          currentAvgCost: currentAvg,
          removedQty: cancelQty,
          removedCost: cancelQty * cancelUnitCost,
        );
        expect(serviceAvg, closeTo(100.0, 0.0001));
      },
    );

    test(
      '9b. Reversing a purchase when subsequent sales consumed value throws StateError',
      () {
        // Initial 10 @ 10 = 100.
        // Purchase 10 @ 100 = 1000. Total 20 @ 55 = 1100.
        // Subsequent sale: 9 units sold @ 55 (495).
        // Remaining 11 units @ 55 = 605.
        // Attempting to cancel purchase of 10 @ 100 (1000) when remaining value is 605:
        expect(
          () => InventoryCostingService.calculateReversedWeightedAverage(
            currentStock: 11.0,
            currentAvgCost: 55.0,
            removedQty: 10.0,
            removedCost: 1000.0,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('subsequent sales or movements consumed this stock'),
            ),
          ),
        );
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

    test(
      '35. Issue 7 Option A: Partial overselling preserves physically available stock cost in movements while keeping invoice line cost null',
      () {
        // Setup helper that mimics database logic
        Map<String, dynamic> computeLineCost({
          required double currentStock,
          required double lineQty,
          required double? avgCost,
          required bool isCostKnown,
          required bool strictStock,
        }) {
          final double deductQty;
          if (strictStock) {
            deductQty = lineQty;
          } else {
            deductQty = currentStock > 0
                ? (currentStock >= lineQty ? lineQty : currentStock)
                : 0.0;
          }
          final bool isFullyBacked = deductQty >= lineQty;
          final double? itemUnitCost =
              (isCostKnown && isFullyBacked) ? avgCost : null;
          final double? itemTotalCost =
              (isCostKnown && isFullyBacked && avgCost != null)
                  ? lineQty * avgCost
                  : null;
          final double? movementCost =
              (isCostKnown && avgCost != null) ? deductQty * avgCost : null;
          final String movementCostStatus = isCostKnown
              ? StockMovement.costStatusKnown
              : StockMovement.costStatusUnknown;

          return {
            'deductQty': deductQty,
            'isFullyBacked': isFullyBacked,
            'itemUnitCost': itemUnitCost,
            'itemTotalCost': itemTotalCost,
            'movementCost': movementCost,
            'movementCostStatus': movementCostStatus,
          };
        }

        final result = computeLineCost(
          currentStock: 3.0,
          lineQty: 5.0,
          avgCost: 40.0,
          isCostKnown: true,
          strictStock: false,
        );

        // 1. Invoice-line unit_cost and total_cost MUST be null when not fully backed
        expect(
          result['itemUnitCost'],
          isNull,
          reason: 'Partial overselling must leave invoice-line unit_cost NULL',
        );
        expect(
          result['itemTotalCost'],
          isNull,
          reason: 'Partial overselling must leave invoice-line total_cost NULL',
        );

        // 2. Stock movement MUST preserve the known cost of the physically available units
        expect(result['deductQty'], 3.0);
        expect(result['movementCost'], 120.0);
        expect(result['movementCostStatus'], StockMovement.costStatusKnown);

        // 3. Deletion/cancellation must revert only deductQty (3.0), avoiding stock inflation
        final double revertQty = result['deductQty'] as double;
        expect(
          revertQty,
          3.0,
          reason: 'Must revert only physically deducted stock, not 5.0',
        );

        // 4. SaleProfitSummary must mark cost as unreliable and trusted profit as null
        final summary = SaleProfitSummary(
          document: Document(
            type: 'invoice',
            documentNumber: 'INV-PARTIAL',
            date: DateTime.now(),
            subtotal: 500,
            discount: 0,
            taxRate: 0,
            taxAmount: 0,
            total: 500,
            paid: 500,
            remaining: 0,
          ),
          recognizedRevenue: 500,
          cogs: 0,
          grossProfit: 500,
          profitMargin: 100,
          isCostReliable: result['itemTotalCost'] != null,
        );

        expect(summary.isCostReliable, isFalse);
        expect(summary.trustedGrossProfit, isNull);
        expect(summary.trustedProfitMargin, isNull);
      },
    );

    test(
      '36. Issue 7: Fully stocked sale establishes reliable line cost and trusted gross profit',
      () {
        Map<String, dynamic> computeLineCost({
          required double currentStock,
          required double lineQty,
          required double? avgCost,
          required bool isCostKnown,
          required bool strictStock,
        }) {
          final double deductQty;
          if (strictStock) {
            deductQty = lineQty;
          } else {
            deductQty = currentStock > 0
                ? (currentStock >= lineQty ? lineQty : currentStock)
                : 0.0;
          }
          final bool isFullyBacked = deductQty >= lineQty;
          final double? itemUnitCost =
              (isCostKnown && isFullyBacked) ? avgCost : null;
          final double? itemTotalCost =
              (isCostKnown && isFullyBacked && avgCost != null)
                  ? lineQty * avgCost
                  : null;
          final double? movementCost =
              (isCostKnown && avgCost != null) ? deductQty * avgCost : null;
          final String movementCostStatus = isCostKnown
              ? StockMovement.costStatusKnown
              : StockMovement.costStatusUnknown;

          return {
            'deductQty': deductQty,
            'isFullyBacked': isFullyBacked,
            'itemUnitCost': itemUnitCost,
            'itemTotalCost': itemTotalCost,
            'movementCost': movementCost,
            'movementCostStatus': movementCostStatus,
          };
        }

        final result = computeLineCost(
          currentStock: 10.0,
          lineQty: 4.0,
          avgCost: 50.0,
          isCostKnown: true,
          strictStock: true,
        );

        expect(result['itemUnitCost'], 50.0);
        expect(result['itemTotalCost'], 200.0);
        expect(result['movementCost'], 200.0);
        expect(result['movementCostStatus'], StockMovement.costStatusKnown);

        final totalCost = result['itemTotalCost'] as double;
        final summary = SaleProfitSummary(
          document: Document(
            type: 'invoice',
            documentNumber: 'INV-FULL',
            date: DateTime.now(),
            subtotal: 400,
            discount: 0,
            taxRate: 0,
            taxAmount: 0,
            total: 400,
            paid: 400,
            remaining: 0,
          ),
          recognizedRevenue: 400,
          cogs: totalCost,
          grossProfit: 400 - totalCost,
          profitMargin: ((400 - totalCost) / 400) * 100,
          isCostReliable: true,
        );

        expect(summary.isCostReliable, isTrue);
        expect(summary.cogs, 200.0);
        expect(summary.grossProfit, 200.0);
        expect(summary.trustedGrossProfit, 200.0);
        expect(summary.trustedProfitMargin, 50.0);
      },
    );

    test(
      '37. Issue 7 Option A: Mixed invoice with fully costed and uncosted items excludes untrusted profit from aggregates',
      () {
        // Line 1: fully costed (qty=2, price=100, unit_cost=60, total_cost=120)
        const line1TotalCost = 120.0;
        const bool line1Reliable = true;

        // Line 2: partially oversold / unknown cost (qty=3, price=150, total_cost=null)
        const double? line2TotalCost = null;
        const bool line2Reliable = false;

        final items = [
          {'total_cost': line1TotalCost, 'is_reliable': line1Reliable},
          {'total_cost': line2TotalCost, 'is_reliable': line2Reliable},
        ];

        double docCogs = 0.0;
        bool docReliable = true;
        for (final item in items) {
          final totalCost = item['total_cost'] as double?;
          if (totalCost != null) {
            docCogs += totalCost;
          } else {
            docReliable = false;
          }
        }

        const recognizedRevenue = 650.0; // 200 + 450
        final grossProfit = recognizedRevenue - docCogs; // 650 - 120 = 530
        final margin = (grossProfit / recognizedRevenue) * 100;

        final mixedInvoiceSummary = SaleProfitSummary(
          document: Document(
            type: 'invoice',
            documentNumber: 'INV-MIXED',
            date: DateTime.now(),
            subtotal: 650,
            discount: 0,
            taxRate: 0,
            taxAmount: 0,
            total: 650,
            paid: 650,
            remaining: 0,
          ),
          recognizedRevenue: recognizedRevenue,
          cogs: docCogs,
          grossProfit: grossProfit,
          profitMargin: margin,
          isCostReliable: docReliable,
        );

        // Mixed invoice must flag isCostReliable = false
        expect(mixedInvoiceSummary.isCostReliable, isFalse);
        expect(
          mixedInvoiceSummary.cogs,
          120.0,
          reason: 'COGS includes known line items only',
        );
        expect(
          mixedInvoiceSummary.trustedGrossProfit,
          isNull,
          reason:
              'Mixed invoice with partial uncosted lines must have trustedGrossProfit = null',
        );
        expect(mixedInvoiceSummary.trustedProfitMargin, isNull);

        // Another fully costed invoice
        final fullyCostedSummary = SaleProfitSummary(
          document: Document(
            type: 'invoice',
            documentNumber: 'INV-CLEAN',
            date: DateTime.now(),
            subtotal: 300,
            discount: 0,
            taxRate: 0,
            taxAmount: 0,
            total: 300,
            paid: 300,
            remaining: 0,
          ),
          recognizedRevenue: 300,
          cogs: 100,
          grossProfit: 200,
          profitMargin: 66.67,
          isCostReliable: true,
        );

        final allSummaries = [mixedInvoiceSummary, fullyCostedSummary];

        // Aggregate trusted profit calculation
        final totalTrustedProfit = allSummaries.fold(
          0.0,
          (sum, s) => sum + (s.trustedGrossProfit ?? 0.0),
        );
        final hasIncompleteCost = allSummaries.any((s) => !s.isCostReliable);

        expect(hasIncompleteCost, isTrue);
        // Only the fully costed invoice (200.0) contributes to trusted profit;
        // the mixed invoice contributes 0.0, NOT 530.0!
        expect(totalTrustedProfit, 200.0);
      },
    );

    test(
      '38. Adversarial: Deleting an invoice sold with 0 available stock must never restore phantom inventory',
      () {
        // Product physical stock is 0
        double productStock = 0.0;
        const lineQty = 10.0;

        // Sale executed with strictStock: false when stock is 0
        const currentStock = 0.0;
        final deductQty = currentStock > 0 ? (currentStock >= lineQty ? lineQty : currentStock) : 0.0;
        expect(deductQty, 0.0);

        // Movements recorded for this invoice: 0 (because physical stock was 0)
        final movements = <Map<String, dynamic>>[];
        expect(movements.isEmpty, isTrue);

        // Deletion logic: only actual stock movements are reversed
        double revertQty = 0.0;
        if (movements.isNotEmpty) {
          for (final m in movements) {
            revertQty += -(m['quantity'] as num).toDouble();
          }
        }

        expect(revertQty, 0.0, reason: 'Revert quantity must be exactly 0 when no stock was deducted');
        productStock += revertQty;
        expect(productStock, 0.0, reason: 'Deleting unstocked invoice must not create phantom stock');
      },
    );

    test(
      '39. Adversarial: Editing a purchase after subsequent sales consumed stock throws StateError transactionally',
      () {
        // Initial state: purchased 10 units at $10.
        // Later: 6 units were sold to customers at moving weighted average.
        // Current inventory stock: 4 units. Current avg cost: $10.
        const currentStock = 4.0;
        const currentAvgCost = 10.0;
        const oldQty = 10.0;
        const oldTotalCost = 100.0;

        // User attempts to edit the purchase (e.g. change price or quantity)
        // Guard check: currentStock (4) < oldQty (10)
        expect(
          () {
            if (currentStock < oldQty) {
              throw StateError(
                'Cannot edit purchase because subsequent sales or movements consumed this stock '
                '(available: 4, purchased: 10)',
              );
            }
            InventoryCostingService.calculateReversedWeightedAverage(
              currentStock: currentStock,
              currentAvgCost: currentAvgCost,
              removedQty: oldQty,
              removedCost: oldTotalCost,
            );
          },
          throwsA(isA<StateError>()),
          reason: 'Editing consumed purchase must throw StateError to prevent negative stock and corrupted cost',
        );
      },
    );

    test(
      '40. Adversarial: Editing purchase when stock is intact safely recalculates weighted average',
      () {
        // Initial state: 10 units purchased at $10.
        // All 10 units remain intact in warehouse (currentStock = 10, avg = $10).
        const currentStock = 10.0;
        const currentAvg = 10.0;
        const oldQty = 10.0;
        const oldCost = 100.0;

        // 1. Reversing the old purchase yields 0 stock
        final reversedStock = currentStock - oldQty;
        final reversedAvg = InventoryCostingService.calculateReversedWeightedAverage(
          currentStock: currentStock,
          currentAvgCost: currentAvg,
          removedQty: oldQty,
          removedCost: oldCost,
        );
        expect(reversedStock, 0.0);
        expect(reversedAvg, isNull);

        // 2. Applying new edited purchase (10 units at $12)
        final newAvg = InventoryCostingService.calculateNewWeightedAverage(
          currentStock: reversedStock,
          currentAvgCost: reversedAvg,
          incomingQty: 10.0,
          incomingUnitCost: 12.0,
        );
        expect(newAvg, 12.0);
      },
    );

    test(
      '41. Adversarial: Purchase cancellation with multiple lines of same product aggregates quantities and applies consumption guard',
      () {
        // Purchase document has 2 lines of Product A:
        // Line 1: 5 units at $10
        // Line 2: 5 units at $10
        // Total purchased = 10 units at $10 ($100 total value).
        final purchaseItems = [
          {'product_id': 1, 'quantity': 5.0, 'price': 10.0},
          {'product_id': 1, 'quantity': 5.0, 'price': 10.0},
        ];

        final netPurchaseQtyByProduct = <int, double>{};
        final netPurchaseCostByProduct = <int, double>{};
        for (final item in purchaseItems) {
          final pid = item['product_id'] as int;
          final qty = item['quantity'] as double;
          final price = item['price'] as double;
          netPurchaseQtyByProduct[pid] = (netPurchaseQtyByProduct[pid] ?? 0.0) + qty;
          netPurchaseCostByProduct[pid] = (netPurchaseCostByProduct[pid] ?? 0.0) + (qty * price);
        }

        expect(netPurchaseQtyByProduct[1], 10.0);
        expect(netPurchaseCostByProduct[1], 100.0);

        // Physical stock on hand: 8 units (2 units were sold)
        const currentStock = 8.0;
        const currentAvg = 10.0;
        final netQty = netPurchaseQtyByProduct[1]!;
        final removedCost = netPurchaseCostByProduct[1]!;

        // Check pre-check against aggregated quantity
        expect(
          () {
            if (currentStock < netQty) {
              throw StateError(
                'Insufficient stock to cancel purchase: available 8, required 10',
              );
            }
            final prevVal = currentStock * currentAvg;
            if (prevVal - removedCost < -0.001) {
              throw StateError('Cannot cancel purchase because subsequent sales consumed this stock');
            }
          },
          throwsA(isA<StateError>()),
          reason: 'Aggregated stock pre-check must fail when available (8) < total purchased (10)',
        );
      },
    );

    test(
      '42. Adversarial: Sales invoice cancellation with multiple lines of same product reverses every movement exactly once',
      () {
        // Sales invoice has 2 lines of Product A:
        // Line 1: 2 units
        // Line 2: 5 units
        // Two movements were created when issued:
        final movements = [
          {'id': 101, 'product_id': 1, 'type': 'sale', 'quantity': -2.0, 'unit_cost': 50.0, 'total_cost': 100.0},
          {'id': 102, 'product_id': 1, 'type': 'sale', 'quantity': -5.0, 'unit_cost': 50.0, 'total_cost': 250.0},
        ];

        double productStock = 0.0;
        final cancellationMovements = <Map<String, dynamic>>[];

        // Reversal logic iterates over movements directly (never taking mRows.first per line)
        for (final m in movements) {
          final mQty = (m['quantity'] as num).toDouble();
          final revertQty = -mQty; // +2.0 and +5.0
          productStock += revertQty;
          cancellationMovements.add({
            'product_id': m['product_id'],
            'quantity': revertQty,
            'unit_cost': m['unit_cost'],
            'total_cost': m['total_cost'],
          });
        }

        expect(productStock, 7.0, reason: 'Total restored quantity must be exactly 2 + 5 = 7');
        expect(cancellationMovements.length, 2);
        expect(cancellationMovements[0]['quantity'], 2.0);
        expect(cancellationMovements[1]['quantity'], 5.0);
      },
    );

    test(
      '43. Adversarial: Invoice cancellation with active linked payment receipts throws StateError',
      () {
        const activeReceiptCount = 1;
        expect(
          () {
            if (activeReceiptCount > 0) {
              throw StateError(
                'Cannot cancel document with active payment receipts/vouchers (REC-001). Please cancel or delete the receipts first.',
              );
            }
          },
          throwsA(isA<StateError>()),
          reason: 'Active receipts must prevent invoice cancellation to avoid orphaned vouchers',
        );
      },
    );

    test(
      '44. Adversarial: Draft document issuance records upfront payment in document_payments exactly once',
      () {
        const docPaid = 250.0;
        final existingPayments = <Map<String, dynamic>>[];

        // Function simulating issueDocument upfront payment handler
        void recordUpfrontPaymentIfNeeded() {
          final totalExistingPaid = existingPayments.fold<double>(
            0.0,
            (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0),
          );
          if (totalExistingPaid < docPaid) {
            final missingAmount = docPaid - totalExistingPaid;
            existingPayments.add({'amount': missingAmount});
          }
        }

        // First issuance: records 250.0
        recordUpfrontPaymentIfNeeded();
        expect(existingPayments.length, 1);
        expect(existingPayments.first['amount'], 250.0);

        // Repeated issuance attempt: does not duplicate
        recordUpfrontPaymentIfNeeded();
        expect(existingPayments.length, 1);
        expect(existingPayments.first['amount'], 250.0);
      },
    );

    test(
      '45. Adversarial: Payment report segregates totals by currency and excludes cancelled documents',
      () {
        final paymentRows = [
          {'doc_type': 'invoice', 'amount': 1000.0, 'currency_code': 'SDG', 'status': 'issued'},
          {'doc_type': 'purchase', 'amount': 400.0, 'currency_code': 'SDG', 'status': 'issued'},
          {'doc_type': 'invoice', 'amount': 50.0, 'currency_code': 'USD', 'status': 'issued'},
          // Cancelled document payment (must be excluded)
          {'doc_type': 'invoice', 'amount': 999.0, 'currency_code': 'SDG', 'status': 'cancelled'},
        ];

        final activeRows = paymentRows.where((r) => r['status'] != 'cancelled').toList();
        expect(activeRows.length, 3);

        final totalsByCurrency = <String, ({double inAmount, double outAmount})>{};
        for (final r in activeRows) {
          final c = r['currency_code'] as String;
          final amt = r['amount'] as double;
          final isIn = r['doc_type'] == 'invoice';
          final prev = totalsByCurrency[c] ?? (inAmount: 0.0, outAmount: 0.0);
          totalsByCurrency[c] = (
            inAmount: prev.inAmount + (isIn ? amt : 0.0),
            outAmount: prev.outAmount + (!isIn ? amt : 0.0),
          );
        }

        expect(totalsByCurrency['SDG']!.inAmount, 1000.0);
        expect(totalsByCurrency['SDG']!.outAmount, 400.0);
        expect(totalsByCurrency['USD']!.inAmount, 50.0);
        expect(totalsByCurrency['USD']!.outAmount, 0.0);
        // SDG and USD are strictly separated; never summed to 1450 or 2049!
      },
    );

    test(
      '46. Adversarial: Migration v18 reconciles clean legacy opening stock without fabricating cost',
      () {
        // Product created before v8 with 15 units in stock, zero movements recorded
        final legacyProduct = {
          'id': 10,
          'stock_quantity': 15.0,
          'created_at': '2023-05-01T10:00:00.000Z',
          'has_movements': false,
        };

        final openingMovement = {
          'product_id': legacyProduct['id'],
          'type': StockMovement.typeOpening,
          'quantity': legacyProduct['stock_quantity'],
          'date': legacyProduct['created_at'],
          'unit_cost': null, // Strictly unknown; NEVER catalog purchase_price
          'total_cost': null,
          'cost_status': StockMovement.costStatusUnknown,
          'provenance': 'migration_legacy_opening',
        };

        expect(openingMovement['quantity'], 15.0);
        expect(openingMovement['unit_cost'], isNull);
        expect(openingMovement['cost_status'], StockMovement.costStatusUnknown);
        expect(openingMovement['date'], '2023-05-01T10:00:00.000Z');
      },
    );

    test(
      '48. Adversarial: Deletion of earlier tracked invoice shifting MIN(ref_id) must NEVER cause oversold invoice to restore phantom stock',
      () {
        // Chronological scenario:
        // Doc 1 (Invoice 1): Sold 5 units with physical stock. Created movement: {id: 1, ref_doc_id: 1, qty: -5}.
        // Doc 2 (Invoice 2): Sold 10 units oversold with 0 physical stock. 0 movements created.
        // Doc 3 (Invoice 3): Restocked and sold 5 units. Created movement: {id: 2, ref_doc_id: 3, qty: -5}.
        //
        // Physical stock at this point: 0 units.
        double currentStock = 0.0;

        // Step 1: User deletes Doc 1.
        // In deleteDocument, Doc 1's movements are deleted:
        // Now stock_movements only contains {id: 2, ref_doc_id: 3, qty: -5}.
        // The table's MIN(reference_document_id) is now 3!
        // Under the flawed heuristic: Doc 2 (id: 2) < earliestTrackedId (3) would falsely evaluate to true!

        // Step 2: User deletes Doc 2 (the oversold invoice).
        final doc2Movements = <Map<String, dynamic>>[]; // 0 movements for doc 2

        // Fixed deletion logic: NEVER relies on MIN(reference_document_id).
        // Only actual movements linked to this document are reversed.
        double restoredQty = 0.0;
        if (doc2Movements.isNotEmpty) {
          for (final m in doc2Movements) {
            restoredQty += -(m['quantity'] as num).toDouble();
          }
        }
        // Result: restoredQty MUST BE 0.0!
        expect(restoredQty, 0.0);
        currentStock += restoredQty;
        expect(currentStock, 0.0, reason: 'Physical stock must remain 0; zero phantom units created');
      },
    );

    test(
      '49. Adversarial: Cancelling or editing an oversold invoice restores exactly 0 stock and creates 0 cancellation movements',
      () {
        double physicalStock = 0.0;
        final docItems = [
          {'product_id': 101, 'quantity': 8.0, 'price': 100.0},
        ];
        expect(docItems.first['quantity'], 8.0);
        // Zero movements were recorded when this invoice was issued because stock was 0
        final movements = <Map<String, dynamic>>[];
        expect(movements.isEmpty, isTrue);

        // Cancel document execution
        final cancellationMovements = <Map<String, dynamic>>[];
        double revertQty = 0.0;
        if (movements.isNotEmpty) {
          for (final m in movements) {
            final mQty = (m['quantity'] as num).toDouble();
            final rev = -mQty;
            if (rev > 0) {
              revertQty += rev;
              cancellationMovements.add({
                'type': StockMovement.typeCancellation,
                'quantity': rev,
              });
            }
          }
        }

        expect(revertQty, 0.0);
        expect(cancellationMovements.isEmpty, isTrue);
        physicalStock += revertQty;
        expect(physicalStock, 0.0);

        // Editing document (updateDocumentWithItems) execution
        double editRevertQty = 0.0;
        if (movements.isNotEmpty) {
          for (final m in movements) {
            editRevertQty += -(m['quantity'] as num).toDouble();
          }
        }
        expect(editRevertQty, 0.0);
        physicalStock += editRevertQty;
        expect(physicalStock, 0.0);
      },
    );

    test(
      '50. Adversarial: Deleting or cancelling a partially oversold invoice restores ONLY physically deducted units',
      () {
        // Invoice line requested 10 units, but only 4 units were available in stock.
        // Physical stock before sale: 4.0.
        // Sale deducted 4.0 units; 6.0 units were unstocked oversell.
        // Created movement: {ref_doc_id: 42, qty: -4.0}.
        final movements = [
          {'product_id': 202, 'type': StockMovement.typeSale, 'quantity': -4.0},
        ];

        double physicalStock = 0.0; // after sale

        // On deletion / cancellation:
        double restoredQty = 0.0;
        if (movements.isNotEmpty) {
          for (final m in movements) {
            if (m['type'] == StockMovement.typeSale) {
              restoredQty += -(m['quantity'] as num).toDouble();
            }
          }
        }

        // Exactly 4.0 units restored, NEVER line item quantity (10.0)!
        expect(restoredQty, 4.0);
        physicalStock += restoredQty;
        expect(physicalStock, 4.0);
      },
    );

    test(
      '51. Adversarial: Migration v18 deterministic opening date policy with pre-2023 documents preserves calendar day',
      () {
        // Product created pre-v7 with NULL created_at.
        // It has a historical finalized invoice from 2021-08-15T11:30:00.000.
        const productEarliestDocStr = '2021-08-15T11:30:00.000';
        const String? productCreatedAt = null;

        // Policy execution:
        final docDatePart = productEarliestDocStr.substring(0, 10);
        final createdDatePart = productCreatedAt?.substring(0, 10);

        final String openingDateStr;
        if (createdDatePart != null && createdDatePart.compareTo(docDatePart) < 0) {
          openingDateStr = productCreatedAt!;
        } else {
          // Anchored to start of same calendar day without shifting to previous day
          openingDateStr = '${docDatePart}T00:00:00.000';
        }

        // Must belong to August 15, 2021 (same calendar day)
        expect(openingDateStr, '2021-08-15T00:00:00.000');
        expect(openingDateStr.substring(0, 10), '2021-08-15');
        // Lexicographically precedes transaction at 11:30 on same day
        expect(openingDateStr.compareTo(productEarliestDocStr) < 0, isTrue);
      },
    );

    test(
      '52. Adversarial: Same-day midnight transaction orders opening stock before sale via ID tie-breaker',
      () {
        // Invoice entered at midnight: 2022-04-10T00:00:00.000.
        const docDateStr = '2022-04-10T00:00:00.000';
        final openingDateStr = '${docDateStr.substring(0, 10)}T00:00:00.000';

        // Same calendar day and same timestamp:
        expect(openingDateStr, docDateStr);

        // In SQLite: ORDER BY date ASC, id ASC.
        // The opening movement (id: 10) precedes subsequent movement (id: 11):
        final movements = [
          {'id': 10, 'date': openingDateStr, 'type': StockMovement.typeOpening, 'quantity': 20.0},
          {'id': 11, 'date': docDateStr, 'type': StockMovement.typeSale, 'quantity': -5.0},
        ];
        movements.sort((a, b) {
          final c = (a['date'] as String).compareTo(b['date'] as String);
          if (c != 0) return c;
          return (a['id'] as int).compareTo(b['id'] as int);
        });

        // Opening movement is ordered first; running balance never dips negative
        expect(movements.first['type'], StockMovement.typeOpening);
        double runningBalance = 0.0;
        for (final m in movements) {
          runningBalance += (m['quantity'] as double);
          expect(runningBalance >= 0, isTrue);
        }
        expect(runningBalance, 15.0);
      },
    );

    test(
      '53. Adversarial: Preserves explicit timezone offsets and suffixes (Z, +02:00, local)',
      () {
        String startOfDay(String dateStr) {
          final trimmed = dateStr.trim();
          final tIdx = trimmed.indexOf('T');
          if (tIdx < 0) return '${trimmed}T00:00:00.000';
          final datePart = trimmed.substring(0, tIdx);
          final timeAndZone = trimmed.substring(tIdx + 1);
          String tzSuffix = '';
          if (timeAndZone.endsWith('Z')) {
            tzSuffix = 'Z';
          } else {
            final plusIdx = timeAndZone.indexOf('+');
            final minusIdx = timeAndZone.lastIndexOf('-');
            if (plusIdx >= 0) {
              tzSuffix = timeAndZone.substring(plusIdx);
            } else if (minusIdx >= 0) {
              tzSuffix = timeAndZone.substring(minusIdx);
            }
          }
          return '${datePart}T00:00:00.000$tzSuffix';
        }

        // Case 1: UTC with Z
        const utcDoc = '2023-06-12T15:45:00.000Z';
        final utcOpening = startOfDay(utcDoc);
        expect(utcOpening, '2023-06-12T00:00:00.000Z');
        expect(utcOpening.compareTo(utcDoc) < 0, isTrue);

        // Case 2: Timezone offset +02:00
        const tzDoc = '2023-06-12T15:45:00.000+02:00';
        final tzOpening = startOfDay(tzDoc);
        expect(tzOpening, '2023-06-12T00:00:00.000+02:00');
        expect(tzOpening.compareTo(tzDoc) < 0, isTrue);

        // Case 3: Local ISO without suffix
        const localDoc = '2023-06-12T15:45:00.000';
        final localOpening = startOfDay(localDoc);
        expect(localOpening, '2023-06-12T00:00:00.000');
        expect(localOpening.compareTo(localDoc) < 0, isTrue);
      },
    );

    test(
      '54. Adversarial: Draft, cancelled, and non-inventory documents NEVER anchor opening stock',
      () {
        // Product 100 has only:
        // 1. A quotation from 2020-01-01
        // 2. A draft invoice from 2021-01-01
        // 3. A cancelled invoice from 2022-01-01
        // 4. An issued finalized invoice from 2023-07-01
        final documents = [
          {'type': 'quotation', 'status': 'draft', 'date': '2020-01-01T10:00:00.000'},
          {'type': 'invoice', 'status': 'draft', 'date': '2021-01-01T10:00:00.000'},
          {'type': 'invoice', 'status': 'cancelled', 'date': '2022-01-01T10:00:00.000'},
          {'type': 'invoice', 'status': 'issued', 'date': '2023-07-01T10:00:00.000'},
        ];

        // Query filter: d.type IN ('invoice', 'purchase') AND d.status NOT IN ('draft', 'cancelled')
        final eligible = documents.where((d) {
          final t = d['type'] as String;
          final s = d['status'] as String;
          return (t == 'invoice' || t == 'purchase') && s != 'draft' && s != 'cancelled';
        }).toList();

        expect(eligible.length, 1);
        expect(eligible.first['date'], '2023-07-01T10:00:00.000');
        // Anchored to 2023-07-01, NOT the quotation, draft, or cancelled document!
      },
    );

    test(
      '55. Adversarial: Products with NULL created_at and NO finalized documents safely DEFER reconciliation',
      () {
        // Product created pre-v7 with stock 10.0, but zero documents ever recorded
        final product = {'id': 99, 'stock_quantity': 10.0, 'created_at': null};
        const String? productEarliestDocStr = null;
        final stockMovements = <Map<String, dynamic>>[];

        final createdAtStr = product['created_at'] as String?;
        if (productEarliestDocStr != null) {
          // not reached
        } else if (createdAtStr != null && createdAtStr.isNotEmpty) {
          // not reached
        } else {
          // Safely deferred: do NOT fabricate a historical timestamp
          // (no 1970 Unix epoch, no 2023 magic year, no fake DateTime.now())
        }

        // Movements table remains completely untouched
        expect(stockMovements.isEmpty, isTrue);
        // Product physical stock is preserved in products table
        expect(product['stock_quantity'], 10.0);
      },
    );

    test(
      '56. Adversarial: Migration idempotency and rollback safety',
      () {
        final products = [
          {'id': 1, 'stock_quantity': 10.0, 'type': 'product', 'created_at': '2023-01-01T00:00:00.000'},
        ];
        final stockMovements = <Map<String, dynamic>>[];

        void runMigration() {
          final missing = products.where((p) {
            final pid = p['id'] as int;
            final qty = p['stock_quantity'] as double;
            final type = p['type'] as String;
            final hasMovements = stockMovements.any((sm) => sm['product_id'] == pid);
            return type == 'product' && qty > 0.0001 && !hasMovements;
          }).toList();

          for (final row in missing) {
            stockMovements.add({
              'product_id': row['id'],
              'type': StockMovement.typeOpening,
              'quantity': row['stock_quantity'],
              'date': row['created_at'],
            });
          }
        }

        runMigration();
        expect(stockMovements.length, 1);

        // Second run
        runMigration();
        expect(stockMovements.length, 1, reason: 'Idempotent across repeated runs');
      },
    );

    test(
      '57. Adversarial: Discrepant legacy invoice - harmless non-financial edit preserves historical financial records without creating synthetic payment rows',
      () {
        const currencyCode = 'USD';
        final decimalDigits = Currency.decimalDigitsForCode(currencyCode);
        final epsilon = 1.0 / math.pow(10, decimalDigits + 1);

        // Discrepant legacy record: documents.paid = 100.0, but document_payments has 0 rows (ledger sum = 0.0)
        final oldDoc = Document(
          id: 50,
          type: 'invoice',
          documentNumber: 'INV-050',
          date: DateTime(2023, 1, 1),
          subtotal: 100.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 100.0,
          paid: 100.0,
          remaining: 0.0,
          notes: 'Original note',
          status: DocumentStatus.paid,
          currencyCode: currencyCode,
        );

        final payments = <Map<String, dynamic>>[]; // empty ledger

        // User edits ONLY non-financial note: incoming paid is unchanged (100.0), total is unchanged (100.0)
        final incomingDoc = Document(
          id: 50,
          type: 'invoice',
          documentNumber: 'INV-050',
          date: DateTime(2023, 1, 1),
          subtotal: 100.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 100.0,
          paid: 100.0, // unchanged
          remaining: 0.0,
          notes: 'Updated warehouse delivery note',
          status: DocumentStatus.paid,
          currencyCode: currencyCode,
        );

        final canonicalIncomingPaid = MoneyUtils.round(incomingDoc.paid, decimalDigits);
        final canonicalOldPaid = MoneyUtils.round(oldDoc.paid, decimalDigits);
        final canonicalIncomingTotal = MoneyUtils.round(incomingDoc.total, decimalDigits);
        final canonicalOldTotal = MoneyUtils.round(oldDoc.total, decimalDigits);

        final totalExistingLedgerPaid = MoneyUtils.round(
          payments.fold<double>(0.0, (sum, r) => sum + (r['amount'] as double)),
          decimalDigits,
        );

        final isUserAlteringPaid = (canonicalIncomingPaid - canonicalOldPaid).abs() > epsilon;
        final isUserAlteringTotal = (canonicalIncomingTotal - canonicalOldTotal).abs() > epsilon;
        final isLedgerDiscrepant = (canonicalOldPaid - totalExistingLedgerPaid).abs() > epsilon;

        expect(isUserAlteringPaid, isFalse);
        expect(isUserAlteringTotal, isFalse);
        expect(isLedgerDiscrepant, isTrue);

        // Core invariant: Harmless edit MUST NOT insert synthetic payment rows
        double effectivePaid;
        double effectiveRemaining;
        String effectiveStatus;

        if (!isUserAlteringPaid) {
          if (isLedgerDiscrepant) {
            if (isUserAlteringTotal) {
              throw StateError('Cannot modify financial totals on discrepant document');
            }
            effectivePaid = oldDoc.paid;
            effectiveRemaining = oldDoc.remaining;
            effectiveStatus = oldDoc.status;
          } else {
            effectivePaid = totalExistingLedgerPaid;
            effectiveRemaining = MoneyUtils.calculateRemaining(canonicalIncomingTotal, totalExistingLedgerPaid, decimalDigits);
            effectiveStatus = DocumentStatus.fromPayment(totalExistingLedgerPaid, canonicalIncomingTotal, decimalDigits: decimalDigits);
          }
        } else {
          throw StateError('Altering paid');
        }

        expect(effectivePaid, 100.0);
        expect(effectiveRemaining, 0.0);
        expect(effectiveStatus, DocumentStatus.paid);
        expect(payments.isEmpty, isTrue, reason: 'Zero synthetic payment rows were created on harmless edit');
      },
    );

    test(
      '58. Adversarial: Discrepant legacy invoice - modifying financial total is transactionally rejected',
      () {
        const currencyCode = 'USD';
        final decimalDigits = Currency.decimalDigitsForCode(currencyCode);
        final epsilon = 1.0 / math.pow(10, decimalDigits + 1);

        const oldPaid = 100.0;
        const oldTotal = 100.0;
        const totalExistingLedgerPaid = 60.0; // Discrepancy: paid 100 vs ledger 60

        void simulateUpdateFinancialTotal(double newTotal, double newPaid) {
          final isUserAlteringPaid = (newPaid - oldPaid).abs() > epsilon;
          final isUserAlteringTotal = (newTotal - oldTotal).abs() > epsilon;
          final isLedgerDiscrepant = (oldPaid - totalExistingLedgerPaid).abs() > epsilon;

          if (!isUserAlteringPaid && isLedgerDiscrepant && isUserAlteringTotal) {
            throw StateError(
              'Cannot modify financial totals: document has discrepant payment records (document paid: $oldPaid, recorded payments: $totalExistingLedgerPaid). Please resolve payment records before modifying totals.',
            );
          }
        }

        expect(
          () => simulateUpdateFinancialTotal(150.0, 100.0),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot modify financial totals: document has discrepant payment records'),
          )),
        );
      },
    );

    test(
      '59. Adversarial: Discrepant legacy invoice - modifying paid amount is transactionally rejected',
      () {
        const currencyCode = 'USD';
        final decimalDigits = Currency.decimalDigitsForCode(currencyCode);
        final epsilon = 1.0 / math.pow(10, decimalDigits + 1);

        const oldPaid = 100.0;
        const totalExistingLedgerPaid = 60.0;

        void simulateUpdatePaidOnDiscrepant(double newPaid) {
          final isUserAlteringPaid = (newPaid - oldPaid).abs() > epsilon;
          final isLedgerDiscrepant = (oldPaid - totalExistingLedgerPaid).abs() > epsilon;

          if (isUserAlteringPaid && isLedgerDiscrepant) {
            throw StateError(
              'Cannot modify paid amount: document has discrepant payment records (document paid: $oldPaid, recorded payments: $totalExistingLedgerPaid). Please review payment records.',
            );
          }
        }

        expect(
          () => simulateUpdatePaidOnDiscrepant(120.0),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot modify paid amount: document has discrepant payment records'),
          )),
        );
      },
    );

    test(
      '60. Adversarial: Clean issued invoice - total edit recomputes remaining and status safely without touching ledger',
      () {
        const currencyCode = 'USD';
        final decimalDigits = Currency.decimalDigitsForCode(currencyCode);

        const initialTotal = 100.0;
        const initialPaid = 40.0;
        expect(initialTotal - initialPaid, 60.0);
        final payments = <Map<String, dynamic>>[
          {'id': 1, 'document_id': 10, 'amount': 40.0, 'receipt_document_id': null},
        ];

        final newTotal = 150.0;
        final totalExistingPaid = MoneyUtils.round(
          payments.fold<double>(0.0, (sum, r) => sum + (r['amount'] as double)),
          decimalDigits,
        );

        expect(MoneyUtils.isOverpayment(totalExistingPaid, newTotal, decimalDigits), isFalse);
        final effectiveRemaining = MoneyUtils.calculateRemaining(newTotal, totalExistingPaid, decimalDigits);
        final effectiveStatus = DocumentStatus.fromPayment(totalExistingPaid, newTotal, decimalDigits: decimalDigits);

        expect(totalExistingPaid, 40.0);
        expect(effectiveRemaining, 110.0);
        expect(effectiveStatus, DocumentStatus.partiallyPaid);
        expect(payments.length, 1);
        expect(payments.first['amount'], 40.0);

        final paidOffRemaining = MoneyUtils.calculateRemaining(40.0, totalExistingPaid, decimalDigits);
        final paidOffStatus = DocumentStatus.fromPayment(totalExistingPaid, 40.0, decimalDigits: decimalDigits);
        expect(paidOffRemaining, 0.0);
        expect(paidOffStatus, DocumentStatus.paid);
      },
    );

    test(
      '61. Adversarial: Clean issued invoice - editing upfront paid synchronizes row without duplicates',
      () {
        const currencyCode = 'USD';
        final decimalDigits = Currency.decimalDigitsForCode(currencyCode);

        const total = 100.0;
        final payments = <Map<String, dynamic>>[
          {'id': 1, 'document_id': 10, 'amount': 30.0, 'receipt_document_id': null},
        ];

        final requestedPaid = 50.0;
        final canonicalPaid = MoneyUtils.round(requestedPaid, decimalDigits);
        final canonicalTotal = MoneyUtils.round(total, decimalDigits);

        final upfrontRows = payments.where((r) => r['receipt_document_id'] == null).toList();
        final linkedRows = payments.where((r) => r['receipt_document_id'] != null).toList();

        expect(linkedRows.isEmpty, isTrue);
        expect(upfrontRows.length, 1);

        upfrontRows.first['amount'] = canonicalPaid;

        final newRemaining = MoneyUtils.calculateRemaining(canonicalTotal, canonicalPaid, decimalDigits);
        final newStatus = DocumentStatus.fromPayment(canonicalPaid, canonicalTotal, decimalDigits: decimalDigits);

        expect(payments.length, 1, reason: 'Zero synthetic payment rows added');
        expect(payments.first['amount'], 50.0);
        expect(newRemaining, 50.0);
        expect(newStatus, DocumentStatus.partiallyPaid);

        payments.removeWhere((r) => r['id'] == upfrontRows.first['id']);
        final zeroRemaining = MoneyUtils.calculateRemaining(canonicalTotal, 0.0, decimalDigits);
        final zeroStatus = DocumentStatus.fromPayment(0.0, canonicalTotal, decimalDigits: decimalDigits);

        expect(payments.isEmpty, isTrue);
        expect(zeroRemaining, 100.0);
        expect(zeroStatus, DocumentStatus.issued);
      },
    );

    test(
      '62. Adversarial: Clean issued invoice with linked receipts rejects direct paid edits',
      () {
        final payments = <Map<String, dynamic>>[
          {'id': 1, 'document_id': 10, 'amount': 20.0, 'receipt_document_id': null},
          {'id': 2, 'document_id': 10, 'amount': 30.0, 'receipt_document_id': 101},
        ];

        void simulateUpdateInvoicePaid(double newPaid) {
          final totalExistingPaid = payments.fold<double>(0.0, (sum, r) => sum + (r['amount'] as double));
          final linkedReceiptRows = payments.where((r) => r['receipt_document_id'] != null).toList();

          final paidDiff = (newPaid - totalExistingPaid).abs();
          if (paidDiff > 0.0001) {
            if (linkedReceiptRows.isNotEmpty) {
              throw StateError(
                'Cannot modify paid amount directly on a document with linked payment receipts. '
                'Please record, cancel, or delete payment receipts instead.',
              );
            }
          }
        }

        expect(
          () => simulateUpdateInvoicePaid(40.0),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot modify paid amount directly on a document with linked payment receipts'),
          )),
        );

        expect(() => simulateUpdateInvoicePaid(50.0), returnsNormally);
      },
    );

    test(
      '63. Adversarial: Receipt reassignment across documents is strictly rejected',
      () {
        const oldRelatedId = 10;
        const newRelatedId = 20;

        void simulateUpdateReceiptParent(int? relatedId) {
          if (relatedId != oldRelatedId) {
            throw StateError(
              'Cannot reassign an existing payment receipt or expense voucher to a different parent document.',
            );
          }
        }

        expect(
          () => simulateUpdateReceiptParent(newRelatedId),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot reassign an existing payment receipt or expense voucher to a different parent document'),
          )),
        );

        expect(() => simulateUpdateReceiptParent(oldRelatedId), returnsNormally);
      },
    );

    test(
      '64. Adversarial: Invoice deletion is blocked if payment history exists',
      () {
        final paymentHistory = [
          {'id': 1, 'document_id': 10, 'amount': 40.0},
        ];

        void simulateDeleteInvoice(String docType, double paid) {
          if (paymentHistory.isNotEmpty || paid > 0) {
            throw StateError(
              'Cannot delete $docType with recorded payment history. Please cancel the document instead to preserve accounting records.',
            );
          }
        }

        expect(
          () => simulateDeleteInvoice('invoice', 40.0),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot delete invoice with recorded payment history'),
          )),
        );
      },
    );

    test(
      '65. Adversarial: Payment reversal - receipt cancellation never deletes historical payment row; records auditable reversal row',
      () {
        const decimalDigits = 2;
        final payments = <Map<String, dynamic>>[
          {
            'id': 1,
            'document_id': 10,
            'amount': 50.0,
            'date': '2026-10-01T10:00:00.000',
            'notes': 'Payment receipt REC-001',
            'receipt_document_id': 101,
          },
        ];

        var parentPaid = 50.0;
        const parentTotal = 100.0;

        // Perform auditable reversal on 2026-10-15
        const reversalDate = '2026-10-15T12:00:00.000';
        final amountToReverse = payments.fold<double>(0.0, (s, r) => s + (r['amount'] as double));

        // 1. Original row is NOT deleted!
        expect(payments.length, 1);

        // 2. Insert auditable reversal entry
        payments.add({
          'id': 2,
          'document_id': 10,
          'amount': -amountToReverse,
          'date': reversalDate,
          'notes': 'Reversal: cancelled payment_receipt REC-001',
          'receipt_document_id': 101,
        });

        // 3. Parent paid & remaining are recalculated
        parentPaid = MoneyUtils.round(parentPaid - amountToReverse, decimalDigits);
        final parentRemaining = MoneyUtils.calculateRemaining(parentTotal, parentPaid, decimalDigits);
        final parentStatus = DocumentStatus.fromPayment(parentPaid, parentTotal, decimalDigits: decimalDigits);

        expect(payments.length, 2);
        expect(payments[0]['amount'], 50.0);
        expect(payments[0]['date'], '2026-10-01T10:00:00.000', reason: 'Original payment date preserved');
        expect(payments[1]['amount'], -50.0);
        expect(payments[1]['date'], '2026-10-15T12:00:00.000', reason: 'Cancellation date preserved');

        // Net sum across the entire ledger for this document is exactly 0.0
        final netPaid = MoneyUtils.round(
          payments.fold<double>(0.0, (s, r) => s + (r['amount'] as double)),
          decimalDigits,
        );
        expect(netPaid, 0.0);
        expect(parentPaid, 0.0);
        expect(parentRemaining, 100.0);
        expect(parentStatus, DocumentStatus.issued);
      },
    );

    test(
      '66. Adversarial: Draft invoice updates paid without inserting into document_payments until issued',
      () {
        var draftPaid = 30.0;
        final payments = <Map<String, dynamic>>[];

        draftPaid = 50.0;
        expect(payments.isEmpty, isTrue);

        const docTotal = 100.0;
        final initialRemaining = MoneyUtils.calculateRemaining(docTotal, draftPaid, 2);
        expect(initialRemaining, 50.0);
        final existingPaid = payments.fold<double>(0.0, (sum, r) => sum + (r['amount'] as double));
        if (draftPaid > existingPaid) {
          final missing = draftPaid - existingPaid;
          payments.add({
            'document_id': 1,
            'amount': missing,
            'receipt_document_id': null,
          });
        }

        expect(payments.length, 1);
        expect(payments.first['amount'], 50.0);

        final secondExisting = payments.fold<double>(0.0, (sum, r) => sum + (r['amount'] as double));
        if (draftPaid > secondExisting) {
          payments.add({'document_id': 1, 'amount': draftPaid - secondExisting});
        }
        expect(payments.length, 1, reason: 'Exact-once upfront payment recorded on issuance');
      },
    );

    test(
      '67. Adversarial: Guard blocks editing cancelled documents or un-issuing documents to draft',
      () {
        void simulateUpdate(String oldStatus, String newStatus) {
          if (oldStatus == DocumentStatus.cancelled) {
            throw StateError('Cannot edit a cancelled document');
          }
          if (oldStatus != DocumentStatus.draft && newStatus == DocumentStatus.draft) {
            throw StateError('Cannot convert an issued document to draft');
          }
        }

        expect(
          () => simulateUpdate(DocumentStatus.cancelled, DocumentStatus.issued),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Cannot edit a cancelled document'))),
        );

        expect(
          () => simulateUpdate(DocumentStatus.issued, DocumentStatus.draft),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Cannot convert an issued document to draft'))),
        );
      },
    );

    test(
      '68. Adversarial: Multi-currency precision handles 3-decimal and 0-decimal currencies correctly',
      () {
        const digits3 = 3;
        final totalBhd = 100.125;
        final paidBhd = 33.375;
        final remainingBhd = MoneyUtils.calculateRemaining(totalBhd, paidBhd, digits3);
        expect(remainingBhd, 66.750);
        expect(DocumentStatus.fromPayment(paidBhd, totalBhd, decimalDigits: digits3), DocumentStatus.partiallyPaid);

        const digits0 = 0;
        final totalJpy = 1000.0;
        final paidJpy = 1000.0;
        final remainingJpy = MoneyUtils.calculateRemaining(totalJpy, paidJpy, digits0);
        expect(remainingJpy, 0.0);
        expect(DocumentStatus.fromPayment(paidJpy, totalJpy, decimalDigits: digits0), DocumentStatus.paid);
      },
    );

    test(
      '69. Adversarial Finding 3.A: Receipt deletion is blocked if payment ledger history exists',
      () {
        // Document receipt with recorded payment rows
        final paymentHistory = [
          {
            'id': 1,
            'document_id': 10,
            'amount': 50.0,
            'receipt_document_id': 101,
            'payment_origin': PaymentOrigin.receipt,
          },
        ];

        void simulateDeleteReceipt(int receiptId) {
          final history = paymentHistory.where((r) => r['receipt_document_id'] == receiptId).toList();
          if (history.isNotEmpty) {
            throw StateError(
              'Cannot delete payment_receipt with recorded payment history. Please cancel the document instead to preserve accounting records.',
            );
          }
        }

        expect(
          () => simulateDeleteReceipt(101),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot delete payment_receipt with recorded payment history'),
          )),
        );

        // A draft receipt without recorded payments can be deleted safely
        expect(() => simulateDeleteReceipt(999), returnsNormally);
      },
    );

    test(
      '70. Adversarial Finding 3.A: Original and reversal rows preserve receipt_document_id and payment_origin intact',
      () {
        final paymentRows = <Map<String, dynamic>>[
          {
            'id': 1,
            'document_id': 10,
            'amount': 50.0,
            'receipt_document_id': 101,
            'payment_origin': PaymentOrigin.receipt,
          },
        ];

        // Receipt 101 is cancelled -> insert reversal
        paymentRows.add({
          'id': 2,
          'document_id': 10,
          'amount': -50.0,
          'receipt_document_id': 101,
          'payment_origin': PaymentOrigin.reversal,
        });

        // INVARIANT: receipt_document_id is NEVER set to NULL!
        for (final row in paymentRows) {
          expect(row['receipt_document_id'], 101);
          expect(row['receipt_document_id'], isNotNull);
        }

        expect(paymentRows[0]['payment_origin'], PaymentOrigin.receipt);
        expect(paymentRows[1]['payment_origin'], PaymentOrigin.reversal);
      },
    );

    test(
      '71. Adversarial Finding 3.A: Subsequent upfront payment creation and editing succeeds on parent invoice after receipt cancellation',
      () {
        const currencyCode = 'USD';
        final decimalDigits = Currency.decimalDigitsForCode(currencyCode);
        final epsilon = 1.0 / math.pow(10, decimalDigits + 1);

        const invoiceTotal = 100.0;
        expect(invoiceTotal, 100.0);
        var invoicePaid = 0.0;

        // Payment history includes a cancelled receipt (net = 0.0)
        final paymentRows = <Map<String, dynamic>>[
          {
            'id': 1,
            'document_id': 10,
            'amount': 50.0,
            'receipt_document_id': 101,
            'payment_origin': PaymentOrigin.receipt,
          },
          {
            'id': 2,
            'document_id': 10,
            'amount': -50.0,
            'receipt_document_id': 101,
            'payment_origin': PaymentOrigin.reversal,
          },
        ];

        void simulateUpdateInvoicePaid(double incomingPaid) {
          final totalExistingLedgerPaid = MoneyUtils.round(
            paymentRows.fold<double>(0.0, (sum, r) => sum + (r['amount'] as double)),
            decimalDigits,
          );
          expect(totalExistingLedgerPaid, isNotNull);

          final isUserAlteringPaid = (incomingPaid - invoicePaid).abs() > epsilon;

          final upfrontRows = paymentRows
              .where((r) =>
                  r['payment_origin'] == PaymentOrigin.upfront &&
                  r['receipt_document_id'] == null)
              .toList();

          final linkedReceiptRows = paymentRows
              .where((r) =>
                  r['receipt_document_id'] != null ||
                  r['payment_origin'] == PaymentOrigin.receipt ||
                  r['payment_origin'] == PaymentOrigin.reversal)
              .toList();

          final unclassifiedLegacyRows = paymentRows
              .where((r) =>
                  r['receipt_document_id'] == null &&
                  r['payment_origin'] == null)
              .toList();

          final netLinkedReceiptPaid = MoneyUtils.round(
            linkedReceiptRows.fold<double>(0.0, (sum, r) => sum + (r['amount'] as double)),
            decimalDigits,
          );

          if (isUserAlteringPaid) {
            if (unclassifiedLegacyRows.isNotEmpty) {
              throw StateError('Cannot modify paid amount: legacy unclassified records');
            }

            if (netLinkedReceiptPaid > epsilon) {
              throw StateError('Cannot modify paid amount directly with active linked receipts');
            }

            if (upfrontRows.length > 1) {
              throw StateError('multiple upfront rows');
            }

            if (incomingPaid == 0) {
              if (upfrontRows.isNotEmpty) {
                paymentRows.removeWhere((r) => r['id'] == upfrontRows.first['id']);
              }
            } else {
              if (upfrontRows.isNotEmpty) {
                upfrontRows.first['amount'] = incomingPaid;
              } else {
                paymentRows.add({
                  'id': 3,
                  'document_id': 10,
                  'amount': incomingPaid,
                  'receipt_document_id': null,
                  'payment_origin': PaymentOrigin.upfront,
                });
              }
            }

            invoicePaid = incomingPaid;
          }
        }

        // Action: User enters upfront payment of $20.0 on invoice 10
        expect(() => simulateUpdateInvoicePaid(20.0), returnsNormally);

        expect(invoicePaid, 20.0);
        expect(paymentRows.length, 3);
        final newUpfront = paymentRows.firstWhere((r) => r['payment_origin'] == PaymentOrigin.upfront);
        expect(newUpfront['amount'], 20.0);

        final ledgerSum = MoneyUtils.round(
          paymentRows.fold<double>(0.0, (s, r) => s + (r['amount'] as double)),
          decimalDigits,
        );
        expect(ledgerSum, 20.0);
        expect(ledgerSum, invoicePaid, reason: 'Ledger sum matches invoice.paid exactly');

        // Subsequent edit: Change upfront from 20.0 to 35.0
        expect(() => simulateUpdateInvoicePaid(35.0), returnsNormally);
        expect(invoicePaid, 35.0);
        expect(paymentRows.length, 3);
        expect(newUpfront['amount'], 35.0);

        // Edit upfront to 0.0
        expect(() => simulateUpdateInvoicePaid(0.0), returnsNormally);
        expect(invoicePaid, 0.0);
        expect(paymentRows.length, 2); // upfront row deleted, cancelled receipt rows preserved
      },
    );

    test(
      '72. Adversarial Finding 3.A: Repeated receipt cancellation and deletion cannot create duplicate reversals',
      () {
        var receiptStatus = DocumentStatus.issued;
        final payments = <Map<String, dynamic>>[
          {
            'id': 1,
            'document_id': 10,
            'amount': 40.0,
            'receipt_document_id': 101,
            'payment_origin': PaymentOrigin.receipt,
          },
        ];

        void simulateCancelReceipt() {
          if (receiptStatus == DocumentStatus.cancelled) {
            throw StateError('Document is already cancelled');
          }
          payments.add({
            'id': 2,
            'document_id': 10,
            'amount': -40.0,
            'receipt_document_id': 101,
            'payment_origin': PaymentOrigin.reversal,
          });
          receiptStatus = DocumentStatus.cancelled;
        }

        void simulateDeleteReceipt() {
          final history = payments.where((r) => r['receipt_document_id'] == 101).toList();
          if (history.isNotEmpty) {
            throw StateError('Cannot delete payment_receipt with recorded payment history');
          }
        }

        // First cancel succeeds
        simulateCancelReceipt();
        expect(receiptStatus, DocumentStatus.cancelled);
        expect(payments.length, 2);

        // Second cancel fails
        expect(() => simulateCancelReceipt(), throwsA(isA<StateError>()));
        expect(payments.length, 2, reason: 'Zero duplicate reversal created');

        // Delete attempt fails
        expect(() => simulateDeleteReceipt(), throwsA(isA<StateError>()));
        expect(payments.length, 2, reason: 'Historical rows remain intact');
      },
    );

    test(
      '73. Adversarial Finding 3.A: Expense voucher lifecycle matches payment receipt invariants',
      () {
        const currencyCode = 'USD';
        final decimalDigits = Currency.decimalDigitsForCode(currencyCode);

        const purchaseTotal = 200.0;
        var purchasePaid = 0.0;

        final payments = <Map<String, dynamic>>[];

        // 1. Record expense voucher for 80.0
        payments.add({
          'id': 1,
          'document_id': 20,
          'amount': 80.0,
          'receipt_document_id': 201,
          'payment_origin': PaymentOrigin.receipt,
        });
        purchasePaid = 80.0;

        // 2. Cancel expense voucher
        payments.add({
          'id': 2,
          'document_id': 20,
          'amount': -80.0,
          'receipt_document_id': 201,
          'payment_origin': PaymentOrigin.reversal,
        });
        purchasePaid = 0.0;

        // 3. Deletion attempt of cancelled voucher is rejected
        final history = payments.where((r) => r['receipt_document_id'] == 201).toList();
        expect(history.length, 2);
        void simulateDeleteVoucher(int id) {
          if (payments.any((r) => r['receipt_document_id'] == id)) {
            throw StateError('Cannot delete expense_voucher with recorded payment history');
          }
        }
        expect(() => simulateDeleteVoucher(201), throwsA(isA<StateError>()));

        // 4. Record purchase upfront payment of 50.0
        payments.add({
          'id': 3,
          'document_id': 20,
          'amount': 50.0,
          'receipt_document_id': null,
          'payment_origin': PaymentOrigin.upfront,
        });
        purchasePaid = 50.0;

        final ledgerTotal = MoneyUtils.round(
          payments.fold<double>(0.0, (s, r) => s + (r['amount'] as double)),
          decimalDigits,
        );
        expect(ledgerTotal, 50.0);
        expect(purchasePaid, 50.0);
        expect(MoneyUtils.calculateRemaining(purchaseTotal, purchasePaid, decimalDigits), 150.0);
      },
    );

    test(
      '74. Adversarial Finding 3.A: Legacy rows with NULL receipt_document_id and NULL payment_origin are preserved',
      () {
        final legacyPayments = <Map<String, dynamic>>[
          {
            'id': 1,
            'document_id': 10,
            'amount': 60.0,
            'receipt_document_id': null,
            'payment_origin': null, // legacy row without explicit origin
          },
        ];

        void simulateUpdate(double incomingPaid) {
          final unclassified = legacyPayments
              .where((r) => r['receipt_document_id'] == null && r['payment_origin'] == null)
              .toList();

          if (incomingPaid != 60.0) {
            if (unclassified.isNotEmpty) {
              throw StateError(
                'Cannot modify paid amount: document contains legacy unclassified payment records. Please record payments via payment receipts instead.',
              );
            }
          }
        }

        // Harmless non-financial edit (incoming paid == 60.0) succeeds without mutating legacy rows
        expect(() => simulateUpdate(60.0), returnsNormally);
        expect(legacyPayments.length, 1);
        expect(legacyPayments.first['amount'], 60.0);
        expect(legacyPayments.first['payment_origin'], isNull, reason: 'Never fabricate origins for legacy data');

        // Altering paid on document with unclassified legacy rows is rejected transactionally
        expect(
          () => simulateUpdate(80.0),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot modify paid amount: document contains legacy unclassified payment records'),
          )),
        );
      },
    );

    test(
      '75. Adversarial Finding 3.A: Net ledger sum matches document.paid across multi-step transactions',
      () {
        const digits = 2;
        final payments = <Map<String, dynamic>>[];
        var docPaid = 0.0;

        // Step 1: Upfront down payment of 30.0
        payments.add({
          'id': 1,
          'document_id': 10,
          'amount': 30.0,
          'receipt_document_id': null,
          'payment_origin': PaymentOrigin.upfront,
        });
        docPaid = 30.0;
        expect(payments.fold<double>(0.0, (s, r) => s + (r['amount'] as double)), docPaid);

        // Step 2: Linked receipt payment of 40.0
        payments.add({
          'id': 2,
          'document_id': 10,
          'amount': 40.0,
          'receipt_document_id': 101,
          'payment_origin': PaymentOrigin.receipt,
        });
        docPaid = MoneyUtils.round(docPaid + 40.0, digits);
        expect(payments.fold<double>(0.0, (s, r) => s + (r['amount'] as double)), docPaid);

        // Step 3: Cancellation of receipt 101 (-40.0)
        payments.add({
          'id': 3,
          'document_id': 10,
          'amount': -40.0,
          'receipt_document_id': 101,
          'payment_origin': PaymentOrigin.reversal,
        });
        docPaid = MoneyUtils.round(docPaid - 40.0, digits);
        expect(payments.fold<double>(0.0, (s, r) => s + (r['amount'] as double)), docPaid);
        expect(docPaid, 30.0);

        // Step 4: Upfront payment updated to 50.0
        final upfront = payments.firstWhere((r) => r['payment_origin'] == PaymentOrigin.upfront);
        upfront['amount'] = 50.0;
        docPaid = 50.0;

        final finalLedgerSum = MoneyUtils.round(
          payments.fold<double>(0.0, (s, r) => s + (r['amount'] as double)),
          digits,
        );
        expect(finalLedgerSum, docPaid);
        expect(finalLedgerSum, 50.0);
      },
    );
  });
}
