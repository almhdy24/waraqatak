import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/document.dart';
import '../models/document_status.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

/// Summary of current inventory valuation at cost.
class InventoryValuationSummary {
  final double totalValuationAtCost;
  final int valuedProductsCount;
  final int unvaluedProductsCount;
  final double unvaluedQuantity;
  final int totalTrackedProducts;

  const InventoryValuationSummary({
    required this.totalValuationAtCost,
    required this.valuedProductsCount,
    required this.unvaluedProductsCount,
    required this.unvaluedQuantity,
    required this.totalTrackedProducts,
  });
}

/// Product profit metrics for a reporting period.
class ProductProfitItem {
  final int productId;
  final String productName;
  final String? productUnit;
  final double currentStock;
  final double? averageCost;
  final bool isCostKnown;
  final double salesQty;
  final double salesRevenue;
  final double cogs;
  final double grossProfit;
  final double profitMargin; // percentage 0..100
  final bool isCostReliable;
  final int unknownCostSalesCount;

  const ProductProfitItem({
    required this.productId,
    required this.productName,
    this.productUnit,
    required this.currentStock,
    this.averageCost,
    required this.isCostKnown,
    required this.salesQty,
    required this.salesRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.profitMargin,
    required this.isCostReliable,
    required this.unknownCostSalesCount,
  });

  /// Gross profit only when cost is fully known; null otherwise.
  double? get trustedGrossProfit => isCostReliable ? grossProfit : null;

  /// Profit margin only when cost is fully known; null otherwise.
  double? get trustedProfitMargin => isCostReliable ? profitMargin : null;
}

/// Sales document with recognized revenue, COGS, and gross profit.
class SaleProfitSummary {
  final Document document;
  final double recognizedRevenue;
  final double cogs;

  /// Partial gross profit (revenue minus known COGS).
  ///
  /// When [isCostReliable] is false this figure is understated because some
  /// item costs were unknown and excluded from [cogs].  Callers MUST check
  /// [isCostReliable] before treating this as a definitive profit figure.
  ///
  /// Use [trustedGrossProfit] when you need a value safe for aggregation.
  final double grossProfit;
  final double profitMargin;
  final bool isCostReliable;

  const SaleProfitSummary({
    required this.document,
    required this.recognizedRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.profitMargin,
    required this.isCostReliable,
  });

  /// Gross profit only when cost is fully known; null otherwise.
  ///
  /// Safe to use in aggregate sums — unreliable invoices contribute nothing
  /// rather than an overstated zero-cost profit figure.
  double? get trustedGrossProfit => isCostReliable ? grossProfit : null;

  /// Profit margin only when cost is fully known; null otherwise.
  double? get trustedProfitMargin => isCostReliable ? profitMargin : null;
}

/// Summary of legacy cost migration and status.
class LegacyCostSummary {
  final int knownMovements;
  final int reconstructedMovements;
  final int unknownMovements;
  final int knownProducts;
  final int unknownProducts;

  const LegacyCostSummary({
    required this.knownMovements,
    required this.reconstructedMovements,
    required this.unknownMovements,
    required this.knownProducts,
    required this.unknownProducts,
  });
}

/// Central service for Perpetual Moving Weighted-Average Inventory Costing
/// and Gross Profit calculations.
class InventoryCostingService {
  InventoryCostingService._();
  static final InventoryCostingService instance = InventoryCostingService._();

  /// Calculates the new perpetual moving weighted-average cost.
  ///
  /// If [currentStock] <= 0 or [currentAvgCost] is null, the incoming cost
  /// sets the new cost basis directly.
  static double calculateNewWeightedAverage({
    required double currentStock,
    required double? currentAvgCost,
    required double incomingQty,
    required double incomingUnitCost,
  }) {
    if (incomingQty <= 0) return currentAvgCost ?? incomingUnitCost;
    if (currentStock <= 0 || currentAvgCost == null) {
      return incomingUnitCost;
    }
    final currentValue = currentStock * currentAvgCost;
    final incomingValue = incomingQty * incomingUnitCost;
    final newStock = currentStock + incomingQty;
    if (newStock <= 0) return incomingUnitCost;
    return (currentValue + incomingValue) / newStock;
  }

  /// Hook called when a product is created with opening stock.
  static Future<void> onProductCreatedWithStock(
    DatabaseExecutor txn, {
    required int productId,
    required double openingStock,
    required double purchasePrice,
    DateTime? date,
  }) async {
    if (openingStock <= 0) return;
    final hasKnownPrice = purchasePrice > 0;
    final avgCost = hasKnownPrice ? purchasePrice : null;
    final costStatus = hasKnownPrice
        ? StockMovement.costStatusKnown
        : StockMovement.costStatusUnknown;

    await txn.update(
      'products',
      {'average_cost': avgCost, 'cost_status': costStatus},
      where: 'id = ?',
      whereArgs: [productId],
    );

    await txn.insert('stock_movements', {
      'product_id': productId,
      'type': StockMovement.typeOpening,
      'quantity': openingStock,
      'reference_document_id': null,
      'date': (date ?? DateTime.now()).toIso8601String(),
      'notes': null,
      'unit_cost': avgCost,
      'total_cost': hasKnownPrice ? openingStock * purchasePrice : null,
      'cost_status': costStatus,
      'provenance': 'opening_stock',
    });
  }

