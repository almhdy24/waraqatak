import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

class InventoryService {
  static Future<List<StockMovement>> getMovements(int productId) =>
      DatabaseHelper.instance.getStockMovements(productId);

  static Future<List<StockMovement>> getAllMovements({
    int? productId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
    int offset = 0,
  }) =>
      DatabaseHelper.instance.getAllStockMovements(
        productId: productId,
        type: type,
        fromDate: fromDate,
        toDate: toDate,
        limit: limit,
        offset: offset,
      );

  static Future<void> adjust({
    required int productId,
    required double delta,
    String? notes,
    String? reason,
    DateTime? date,
  }) async {
    if (delta == 0) throw ArgumentError('Delta cannot be zero');
    await DatabaseHelper.instance.adjustStock(
      productId: productId,
      delta: delta,
      notes: notes,
      reason: reason,
      date: date,
    );
  }

  static Future<List<Product>> getLowStockProducts() async {
    final all = await DatabaseHelper.instance.getAllProducts(type: 'product');
    return all
        .where((p) => p.isActive && p.minStock > 0 && p.stockQuantity <= p.minStock)
        .toList();
  }

  static Future<List<Product>> getOutOfStockProducts() async {
    final all = await DatabaseHelper.instance.getAllProducts(type: 'product');
    return all.where((p) => p.isActive && p.stockQuantity <= 0).toList();
  }
}
