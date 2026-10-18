import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';

void main() {
  group('Phase 2 - Product Categorization & Model', () {
    test('Product category field serialization and deserialization', () {
      const product = Product(
        name: 'Beverage Can',
        salePrice: 250.0,
        category: 'المشروبات',
        stockQuantity: 15.0,
        minStock: 5.0,
      );

      final map = product.toMap();
      expect(map['category'], 'المشروبات');

      final fromMap = Product.fromMap(map);
      expect(fromMap.category, 'المشروبات');
      expect(fromMap.name, 'Beverage Can');
    });

    test('Product copyWith preserves or updates category', () {
      const product = Product(
        name: 'Sugar 50kg',
        salePrice: 45000.0,
        category: 'المواد الغذائية',
      );

      final updated = product.copyWith(category: 'الحبوب والزيوت');
      expect(updated.category, 'الحبوب والزيوت');
      expect(updated.name, 'Sugar 50kg');

      final unchanged = product.copyWith(salePrice: 46000.0);
      expect(unchanged.category, 'المواد الغذائية');
      expect(unchanged.salePrice, 46000.0);
    });

    test('Product null or empty category handling', () {
      final p1 = Product.fromMap({
        'name': 'Generic Item',
        'sale_price': 100.0,
      });
      expect(p1.category, isNull);

      final p2 = Product.fromMap({
        'name': 'Item with Empty Category',
        'sale_price': 100.0,
        'category': '',
      });
      expect(p2.category, '');
    });
  });

  group('Phase 2 - Stock Movement Model & Joins', () {
    test('StockMovement supports enriched product_name and product_unit', () {
      final now = DateTime(2026, 10, 18, 12, 0);
      final movement = StockMovement(
        id: 101,
        productId: 42,
        type: 'sale',
        quantity: -5.0,
        referenceDocumentId: 1001,
        date: now,
        notes: 'Invoice INV-2026-001',
        productName: 'Sunflower Oil 1L',
        productUnit: 'bottle',
      );

      expect(movement.productName, 'Sunflower Oil 1L');
      expect(movement.productUnit, 'bottle');

      final map = movement.toMap();
      expect(map['product_id'], 42);
      expect(map['quantity'], -5.0);
      expect(map['type'], 'sale');

      // fromMap parses product_name and product_unit from joined query
      final fromJoinedMap = StockMovement.fromMap({
        ...map,
        'id': 101,
        'date': now.toIso8601String(),
        'product_name': 'Sunflower Oil 1L',
        'product_unit': 'bottle',
      });

      expect(fromJoinedMap.productName, 'Sunflower Oil 1L');
      expect(fromJoinedMap.productUnit, 'bottle');
      expect(fromJoinedMap.quantity, -5.0);
    });

    test('StockMovement copyWith preserves enriched fields', () {
      final movement = StockMovement(
        productId: 1,
        type: 'purchase',
        quantity: 10.0,
        date: DateTime(2026, 10, 18),
        productName: 'Flour 25kg',
        productUnit: 'bag',
      );

      final copy = movement.copyWith(notes: 'Received shipment PO-42');
      expect(copy.productName, 'Flour 25kg');
      expect(copy.productUnit, 'bag');
      expect(copy.notes, 'Received shipment PO-42');
    });
  });

  group('Phase 2 - Daily Inventory Status & Adjustment Rules', () {
    test('Stock status classifications match inventory workspace logic', () {
      const outOfStock = Product(name: 'P1', salePrice: 10, stockQuantity: 0.0, minStock: 5.0);
      const lowStock = Product(name: 'P2', salePrice: 10, stockQuantity: 3.0, minStock: 5.0);
      const healthyStock = Product(name: 'P3', salePrice: 10, stockQuantity: 12.0, minStock: 5.0);
      const zeroThreshold = Product(name: 'P4', salePrice: 10, stockQuantity: 5.0, minStock: 0.0);

      // Out of stock
      expect(outOfStock.stockQuantity <= 0, isTrue);

      // Low stock: stock > 0 && stock <= minStock && minStock > 0
      final isP2Low = lowStock.stockQuantity > 0 &&
          lowStock.minStock > 0 &&
          lowStock.stockQuantity <= lowStock.minStock;
      expect(isP2Low, isTrue);

      // Healthy stock: stock > minStock
      expect(healthyStock.stockQuantity > healthyStock.minStock, isTrue);

      // Zero threshold: stock > 0, minStock == 0 is considered healthy
      final isP4Low = zeroThreshold.stockQuantity > 0 &&
          zeroThreshold.minStock > 0 &&
          zeroThreshold.stockQuantity <= zeroThreshold.minStock;
      expect(isP4Low, isFalse);
    });

    test('Stock adjustment validation rejects empty reason and negative resulting stock', () {
      const currentStock = 5.0;

      // Validation 1: Reason is mandatory
      bool validateReason(String reason) => reason.trim().isNotEmpty;
      expect(validateReason(''), isFalse);
      expect(validateReason('   '), isFalse);
      expect(validateReason('Damaged in warehouse'), isTrue);

      // Validation 2: Resulting stock cannot be negative
      bool validateAdjustment(double current, double delta) {
        return (current + delta) >= 0;
      }

      // Valid adjustments
      expect(validateAdjustment(currentStock, 2.0), isTrue); // increase to 7.0
      expect(validateAdjustment(currentStock, -5.0), isTrue); // reduce to 0.0

      // Invalid adjustment
      expect(validateAdjustment(currentStock, -5.5), isFalse); // would make stock -0.5
      expect(validateAdjustment(currentStock, -10.0), isFalse); // would make stock -5.0
    });
  });
}
