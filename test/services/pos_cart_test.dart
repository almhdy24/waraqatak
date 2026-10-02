import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/pos_cart.dart';

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
  });
}
