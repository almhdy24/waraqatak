import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/utils/number_input.dart';

void main() {
  group('NumberInput.parse', () {
    test('parses numbers and formats correctly', () {
      expect(NumberInput.parse('1,500'), 1500);
      expect(NumberInput.parse('1،500'), 1500);
      expect(NumberInput.parse('١٢٣٫٥'), 123.5);
      expect(NumberInput.parse('۱۲۳'), 123);
      expect(NumberInput.parse('  ٢٥٠ '), 250);
      expect(NumberInput.parse('.5'), 0.5);
      expect(NumberInput.parse('5.'), 5);
      expect(NumberInput.parse('-7'), -7);
      expect(NumberInput.parse('1.2.3'), isNull);
      expect(NumberInput.parse('1e5'), isNull);
      expect(NumberInput.parse(''), isNull);
      expect(NumberInput.parse('-'), isNull);
      expect(NumberInput.parse('abc'), isNull);
      expect(NumberInput.parse(null), isNull);
    });
  });

  group('NumberInput.group', () {
    test('groups integers with commas', () {
      expect(NumberInput.group('1500'), '1,500');
      expect(NumberInput.group('1234567.891'), '1,234,567.891');
      expect(NumberInput.group('-1500'), '-1,500');
      expect(NumberInput.group('999'), '999');
    });
  });

  group('NumberInput.formatForInput', () {
    test('formats numbers for input field', () {
      expect(NumberInput.formatForInput(1500.0), '1,500');
      expect(NumberInput.formatForInput(0.5), '0.5');
      expect(NumberInput.formatForInput(1234.5678), '1,234.5678');
      expect(NumberInput.formatForInput(12500.0), '12,500');
      expect(NumberInput.formatForInput(0.0), '0');
      expect(NumberInput.formatForInput(5.0, maxDecimals: 0), '5');
    });
  });

  group('AmountInputFormatter', () {
    test('default formatter formats input correctly', () {
      final formatter = AmountInputFormatter();

      TextEditingValue apply(String text) {
        return formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        );
      }

      final res1500 = apply('1500');
      expect(res1500.text, '1,500');
      expect(res1500.selection.baseOffset, 5);

      expect(apply('١٥٠٠').text, '1,500');
      expect(apply('1,5').text, '15');
      expect(apply('.5').text, '0.5');
      expect(apply('007').text, '7');
      expect(apply('1500.123456').text, '1,500.1234');
      expect(apply('1.2.3').text, '1.23');
      expect(apply('-5').text, '5');
      expect(apply('abc').text, '');
    });

    test('allowNegative: true', () {
      final formatter = AmountInputFormatter(allowNegative: true);
      final res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '-1500',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(res.text, '-1,500');
    });

    test('maxDecimals: 0', () {
      final formatter = AmountInputFormatter(maxDecimals: 0);
      final res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '12.5',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(res.text, '125');
    });

    test('cursor position preserved through grouping', () {
      final formatter = AmountInputFormatter();
      final res = formatter.formatEditUpdate(
        const TextEditingValue(text: '1,500'),
        const TextEditingValue(
          text: '1,2500',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(res.text, '12,500');
      expect(res.selection.baseOffset, 2);
    });
  });
}
