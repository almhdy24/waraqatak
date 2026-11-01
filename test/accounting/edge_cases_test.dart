import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/utils/money_utils.dart';

void main() {
  group('Accounting Edge Cases Suite', () {
    test('100% discount document results in zero total and zero tax', () {
      final items = [
        const DocumentItemInput(
          description: 'هدية ترويجية',
          quantity: 2,
          price: 250.0,
          taxable: true,
        ),
      ];

      // Subtotal = 500, Discount = 500
      final result = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 500.0,
        taxRate: 15.0,
        pricesIncludeTax: false,
        decimalDigits: 2,
      );

      expect(result.subtotal, 500.0);
      expect(result.taxAmount, 0.0);
      expect(result.total, 0.0);
    });

    test('Zero price items (free samples) calculate cleanly', () {
      final items = [
        const DocumentItemInput(
          description: 'عينة مجانية',
          quantity: 10,
          price: 0.0,
          taxable: true,
        ),
      ];

      final result = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 0.0,
        taxRate: 15.0,
        pricesIncludeTax: false,
        decimalDigits: 2,
      );

      expect(result.subtotal, 0.0);
      expect(result.taxAmount, 0.0);
      expect(result.total, 0.0);
    });

    test('Fractional quantity (0.001) calculates precise minor unit totals', () {
      final items = [
        const DocumentItemInput(
          description: 'زعفران بالغرام',
          quantity: 0.005,
          price: 25000.0, // 25,000 per kg -> 0.005 kg = 125.0
          taxable: false,
        ),
      ];

      final result = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 0.0,
        taxRate: 0.0,
        decimalDigits: 2,
      );

      expect(result.subtotal, 125.0);
      expect(result.total, 125.0);
    });

    test('10-line discount allocation distributes indivisible minor unit remainder deterministically', () {
      // 10 lines of 10.00 each = subtotal 100.00. Discount 3.01 (indivisible by 10)
      final lineAmounts = List<double>.filled(10, 10.0);
      final allocated = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 100.0,
        docDiscount: 3.01,
        lineAmounts: lineAmounts,
        decimalDigits: 2,
      );

      expect(allocated.length, 10);
      final sumNet = allocated.fold<double>(0.0, (s, a) => s + a);
      expect(MoneyUtils.round(sumNet, 2), 96.99); // 100.00 - 3.01 = 96.99 exactly

      final minorUnits = allocated.map((a) => MoneyUtils.toMinorUnits(a, 2)).toList();
      final totalMinor = minorUnits.reduce((a, b) => a + b);
      expect(totalMinor, 9699); // 96.99 in minor units
    });

    test('Date boundary: midnight and daylight boundary comparison', () {
      final t1 = DateTime(2026, 11, 1, 0, 0, 0);
      final t2 = DateTime(2026, 11, 1, 23, 59, 59, 999);

      expect(t1.isBefore(t2), isTrue);
      expect(t2.difference(t1).inHours, 23);
    });
  });
}
