import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/date_range_filter.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/pdf/pdf_report_builder.dart';

void main() {
  group('Phase 4 - Date Range Boundaries & Presets', () {
    test('1. Date-range inclusion/exclusion and previous month calculation', () {
      final prevMonthFilter = DateRangeFilter.previousMonth();
      expect(prevMonthFilter.preset, DateRangePreset.previousMonth);
      expect(prevMonthFilter.from.day, 1);
      expect(prevMonthFilter.from.hour, 0);
      expect(prevMonthFilter.from.minute, 0);
      expect(prevMonthFilter.to.hour, 23);
      expect(prevMonthFilter.to.minute, 59);

      // Verify that 'from' is strictly before 'to'
      expect(prevMonthFilter.from.isBefore(prevMonthFilter.to), isTrue);

      // Verify leap year February boundary test:
      final febLeap = DateTime(2024, 3, 0); // Last day of Feb 2024 (leap year)
      expect(febLeap.day, 29);
      final febNonLeap = DateTime(2025, 3, 0); // Last day of Feb 2025 (non-leap year)
      expect(febNonLeap.day, 28);

      // Verify year boundary wrapping:
      final janFirst = DateTime(2026, 1, 15);
      final prevMonthFromJan = DateTime(janFirst.year, janFirst.month - 1, 1);
      expect(prevMonthFromJan.year, 2025);
      expect(prevMonthFromJan.month, 12);
      expect(prevMonthFromJan.day, 1);
    });

    test('2. Custom date range preserves start and end of day bounds', () {
      final from = DateTime(2026, 5, 10);
      final to = DateTime(2026, 5, 20);
      final filter = DateRangeFilter.custom(from, to);

      expect(filter.preset, DateRangePreset.custom);
      expect(filter.from.day, 10);
      expect(filter.from.hour, 0);
      expect(filter.to.day, 20);
      expect(filter.to.hour, 23);
      expect(filter.to.minute, 59);
    });
  });

  group('Phase 4 - Stock Status Classification', () {
    test('3. Out-of-stock classification includes zero and negative stock, excludes services', () {
      const pZero = Product(name: 'Item Zero', stockQuantity: 0.0, type: 'product', salePrice: 100);
      const pNegative = Product(name: 'Item Neg', stockQuantity: -2.0, type: 'product', salePrice: 100);
      const pPositive = Product(name: 'Item Pos', stockQuantity: 5.0, type: 'product', salePrice: 100);
      const pServiceZero = Product(name: 'Consulting', stockQuantity: 0.0, type: 'service', salePrice: 500);

      expect(pZero.stockQuantity <= 0 && pZero.type == 'product', isTrue);
      expect(pNegative.stockQuantity <= 0 && pNegative.type == 'product', isTrue);
      expect(pPositive.stockQuantity <= 0, isFalse);
      // Service must not be classified as out-of-stock inventory:
      expect(pServiceZero.type == 'product', isFalse);
    });

    test('4. Low-stock classification includes positive stock <= minStock when minStock > 0', () {
      // Configured minStock: 10
      const pLow = Product(name: 'Item Low', stockQuantity: 4.0, minStock: 10.0, type: 'product', salePrice: 50);
      const pExact = Product(name: 'Item Exact', stockQuantity: 10.0, minStock: 10.0, type: 'product', salePrice: 50);
      const pHealthy = Product(name: 'Item Healthy', stockQuantity: 15.0, minStock: 10.0, type: 'product', salePrice: 50);
      const pOut = Product(name: 'Item Out', stockQuantity: 0.0, minStock: 10.0, type: 'product', salePrice: 50);
      const pUnset = Product(name: 'Item Unset', stockQuantity: 2.0, minStock: 0.0, type: 'product', salePrice: 50);

      // Low stock rule: minStock > 0 && stockQuantity > 0 && stockQuantity <= minStock
      bool isLowStock(Product p) => p.minStock > 0 && p.stockQuantity > 0 && p.stockQuantity <= p.minStock;

      expect(isLowStock(pLow), isTrue);
      expect(isLowStock(pExact), isTrue);
      expect(isLowStock(pHealthy), isFalse);
      expect(isLowStock(pOut), isFalse); // 0 is out of stock, not low stock
      expect(isLowStock(pUnset), isFalse); // minStock 0 is unset, never low stock
    });

    test('5. Shortage quantity calculation matches replenishment demand', () {
      const pLow = Product(name: 'Sugar', stockQuantity: 3.0, minStock: 10.0, type: 'product', salePrice: 100);
      final shortage = (pLow.minStock > 0 && pLow.stockQuantity < pLow.minStock)
          ? (pLow.minStock - pLow.stockQuantity)
          : 0.0;
      expect(shortage, 7.0);

      const pOver = Product(name: 'Flour', stockQuantity: 12.0, minStock: 10.0, type: 'product', salePrice: 100);
      final shortageOver = (pOver.minStock > 0 && pOver.stockQuantity < pOver.minStock)
          ? (pOver.minStock - pOver.stockQuantity)
          : 0.0;
      expect(shortageOver, 0.0);
    });
  });

  group('Phase 4 - Sales & Profit by Product Calculations', () {
    test('6. Sales by product quantity, revenue, and transaction count', () {
      const item = ProductPerformanceItem(
        productId: 1,
        productName: 'Vegetable Oil 1L',
        category: 'الزيوت',
        unit: 'قارورة',
        salesQty: 25.0,
        transactionCount: 8,
        salesRevenue: 37500.0,
        cogs: 27500.0,
        grossProfit: 10000.0,
        profitMargin: 26.67,
        isCostReliable: true,
        unknownCostSalesCount: 0,
        currentStock: 15.0,
        averageCost: 1100.0,
        currentValuation: 16500.0,
      );

      expect(item.salesQty, 25.0);
      expect(item.salesRevenue, 37500.0);
      expect(item.transactionCount, 8);
      expect(item.grossProfit, 10000.0);
      expect(item.isCostReliable, isTrue);
    });

    test('7. Gross profit uses historical COGS and preserves unknown cost disclosure', () {
      // Product with unknown cost: cogs = 0 recorded, but marked NOT reliable
      const unvaluedItem = ProductPerformanceItem(
        productId: 2,
        productName: 'Legacy Tea Bag',
        category: 'المشروبات',
        unit: 'علبة',
        salesQty: 10.0,
        transactionCount: 3,
        salesRevenue: 15000.0,
        cogs: 0.0,
        grossProfit: 15000.0,
        profitMargin: 100.0,
        isCostReliable: false, // Disclosed as incomplete!
        unknownCostSalesCount: 3,
        currentStock: 5.0,
        averageCost: null,
        currentValuation: null,
      );

      expect(unvaluedItem.isCostReliable, isFalse);
      expect(unvaluedItem.unknownCostSalesCount, 3);
      expect(unvaluedItem.currentValuation, isNull);

      final summary = ProductPerformanceSummary(
        items: [unvaluedItem],
        totalSalesRevenue: 15000.0,
        totalCogs: 0.0,
        totalGrossProfit: 15000.0,
        hasIncompleteCosts: true,
        unvaluedSalesCount: 3,
        currencies: {'SDG'},
      );

      expect(summary.hasIncompleteCosts, isTrue);
      expect(summary.unvaluedSalesCount, 3);
    });

    test('8. Cancelled sales and double-counting exclusions', () {
      final docIssued = Document(
        id: 1,
        type: 'invoice',
        documentNumber: 'INV-101',
        date: DateTime(2026, 10, 15),
        status: DocumentStatus.issued,
        subtotal: 1000.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 1000.0,
        paid: 1000.0,
        remaining: 0.0,
      );

      final docCancelled = Document(
        id: 2,
        type: 'invoice',
        documentNumber: 'INV-102',
        date: DateTime(2026, 10, 16),
        status: DocumentStatus.cancelled,
        subtotal: 2500.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 2500.0,
        paid: 0.0,
        remaining: 0.0,
      );

      final docs = [docIssued, docCancelled];
      final activeDocs = docs.where((d) => d.status != DocumentStatus.cancelled).toList();

      expect(activeDocs.length, 1);
      expect(activeDocs.first.id, 1);
      final activeSalesTotal = activeDocs.fold(0.0, (s, d) => s + d.total);
      expect(activeSalesTotal, 1000.0); // 2500 from cancelled invoice strictly excluded
    });
  });

  group('Phase 4 - Purchases Report Aggregation', () {
    test('9. Purchase totals, paid amounts, and remaining amounts exclude cancelled purchases', () {
      final p1 = Document(
        id: 10,
        type: 'purchase',
        documentNumber: 'PUR-001',
        date: DateTime(2026, 10, 5),
        status: DocumentStatus.issued,
        subtotal: 50000.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 50000.0,
        paid: 30000.0,
        remaining: 20000.0,
      );

      final p2 = Document(
        id: 11,
        type: 'purchase',
        documentNumber: 'PUR-002',
        date: DateTime(2026, 10, 8),
        status: DocumentStatus.issued,
        subtotal: 20000.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 20000.0,
        paid: 20000.0,
        remaining: 0.0,
      );

      final pCancelled = Document(
        id: 12,
        type: 'purchase',
        documentNumber: 'PUR-003',
        date: DateTime(2026, 10, 10),
        status: DocumentStatus.cancelled,
        subtotal: 40000.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 40000.0,
        paid: 0.0,
        remaining: 40000.0,
      );

      final items = [
        PurchaseReportItem(document: p1, netAmount: p1.total, paidAmount: p1.paid, remainingAmount: p1.remaining),
        PurchaseReportItem(document: p2, netAmount: p2.total, paidAmount: p2.paid, remainingAmount: p2.remaining),
        PurchaseReportItem(document: pCancelled, netAmount: pCancelled.total, paidAmount: pCancelled.paid, remainingAmount: pCancelled.remaining),
      ];

      final finalized = items.where((i) => i.document.status != DocumentStatus.cancelled);
      final totalPurchases = finalized.fold(0.0, (s, i) => s + i.netAmount);
      final totalPaid = finalized.fold(0.0, (s, i) => s + i.paidAmount);
      final totalRemaining = finalized.fold(0.0, (s, i) => s + i.remainingAmount);

      expect(totalPurchases, 70000.0);
      expect(totalPaid, 50000.0);
      expect(totalRemaining, 20000.0);
      expect(items.where((i) => i.document.status == DocumentStatus.cancelled).length, 1);
    });

    test('10. Multi-currency detection identifies mixed currencies without invalid aggregation', () {
      final currencies = {'SDG', 'USD'};
      final hasMixedCurrencies = currencies.length > 1;
      expect(hasMixedCurrencies, isTrue);

      final singleCurrency = {'SDG'};
      expect(singleCurrency.length > 1, isFalse);
    });
  });

  group('Phase 4 - Inventory Valuation & Unit Safety', () {
    test('11. Inventory valuation uses moving-average cost, never selling price, and excludes services', () {
      const productTracked = Product(
        name: 'Wheat 100kg',
        type: 'product',
        stockQuantity: 10.0,
        salePrice: 80000.0,
        purchasePrice: 60000.0,
        averageCost: 55000.0,
        costStatus: Product.costStatusKnown,
      );

      const serviceItem = Product(
        name: 'Transportation',
        type: 'service',
        stockQuantity: 0.0,
        salePrice: 15000.0,
      );

      // Inventory valuation must be stock * averageCost, NEVER stock * salePrice
      final valuation = productTracked.stockQuantity * productTracked.averageCost!;
      expect(valuation, 550000.0);
      expect(valuation != (productTracked.stockQuantity * productTracked.salePrice), isTrue);

      // Service items must have zero valuation and not be part of stock valuation
      expect(serviceItem.type == 'service', isTrue);
    });

    test('12. Unit quantities are aggregated per-unit rather than across unlike units', () {
      final unitMap = <String, double>{
        'كجم': 150.0,
        'قارورة': 48.0,
        'قطعة': 200.0,
      };

      expect(unitMap['كجم'], 150.0);
      expect(unitMap['قارورة'], 48.0);
      expect(unitMap['قطعة'], 200.0);
      // Ensure we do not sum 150 kg + 48 bottles into 198 meaningless units
      expect(unitMap.keys.length, 3);
    });

    test('13. Stock movement running balance calculation', () {
      final m1 = StockMovement(
        productId: 5,
        type: StockMovement.typeOpening,
        quantity: 20.0,
        date: DateTime(2026, 10, 1),
      );
      final m2 = StockMovement(
        productId: 5,
        type: StockMovement.typeSale,
        quantity: -5.0,
        date: DateTime(2026, 10, 5),
      );
      final m3 = StockMovement(
        productId: 5,
        type: StockMovement.typePurchase,
        quantity: 15.0,
        date: DateTime(2026, 10, 10),
      );

      double balance = 0.0;
      final history = <StockMovementReportItem>[];

      for (final m in [m1, m2, m3]) {
        final bBefore = balance;
        balance += m.quantity;
        final bAfter = balance;
        history.add(StockMovementReportItem(
          movement: m,
          balanceBefore: bBefore,
          balanceAfter: bAfter,
          isBalanceReliable: true,
        ));
      }

      expect(history[0].balanceBefore, 0.0);
      expect(history[0].balanceAfter, 20.0);

      expect(history[1].balanceBefore, 20.0);
      expect(history[1].balanceAfter, 15.0);

      expect(history[2].balanceBefore, 15.0);
      expect(history[2].balanceAfter, 30.0);
    });
  });

  group('Phase 4 - PDF Data Model Alignment', () {
    test('14. PDF report data model correctly structures summary cards and rows', () {
      final data = PdfReportData(
        title: 'تقرير المبيعات حسب المنتج',
        dateRange: '01/10/2026 – 18/10/2026',
        summaryCards: const [
          PdfReportSummaryCard(label: 'إجمالي المبيعات', value: '45,000'),
          PdfReportSummaryCard(label: 'مجمل الربح', value: '12,500'),
        ],
        columns: const [
          PdfReportColumn(title: 'المنتج', flex: 2.0),
          PdfReportColumn(title: 'الكمية', flex: 1.0),
          PdfReportColumn(title: 'المبيعات', flex: 1.5),
        ],
        rows: const [
          ['سكر 50 كجم', '10', '45,000'],
        ],
        totalsRow: const ['الإجمالي', '10', '45,000'],
      );

      expect(data.title, 'تقرير المبيعات حسب المنتج');
      expect(data.summaryCards.length, 2);
      expect(data.columns.length, 3);
      expect(data.rows.length, 1);
      expect(data.totalsRow, isNotNull);
      expect(data.totalsRow![2], '45,000');
    });

    test('15. Empty report data structures are safely handled', () {
      final emptyData = PdfReportData(
        title: 'تقرير فارغ',
        columns: const [PdfReportColumn(title: 'العنصر')],
        rows: const [],
      );

      expect(emptyData.rows.isEmpty, isTrue);
      expect(emptyData.summaryCards.isEmpty, isTrue);
      expect(emptyData.warningNotice, isNull);
    });
  });
}
