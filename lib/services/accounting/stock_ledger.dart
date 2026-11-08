import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/stock_movement.dart';
import '../access/access_context.dart';
import '../access/access_guard.dart';
import '../access/permission_registry.dart';
import 'journal_writer.dart';
import 'posting_service.dart';

/// Authoritative single stock writer for Waraqatak (D4).
///
/// Every modification to `stock_movements` and `products.stock_quantity` /
/// `products.average_cost` MUST route strictly through this service.
/// Enforces physical stock balance integrity (INV-11) and inventory invariants.
class StockLedger {
  StockLedger._();

  /// The authoritative method for recording stock movements and physical stock balance changes.
  static Future<int> record(
    DatabaseExecutor txn, {
    required int productId,
    required double deltaQuantity,
    required String type,
    DateTime? date,
    int? referenceDocumentId,
    String? notes,
    double? unitCost,
    double? totalCost,
    String costStatus = StockMovement.costStatusUnknown,
    String? provenance,
    String? reason,
    int? targetMovementId,
    double? newStockQuantity,
    double? newAverageCost,
    String? newCostStatus,
    bool skipProductUpdate = false,
    bool updateAverageCost = false,
    bool strictStock = false,
  }) async {
    if (referenceDocumentId == null &&
        (type == StockMovement.typeAdjustment ||
            type == StockMovement.typeOpening)) {
      AccessGuard.require(PermissionRegistry.stockAdjust);
    }
    final movementDate = date ?? DateTime.now();

    // 1. Fetch current product state
    final pRows = await txn.query(
      'products',
      columns: ['name', 'type', 'stock_quantity', 'average_cost', 'cost_status'],
      where: 'id = ?',
      whereArgs: [productId],
    );

    if (pRows.isEmpty) {
      throw StateError('Cannot record stock movement for non-existent product ID $productId');
    }

    final pData = pRows.first;
    final currentStock = (pData['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final targetStock = newStockQuantity ?? (currentStock + deltaQuantity);

    if (strictStock && targetStock < -0.0001) {
      final name = pData['name'] as String? ?? 'Product $productId';
      throw StateError('Insufficient stock for "$name" (available: $currentStock, required: ${deltaQuantity.abs()})');
    }

    // 2. Update physical product stock and costing if applicable
    if (!skipProductUpdate) {
      final productUpdates = <String, dynamic>{
        'stock_quantity': targetStock,
      };

      if (updateAverageCost || newAverageCost != null || newCostStatus != null) {
        if (newAverageCost != null || updateAverageCost) {
          productUpdates['average_cost'] = newAverageCost;
        }
        if (newCostStatus != null) {
          productUpdates['cost_status'] = newCostStatus;
        }
      }

      await txn.update(
        'products',
        productUpdates,
        where: 'id = ?',
        whereArgs: [productId],
      );
    }

    // 3. Compute costs if missing
    final effectiveTotalCost = totalCost ??
        (unitCost != null ? deltaQuantity.abs() * unitCost : null);

    // 4. Insert authoritative stock movement record
    final movementId = await txn.insert('stock_movements', {
      'product_id': productId,
      'type': type,
      'quantity': deltaQuantity,
      'reference_document_id': referenceDocumentId,
      'date': movementDate.toIso8601String(),
      'notes': notes,
      'unit_cost': unitCost,
      'total_cost': effectiveTotalCost,
      'cost_status': costStatus,
      'provenance': provenance,
      'reason': reason,
      'target_movement_id': targetMovementId,
      'created_by': AccessContext.currentUserId,
      'origin_device_id': AccessContext.currentDeviceId,
    });

    // 5. Lock base currency if movement quantity != 0
    if (deltaQuantity != 0) {
      await txn.rawUpdate(
        'UPDATE businesses SET currency_locked_at = ? WHERE currency_locked_at IS NULL',
        [DateTime.now().toIso8601String()],
      );
    }

    // 6. Shadow posting for standalone adjustments / opening movements
    if (referenceDocumentId == null && deltaQuantity != 0) {
      final shadowEnabled = await DatabaseHelper.instance.isJournalShadowWriteEnabled(txn: txn);
      if (shadowEnabled && (type == StockMovement.typeAdjustment || type == StockMovement.typeOpening)) {
        final effectiveReason = reason ?? (type == StockMovement.typeOpening ? 'opening_stock' : (deltaQuantity > 0 ? 'count_gain' : 'count_loss'));
        final draft = PostingService.postStockAdjusted(
          productId: productId,
          quantity: deltaQuantity,
          unitCost: unitCost ?? 0.0,
          reason: effectiveReason,
          decimalDigits: 2,
          date: movementDate,
          nextEntryNo: (prefix) => '$prefix-MOV-$movementId',
          memo: notes != null && notes.isNotEmpty
              ? '$notes ($effectiveReason)'
              : 'Stock adjustment ($effectiveReason)',
          targetMovementId: targetMovementId,
        );
        if (draft != null) {
          await JournalWriter.postDraftIsolated(
            txn,
            draft,
            operation: 'stock_adjustment',
          );
        }
      }
    }

    return movementId;
  }
}
