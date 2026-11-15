import '../database/database_helper.dart';
import '../models/stocktake.dart';
import 'access/access_guard.dart';
import 'access/permission_registry.dart';
import 'analytics/analytics_service.dart';

class StocktakeReviewItem {
  final StocktakeItem item;
  final double currentLiveStock;
  final bool hasInterimMovement;
  final double? liveVariance;
  final double? valuationImpact;

  const StocktakeReviewItem({
    required this.item,
    required this.currentLiveStock,
    required this.hasInterimMovement,
    this.liveVariance,
    this.valuationImpact,
  });
}

class StocktakeReviewSummary {
  final StocktakeSession session;
  final List<StocktakeReviewItem> items;
  final int totalCounted;
  final int totalUncounted;
  final int matchedCount;
  final int discrepantCount;
  final bool hasInterimMovements;
  final double netValuationImpact;

  const StocktakeReviewSummary({
    required this.session,
    required this.items,
    required this.totalCounted,
    required this.totalUncounted,
    required this.matchedCount,
    required this.discrepantCount,
    required this.hasInterimMovements,
    required this.netValuationImpact,
  });
}

class StocktakeService {
  StocktakeService._();
  static final StocktakeService instance = StocktakeService._();

  Future<StocktakeSession> startSession({
    String? categoryFilter,
    String? notes,
  }) async {
    AccessGuard.require(PermissionRegistry.stocktakeManage);
    return DatabaseHelper.instance.createStocktakeSession(
      categoryFilter: categoryFilter,
      notes: notes,
    );
  }

  Future<StocktakeSession?> getSession(int id) async {
    return DatabaseHelper.instance.getStocktakeSession(id);
  }

  Future<List<StocktakeSession>> getAllSessions({int limit = 50}) async {
    return DatabaseHelper.instance.getAllStocktakeSessions(limit: limit);
  }

  Future<List<StocktakeItem>> getItems(int sessionId) async {
    return DatabaseHelper.instance.getStocktakeItems(sessionId);
  }

  Future<int> recordCount(
    int itemId,
    double? countedQuantity, {
    String? notes,
  }) async {
    AccessGuard.require(PermissionRegistry.stocktakeManage);
    if (countedQuantity != null &&
        (countedQuantity.isNaN ||
            countedQuantity.isInfinite ||
            countedQuantity < 0)) {
      throw ArgumentError('Invalid counted quantity: $countedQuantity');
    }
    return DatabaseHelper.instance.updateStocktakeItemCount(
      itemId,
      countedQuantity,
      notes: notes,
    );
  }

  Future<StocktakeReviewSummary> reviewSession(int sessionId) async {
    final session = await DatabaseHelper.instance.getStocktakeSession(
      sessionId,
    );
    if (session == null) {
      throw StateError('Stocktake session $sessionId not found');
    }

    final items = await DatabaseHelper.instance.getStocktakeItems(sessionId);
    final db = await DatabaseHelper.instance.database;

    // Batch-fetch current stock balances and costs to eliminate N+1 queries
    final productIds = items.map((it) => it.productId).toSet().toList();
    final productMap = <int, Map<String, dynamic>>{};
    const chunkSize = 500;
    for (var i = 0; i < productIds.length; i += chunkSize) {
      final chunk = productIds.sublist(
        i,
        i + chunkSize > productIds.length ? productIds.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.query(
        'products',
        columns: ['id', 'stock_quantity', 'average_cost', 'purchase_price'],
        where: 'id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final r in rows) {
        productMap[r['id'] as int] = r;
      }
    }

    final reviewItems = <StocktakeReviewItem>[];
    int counted = 0;
    int uncounted = 0;
    int matched = 0;
    int discrepant = 0;
    bool anyInterimMovement = false;
    double netValuation = 0.0;

    for (final it in items) {
      final prod = productMap[it.productId];
      final liveStock = prod != null
          ? (prod['stock_quantity'] as num?)?.toDouble() ?? 0.0
          : it.baselineQuantity;

      // Robust cost fallback: average_cost -> purchase_price -> item unitCost
      double? effectiveCost = prod != null
          ? (prod['average_cost'] as num?)?.toDouble()
          : null;
      if (effectiveCost == null || effectiveCost <= 0) {
        effectiveCost = prod != null
            ? (prod['purchase_price'] as num?)?.toDouble()
            : null;
      }
      if (effectiveCost == null || effectiveCost <= 0) {
        effectiveCost = it.unitCost;
      }
      if (effectiveCost != null && effectiveCost <= 0) {
        effectiveCost = null;
      }

      final hasInterim = (liveStock - it.baselineQuantity).abs() > 0.0001;
      if (hasInterim) anyInterimMovement = true;

      if (!it.isCounted) {
        uncounted++;
        reviewItems.add(
          StocktakeReviewItem(
            item: it,
            currentLiveStock: liveStock,
            hasInterimMovement: hasInterim,
            liveVariance: null,
            valuationImpact: null,
          ),
        );
      } else {
        counted++;
        final variance = it.countedQuantity! - liveStock;
        final valImpact = effectiveCost != null
            ? (variance * effectiveCost)
            : null;
        if (valImpact != null) netValuation += valImpact;

        if (variance.abs() < 0.0001) {
          matched++;
        } else {
          discrepant++;
        }

        reviewItems.add(
          StocktakeReviewItem(
            item: it,
            currentLiveStock: liveStock,
            hasInterimMovement: hasInterim,
            liveVariance: variance,
            valuationImpact: valImpact,
          ),
        );
      }
    }

    return StocktakeReviewSummary(
      session: session,
      items: reviewItems,
      totalCounted: counted,
      totalUncounted: uncounted,
      matchedCount: matched,
      discrepantCount: discrepant,
      hasInterimMovements: anyInterimMovement,
      netValuationImpact: netValuation,
    );
  }

  Future<Map<String, dynamic>> finalizeSession(
    int sessionId, {
    String? notes,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      throw ArgumentError('Confirmation is required to finalize stocktake');
    }
    AccessGuard.require(PermissionRegistry.stocktakeFinalize);
    AccessGuard.require(PermissionRegistry.stockAdjust);
    final result = await DatabaseHelper.instance.finalizeStocktakeSession(
      sessionId,
      notes: notes,
    );
    try {
      AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
    } catch (_) {}
    return result;
  }

  Future<void> cancelSession(int sessionId) async {
    AccessGuard.require(PermissionRegistry.stocktakeManage);
    return DatabaseHelper.instance.cancelStocktakeSession(sessionId);
  }
}
