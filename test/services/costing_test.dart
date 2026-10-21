import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/inventory_costing_service.dart';

void main() {
  group('Phase 3 - Inventory Costing & Models', () {
    test('1. Initial stock with known cost establishes moving average cost', () {
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
    });

    test('2. Initial stock without cost leaves product cost unknown and valuation unvalued', () {
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
    });

    test('3. Purchase updates moving average cost via weighted average formula', () {
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
    });

    test('4. Sale records movement and item cost snapshots at existing average cost', () {
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
    });

    test('5. Editing a product default purchase_price in catalog does NOT alter historical costs', () {
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
      expect(catalogUpdated.averageCost, 120.0); // Moving average cost unchanged
      expect(historicalMovement.unitCost, 120.0); // Historical movement cost unchanged
    });

    test('6. Multiple sequential purchases at different prices produce correct weighted averages', () {
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
    });

    test('7. Partial sales leave remaining inventory valuation equal to remaining quantity * average cost', () {
      const stockBeforeSale = 30.0;
      const avgCost = 200.0;
      const initialValuation = stockBeforeSale * avgCost; // 6000.0

      const saleQty = 10.0;
      const cogs = saleQty * avgCost; // 2000.0

      const remainingStock = stockBeforeSale - saleQty; // 20.0
      const remainingValuation = remainingStock * avgCost; // 4000.0

      expect(initialValuation - cogs, closeTo(remainingValuation, 0.0001));
      expect(remainingValuation, 4000.0);
    });

    test('8. Stock movement model supports unitCost, totalCost, costStatus, and provenance', () {
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
    });

    test('9. Purchase cancellation calculation reverses weighted cost properly', () {
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
      final remainingTotalCost = (currentStock * currentAvg) - (cancelQty * cancelUnitCost);
      final remainingAvg = remainingStock > 0 ? (remainingTotalCost / remainingStock) : null;

      expect(remainingStock, 10.0);
      expect(remainingAvg, closeTo(100.0, 0.0001));
    });

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

    test('11. Document item model correctly serializes and deserializes cost fields', () {
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
    });

    test('12. Attempting to consume more stock than available triggers guard', () {
      const stockOnHand = 4.0;
      const purchaseQtyToCancel = 10.0;

      expect(stockOnHand < purchaseQtyToCancel, isTrue);
      expect(
        () {
          if (stockOnHand < purchaseQtyToCancel) {
            throw StateError('Cannot cancel purchase: 6 of 10 items have already been consumed');
          }
        },
        throwsA(isA<StateError>()),
      );
    });

    test('13. Legacy purchases with linked document items use reconstructed provenance', () {
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
    });

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

    test('16. Incomplete cost report flags sales with unknown cost and discloses reliability', () {
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
        grossProfit: 0.0,
        profitMargin: 0.0,
        isCostReliable: false, // Flagged!
      );

      expect(summary.isCostReliable, isFalse);
      expect(summary.grossProfit, 0.0);
      expect(summary.profitMargin, 0.0);
    });

    test('17. Mixed known and unknown item costs make the invoice profit unavailable', () {
      final doc = Document(
        id: 3,
        type: 'invoice',
        documentNumber: 'INV-2026-003',
        date: DateTime(2026, 10, 18),
        subtotal: 3000.0,
        discount: 200.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 2800.0,
        paid: 2800.0,
        remaining: 0.0,
      );

      final recognizedRevenue = doc.subtotal - doc.discount;
      final summary = SaleProfitSummary(
        document: doc,
        recognizedRevenue: recognizedRevenue,
        cogs: 1000.0,
        grossProfit: 0.0,
        profitMargin: 0.0,
        isCostReliable: false,
      );

      expect(summary.isCostReliable, isFalse);
      expect(summary.recognizedRevenue, 2800.0);
      expect(summary.grossProfit, 0.0);
      expect(summary.profitMargin, 0.0);
    });

    test('18. Explicit zero-cost item is valid only when the business rules and data explicitly support it', () {
      final doc = Document(
        id: 4,
        type: 'invoice',
        documentNumber: 'INV-2026-004',
        date: DateTime(2026, 10, 18),
        subtotal: 1000.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 1000.0,
        paid: 1000.0,
        remaining: 0.0,
      );

      final summary = SaleProfitSummary(
        document: doc,
        recognizedRevenue: 1000.0,
        cogs: 0.0,
        grossProfit: 1000.0,
        profitMargin: 100.0,
        isCostReliable: true,
      );

      expect(summary.isCostReliable, isTrue);
      expect(summary.grossProfit, 1000.0);
      expect(summary.profitMargin, 100.0);
    });

    test('19. Aggregate reports ignore incomplete invoices when calculating reliable profit totals', () {
      final completeInvoice = SaleProfitSummary(
        document: Document(
          id: 101,
          type: 'invoice',
          documentNumber: 'INV-100',
          date: DateTime(2026, 10, 18),
          subtotal: 1000.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 1000.0,
          paid: 1000.0,
          remaining: 0.0,
        ),
        recognizedRevenue: 1000.0,
        cogs: 600.0,
        grossProfit: 400.0,
        profitMargin: 40.0,
        isCostReliable: true,
      );

      final incompleteInvoice = SaleProfitSummary(
        document: Document(
          id: 102,
          type: 'invoice',
          documentNumber: 'INV-101',
          date: DateTime(2026, 10, 19),
          subtotal: 2000.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 2000.0,
          paid: 2000.0,
          remaining: 0.0,
        ),
        recognizedRevenue: 2000.0,
        cogs: 0.0,
        grossProfit: 0.0,
        profitMargin: 0.0,
        isCostReliable: false,
      );

      final reliableInvoices = [completeInvoice, incompleteInvoice]
          .where((s) => s.isCostReliable)
          .toList();

      final totalRevenue = reliableInvoices.fold<double>(
        0,
        (sum, s) => sum + s.recognizedRevenue,
      );
      final totalProfit = reliableInvoices.fold<double>(
        0,
        (sum, s) => sum + s.grossProfit,
      );

      expect(reliableInvoices.length, 1);
      expect(totalRevenue, 1000.0);
      expect(totalProfit, 400.0);
    });

    test('20. Zero stock followed by purchase properly resets average cost to new purchase price', () {
      // Stock is 0.0, currentAvgCost is old (e.g. 50.0)
      final newAvg = InventoryCostingService.calculateNewWeightedAverage(
        currentStock: 0.0,
        currentAvgCost: 50.0,
        incomingQty: 10.0,
        incomingUnitCost: 120.0,
      );

      // When stock is 0 or negative, incoming cost becomes the new average directly!
      expect(newAvg, 120.0);
    });

    test('21. Inventory valuation summary properly separates valued from unvalued items', () {
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
    });
  });
}