  /// Hook called when a manual stock adjustment is recorded.
  static Future<void> onStockAdjusted(
    DatabaseExecutor txn, {
    required int productId,
    required double delta,
    String? notes,
    DateTime? date,
  }) async {
    final pRows = await txn.query(
      'products',
      columns: ['stock_quantity', 'average_cost', 'cost_status'],
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (pRows.isEmpty) throw StateError('Product not found: $productId');

    final currentStock =
        (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final avgCost = (pRows.first['average_cost'] as num?)?.toDouble();
    final costStatus =
        pRows.first['cost_status'] as String? ??
        StockMovement.costStatusUnknown;

    if (delta < 0 && (currentStock + delta) < -0.0001) {
      throw StateError('Stock cannot be negative');
    }

    final newStock = currentStock + delta;
    await txn.update(
      'products',
      {'stock_quantity': newStock},
      where: 'id = ?',
      whereArgs: [productId],
    );

    final isCostKnown =
        costStatus == StockMovement.costStatusKnown && avgCost != null;
    final unitCost = isCostKnown ? avgCost : null;
    final totalCost = isCostKnown ? delta.abs() * avgCost : null;

    await txn.insert('stock_movements', {
      'product_id': productId,
      'type': StockMovement.typeAdjustment,
      'quantity': delta,
      'reference_document_id': null,
      'date': (date ?? DateTime.now()).toIso8601String(),
      'notes': notes,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'cost_status': isCostKnown
          ? StockMovement.costStatusKnown
          : StockMovement.costStatusUnknown,
      'provenance': 'manual_adjustment',
    });
  }

  /// Reconciles the cost basis for a product (e.g. legacy products with unknown cost).
  static Future<void> reconcileProductCost(
    DatabaseExecutor txn, {
    required int productId,
    required double newUnitCost,
    String? notes,
  }) async {
    final pRows = await txn.query(
      'products',
      columns: ['stock_quantity', 'name'],
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (pRows.isEmpty) throw StateError('Product not found: $productId');

    final stock = (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final name = pRows.first['name'] as String? ?? '';

    await txn.update(
      'products',
      {
        'average_cost': newUnitCost,
        'cost_status': Product.costStatusKnown,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );

    // Audit log event
    await txn.insert('audit_log', {
      'action': 'cost_reconciled',
      'entity_type': 'product',
      'entity_id': productId,
      'details':
          'product="$name" new_cost=$newUnitCost stock=$stock${notes != null ? " reason=$notes" : ""}',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Returns overall inventory valuation at cost.
  Future<InventoryValuationSummary> getInventoryValuationSummary() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        id,
        stock_quantity,
        average_cost,
        cost_status
      FROM products
      WHERE is_active = 1 AND type = 'product'
    ''');

    double totalValuation = 0.0;
    int valuedCount = 0;
    int unvaluedCount = 0;
    double unvaluedQuantity = 0.0;

    for (final r in rows) {
      final qty = (r['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      final avgCost = (r['average_cost'] as num?)?.toDouble();
      final status = r['cost_status'] as String? ?? Product.costStatusUnknown;

      if (qty > 0) {
        if (status == Product.costStatusKnown &&
            avgCost != null &&
            avgCost >= 0) {
          totalValuation += qty * avgCost;
          valuedCount++;
        } else {
          unvaluedCount++;
          unvaluedQuantity += qty;
        }
      }
    }

    return InventoryValuationSummary(
      totalValuationAtCost: totalValuation,
      valuedProductsCount: valuedCount,
      unvaluedProductsCount: unvaluedCount,
      unvaluedQuantity: unvaluedQuantity,
      totalTrackedProducts: rows.length,
    );
  }

  /// Generates product profit report in a given period.
  Future<List<ProductProfitItem>> getProductProfitReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        p.id,
        p.name,
        p.unit,
        p.stock_quantity,
        p.average_cost,
        p.cost_status,
        COALESCE(SUM(CASE WHEN d.type = 'invoice' THEN di.quantity ELSE 0 END), 0) AS sales_qty,
        COALESCE(SUM(CASE WHEN d.type = 'invoice' THEN di.total ELSE 0 END), 0) AS sales_revenue,
        COALESCE(SUM(CASE WHEN d.type = 'invoice' AND di.total_cost IS NOT NULL THEN di.total_cost ELSE 0 END), 0) AS known_cogs,
        COUNT(CASE WHEN d.type = 'invoice' AND di.quantity > 0 AND di.total_cost IS NULL THEN 1 END) AS unknown_cost_sales_count
      FROM products p
      LEFT JOIN document_items di ON di.product_id = p.id
      LEFT JOIN documents d ON d.id = di.document_id
        AND d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
        AND d.date >= ? AND d.date <= ?
      WHERE p.is_active = 1
      GROUP BY p.id
      ORDER BY sales_revenue DESC, p.name
    ''',
      [from.toIso8601String(), to.toIso8601String()],
    );

    return rows.map((r) {
      final salesQty = (r['sales_qty'] as num?)?.toDouble() ?? 0.0;
      final revenue = (r['sales_revenue'] as num?)?.toDouble() ?? 0.0;
      final cogs = (r['known_cogs'] as num?)?.toDouble() ?? 0.0;
      final unknownCount =
          (r['unknown_cost_sales_count'] as num?)?.toInt() ?? 0;
      final isReliable = unknownCount == 0;
      final grossProfit = revenue - cogs;
      // Show partial margin even when unreliable so callers can disclose it;
      // isCostReliable=false signals that the cost figure is incomplete.
      final margin = revenue > 0 ? (grossProfit / revenue) * 100 : 0.0;

      return ProductProfitItem(
        productId: (r['id'] as num).toInt(),
        productName: r['name'] as String? ?? '',
        productUnit: r['unit'] as String?,
        currentStock: (r['stock_quantity'] as num?)?.toDouble() ?? 0.0,
        averageCost: (r['average_cost'] as num?)?.toDouble(),
        isCostKnown:
            r['cost_status'] == Product.costStatusKnown &&
            r['average_cost'] != null,
        salesQty: salesQty,
        salesRevenue: revenue,
        cogs: cogs,
        grossProfit: grossProfit,
        profitMargin: margin,
        isCostReliable: isReliable,
        unknownCostSalesCount: unknownCount,
      );
    }).toList();
  }

  /// Generates sales document profit report in a given period.
  Future<List<SaleProfitSummary>> getSalesReportWithCost({
    required DateTime from,
    required DateTime to,
    bool includeCancelled = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final where = includeCancelled
        ? 'type = ? AND date >= ? AND date <= ?'
        : 'type = ? AND status != ? AND date >= ? AND date <= ?';
    final whereArgs = includeCancelled
        ? ['invoice', from.toIso8601String(), to.toIso8601String()]
        : [
            'invoice',
            DocumentStatus.cancelled,
            from.toIso8601String(),
            to.toIso8601String(),
          ];

    final docMaps = await db.query(
      'documents',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );

    final results = <SaleProfitSummary>[];
    for (final docMap in docMaps) {
      final doc = Document.fromMap(docMap);
      if (doc.status == DocumentStatus.cancelled) {
        results.add(
          SaleProfitSummary(
            document: doc,
            recognizedRevenue: 0.0,
            cogs: 0.0,
            grossProfit: 0.0,
            profitMargin: 0.0,
            isCostReliable: true,
          ),
        );
        continue;
      }
      final itemRows = await db.query(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [doc.id],
      );

      double docCogs = 0.0;
      bool isReliable = true;

      for (final item in itemRows) {
        final pid = item['product_id'] as int?;
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final totalCost = (item['total_cost'] as num?)?.toDouble();

        if (pid != null && qty > 0) {
          if (totalCost != null) {
            docCogs += totalCost;
          } else {
            isReliable = false;
          }
        }
      }

      // Recognized net revenue (subtotal minus discount)
      final recognizedRevenue = doc.subtotal - doc.discount;
      final grossProfit = recognizedRevenue - docCogs;
      final margin = recognizedRevenue > 0
          ? (grossProfit / recognizedRevenue) * 100
          : 0.0;

      results.add(
        SaleProfitSummary(
          document: doc,
          recognizedRevenue: recognizedRevenue,
          cogs: docCogs,
          grossProfit: grossProfit,
          profitMargin: margin,
          isCostReliable: isReliable,
        ),
      );
    }

    return results;
  }

  /// Queries the count of movements and products by cost status.
  Future<LegacyCostSummary> getLegacyCostSummary() async {
    final db = await DatabaseHelper.instance.database;

    final mKnown =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM stock_movements WHERE cost_status = '${StockMovement.costStatusKnown}'",
          ),
        ) ??
        0;

    final mReconstructed =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM stock_movements WHERE cost_status = '${StockMovement.costStatusReconstructed}'",
          ),
        ) ??
        0;

    final mUnknown =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM stock_movements WHERE cost_status = '${StockMovement.costStatusUnknown}' OR cost_status IS NULL",
          ),
        ) ??
        0;

    final pKnown =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM products WHERE cost_status = '${Product.costStatusKnown}'",
          ),
        ) ??
        0;

    final pUnknown =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM products WHERE cost_status != '${Product.costStatusKnown}' OR cost_status IS NULL",
          ),
        ) ??
        0;

    return LegacyCostSummary(
      knownMovements: mKnown,
      reconstructedMovements: mReconstructed,
      unknownMovements: mUnknown,
      knownProducts: pKnown,
      unknownProducts: pUnknown,
    );
  }
}
