import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/utils/format_utils.dart';

void main() {
  group('FormatUtils.formatQuantity', () {
    test('formats null as 0', () {
      expect(FormatUtils.formatQuantity(null), '0');
    });

    test('formats zero as 0 without trailing decimals', () {
      expect(FormatUtils.formatQuantity(0), '0');
      expect(FormatUtils.formatQuantity(0.0), '0');
    });

    test('formats whole integers cleanly without trailing decimals', () {
      expect(FormatUtils.formatQuantity(1), '1');
      expect(FormatUtils.formatQuantity(2), '2');
      expect(FormatUtils.formatQuantity(100), '100');
      expect(FormatUtils.formatQuantity(1000), '1,000');
    });

    test('formats common fractional quantities accurately', () {
      expect(FormatUtils.formatQuantity(1.5), '1.5');
      expect(FormatUtils.formatQuantity(0.25), '0.25');
      expect(FormatUtils.formatQuantity(0.125), '0.125');
      expect(FormatUtils.formatQuantity(0.0625), '0.0625');
      expect(FormatUtils.formatQuantity(3.75), '3.75');
    });

    test('formats negative quantities correctly', () {
      expect(FormatUtils.formatQuantity(-1), '-1');
      expect(FormatUtils.formatQuantity(-2.5), '-2.5');
      expect(FormatUtils.formatQuantity(-0.125), '-0.125');
    });

    test('appends unit if provided and non-empty', () {
      expect(FormatUtils.formatQuantity(1.5, unit: 'كجم'), '1.5 كجم');
      expect(FormatUtils.formatQuantity(2, unit: 'متر'), '2 متر');
      expect(FormatUtils.formatQuantity(0, unit: 'قطعة'), '0 قطعة');
      expect(FormatUtils.formatQuantity(null, unit: 'حبة'), '0');
    });

    test('ignores empty or whitespace unit', () {
      expect(FormatUtils.formatQuantity(1.5, unit: ''), '1.5');
      expect(FormatUtils.formatQuantity(2, unit: '   '), '2');
    });
  });

  group('FormatUtils.formatTaxRate', () {
    test('formats whole integers without trailing decimals', () {
      expect(FormatUtils.formatTaxRate(0.0), '0%');
      expect(FormatUtils.formatTaxRate(15.0), '15%');
      expect(FormatUtils.formatTaxRate(100.0), '100%');
    });

    test('preserves fractional decimal tax rates accurately', () {
      expect(FormatUtils.formatTaxRate(15.5), '15.5%');
      expect(FormatUtils.formatTaxRate(5.25), '5.25%');
      expect(FormatUtils.formatTaxRate(0.5), '0.5%');
      expect(FormatUtils.formatTaxRate(7.75), '7.75%');
    });
  });
}
