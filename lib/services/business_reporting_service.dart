import '../database/database_helper.dart';
import '../models/currency.dart';
import '../models/document.dart';
import '../models/document_status.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../utils/money_utils.dart';
import 'inventory_service.dart';

/// Single item representing a product's sales, costs, profit, and stock performance.
class ProductPerformanceItem {
  final int productId;
  final String productName;
  final String? category;
  final String? unit;
  final double salesQty;
  final int transactionCount;
  final double salesRevenue;
  final double cogs;
  final double grossProfit;
  final double profitMargin;
  final bool isCostReliable;
  final int unknownCostSalesCount;
  final double currentStock;
  final double? averageCost;
  final double? currentValuation;
  final String? currencyCode;
  final Map<String, ({
    double qty,
    double revenue,
    double cogs,
    double grossProfit,
    double profitMargin,
    bool isReliable,
    int unknownCount,
  })> salesByCurrency;

  const ProductPerformanceItem({
    required this.productId,
    required this.productName,
    this.category,
    this.unit,
    required this.salesQty,
    required this.transactionCount,
    required this.salesRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.profitMargin,
    required this.isCostReliable,
    required this.unknownCostSalesCount,
    required this.currentStock,
    this.averageCost,
    this.currentValuation,
    this.currencyCode,
    this.salesByCurrency = const {},
  });

  /// Gross profit only when cost is fully known; null otherwise.
  double? get trustedGrossProfit => isCostReliable ? grossProfit : null;

  /// Profit margin only when cost is fully known; null otherwise.
  double? get trustedProfitMargin => isCostReliable ? profitMargin : null;
}

/// Consolidated summary for product performance reports.
class ProductPerformanceSummary {
  final List<ProductPerformanceItem> items;
  final double totalSalesRevenue;
  final double totalCogs;

  /// Sum of gross profit across ALL products, including those with incomplete
  /// cost data.  This value is understated for products with unknown cost
  /// (their COGS is excluded from the sum).  Check [hasIncompleteCosts] before
  /// treating this as a definitive profit figure.
  ///
  /// Use [totalTrustedGrossProfit] for aggregate totals that must not include
  /// overstated figures.
  final double totalGrossProfit;

  /// Sum of gross profit only from products whose cost is fully known
  /// ([ProductPerformanceItem.isCostReliable] == true).
  ///
  /// Safe to display as a definitive aggregate — unreliable products
  /// contribute zero rather than an inflated zero-COGS figure.
  final double totalTrustedGrossProfit;

  final bool hasIncompleteCosts;
  final int unvaluedSalesCount;
  final Set<String> currencies;
  final Map<String, ({
    double revenue,
    double cogs,
    double grossProfit,
    double trustedProfit,
    bool hasIncompleteCost,
    int unvaluedSalesCount,
  })> totalsByCurrency;

  bool get hasMultipleCurrencies => currencies.length > 1;

  const ProductPerformanceSummary({
    required this.items,
    required this.totalSalesRevenue,
    required this.totalCogs,
    required this.totalGrossProfit,
    double? totalTrustedGrossProfit,
    required this.hasIncompleteCosts,
    required this.unvaluedSalesCount,
    required this.currencies,
    this.totalsByCurrency = const {},
  }) : totalTrustedGrossProfit = totalTrustedGrossProfit ??
            (hasIncompleteCosts ? 0.0 : totalGrossProfit);
}

/// Item representing a purchase document in purchase reports.
class PurchaseReportItem {
  final Document document;
  final String? supplierName;
  final String? supplierPhone;
  final double netAmount;
  final double paidAmount;
  final double remainingAmount;

  const PurchaseReportItem({
    required this.document,
    this.supplierName,
    this.supplierPhone,
    required this.netAmount,
    required this.paidAmount,
    required this.remainingAmount,
  });
}

/// Consolidated summary for purchase reports.
class PurchaseReportSummary {
  final List<PurchaseReportItem> items;
  final double totalPurchases;
  final double totalPaid;
  final double totalRemaining;
  final int cancelledCount;
  final Set<String> currencies;
  final Map<String, ({double purchases, double paid, double remaining})> totalsByCurrency;

  const PurchaseReportSummary({
    required this.items,
    required this.totalPurchases,
    required this.totalPaid,
    required this.totalRemaining,
    required this.cancelledCount,
    required this.currencies,
    this.totalsByCurrency = const {},
  });
}

/// Item representing inventory stock status, thresholds, and valuation.
class InventoryReportItem {
  final Product product;
  final double stockQuantity;
  final double minStock;
  final double? averageCost;
  final double? valuationAtCost;
  final bool isLowStock;
  final bool isOutOfStock;
  final double shortageQuantity;
  final bool isCostKnown;

