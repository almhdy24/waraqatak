import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/tax_profile.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  // ── TaxProfile model ──────────────────────────────────────────
  group('TaxProfile model', () {
    test('defaults to exclusive mode', () {
      const p = TaxProfile(name: 'VAT', rate: 15);
      expect(p.calculationMode, TaxProfile.modeExclusive);
    });

    test('fromMap / toMap round-trip', () {
      const p = TaxProfile(
        id: 1,
        name: 'Service Charge',
        type: 'service_charge',
        rate: 10,
        isActive: true,
        isDefault: true,
        calculationMode: TaxProfile.modeInclusive,
        notes: 'Applied to services',
      );
      final map = p.toMap();
      final p2 = TaxProfile.fromMap(map);
      expect(p2.name, p.name);
      expect(p2.rate, p.rate);
      expect(p2.calculationMode, TaxProfile.modeInclusive);
      expect(p2.isDefault, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const p = TaxProfile(name: 'VAT', rate: 15);
      final p2 = p.copyWith(rate: 20);
      expect(p2.name, 'VAT');
      expect(p2.rate, 20);
      expect(p2.calculationMode, TaxProfile.modeExclusive);
    });

    test('rate can be 0 (tax-exempt profile)', () {
      const p = TaxProfile(name: 'Exempt', rate: 0);
      expect(p.rate, 0.0);
    });
  });

  // ── Exclusive tax calculation ─────────────────────────────────
  group('Exclusive tax (added on top)', () {
    DocumentItemInput item(double price, {bool taxable = true, double? taxRate}) =>
        DocumentItemInput(
          description: 'Item',
          quantity: 1,
          price: price,
          taxable: taxable,
          taxRate: taxRate,
        );

    test('simple 15% exclusive', () {
      final result = DocumentService.calculateInvoiceTotals(
        items: [item(100)],
        discount: 0,
        taxRate: 15,
      );
      expect(result.subtotal, 100.0);
      expect(result.taxAmount, closeTo(15.0, 0.001));
      expect(result.total, closeTo(115.0, 0.001));
    });

    test('discount reduces taxable base proportionally', () {
      final result = DocumentService.calculateInvoiceTotals(
        items: [item(200)],
        discount: 20,
        taxRate: 10,
      );
      // After 20 discount, base = 180; tax = 180 * 10% = 18
      expect(result.taxAmount, closeTo(18.0, 0.001));
      expect(result.total, closeTo(198.0, 0.001));
    });

    test('non-taxable item has no tax', () {
      final result = DocumentService.calculateInvoiceTotals(
        items: [item(100, taxable: false)],
        discount: 0,
        taxRate: 15,
      );
      expect(result.taxAmount, 0.0);
      expect(result.total, 100.0);
    });

    test('per-item rate overrides business fallback', () {
      final result = DocumentService.calculateInvoiceTotals(
        items: [item(100, taxRate: 5)], // explicit 5%, business is 15%
        discount: 0,
        taxRate: 15,
      );
      expect(result.taxAmount, closeTo(5.0, 0.001));
      expect(result.total, closeTo(105.0, 0.001));
    });

    test('mixed items with different per-item rates', () {
      final items = [
        item(100, taxRate: 10), // tax = 10
        item(200, taxRate: 5),  // tax = 10
        item(50, taxable: false), // tax = 0
      ];
      final result = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 0,
        taxRate: 0,
      );
      expect(result.subtotal, 350.0);
      expect(result.taxAmount, closeTo(20.0, 0.001));
      expect(result.total, closeTo(370.0, 0.001));
    });

    test('zero tax rate produces no tax', () {
      final result = DocumentService.calculateInvoiceTotals(
        items: [item(100)],
        discount: 0,
        taxRate: 0,
      );
      expect(result.taxAmount, 0.0);
      expect(result.total, 100.0);
    });
  });

  // ── Inclusive tax calculation ─────────────────────────────────
  group('Inclusive tax (embedded in price)', () {
    DocumentItemInput item(double price, {bool taxable = true, double? taxRate}) =>
        DocumentItemInput(
          description: 'Item',
          quantity: 1,
          price: price,
          taxable: taxable,
          taxRate: taxRate,
        );

    test('inclusive 15%: total = subtotal, tax extracted', () {
      final result = DocumentService.calculateInvoiceTotals(
        items: [item(115)],
        discount: 0,
        taxRate: 15,
        pricesIncludeTax: true,
      );
      expect(result.subtotal, 115.0);
      // tax = 115 * 15 / (100 + 15) = 115 * 15 / 115 = 15
      expect(result.taxAmount, closeTo(15.0, 0.001));
      expect(result.total, 115.0); // no extra added
    });

    test('inclusive discount: total = subtotal - discount', () {
      final result = DocumentService.calculateInvoiceTotals(
        items: [item(115)],
        discount: 15,
        taxRate: 15,
        pricesIncludeTax: true,
      );
      expect(result.total, closeTo(100.0, 0.001));
    });

    test('inclusive per-item rate', () {
      final result = DocumentService.calculateInvoiceTotals(
        items: [item(110, taxRate: 10)],
        discount: 0,
        taxRate: 0,
        pricesIncludeTax: true,
      );
      // tax = 110 * 10 / 110 = 10
      expect(result.taxAmount, closeTo(10.0, 0.001));
      expect(result.total, 110.0);
    });
  });

  // ── Historical integrity ──────────────────────────────────────
  group('DocumentItemInput taxRate snapshot', () {
    test('taxRate field is nullable', () {
      const item = DocumentItemInput(
          description: 'X', quantity: 1, price: 100);
      expect(item.taxRate, isNull);
    });

    test('explicit taxRate is stored', () {
      const item = DocumentItemInput(
          description: 'X', quantity: 1, price: 100, taxRate: 12.5);
      expect(item.taxRate, 12.5);
    });
  });
}
