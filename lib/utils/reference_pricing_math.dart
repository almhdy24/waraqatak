/// Pure mathematical utilities and validation for reference-currency pricing.
library;

import 'dart:math' as math;

import '../models/reference_pricing_types.dart';
import 'money_utils.dart';

/// Pure functions and constants for reference currency conversions and validations.
abstract final class ReferencePricingMath {
  /// Maximum monetary price value (10^12).
  static const double maxPrice = 1e12;

  /// Maximum exchange rate value (10^9).
  static const double maxRate = 1e9;

  /// Maximum decimal places supported for exchange rates.
  static const int maxRateDecimals = 6;

  /// Maximum decimal places supported for reference prices.
  static const int maxReferenceDecimals = 4;

  /// Allowed rounding step values in base-currency units.
  static const List<int> allowedRounding = [0, 1, 5, 10, 50, 100];

  /// Default rounding step (0 = no additional rounding step beyond decimal precision).
  static const int defaultRounding = 0;

  /// Computes the exact number of decimal places for a finite [v].
  ///
  /// Works from the shortest round-trip string of the double.
  /// Throws [ArgumentError] if [v] is not finite (NaN or Infinity).
  static int decimalPlaces(double v) {
    if (!v.isFinite) {
      throw ArgumentError('Value must be finite: $v');
    }
    final s = v.abs().toString();
    int exp = 0;
    String mantissa = s;
    final eIndex = s.indexOf(RegExp(r'[eE]'));
    if (eIndex != -1) {
      mantissa = s.substring(0, eIndex);
      exp = int.parse(s.substring(eIndex + 1));
    }
    int fractionDigits = 0;
    final dotIndex = mantissa.indexOf('.');
    if (dotIndex != -1) {
      var frac = mantissa.substring(dotIndex + 1);
      while (frac.endsWith('0')) {
        frac = frac.substring(0, frac.length - 1);
      }
      fractionDigits = frac.length;
    }
    final res = fractionDigits - exp;
    return math.max(0, res);
  }

  /// Parses a decimal string with localization awareness.
  ///
  /// Maps Arabic-Indic and Persian digits to ASCII, and Arabic decimal '٫' to '.'.
  /// When [allowCommaDecimal] is true, ',' and '،' are mapped to '.'.
  /// When [allowCommaDecimal] is false, any ',' or '،' makes the input invalid.
  /// Accepts strictly `^\d+(\.\d+)?$`. Returns a finite double or null.
  static double? parseDecimal(String? input, {bool allowCommaDecimal = true}) {
    if (input == null) return null;
    var trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    if (!allowCommaDecimal) {
      if (trimmed.contains(',') || trimmed.contains('،')) {
        return null;
      }
    }

    // Map Arabic-Indic and Persian digits to ASCII 0-9
    final sb = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      final code = trimmed.codeUnitAt(i);
      if (code >= 0x0660 && code <= 0x0669) {
        sb.writeCharCode(0x30 + (code - 0x0660));
      } else if (code >= 0x06F0 && code <= 0x06F9) {
        sb.writeCharCode(0x30 + (code - 0x06F0));
      } else if (code == 0x066B) {
        // Arabic decimal separator '٫'
        sb.write('.');
      } else if (allowCommaDecimal && (code == 0x002C || code == 0x060C)) {
        // Standard comma ',' or Arabic comma '،'
        sb.write('.');
      } else {
        sb.writeCharCode(code);
      }
    }
    final normalized = sb.toString();

    final pattern = RegExp(r'^\d+(\.\d+)?$');
    if (!pattern.hasMatch(normalized)) {
      return null;
    }

    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed;
  }

  /// Returns true if [rate] is finite, > 0, <= 1e9, and has at most 6 decimal places.
  static bool isValidRate(double rate) {
    if (!rate.isFinite || rate <= 0 || rate > maxRate) {
      return false;
    }
    return decimalPlaces(rate) <= maxRateDecimals;
  }

  /// Returns true if [price] is finite, >= 0, <= 1e12, and has at most 4 decimal places.
  static bool isValidReferencePrice(double price) {
    if (!price.isFinite || price < 0 || price > maxPrice) {
      return false;
    }
    return decimalPlaces(price) <= maxReferenceDecimals;
  }

  /// Asserts that [rate] is valid, throwing [ReferencePricingException] with [ReferencePricingError.invalidRate].
  static void assertValidRate(double rate) {
    if (!isValidRate(rate)) {
      throw const ReferencePricingException(
        ReferencePricingError.invalidRate,
        'Invalid exchange rate',
      );
    }
  }

  /// Asserts that [price] is valid, throwing [ReferencePricingException] with [ReferencePricingError.invalidPrice].
  static void assertValidReferencePrice(double price) {
    if (!isValidReferencePrice(price)) {
      throw const ReferencePricingException(
        ReferencePricingError.invalidPrice,
        'Invalid reference price',
      );
    }
  }

  /// Parses and validates an exchange rate string.
  static double? parseRate(String? input, {bool allowCommaDecimal = true}) {
    final v = parseDecimal(input, allowCommaDecimal: allowCommaDecimal);
    if (v == null || !isValidRate(v)) return null;
    return v;
  }

  /// Parses and validates a reference price string.
  static double? parseReferencePrice(
    String? input, {
    bool allowCommaDecimal = true,
  }) {
    final v = parseDecimal(input, allowCommaDecimal: allowCommaDecimal);
    if (v == null || !isValidReferencePrice(v)) return null;
    return v;
  }

  /// Parses a rounding string from app_settings, returning an allowed integer or [defaultRounding].
  static int parseRounding(String? input) {
    if (input == null) return defaultRounding;
    final val = int.tryParse(input.trim());
    if (val != null && allowedRounding.contains(val)) {
      return val;
    }
    return defaultRounding;
  }

  /// Converts a [reference] price using an exchange [rate] into base-currency price.
  ///
  /// Applies validation, optional [rounding] step, and base-currency [baseDecimals] rounding.
  /// Throws [ReferencePricingException] with [ReferencePricingError.priceOutOfRange] if
  /// any intermediate or final result is out of range (not finite, < 0, or > 1e12).
  static double convert({
    required double reference,
    required double rate,
    required int rounding,
    required int baseDecimals,
  }) {
    assertValidReferencePrice(reference);
    assertValidRate(rate);

    void checkRange(double val) {
      if (!val.isFinite || val < 0 || val > maxPrice) {
        throw const ReferencePricingException(
          ReferencePricingError.priceOutOfRange,
          'Converted price out of range',
        );
      }
    }

    var v = reference * rate;
    checkRange(v);

    if (rounding > 0) {
      v = (v / rounding).roundToDouble() * rounding;
    }
    checkRange(v);

    final r = MoneyUtils.round(v, baseDecimals);
    checkRange(r);

    return r;
  }
}