  const InventoryReportItem({
    required this.product,
    required this.stockQuantity,
    required this.minStock,
    this.averageCost,
    this.valuationAtCost,
    required this.isLowStock,
    required this.isOutOfStock,
    required this.shortageQuantity,
    required this.isCostKnown,
  });
}

/// Consolidated summary for inventory, replenishment, and valuation reports.
class InventoryReportSummary {
  final List<InventoryReportItem> items;
  final double totalValuationAtCost;
  final int valuedProductsCount;
  final int unvaluedProductsCount;
  final double unvaluedQuantity;
  final int lowStockCount;
  final int outOfStockCount;
  final int trackedProductsCount;
  final Map<String, double> unitsSummary;

  const InventoryReportSummary({
    required this.items,
    required this.totalValuationAtCost,
    required this.valuedProductsCount,
    required this.unvaluedProductsCount,
    required this.unvaluedQuantity,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.trackedProductsCount,
    required this.unitsSummary,
  });
}

/// Item representing a stock movement with running balance calculation.
class StockMovementReportItem {
  final StockMovement movement;
  final double? balanceBefore;
  final double? balanceAfter;
  final bool isBalanceReliable;

  const StockMovementReportItem({
    required this.movement,
    this.balanceBefore,
    this.balanceAfter,
    required this.isBalanceReliable,
  });
}

/// Consolidated summary for stock movements report.
class StockMovementReportSummary {
  final List<StockMovementReportItem> items;
  final double totalInQuantity;
  final double totalOutQuantity;
  final int unvaluedMovementsCount;

  const StockMovementReportSummary({
    required this.items,
    required this.totalInQuantity,
    required this.totalOutQuantity,
    required this.unvaluedMovementsCount,
  });
}

/// Central business reporting service providing verified queries,
/// consistent aggregations, and currency/unit safety.
class BusinessReportingService {
  BusinessReportingService._();
  static final BusinessReportingService instance = BusinessReportingService._();

