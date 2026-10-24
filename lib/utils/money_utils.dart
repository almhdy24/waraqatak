import 'dart:math' as math;

/// Utility class for canonical monetary rounding, conversions, and comparisons.
///
/// Follows standard accounting half-up rounding (round half away from zero)
/// to the currency's decimal precision.
class MoneyUtils {
  /// Rounds a monetary [amount] to [decimalDigits] (default: 2) using
  /// standard financial half-up rounding.
  ///
  /// A 1e-9 representation adjustment compensates for IEEE 754 binary floating
  /// point imprecision (e.g., 1.005 being stored as 1.00499999999999989).
  static double round(double amount, [int decimalDigits = 2]) {
    if (amount.isNaN || amount.isInfinite || amount == 0.0) return 0.0;
    final factor = math.pow(10, decimalDigits).toDouble();
    final adjustment = amount >= 0 ? 1e-9 : -1e-9;
    final result = ((amount + adjustment) * factor).roundToDouble() / factor;
    return result == 0.0 ? 0.0 : result;
  }

  /// Converts a monetary [amount] to integer minor units (e.g. cents, piastres, halalas).
  static int toMinorUnits(double amount, [int decimalDigits = 2]) {
    if (amount.isNaN || amount.isInfinite) return 0;
    final factor = math.pow(10, decimalDigits).toDouble();
    final adjustment = amount >= 0 ? 1e-9 : -1e-9;
    return ((amount + adjustment) * factor).round();
  }

  /// Converts integer [minorUnits] back to a double monetary amount.
  static double fromMinorUnits(int minorUnits, [int decimalDigits = 2]) {
    final factor = math.pow(10, decimalDigits).toDouble();
    final result = minorUnits / factor;
    return result == 0.0 ? 0.0 : result;
  }

  /// Checks if [payment] strictly exceeds [remaining] beyond the currency's smallest unit.
  ///
  /// Comparison is performed at integer minor-unit precision, ensuring binary
  /// representation jitter (e.g. 10^-16) never triggers false overpayment exceptions,
  /// while genuine overpayments of 1 minor unit or more are strictly caught.
  static bool isOverpayment(double payment, double remaining, [int decimalDigits = 2]) {
    return toMinorUnits(payment, decimalDigits) > toMinorUnits(remaining, decimalDigits);
  }

  /// Computes remaining balance after [paid] is applied against [total], clamped to >= 0.0.
  static double calculateRemaining(double total, double paid, [int decimalDigits = 2]) {
    final totalUnits = toMinorUnits(total, decimalDigits);
    final paidUnits = toMinorUnits(paid, decimalDigits);
    final remainingUnits = math.max(0, totalUnits - paidUnits);
    return fromMinorUnits(remainingUnits, decimalDigits);
  }

  /// Determines whether [paid] satisfies [total] in full at minor-unit precision.
  static bool isPaidInFull(double paid, double total, [int decimalDigits = 2]) {
    return toMinorUnits(paid, decimalDigits) >= toMinorUnits(total, decimalDigits);
  }

  /// Determines whether [amount] is effectively zero at minor-unit precision.
  static bool isZero(double amount, [int decimalDigits = 2]) {
    return toMinorUnits(amount, decimalDigits) == 0;
  }

  /// Allocates a document-level [docDiscount] proportionally across [lineAmounts]
  /// according to their share of [docSubtotal], using the largest-remainder method
  /// (Hamilton-Hare) at the specified [decimalDigits] precision.
  ///
  /// Guarantees:
  /// - Sum of allocated discounts equals min(docDiscount, docSubtotal) exactly in minor units.
  /// - Sum of returned net revenues equals max(0.0, docSubtotal - docDiscount) exactly in minor units.
  /// - Zero division is safely handled when docSubtotal <= 0 (all lines return 0.0).
  /// - Fully discounted documents (docDiscount >= docSubtotal) return 0.0 for all lines.
  /// - Deterministic tie-breaking ensures identical inputs always produce identical distributions.
  static List<double> allocateDocumentDiscount({
    required double docSubtotal,
    required double docDiscount,
    required List<double> lineAmounts,
    int decimalDigits = 2,
  }) {
    if (lineAmounts.isEmpty) return const [];

    final subtotalUnits = toMinorUnits(docSubtotal, decimalDigits);
    final discountUnits = toMinorUnits(docDiscount, decimalDigits);

    // If subtotal is non-positive, net revenue is zero
    if (subtotalUnits <= 0) {
      return List<double>.filled(lineAmounts.length, 0.0);
    }

    // If discount is non-positive, each line retains its full amount
    if (discountUnits <= 0) {
      return lineAmounts
          .map((a) => fromMinorUnits(toMinorUnits(a, decimalDigits), decimalDigits))
          .toList();
    }

    final n = lineAmounts.length;
    final lineUnitsList = List<int>.generate(
      n,
      (i) => math.max(0, toMinorUnits(lineAmounts[i], decimalDigits)),
    );
    final totalLinesUnits = lineUnitsList.fold<int>(0, (sum, u) => sum + u);

    if (totalLinesUnits <= 0) {
      return List<double>.filled(n, 0.0);
    }

    // Base for apportionment is the actual sum of line minor units
    final baseUnits = totalLinesUnits;
    final effectiveDiscountUnits = math.min(discountUnits, baseUnits);

    // If fully discounted (or over-discounted), net revenue is zero
    if (effectiveDiscountUnits >= baseUnits) {
      return List<double>.filled(n, 0.0);
    }

    final bigEffectiveDiscount = BigInt.from(effectiveDiscountUnits);
    final bigBase = BigInt.from(baseUnits);

    final floorAllocations = List<int>.filled(n, 0);
    final remainders = List<BigInt>.filled(n, BigInt.zero);
    var sumAllocated = 0;

    for (var i = 0; i < n; i++) {
      final lineUnits = lineUnitsList[i];
      if (lineUnits <= 0) continue;
      final bigLine = BigInt.from(lineUnits);
      final bigProd = bigEffectiveDiscount * bigLine;
      final q = (bigProd ~/ bigBase).toInt();
      final r = bigProd % bigBase;

      floorAllocations[i] = q;
      remainders[i] = r;
      sumAllocated += q;
    }

    final residual = effectiveDiscountUnits - sumAllocated;
    if (residual > 0) {
      // Sort indices by remainder descending, tie-breaking deterministically by index ascending
      final indices = List<int>.generate(n, (i) => i);
      indices.sort((a, b) {
        final cmp = remainders[b].compareTo(remainders[a]);
        if (cmp != 0) return cmp;
        return a.compareTo(b);
      });

      for (var i = 0; i < residual && i < n; i++) {
        floorAllocations[indices[i]] += 1;
      }
    }

    return List<double>.generate(n, (i) {
      final lineUnits = lineUnitsList[i];
      final allocatedUnits = floorAllocations[i];
      final netUnits = math.max(0, lineUnits - allocatedUnits);
      return fromMinorUnits(netUnits, decimalDigits);
    });
  }
}
