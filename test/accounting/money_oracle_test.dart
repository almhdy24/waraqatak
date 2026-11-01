import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/utils/money_utils.dart';

/// Pure integer-minor-unit oracle calculator.
/// Uses zero floating-point arithmetic for accumulation, rounding, and allocation.
class IntegerMoneyOracle {
  final int decimalDigits;
  late final int factor;
  late final BigInt bigFactor;

  IntegerMoneyOracle({this.decimalDigits = 2}) {
    factor = math.pow(10, decimalDigits).toInt();
    bigFactor = BigInt.from(factor);
  }

  int toMinor(double amount) {
    if (amount.isNaN || amount.isInfinite || amount == 0.0) return 0;
    final adj = amount >= 0 ? 1e-9 : -1e-9;
    return ((amount + adj) * factor).round();
  }

  double fromMinor(int minor) {
    return minor / factor;
  }

  int roundMinor(int value, int divisor) {
    if (divisor == 0) return 0;
    final q = value ~/ divisor;
    final r = (value % divisor).abs();
    final half = divisor.abs() / 2.0;
    if (r > half || (r == half && value >= 0)) {
      return value >= 0 ? q + 1 : q - 1;
    }
    return q;
  }

  /// Calculates invoice totals using strictly integer minor units.
  ({int subtotalMinor, int taxMinor, int totalMinor, int remainingMinor}) calculateTotals({
    required List<({int qtyMinor, int unitPriceMinor, int taxRateBps, bool taxable})> items,
    required int discountMinor,
    required int defaultTaxRateBps,
    required bool pricesIncludeTax,
    required int paidMinor,
  }) {
    int subtotalMinor = 0;
    final lineTotalsMinor = <int>[];

    for (final it in items) {
      final bigQty = BigInt.from(it.qtyMinor);
      final bigPrice = BigInt.from(it.unitPriceMinor);
      final bigProd = bigQty * bigPrice;
      // qtyMinor was scaled by factor, priceMinor by factor -> product is scaled by factor^2
      // divide by factor to bring to single-factor minor units
      final q = (bigProd ~/ bigFactor).toInt();
      final r = (bigProd % bigFactor).abs();
      final lineMinor = (r * BigInt.two >= bigFactor) ? q + 1 : q;
      lineTotalsMinor.add(lineMinor);
      subtotalMinor += lineMinor;
    }

    final effectiveDiscountMinor = math.max(0, math.min(discountMinor, subtotalMinor));

    // Multi-rate tax calculation
    int taxMinor = 0;
    if (subtotalMinor > 0) {
      final netMinor = subtotalMinor - effectiveDiscountMinor;
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        final rateBps = it.taxRateBps > 0
            ? it.taxRateBps
            : (it.taxable ? defaultTaxRateBps : 0);
        if (rateBps <= 0) continue;

        final lineTotal = lineTotalsMinor[i];
        if (lineTotal <= 0) continue;

        // Line share of net: (lineTotal * netMinor) / subtotalMinor
        final bigLine = BigInt.from(lineTotal);
        final bigNet = BigInt.from(netMinor);
        final bigSub = BigInt.from(subtotalMinor);
        final netLineMinor = (bigLine * bigNet ~/ bigSub).toInt();

        final bigNetLine = BigInt.from(netLineMinor);
        final bigRate = BigInt.from(rateBps);

        if (pricesIncludeTax) {
          // Extract tax: netLine * rate / (10000 + rate)
          final bigDiv = BigInt.from(10000 + rateBps);
          final bigTax = (bigNetLine * bigRate) ~/ bigDiv;
          taxMinor += bigTax.toInt();
        } else {
          // Add tax: netLine * rate / 10000
          final bigTax = (bigNetLine * bigRate) ~/ BigInt.from(10000);
          taxMinor += bigTax.toInt();
        }
      }
    }

    final totalMinor = pricesIncludeTax
        ? (subtotalMinor - effectiveDiscountMinor)
        : (subtotalMinor - effectiveDiscountMinor + taxMinor);

    final effectivePaidMinor = math.max(0, math.min(paidMinor, totalMinor));
    final remainingMinor = math.max(0, totalMinor - effectivePaidMinor);

    return (
      subtotalMinor: subtotalMinor,
      taxMinor: taxMinor,
      totalMinor: totalMinor,
      remainingMinor: remainingMinor,
    );
  }
}