  /// Product Performance, Sales by Product, and Profit by Product report.
  Future<ProductPerformanceSummary> getProductPerformance({
    required DateTime from,
    required DateTime to,
    String? category,
    String? currencyCode,
    String sortBy = 'revenue', // 'revenue', 'quantity', 'profit'
  }) async {
    final db = await DatabaseHelper.instance.database;

    final conditions = <String>[
      'p.is_active = 1',
      "p.type = 'product'",
    ];
    final productArgs = <Object?>[];

    if (category != null && category.isNotEmpty && category != 'all') {
      conditions.add('p.category = ?');
      productArgs.add(category);
    }

    // 1. Fetch eligible active products
    final productRows = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.category,
        p.unit,
        p.stock_quantity,
        p.average_cost,
        p.cost_status
      FROM products p
      WHERE ${conditions.join(' AND ')}
      ORDER BY p.id
    ''', productArgs);

    // 2. Fetch all line items from eligible finalized invoices in the period
    final docConditions = <String>[
      "d.type = 'invoice'",
      "d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')",
      "d.date >= ? AND d.date <= ?",
    ];
    final docArgs = <Object?>[from.toIso8601String(), to.toIso8601String()];
    if (currencyCode != null && currencyCode.isNotEmpty) {
      docConditions.add('d.currency_code = ?');
      docArgs.add(currencyCode);
    }

    final invoiceItemRows = await db.rawQuery('''
      SELECT
        di.id AS item_id,
        di.document_id,
        di.product_id,
        COALESCE(di.base_quantity, di.quantity) AS quantity,
        di.total AS line_total,
        di.total_cost,
        d.subtotal AS doc_subtotal,
        d.discount AS doc_discount,
        d.currency_code
      FROM document_items di
      JOIN documents d ON d.id = di.document_id
      WHERE ${docConditions.join(' AND ')}
      ORDER BY d.id, di.id
    ''', docArgs);

    // Group items by invoice document to allocate document-level discount across lines
    final docItemsMap = <int, List<Map<String, Object?>>>{};
    for (final row in invoiceItemRows) {
      final docId = (row['document_id'] as num).toInt();
      docItemsMap.putIfAbsent(docId, () => []).add(row);
    }

    final business = await DatabaseHelper.instance.getFirstBusiness();
    final baseCurrency = business?.currencyCode ?? 'SDG';

    final productAggregators = <int, _ProductSalesAggregator>{};
    for (final p in productRows) {
      final pid = (p['id'] as num).toInt();
      productAggregators[pid] = _ProductSalesAggregator();
    }

    final allCurrencies = <String>{};

    for (final entry in docItemsMap.entries) {
      final docId = entry.key;
      final docItems = entry.value;
      if (docItems.isEmpty) continue;

      final docSubtotal = (docItems.first['doc_subtotal'] as num?)?.toDouble() ?? 0.0;
      final docDiscount = (docItems.first['doc_discount'] as num?)?.toDouble() ?? 0.0;
      final docCurrency = (docItems.first['currency_code'] as String?)?.trim() ?? 'SDG';
      final currency = docCurrency.isNotEmpty ? docCurrency : 'SDG';
      final decimals = Currency.decimalDigitsForCode(currency);

      allCurrencies.add(currency);

      final lineAmounts = docItems
          .map((r) => (r['line_total'] as num?)?.toDouble() ?? 0.0)
          .toList();

      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: docSubtotal,
        docDiscount: docDiscount,
        lineAmounts: lineAmounts,
        decimalDigits: decimals,
      );

      for (var i = 0; i < docItems.length; i++) {
        final item = docItems[i];
        final pid = item['product_id'] as int?;
        if (pid == null) continue;
        final agg = productAggregators[pid];
        if (agg == null) continue; // product not in current category filter or inactive

        final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final totalCost = (item['total_cost'] as num?)?.toDouble();
        final netRev = netRevenues[i];

        agg.totalSalesQty += qty;
        agg.allTransactionIds.add(docId);

        final curAgg = agg.byCurrency.putIfAbsent(currency, () => _PerCurrencySales());
        curAgg.salesQty += qty;
        curAgg.salesRevenue = MoneyUtils.round(curAgg.salesRevenue + netRev, decimals);
        curAgg.transactionIds.add(docId);

        // COGS currency safety:
        // Inventory costs (average_cost / purchase price) are recorded in baseCurrency.
        // We only attribute known COGS against sales in the same currency (baseCurrency).
        if (currency == baseCurrency) {
          if (totalCost != null) {
            curAgg.knownCogs = MoneyUtils.round(curAgg.knownCogs + totalCost, decimals);
          }
          if (qty > 0 && totalCost == null) {
            curAgg.unknownCostSalesCount += 1;
          }
        } else {
          // Cross-currency sale: subtracting base-currency COGS directly from
          // foreign-currency revenue without conversion is financially invalid.
          // Flag as unconvertible cross-currency cost (incomplete for this currency).
          curAgg.isCrossCurrencyCost = true;
          curAgg.unknownCostSalesCount += 1;
        }
      }
    }

    final items = <ProductPerformanceItem>[];

    for (final r in productRows) {
      final pid = (r['id'] as num).toInt();
      final name = r['name'] as String? ?? '';
      final cat = r['category'] as String?;
      final unit = r['unit'] as String?;
      final stockQty = (r['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      final avgCost = (r['average_cost'] as num?)?.toDouble();
      final costStatus = r['cost_status'] as String? ?? Product.costStatusUnknown;
      final isCostKnown = costStatus == Product.costStatusKnown && avgCost != null;

      final agg = productAggregators[pid] ?? _ProductSalesAggregator();
      final totalSalesQty = agg.totalSalesQty;
      final txCount = agg.allTransactionIds.length;

      final itemSalesByCurrency = <String, ({
        double qty,
        double revenue,
        double cogs,
        double grossProfit,
        double profitMargin,
        bool isReliable,
        int unknownCount,
      })>{};

      for (final entry in agg.byCurrency.entries) {
        final c = entry.key;
        final d = entry.value;
        final isRel = d.unknownCostSalesCount == 0 && !d.isCrossCurrencyCost;
        final gp = MoneyUtils.round(d.salesRevenue - d.knownCogs);
        final margin = d.salesRevenue > 0 ? (gp / d.salesRevenue) * 100 : 0.0;
        itemSalesByCurrency[c] = (
          qty: d.salesQty,
          revenue: d.salesRevenue,
          cogs: d.knownCogs,
          grossProfit: gp,
          profitMargin: margin,
          isReliable: isRel,
          unknownCount: d.unknownCostSalesCount,
        );
      }

      // Backward-compatible scalars for ProductPerformanceItem
      double salesRevenue = 0.0;
      double cogs = 0.0;
      double grossProfit = 0.0;
      double margin = 0.0;
      bool isReliable = true;
      int unknownCount = 0;
      String? itemCurrency;

      if (currencyCode != null && currencyCode.isNotEmpty) {
        itemCurrency = currencyCode;
        final currData = itemSalesByCurrency[currencyCode];
        if (currData != null) {
          salesRevenue = currData.revenue;
          cogs = currData.cogs;
          grossProfit = currData.grossProfit;
          margin = currData.profitMargin;
          isReliable = currData.isReliable;
          unknownCount = currData.unknownCount;
        }
      } else if (itemSalesByCurrency.length == 1) {
        final entry = itemSalesByCurrency.entries.first;
        itemCurrency = entry.key;
        salesRevenue = entry.value.revenue;
        cogs = entry.value.cogs;
        grossProfit = entry.value.grossProfit;
        margin = entry.value.profitMargin;
        isReliable = entry.value.isReliable;
        unknownCount = entry.value.unknownCount;
      } else if (itemSalesByCurrency.length > 1) {
        // Multi-currency product activity: NEVER sum nominally across currencies
        itemCurrency = null;
        isReliable = false;
        unknownCount = itemSalesByCurrency.values.fold(0, (s, e) => s + e.unknownCount);
      } else {
        itemCurrency = baseCurrency;
      }

      final currentValuation = isCostKnown ? (stockQty > 0 ? stockQty * avgCost : 0.0) : null;

      items.add(ProductPerformanceItem(
        productId: pid,
        productName: name,
        category: cat,
        unit: unit,
        salesQty: totalSalesQty,
        transactionCount: txCount,
        salesRevenue: salesRevenue,
        cogs: cogs,
        grossProfit: grossProfit,
        profitMargin: margin,
        isCostReliable: isReliable,
        unknownCostSalesCount: unknownCount,
        currentStock: stockQty,
        averageCost: avgCost,
        currentValuation: currentValuation,
        currencyCode: itemCurrency,
        salesByCurrency: itemSalesByCurrency,
      ));
    }

    // Sort items
    if (sortBy == 'quantity') {
      items.sort((a, b) => b.salesQty.compareTo(a.salesQty));
    } else if (sortBy == 'profit') {
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
        // Tie-break deterministically: revenue descending, then product name
        final revCmp = b.salesRevenue.compareTo(a.salesRevenue);
        if (revCmp != 0) return revCmp;
        return a.productName.compareTo(b.productName);
      });
    } else {
      // default: revenue
      items.sort((a, b) => b.salesRevenue.compareTo(a.salesRevenue));
    }

    final summaryTotalsByCurrency = <String, ({
      double revenue,
      double cogs,
      double grossProfit,
      double trustedProfit,
      bool hasIncompleteCost,
      int unvaluedSalesCount,
    })>{};

    for (final c in allCurrencies) {
      double cRev = 0.0;
      double cCogs = 0.0;
      double cTrustedProfit = 0.0;
      int cUnvalued = 0;

      for (final item in items) {
        final cData = item.salesByCurrency[c];
        if (cData == null) continue;
        cRev += cData.revenue;
        cCogs += cData.cogs;
        if (cData.isReliable) {
          cTrustedProfit += cData.grossProfit;
        }
        cUnvalued += cData.unknownCount;
      }

      summaryTotalsByCurrency[c] = (
        revenue: MoneyUtils.round(cRev),
        cogs: MoneyUtils.round(cCogs),
        grossProfit: MoneyUtils.round(cRev - cCogs),
        trustedProfit: MoneyUtils.round(cTrustedProfit),
        hasIncompleteCost: cUnvalued > 0,
        unvaluedSalesCount: cUnvalued,
      );
    }

    double totalRevenue = 0.0;
    double totalCogs = 0.0;
    double totalGrossProfit = 0.0;
    double totalTrustedGrossProfit = 0.0;
    bool hasIncompleteCosts = false;
    int unvaluedSalesTotal = 0;

    if (currencyCode != null && currencyCode.isNotEmpty) {
      final curTotals = summaryTotalsByCurrency[currencyCode];
      if (curTotals != null) {
        totalRevenue = curTotals.revenue;
        totalCogs = curTotals.cogs;
        totalGrossProfit = curTotals.grossProfit;
        totalTrustedGrossProfit = curTotals.trustedProfit;
        hasIncompleteCosts = curTotals.hasIncompleteCost;
        unvaluedSalesTotal = curTotals.unvaluedSalesCount;
      }
    } else if (summaryTotalsByCurrency.length == 1) {
      final single = summaryTotalsByCurrency.values.first;
      totalRevenue = single.revenue;
      totalCogs = single.cogs;
      totalGrossProfit = single.grossProfit;
      totalTrustedGrossProfit = single.trustedProfit;
      hasIncompleteCosts = single.hasIncompleteCost;
      unvaluedSalesTotal = single.unvaluedSalesCount;
    } else if (summaryTotalsByCurrency.length > 1) {
      // Multi-currency without filter: never sum nominally across currencies
      hasIncompleteCosts = summaryTotalsByCurrency.values.any((e) => e.hasIncompleteCost);
      unvaluedSalesTotal = summaryTotalsByCurrency.values.fold(0, (s, e) => s + e.unvaluedSalesCount);
      totalRevenue = 0.0;
      totalCogs = 0.0;
      totalGrossProfit = 0.0;
      totalTrustedGrossProfit = 0.0;
    }

    return ProductPerformanceSummary(
      items: items,
      totalSalesRevenue: MoneyUtils.round(totalRevenue),
      totalCogs: MoneyUtils.round(totalCogs),
      totalGrossProfit: MoneyUtils.round(totalGrossProfit),
      totalTrustedGrossProfit: MoneyUtils.round(totalTrustedGrossProfit),
      hasIncompleteCosts: hasIncompleteCosts,
      unvaluedSalesCount: unvaluedSalesTotal,
      currencies: allCurrencies,
      totalsByCurrency: summaryTotalsByCurrency,
    );
  }

  /// Purchase documents report with supplier filter and payment status.
  Future<PurchaseReportSummary> getPurchasesReport({
    required DateTime from,
    required DateTime to,
    int? supplierId,
    String? documentStatus,
    String? paymentStatus, // 'all', 'paid', 'partial', 'unpaid'
  }) async {
    final db = await DatabaseHelper.instance.database;

    final conditions = <String>[
      "d.type = 'purchase'",
      'd.date >= ?',
      'd.date <= ?',
    ];
    final args = <Object?>[
      from.toIso8601String(),
      to.toIso8601String(),
    ];

    if (supplierId != null) {
      conditions.add('d.contact_id = ?');
      args.add(supplierId);
    }

    if (documentStatus != null && documentStatus.isNotEmpty && documentStatus != 'all') {
      conditions.add('d.status = ?');
      args.add(documentStatus);
    }

    if (paymentStatus == 'paid') {
      conditions.add('d.remaining <= 0.0001');
      conditions.add("d.status != '${DocumentStatus.cancelled}'");
    } else if (paymentStatus == 'unpaid') {
      conditions.add('d.paid <= 0.0001');
      conditions.add("d.status != '${DocumentStatus.cancelled}'");
    } else if (paymentStatus == 'partial') {
      conditions.add('d.paid > 0.0001 AND d.remaining > 0.0001');
      conditions.add("d.status != '${DocumentStatus.cancelled}'");
    }

    final sql = '''
      SELECT
        d.*,
        c.name AS supplier_name,
        c.phone AS supplier_phone
      FROM documents d
      LEFT JOIN contacts c ON d.contact_id = c.id
      WHERE ${conditions.join(' AND ')}
      ORDER BY d.date DESC
    ''';

    final rows = await db.rawQuery(sql, args);

    double totalPurchases = 0.0;
    double totalPaid = 0.0;
    double totalRemaining = 0.0;
    int cancelledCount = 0;
    final currencies = <String>{};
    final totalsByCurrency =
        <String, ({double purchases, double paid, double remaining})>{};

    final items = <PurchaseReportItem>[];

    for (final r in rows) {
      final doc = Document.fromMap(r);
      final sName = r['supplier_name'] as String? ?? doc.recipientName;
      final sPhone = r['supplier_phone'] as String? ?? doc.recipientPhone;
      final isCancelled = doc.status == DocumentStatus.cancelled;

      currencies.add(doc.currencyCode);

      if (isCancelled) {
        cancelledCount++;
      } else {
        totalPurchases += doc.total;
        totalPaid += doc.paid;
        totalRemaining += doc.remaining;

        final prev = totalsByCurrency[doc.currencyCode] ??
            (purchases: 0.0, paid: 0.0, remaining: 0.0);
        totalsByCurrency[doc.currencyCode] = (
          purchases: prev.purchases + doc.total,
          paid: prev.paid + doc.paid,
          remaining: prev.remaining + doc.remaining,
        );
      }

      items.add(PurchaseReportItem(
        document: doc,
        supplierName: sName,
        supplierPhone: sPhone,
        netAmount: doc.total,
        paidAmount: doc.paid,
        remainingAmount: doc.remaining,
      ));
    }

    return PurchaseReportSummary(
      items: items,
      totalPurchases: totalPurchases,
      totalPaid: totalPaid,
      totalRemaining: totalRemaining,
      cancelledCount: cancelledCount,
      currencies: currencies,
      totalsByCurrency: totalsByCurrency,
    );
  }

  /// Current inventory report with stock threshold and valuation at cost.
  Future<InventoryReportSummary> getInventoryReport({
    String? category,
    String? stockStatus, // 'all', 'low_stock', 'out_of_stock', 'unvalued', 'healthy'
    String? searchQuery,
  }) async {
    final allProducts = await DatabaseHelper.instance.getAllProducts(
      activeOnly: true,
      type: 'product', // Exclude services from stock valuation and stock reports
    );

    double totalValuation = 0.0;
    int valuedCount = 0;
    int unvaluedCount = 0;
    double unvaluedQty = 0.0;
    int lowCount = 0;
    int outCount = 0;
    final unitQuantities = <String, double>{};

    final items = <InventoryReportItem>[];

    for (final p in allProducts) {
      final qty = p.stockQuantity;
      final min = p.minStock;
      final isOut = qty <= 0;
      final isLow = min > 0 && qty > 0 && qty <= min;
      final shortage = (min > 0 && qty < min) ? (min - qty) : 0.0;
      final isCostKnown = p.isCostKnown && p.averageCost != null && p.averageCost! >= 0;

      if (isOut) {
        outCount++;
      } else if (isLow) {
        lowCount++;
      }

      if (qty > 0) {
        final u = (p.unit != null && p.unit!.trim().isNotEmpty) ? p.unit!.trim() : 'قطعة';
        unitQuantities[u] = (unitQuantities[u] ?? 0.0) + qty;

        if (isCostKnown) {
          totalValuation += qty * p.averageCost!;
          valuedCount++;
        } else {
          unvaluedCount++;
          unvaluedQty += qty;
        }
      }

      final valuation = isCostKnown ? (qty > 0 ? qty * p.averageCost! : 0.0) : null;

      // Filter by category
      if (category != null && category.isNotEmpty && category != 'all') {
        if (p.category != category) continue;
      }

      // Filter by stock status
      if (stockStatus == 'low_stock' && !isLow) continue;
      if (stockStatus == 'out_of_stock' && !isOut) continue;
      if (stockStatus == 'healthy' && (isLow || isOut)) continue;
      if (stockStatus == 'unvalued' && (isCostKnown || qty <= 0)) continue;

      // Filter by search query
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchBarcode = p.barcode?.toLowerCase().contains(q) ?? false;
        final matchCode = p.code?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchBarcode && !matchCode) continue;
      }

      items.add(InventoryReportItem(
        product: p,
        stockQuantity: qty,
        minStock: min,
        averageCost: p.averageCost,
        valuationAtCost: valuation,
        isLowStock: isLow,
        isOutOfStock: isOut,
        shortageQuantity: shortage,
        isCostKnown: isCostKnown,
      ));
    }

    return InventoryReportSummary(
      items: items,
      totalValuationAtCost: totalValuation,
      valuedProductsCount: valuedCount,
      unvaluedProductsCount: unvaluedCount,
      unvaluedQuantity: unvaluedQty,
      lowStockCount: lowCount,
      outOfStockCount: outCount,
      trackedProductsCount: allProducts.length,
      unitsSummary: unitQuantities,
    );
  }

  /// Stock movement report with running balance calculation when product is selected.
  Future<StockMovementReportSummary> getStockMovementsReport({
    int? productId,
    String? type,
    DateTime? from,
    DateTime? to,
    int limit = 250,
    int offset = 0,
  }) async {
    final movements = await InventoryService.getAllMovements(
      productId: productId,
      type: type,
      fromDate: from,
      toDate: to,
      limit: limit,
      offset: offset,
    );

    double totalIn = 0.0;
    double totalOut = 0.0;
    int unvaluedCount = 0;

    for (final m in movements) {
      if (m.quantity > 0) {
        totalIn += m.quantity;
      } else {
        totalOut += m.quantity.abs();
      }
      if (m.costStatus == StockMovement.costStatusUnknown || m.unitCost == null) {
        unvaluedCount++;
      }
    }

    // Calculate running balance when a specific product is filtered
    final items = <StockMovementReportItem>[];
    if (productId != null) {
      final db = await DatabaseHelper.instance.database;
      double runningBalance = 0.0;
      if (from != null) {
        final preRows = await db.rawQuery('''
          SELECT COALESCE(SUM(quantity), 0) AS balance
          FROM stock_movements
          WHERE product_id = ? AND date < ?
        ''', [productId, from.toIso8601String()]);
        runningBalance = (preRows.first['balance'] as num?)?.toDouble() ?? 0.0;
      }

      // Movements are returned in DESC order from DB, reverse to calculate chronological running balance
      final chronological = movements.reversed.toList();
      final chronologicalItems = <StockMovementReportItem>[];

      for (final m in chronological) {
        final bBefore = runningBalance;
        runningBalance += m.quantity;
        final bAfter = runningBalance;

        chronologicalItems.add(StockMovementReportItem(
          movement: m,
          balanceBefore: bBefore,
          balanceAfter: bAfter,
          isBalanceReliable: true,
        ));
      }

      // Return items in original user-friendly descending order
      items.addAll(chronologicalItems.reversed);
    } else {
      for (final m in movements) {
        items.add(StockMovementReportItem(
          movement: m,
          balanceBefore: null,
          balanceAfter: null,
          isBalanceReliable: false,
        ));
      }
    }

    return StockMovementReportSummary(
      items: items,
      totalInQuantity: totalIn,
      totalOutQuantity: totalOut,
      unvaluedMovementsCount: unvaluedCount,
    );
  }

  /// Calculates advanced inventory analysis metrics: turnover, velocity,
  /// estimated days of stock, slow-moving items, reorder suggestions,
  /// negative margins, and category valuation concentration.
  Future<AdvancedInventoryMetrics> getAdvancedInventoryMetrics({
    required DateTime from,
    required DateTime to,
    String? category,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Fetch active products (excluding services)
    String prodWhere = "type = 'product' AND is_active = 1";
    List<Object?> prodArgs = [];
    if (category != null && category.isNotEmpty && category != 'all') {
      prodWhere += " AND category = ?";
      prodArgs.add(category);
    }
    final prodRows = await db.query(
      'products',
      where: prodWhere,
      whereArgs: prodArgs.isEmpty ? null : prodArgs,
      orderBy: 'name ASC',
    );
    final products = prodRows.map((r) => Product.fromMap(r)).toList();

    // 2. Fetch sales items in period (excluding cancelled and draft documents)
    final fromStr = from.toIso8601String();
    final toStr = to.toIso8601String();

    final salesRows = await db.rawQuery('''
      SELECT di.product_id, COALESCE(di.base_quantity, di.quantity) AS quantity, di.unit_cost, di.total_cost
      FROM document_items di
      INNER JOIN documents d ON d.id = di.document_id
      WHERE d.type = 'invoice'
        AND d.status != 'cancelled'
        AND d.status != 'draft'
        AND d.date >= ? AND d.date <= ?
    ''', [fromStr, toStr]);

    final soldQtyByProd = <int, double>{};
    double totalCogsInPeriod = 0.0;

    for (final s in salesRows) {
      final pid = s['product_id'] as int?;
      if (pid == null) continue;
      final q = (s['quantity'] as num?)?.toDouble() ?? 0.0;
      soldQtyByProd[pid] = (soldQtyByProd[pid] ?? 0.0) + q;
      final tc = (s['total_cost'] as num?)?.toDouble();
      if (tc != null) {
        totalCogsInPeriod += tc;
      }
    }

    final days = (to.difference(from).inHours / 24.0).clamp(1.0, 365.0);

    final velocityItems = <ProductVelocityItem>[];
    final slowMovingItems = <ProductVelocityItem>[];
    final negativeMarginItems = <Product>[];
    double totalStockValuation = 0.0;
    double slowMovingTiedCapital = 0.0;
    int reorderCount = 0;

    final catValuations = <String, double>{};
    final catCounts = <String, int>{};

    for (final p in products) {
      final qtySold = soldQtyByProd[p.id] ?? 0.0;
      final velocity = qtySold / days;
      final stock = p.stockQuantity;
      final avgCost = p.averageCost;
      final val = avgCost != null ? (stock * avgCost) : null;
      if (val != null && val > 0) {
        totalStockValuation += val;
      }

      // Group valuation by category
      final cat = (p.category != null && p.category!.isNotEmpty) ? p.category! : 'غير مصنف';
      if (val != null && val > 0) {
        catValuations[cat] = (catValuations[cat] ?? 0.0) + val;
      }
      catCounts[cat] = (catCounts[cat] ?? 0) + 1;

      // Estimated days remaining
      int? estDays;
      if (velocity > 0.0001 && stock > 0) {
        estDays = (stock / velocity).round();
      }

      // Reorder suggestion
      double reorderSug = 0.0;
      if (p.minStock > 0 && stock <= p.minStock) {
        reorderSug = (p.minStock - stock).clamp(0.0, double.infinity);
        reorderCount++;
      } else if (stock <= 0) {
        reorderSug = p.minStock > 0 ? p.minStock : 10.0;
        reorderCount++;
      }

      final item = ProductVelocityItem(
        product: p,
        quantitySold: qtySold,
        salesVelocity: velocity,
        estimatedDaysRemaining: estDays,
        reorderSuggestion: reorderSug,
        stockQuantity: stock,
        averageCost: avgCost,
        valuation: val,
      );

      velocityItems.add(item);

      // Slow moving: stock > 0 and 0 sales in period
      if (stock > 0 && qtySold <= 0.0001) {
        slowMovingItems.add(item);
        if (val != null && val > 0) {
          slowMovingTiedCapital += val;
        }
      }

      // Negative margin: salePrice < averageCost
      if (avgCost != null && p.salePrice < avgCost) {
        negativeMarginItems.add(p);
      }
    }

    velocityItems.sort((a, b) => b.salesVelocity.compareTo(a.salesVelocity));
    slowMovingItems.sort((a, b) => (b.valuation ?? 0.0).compareTo(a.valuation ?? 0.0));

    final turnoverRatio = totalStockValuation > 0 ? (totalCogsInPeriod / totalStockValuation) : 0.0;

    final catList = catValuations.entries.map((e) {
      final share = totalStockValuation > 0 ? (e.value / totalStockValuation) * 100.0 : 0.0;
      return CategoryValuationShare(
        category: e.key,
        valuationAtCost: e.value,
        sharePercentage: share,
        productCount: catCounts[e.key] ?? 0,
      );
    }).toList();
    catList.sort((a, b) => b.valuationAtCost.compareTo(a.valuationAtCost));

    return AdvancedInventoryMetrics(
      inventoryTurnoverRatio: turnoverRatio,
      totalTiedUpCapitalInSlowMoving: slowMovingTiedCapital,
      slowMovingCount: slowMovingItems.length,
      reorderCount: reorderCount,
      negativeMarginCount: negativeMarginItems.length,
      velocityItems: velocityItems,
      slowMovingItems: slowMovingItems,
      negativeMarginItems: negativeMarginItems,
      categoryValuations: catList,
      totalInventoryValuation: totalStockValuation,
      totalCogsInPeriod: totalCogsInPeriod,
    );
  }
}

class ProductVelocityItem {
  final Product product;
  final double quantitySold;
  final double salesVelocity;
  final int? estimatedDaysRemaining;
  final double reorderSuggestion;
  final double stockQuantity;
  final double? averageCost;
  final double? valuation;

  const ProductVelocityItem({
    required this.product,
    required this.quantitySold,
    required this.salesVelocity,
    this.estimatedDaysRemaining,
    required this.reorderSuggestion,
    required this.stockQuantity,
    this.averageCost,
    this.valuation,
  });
}

class CategoryValuationShare {
  final String category;
  final double valuationAtCost;
  final double sharePercentage;
  final int productCount;

  const CategoryValuationShare({
    required this.category,
    required this.valuationAtCost,
    required this.sharePercentage,
    required this.productCount,
  });
}

class AdvancedInventoryMetrics {
  final double inventoryTurnoverRatio;
  final double totalTiedUpCapitalInSlowMoving;
  final int slowMovingCount;
  final int reorderCount;
  final int negativeMarginCount;
  final List<ProductVelocityItem> velocityItems;
  final List<ProductVelocityItem> slowMovingItems;
  final List<Product> negativeMarginItems;
  final List<CategoryValuationShare> categoryValuations;
  final double totalInventoryValuation;
  final double totalCogsInPeriod;

  const AdvancedInventoryMetrics({
    required this.inventoryTurnoverRatio,
    required this.totalTiedUpCapitalInSlowMoving,
    required this.slowMovingCount,
    required this.reorderCount,
    required this.negativeMarginCount,
    required this.velocityItems,
    required this.slowMovingItems,
    required this.negativeMarginItems,
    required this.categoryValuations,
    required this.totalInventoryValuation,
    required this.totalCogsInPeriod,
  });
}

class _PerCurrencySales {
  double salesQty = 0.0;
  double salesRevenue = 0.0;
  double knownCogs = 0.0;
  int unknownCostSalesCount = 0;
  bool isCrossCurrencyCost = false;
  final Set<int> transactionIds = <int>{};
}

class _ProductSalesAggregator {
  double totalSalesQty = 0.0;
  final Set<int> allTransactionIds = <int>{};
  final Map<String, _PerCurrencySales> byCurrency = <String, _PerCurrencySales>{};
}

