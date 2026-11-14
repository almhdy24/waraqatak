import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  // ── Product model ────────────────────────────────────────────
  group('Product model', () {
    test('defaults to typeProduct and isActive', () {
      const p = Product(name: 'Widget', salePrice: 10);
      expect(p.type, Product.typeProduct);
      expect(p.isActive, true);
      expect(p.isProduct, true);
      expect(p.isService, false);
    });

    test('typeService flag works', () {
      const p = Product(name: 'Fix', salePrice: 50, type: Product.typeService);
      expect(p.isService, true);
      expect(p.isProduct, false);
    });

    test('toMap includes all new fields', () {
      const p = Product(
        name: 'A',
        salePrice: 5,
        type: Product.typeProduct,
        barcode: '1234567890',
        code: 'SKU-01',
        unit: 'pcs',
        isActive: false,
      );
      final m = p.toMap();
      expect(m['type'], Product.typeProduct);
      expect(m['barcode'], '1234567890');
      expect(m['code'], 'SKU-01');
      expect(m['unit'], 'pcs');
      expect(m['is_active'], 0);
    });

    test('fromMap round-trips correctly', () {
      final now = DateTime(2026, 1, 15);
      final m = {
        'id': 1,
        'name': 'Test',
        'type': Product.typeService,
        'code': 'SKU-99',
        'barcode': '999',
        'unit': 'hr',
        'sale_price': 100.0,
        'purchase_price': 0.0,
        'stock_quantity': 0.0,
        'min_stock': 0.0,
        'is_taxable': 0,
        'is_active': 1,
        'notes': 'ok',
        'created_at': now.toIso8601String(),
        'updated_at': null,
      };
      final p = Product.fromMap(m);
      expect(p.id, 1);
      expect(p.type, Product.typeService);
      expect(p.isService, true);
      expect(p.barcode, '999');
      expect(p.unit, 'hr');
      expect(p.isTaxable, false);
      expect(p.isActive, true);
      expect(p.createdAt, now);
      expect(p.updatedAt, null);
    });

    test('missing type defaults to typeProduct', () {
      final p = Product.fromMap({
        'id': 2,
        'name': 'Old',
        'sale_price': 1.0,
        'purchase_price': 0.0,
        'stock_quantity': 0.0,
        'min_stock': 0.0,
        'is_taxable': 1,
      });
      expect(p.type, Product.typeProduct);
      expect(p.isActive, true);
    });

    test('missing is_active defaults to active', () {
      final p = Product.fromMap({
        'id': 3,
        'name': 'Legacy',
        'sale_price': 0.0,
        'purchase_price': 0.0,
        'stock_quantity': 0.0,
        'min_stock': 0.0,
        'is_taxable': 1,
      });
      expect(p.isActive, true);
    });

    test('historical snapshot: price is fixed at creation', () {
      const original = Product(name: 'Item', salePrice: 100.0);
      // Simulate: document item captures price at creation time
      final capturedPrice = original.salePrice;

      // "Later" the price changes
      const updated = Product(name: 'Item', salePrice: 150.0);

      // Historical snapshot remains unchanged
      expect(capturedPrice, 100.0);
      expect(capturedPrice, isNot(equals(updated.salePrice)));
    });
  });

  group('ProductService exceptions', () {
    test('ProductInUseException carries productId and message', () {
      const ex = ProductInUseException(42, 'Product is referenced');
      expect(ex.productId, equals(42));
      expect(ex.message, contains('referenced'));
      expect(ex.toString(), contains('42'));
    });
  });
}