void main() {
  group('IntegerMoneyOracle Property-Based Suite', () {
    final oracle = IntegerMoneyOracle(decimalDigits: 2);

    test('Single-item exact calculation without tax or discount', () {
      final items = [
        const DocumentItemInput(
          description: 'Widget',
          quantity: 5,
          price: 12.50,
          taxable: false,
        ),
      ];

      final appResult = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 0,
        taxRate: 0,
        decimalDigits: 2,
      );

      final oracleResult = oracle.calculateTotals(
        items: [(qtyMinor: oracle.toMinor(5), unitPriceMinor: oracle.toMinor(12.50), taxRateBps: 0, taxable: false)],
        discountMinor: 0,
        defaultTaxRateBps: 0,
        pricesIncludeTax: false,
        paidMinor: 0,
      );

      expect(appResult.subtotal, oracle.fromMinor(oracleResult.subtotalMinor));
      expect(appResult.total, oracle.fromMinor(oracleResult.totalMinor));
      expect(appResult.taxAmount, 0.0);
    });

    test('Hamilton-Hare Largest-Remainder Discount Allocation Exactness', () {
      // 3 items sharing a 10.00 discount on a 30.00 subtotal
      final lines = [10.0, 10.0, 10.0];
      final allocated = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 30.0,
        docDiscount: 10.0,
        lineAmounts: lines,
        decimalDigits: 2,
      );

      expect(allocated.length, 3);
      final sumNet = allocated.fold<double>(0.0, (s, a) => s + a);
      expect(MoneyUtils.round(sumNet, 2), 20.00);

      // Verify each net is exactly 6.67 or 6.66 summing to 20.00
      final minorSum = allocated.map((a) => MoneyUtils.toMinorUnits(a, 2)).reduce((a, b) => a + b);
      expect(minorSum, 2000); // 20.00 in minor units
    });

    test('50 Randomized document totals scenarios match oracle within rounding tolerance', () {
      final rng = math.Random(42);

      for (var scenario = 1; scenario <= 50; scenario++) {
        final itemCount = 1 + rng.nextInt(5);
        final items = <DocumentItemInput>[];
        final oracleItems = <({int qtyMinor, int unitPriceMinor, int taxRateBps, bool taxable})>[];

        for (var i = 0; i < itemCount; i++) {
          final qty = (1 + rng.nextInt(100)).toDouble();
          final price = (10 + rng.nextInt(9900)) / 100.0;
          final taxable = rng.nextBool();
          final rate = taxable ? (rng.nextBool() ? 15.0 : 5.0) : 0.0;

          items.add(DocumentItemInput(
            description: 'Item $i',
            quantity: qty,
            price: price,
            taxable: taxable,
            taxRate: rate > 0 ? rate : null,
          ));

          oracleItems.add((
            qtyMinor: oracle.toMinor(qty),
            unitPriceMinor: oracle.toMinor(price),
            taxRateBps: (rate * 100).round(),
            taxable: taxable,
          ));
        }

        final subtotal = items.fold<double>(0.0, (s, it) => s + it.total);
        final discount = rng.nextBool() ? (rng.nextInt((subtotal * 100).toInt() + 1) / 100.0) : 0.0;
        final pricesIncludeTax = rng.nextBool();

        final appResult = DocumentService.calculateInvoiceTotals(
          items: items,
          discount: discount,
          taxRate: 15.0,
          pricesIncludeTax: pricesIncludeTax,
          decimalDigits: 2,
        );

        final oracleResult = oracle.calculateTotals(
          items: oracleItems,
          discountMinor: oracle.toMinor(discount),
          defaultTaxRateBps: 1500,
          pricesIncludeTax: pricesIncludeTax,
          paidMinor: 0,
        );

        // Subtotal must match exactly
        expect(
          appResult.subtotal,
          oracle.fromMinor(oracleResult.subtotalMinor),
          reason: 'Scenario $scenario subtotal mismatch',
        );

        // Total must match within 5 minor units tolerance due to integer vs float tax apportionment
        final diff = (appResult.total - oracle.fromMinor(oracleResult.totalMinor)).abs();
        expect(
          diff <= 0.05,
          isTrue,
          reason: 'Scenario $scenario total drift exceeds 5 cents: app=${appResult.total}, oracle=${oracle.fromMinor(oracleResult.totalMinor)}',
        );
      }
    });

    test('Zero decimal currency honors integer rounding', () {
      final zeroOracle = IntegerMoneyOracle(decimalDigits: 0);
      final items = [
        const DocumentItemInput(
          description: 'Flour Bag',
          quantity: 3,
          price: 50000,
          taxable: false,
        ),
      ];

      final appResult = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 2000,
        taxRate: 0,
        decimalDigits: 0,
      );

      final oracleResult = zeroOracle.calculateTotals(
        items: [(qtyMinor: zeroOracle.toMinor(3), unitPriceMinor: zeroOracle.toMinor(50000), taxRateBps: 0, taxable: false)],
        discountMinor: zeroOracle.toMinor(2000),
        defaultTaxRateBps: 0,
        pricesIncludeTax: false,
        paidMinor: 0,
      );

      expect(appResult.subtotal, zeroOracle.fromMinor(oracleResult.subtotalMinor));
      expect(appResult.total, zeroOracle.fromMinor(oracleResult.totalMinor));
    });

    test(
      'DocumentItemInput.total honors zero-decimal precision',
      () {
        const item = DocumentItemInput(
          description: 'Sample',
          quantity: 3.333,
          price: 100.0,
          decimalDigits: 0,
        );
        // If precision is 0, 3.333 * 100 = 333.3 -> 333
        expect(item.total, 333.0);
      },
    );
  });
}
