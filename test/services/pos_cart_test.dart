import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/product_unit.dart';
import 'package:warqatek/services/pos_cart.dart';
import 'package:warqatek/utils/format_utils.dart';

void main() {
  const pen = Product(id: 1, name: 'قلم', salePrice: 500, stockQuantity: 3);
  const book = Product(id: 2, name: 'كتاب', salePrice: 2000, stockQuantity: 10, isTaxable: false);
  const repair = Product(id: 3, name: 'صيانة', salePrice: 1500, type: Product.typeService);

  group('PosCart', () {
    test('adding the same product increments one line', () {
      final c = PosCart()..add(pen)..add(pen);
      expect(c.lines, hasLength(1));
      expect(c.lines.single.quantity, 2);
      expect(c.subtotal, 1000);
    });

    test('cannot exceed stock of a stocked product', () {
      final c = PosCart();
      expect(c.add(pen, quantity: 3), isNull);
      expect(c.add(pen), PosCartError.outOfStock);
      expect(c.quantityOf(1), 3);
      expect(c.setQuantity(0, 4), PosCartError.outOfStock);
      expect(c.lines.single.quantity, 3);
    });

    test('services have no stock limit', () {
      final c = PosCart();
      expect(c.add(repair, quantity: 50), isNull);
      expect(c.subtotal, 75000);
    });

    test('quantity zero removes the line and discount stays within subtotal', () {
      final c = PosCart()..add(pen)..add(book);
      c.discount = 2400;
      expect(c.discount, 2400);
      c.setQuantity(1, 0); // remove book -> subtotal 500
      expect(c.lines, hasLength(1));
      expect(c.discount, 500);
      c.discount = -5;
      expect(c.discount, 0);
    });

    test('item inputs mirror the invoice screen', () {
      final c = PosCart()..add(book, quantity: 2);
      final i = c.toItemInputs().single;
      expect(i.productId, 2);
      expect(i.description, 'كتاب');
      expect(i.price, 2000);
      expect(i.quantity, 2);
      expect(i.taxable, isFalse);
    });

    test('totals use invoice rules (tax on taxable items only)', () {
      final c = PosCart()..add(pen, quantity: 2)..add(book);
      final t = c.totals(taxRate: 10, pricesIncludeTax: false);
      expect(t.subtotal, 3000);
      expect(t.taxAmount, closeTo(100, 0.001)); // 10% of the 1000 taxable
      expect(t.total, closeTo(3100, 0.001));
    });

    test('change is never negative', () {
      expect(PosCart.changeFor(total: 3100, received: 5000), 1900);
      expect(PosCart.changeFor(total: 3100, received: 3000), 0);
    });

    test('clear resets lines and discount', () {
      final c = PosCart()..add(pen);
      c.discount = 100;
      c.clear();
      expect(c.isEmpty, isTrue);
      expect(c.discount, 0);
    });

    test('direct decimal quantity input preserves precision and totals', () {
      final c = PosCart();
      // Add fractional quantity 0.125
      expect(c.add(pen, quantity: 0.125), isNull);
      expect(c.lines.single.quantity, 0.125);
      expect(c.subtotal, 62.5); // 0.125 * 500 = 62.5

      // Update to 2.5
      expect(c.setQuantity(0, 2.5), isNull);
      expect(c.lines.single.quantity, 2.5);
      expect(c.subtotal, 1250); // 2.5 * 500 = 1250

      // Exceeding remaining stock with decimal (stock is 3, set to 3.1)
      expect(c.setQuantity(0, 3.1), PosCartError.outOfStock);
      expect(c.lines.single.quantity, 2.5);

      // Setting exactly to remaining stock
      expect(c.setQuantity(0, 3.0), isNull);
      expect(c.lines.single.quantity, 3.0);
    });

    test('decimal quantity with unit conversion respects base stock', () {
      // Product with stock 30
      const bulkItem = Product(id: 10, name: 'سكر', salePrice: 100, stockQuantity: 30);
      const sackUnit = ProductUnit(id: 1, productId: 10, unitName: 'شوال', conversionFactor: 10, salePrice: 950);

      final c = PosCart();
      // Add 2.5 sacks = 25 units in base stock
      expect(c.add(bulkItem, quantity: 2.5, unit: sackUnit), isNull);
      expect(c.lines.single.quantity, 2.5);
      expect(c.lines.single.baseQuantity, 25.0);
      expect(c.baseQuantityOf(10), 25.0);

      // Adding another 0.6 sacks = 6 units (total 31 > 30) -> out of stock
      expect(c.add(bulkItem, quantity: 0.6, unit: sackUnit), PosCartError.outOfStock);

      // Adding 0.5 sacks = 5 units (total 30 == 30) -> succeeds
      expect(c.add(bulkItem, quantity: 0.5, unit: sackUnit), isNull);
      expect(c.lines.single.quantity, 3.0);
      expect(c.lines.single.baseQuantity, 30.0);
    });

    test('FormatUtils.parseQuantity handles decimals and locale separators', () {
      expect(FormatUtils.parseQuantity('44.5'), 44.5);
      expect(FormatUtils.parseQuantity('25,25'), 25.25);
      expect(FormatUtils.parseQuantity('0،125'), 0.125);
      expect(FormatUtils.parseQuantity('  100.50  '), 100.5);
      expect(FormatUtils.parseQuantity(''), isNull);
      expect(FormatUtils.parseQuantity(null), isNull);
      expect(FormatUtils.parseQuantity('abc'), isNull);
    });

    test('B2-5: setDecimalDigits(3) gives subtotal 0.334 for qty=1 price=0.3336', () {
      const item = Product(id: 99, name: 'ثلاثة أرقام', salePrice: 0.3336, type: Product.typeService);
      final c = PosCart()
        ..setDecimalDigits(3)
        ..add(item);
      expect(c.subtotal, closeTo(0.334, 0.0001));
    });

    test('B2-6: floating point tolerance in stock checks (0.3 total stock)', () {
      const p = Product(id: 50, name: 'تفاح', salePrice: 10, stockQuantity: 0.3);
      final c = PosCart();
      expect(c.add(p, quantity: 0.1), isNull, reason: 'first 0.1 should fit');
      expect(c.add(p, quantity: 0.2), isNull, reason: '0.1+0.2 ≈ 0.3 should fit within tolerance');
      expect(c.add(p, quantity: 0.4), PosCartError.outOfStock);
    });
  });
}
