import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/reference_pricing_types.dart';
import 'package:warqatek/utils/money_utils.dart';
import 'package:warqatek/utils/reference_pricing_math.dart';

void main() {
  group('ReferencePricingMath M1: decimalPlaces and validity', () {
    test('decimalPlaces handles standard, exponents, and edge cases', () {
      expect(ReferencePricingMath.decimalPlaces(0.1), 1);
      expect(ReferencePricingMath.decimalPlaces(0.30000000000000004), 17);
      expect(ReferencePricingMath.decimalPlaces(1e-7), 7);
      expect(ReferencePricingMath.decimalPlaces(1.5e-7), 8);
      expect(ReferencePricingMath.decimalPlaces(1e21), 0);
      expect(ReferencePricingMath.decimalPlaces(123456.1234), 4);
      expect(ReferencePricingMath.decimalPlaces(1100), 0);
      expect(ReferencePricingMath.decimalPlaces(0.000001), 6);
      expect(ReferencePricingMath.decimalPlaces(0.0000001), 7);

      expect(() => ReferencePricingMath.decimalPlaces(double.nan),
          throwsA(isA<ArgumentError>()));
      expect(() => ReferencePricingMath.decimalPlaces(double.infinity),
          throwsA(isA<ArgumentError>()));
      expect(() => ReferencePricingMath.decimalPlaces(double.negativeInfinity),
          throwsA(isA<ArgumentError>()));
    });

    test('isValidRate and isValidReferencePrice return false for non-finite values', () {
      expect(ReferencePricingMath.isValidRate(double.nan), isFalse);
      expect(ReferencePricingMath.isValidRate(double.infinity), isFalse);
      expect(ReferencePricingMath.isValidRate(double.negativeInfinity), isFalse);

      expect(ReferencePricingMath.isValidReferencePrice(double.nan), isFalse);
      expect(ReferencePricingMath.isValidReferencePrice(double.infinity), isFalse);
      expect(
          ReferencePricingMath.isValidReferencePrice(double.negativeInfinity),
          isFalse);
    });
  });

  group('ReferencePricingMath M2: parseDecimal', () {
    test('normalizes Arabic-Indic and Persian digits and decimal marks', () {
      expect(ReferencePricingMath.parseDecimal('١٢٫٣٤'), 12.34);
      expect(ReferencePricingMath.parseDecimal('۱۲.۳۴'), 12.34);
      expect(ReferencePricingMath.parseDecimal('12٫34'), 12.34);
    });

    test('allowCommaDecimal behavior', () {
      expect(ReferencePricingMath.parseDecimal('1,500', allowCommaDecimal: false),
          isNull);
      expect(ReferencePricingMath.parseDecimal('1،5', allowCommaDecimal: false),
          isNull);
      expect(ReferencePricingMath.parseDecimal('1,5', allowCommaDecimal: true),
          1.5);
      expect(ReferencePricingMath.parseDecimal('1،5', allowCommaDecimal: true),
          1.5);
    });

    test('rejects signs, exponents, words, spaces, empty, multiple dots', () {
      expect(ReferencePricingMath.parseDecimal('+1'), isNull);
      expect(ReferencePricingMath.parseDecimal('-1'), isNull);
      expect(ReferencePricingMath.parseDecimal('1e-5'), isNull);
      expect(ReferencePricingMath.parseDecimal('NaN'), isNull);
      expect(ReferencePricingMath.parseDecimal('Infinity'), isNull);
      expect(ReferencePricingMath.parseDecimal('1 2'), isNull);
      expect(ReferencePricingMath.parseDecimal(''), isNull);
      expect(ReferencePricingMath.parseDecimal('   '), isNull);
      expect(ReferencePricingMath.parseDecimal('1.2.3'), isNull);
    });
  });

  group('ReferencePricingMath M3: parseRate and parseReferencePrice', () {
    test('parseRate accepts valid bounds and at most 6 decimal places', () {
      expect(ReferencePricingMath.parseRate('0.000001'), 0.000001);
      expect(ReferencePricingMath.parseRate('1'), 1.0);
      expect(ReferencePricingMath.parseRate('530.5'), 530.5);
      expect(ReferencePricingMath.parseRate('123456.789012'), 123456.789012);

      expect(ReferencePricingMath.parseRate('0'), isNull);
      expect(ReferencePricingMath.parseRate('-0.5'), isNull);
      expect(ReferencePricingMath.parseRate('1.1234567'), isNull);
      expect(ReferencePricingMath.parseRate('1000000001'), isNull);
      expect(ReferencePricingMath.parseRate('NaN'), isNull);
    });

    test('parseReferencePrice accepts 0 and up to 4 decimal places, rejects negatives and > 1e12', () {
      expect(ReferencePricingMath.parseReferencePrice('0'), 0.0);
      expect(ReferencePricingMath.parseReferencePrice('0.0'), 0.0);
      expect(ReferencePricingMath.parseReferencePrice('12'), 12.0);
      expect(ReferencePricingMath.parseReferencePrice('12.3456'), 12.3456);

      expect(ReferencePricingMath.parseReferencePrice(''), isNull);
      expect(ReferencePricingMath.parseReferencePrice('  '), isNull);
      expect(ReferencePricingMath.parseReferencePrice('abc'), isNull);
      expect(ReferencePricingMath.parseReferencePrice('-1'), isNull);
      expect(ReferencePricingMath.parseReferencePrice('12.34567'), isNull);
      expect(ReferencePricingMath.parseReferencePrice('1000000000001'), isNull);
    });
  });

  group('ReferencePricingMath M4: assertValidRate & assertValidReferencePrice', () {
    test('assertValidRate throws ReferencePricingException with invalidRate', () {
      expect(
        () => ReferencePricingMath.assertValidRate(double.nan),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidRate)),
      );
      expect(
        () => ReferencePricingMath.assertValidRate(double.infinity),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidRate)),
      );
      expect(
        () => ReferencePricingMath.assertValidRate(-5.0),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidRate)),
      );
      expect(
        () => ReferencePricingMath.assertValidRate(1e-7),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidRate)),
      );
      expect(
        () => ReferencePricingMath.assertValidRate(1e9 + 1),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidRate)),
      );
    });

    test('assertValidReferencePrice throws ReferencePricingException with invalidPrice', () {
      expect(
        () => ReferencePricingMath.assertValidReferencePrice(double.nan),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidPrice)),
      );
      expect(
        () => ReferencePricingMath.assertValidReferencePrice(-1.0),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidPrice)),
      );
      expect(
        () => ReferencePricingMath.assertValidReferencePrice(1e-5),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidPrice)),
      );
      expect(
        () => ReferencePricingMath.assertValidReferencePrice(1e12 + 1),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidPrice)),
      );
      // Floating-point math artifact 0.1 + 0.2 has 17 decimal places
      expect(
        () => ReferencePricingMath.assertValidReferencePrice(0.1 + 0.2),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.invalidPrice)),
      );
    });
  });

  group('ReferencePricingMath M5: convert', () {
    test('converts cleanly with rounding = 0', () {
      expect(
        ReferencePricingMath.convert(
          reference: 10,
          rate: 530.5,
          rounding: 0,
          baseDecimals: 2,
        ),
        5305.0,
      );
      expect(
        ReferencePricingMath.convert(
          reference: 10.5,
          rate: 530.25,
          rounding: 0,
          baseDecimals: 2,
        ),
        5567.63,
      );
      expect(
        ReferencePricingMath.convert(
          reference: 0,
          rate: 530.5,
          rounding: 0,
          baseDecimals: 2,
        ),
        0.0,
      );
      expect(
        ReferencePricingMath.convert(
          reference: 10.5,
          rate: 530.25,
          rounding: 0,
          baseDecimals: 2,
        ),
        MoneyUtils.round(10.5 * 530.25, 2),
      );
    });

    test('converts with rounding steps 5, 50, 100', () {
      // Step 5
      expect(
        ReferencePricingMath.convert(
          reference: 10,
          rate: 530.5,
          rounding: 5,
          baseDecimals: 2,
        ),
        5305.0,
      );
      expect(
        ReferencePricingMath.convert(
          reference: 10,
          rate: 531.1,
          rounding: 5,
          baseDecimals: 2,
        ),
        5310.0,
      );
      expect(
        ReferencePricingMath.convert(
          reference: 10,
          rate: 533.0,
          rounding: 5,
          baseDecimals: 2,
        ),
        5330.0,
      );

      // Step 50
      expect(
        ReferencePricingMath.convert(
          reference: 10,
          rate: 530.0,
          rounding: 50,
          baseDecimals: 2,
        ),
        5300.0,
      );
      expect(
        ReferencePricingMath.convert(
          reference: 10,
          rate: 534.0,
          rounding: 50,
          baseDecimals: 2,
        ),
        5350.0,
      );
      expect(
        ReferencePricingMath.convert(
          reference: 10,
          rate: 510.0,
          rounding: 50,
          baseDecimals: 2,
        ),
        5100.0,
      );

      // Step 100
      expect(
        ReferencePricingMath.convert(
          reference: 1,
          rate: 150.0,
          rounding: 100,
          baseDecimals: 0,
        ),
        200.0,
      );
    });

    test('range checks throw priceOutOfRange even if intermediate rounding brings it back', () {
      // reference * rate = (1e12 + 0.4) * 1.0 > 1e12
      expect(
        () => ReferencePricingMath.convert(
          reference: 1e12,
          rate: 2.0,
          rounding: 0,
          baseDecimals: 2,
        ),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.priceOutOfRange)),
      );

      // reference * rate = 100000000000.04 * 10 = 1e12 + 0.4 > 1e12
      expect(
        () => ReferencePricingMath.convert(
          reference: 100000000000.04,
          rate: 10.0,
          rounding: 1,
          baseDecimals: 0,
        ),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.priceOutOfRange)),
      );
    });
  });
}
