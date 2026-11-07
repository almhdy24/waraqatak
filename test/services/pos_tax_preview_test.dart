import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/tax_profile.dart';
import 'package:warqatek/services/pos_cart.dart';

void main() {
  group('PosCart Tax Preview Parity (Pure Unit Tests - Fact B4)', () {
    const profile5Pct = TaxProfile(
      id: 101,
      name: 'Reduced VAT 5%',
      rate: 5.0,
      isActive: true,
    );

    const profileInactive = TaxProfile(
      id: 102,
      name: 'Legacy 8%',
      rate: 8.0,
      isActive: false,
    );

    final taxProfilesMap = {101: profile5Pct, 102: profileInactive};

    test(
      '1. Fact B4 scenario: product with active 5% profile against 15% business rate -> POS preview is 105 (not 115)',
      () {
        final cart = PosCart();
        cart.setDecimalDigits(2);
        cart.setTaxConfiguration(
          taxesEnabled: true,
          businessTaxRate: 15.0,
          taxProfiles: taxProfilesMap,
        );

        const productWith5Pct = Product(
          id: 1,
          name: 'Medicine',
          salePrice: 100.0,
          stockQuantity: 100.0,
          taxProfileId: 101,
          isTaxable: true,
        );

        cart.add(productWith5Pct, quantity: 1);

        final totals = cart.totals(
          taxRate: 15.0,
          pricesIncludeTax: false,
          taxesEnabled: true,
        );

        expect(totals.subtotal, equals(100.0));
        expect(totals.taxAmount, equals(5.0));
        expect(totals.total, equals(105.0));

        final items = cart.toItemInputs();
        expect(items.first.taxRate, equals(5.0));
        expect(items.first.taxable, isTrue);
      },
    );

    test(
      '2. Non-taxable product resolves line tax to 0.0 regardless of business rate',
      () {
        final cart = PosCart();
        cart.setTaxConfiguration(
          taxesEnabled: true,
          businessTaxRate: 15.0,
          taxProfiles: taxProfilesMap,
        );

        const nonTaxableProduct = Product(
          id: 2,
          name: 'Bread',
          salePrice: 100.0,
          stockQuantity: 100.0,
          isTaxable: false,
        );

        cart.add(nonTaxableProduct, quantity: 1);

        final totals = cart.totals(
          taxRate: 15.0,
          pricesIncludeTax: false,
          taxesEnabled: true,
        );

        expect(totals.subtotal, equals(100.0));
        expect(totals.taxAmount, equals(0.0));
        expect(totals.total, equals(100.0));

        final items = cart.toItemInputs();
        expect(items.first.taxRate, equals(0.0));
        expect(items.first.taxable, isFalse);
      },
    );

    test('3. Taxes disabled resolves all line taxes to 0.0', () {
      final cart = PosCart();
      cart.setTaxConfiguration(
        taxesEnabled: false,
        businessTaxRate: 15.0,
        taxProfiles: taxProfilesMap,
      );

      const product = Product(
        id: 3,
        name: 'Product A',
        salePrice: 100.0,
        stockQuantity: 100.0,
        taxProfileId: 101,
        isTaxable: true,
      );

      cart.add(product, quantity: 1);

      final totals = cart.totals(
        taxRate: 15.0,
        pricesIncludeTax: false,
        taxesEnabled: false,
      );

      expect(totals.subtotal, equals(100.0));
      expect(totals.taxAmount, equals(0.0));
      expect(totals.total, equals(100.0));

      final items = cart.toItemInputs();
      expect(items.first.taxRate, equals(0.0));
      expect(items.first.taxable, isFalse);
    });

    test('4. Inactive tax profile falls back to business default tax rate', () {
      final cart = PosCart();
      cart.setTaxConfiguration(
        taxesEnabled: true,
        businessTaxRate: 15.0,
        taxProfiles: taxProfilesMap,
      );

      const productWithInactive = Product(
        id: 4,
        name: 'Product Inactive',
        salePrice: 100.0,
        stockQuantity: 100.0,
        taxProfileId: 102, // inactive
        isTaxable: true,
      );

      cart.add(productWithInactive, quantity: 1);

      final totals = cart.totals(
        taxRate: 15.0,
        pricesIncludeTax: false,
        taxesEnabled: true,
      );

      expect(totals.subtotal, equals(100.0));
      expect(totals.taxAmount, equals(15.0));
      expect(totals.total, equals(115.0));

      final items = cart.toItemInputs();
      expect(items.first.taxRate, equals(15.0));
      expect(items.first.taxable, isTrue);
    });

    test(
      '5. Product without tax profile falls back to business default tax rate',
      () {
        final cart = PosCart();
        cart.setTaxConfiguration(
          taxesEnabled: true,
          businessTaxRate: 15.0,
          taxProfiles: taxProfilesMap,
        );

        const standardProduct = Product(
          id: 5,
          name: 'Standard Product',
          salePrice: 100.0,
          stockQuantity: 100.0,
          isTaxable: true,
        );

        cart.add(standardProduct, quantity: 1);

        final totals = cart.totals(
          taxRate: 15.0,
          pricesIncludeTax: false,
          taxesEnabled: true,
        );

        expect(totals.subtotal, equals(100.0));
        expect(totals.taxAmount, equals(15.0));
        expect(totals.total, equals(115.0));

        final items = cart.toItemInputs();
        expect(items.first.taxRate, equals(15.0));
        expect(items.first.taxable, isTrue);
      },
    );

    test(
      '6. Mixed cart with multiple tax profiles and fallbacks calculates accurately',
      () {
        final cart = PosCart();
        cart.setTaxConfiguration(
          taxesEnabled: true,
          businessTaxRate: 15.0,
          taxProfiles: taxProfilesMap,
        );

        // Line 1: 100 @ 5% profile -> tax 5
        cart.add(
          const Product(
            id: 1,
            name: 'Item 5%',
            salePrice: 100.0,
            stockQuantity: 100.0,
            taxProfileId: 101,
            isTaxable: true,
          ),
        );

        // Line 2: 200 non-taxable -> tax 0
        cart.add(
          const Product(
            id: 2,
            name: 'Item 0%',
            salePrice: 200.0,
            stockQuantity: 100.0,
            isTaxable: false,
          ),
        );

        // Line 3: 300 fallback 15% -> tax 45
        cart.add(
          const Product(
            id: 3,
            name: 'Item 15%',
            salePrice: 300.0,
            stockQuantity: 100.0,
            isTaxable: true,
          ),
        );

        final totals = cart.totals(
          taxRate: 15.0,
          pricesIncludeTax: false,
          taxesEnabled: true,
        );

        expect(totals.subtotal, equals(600.0));
        expect(totals.taxAmount, equals(50.0)); // 5 + 0 + 45
        expect(totals.total, equals(650.0));
      },
    );

    test('7. Inclusive tax mode extracts tax embedded in price', () {
      final cart = PosCart();
      cart.setTaxConfiguration(
        taxesEnabled: true,
        businessTaxRate: 15.0,
        taxProfiles: taxProfilesMap,
      );

      cart.add(
        const Product(
          id: 1,
          name: 'Item 5%',
          salePrice: 105.0,
          stockQuantity: 100.0,
          taxProfileId: 101, // 5%
          isTaxable: true,
        ),
      );

      final totals = cart.totals(
        taxRate: 15.0,
        pricesIncludeTax: true,
        taxesEnabled: true,
      );

      expect(totals.subtotal, equals(105.0));
      expect(totals.total, equals(105.0));
      // In inclusive mode: tax = 105 * 5 / 105 = 5.0
      expect(totals.taxAmount, equals(5.0));
    });
  });
}
