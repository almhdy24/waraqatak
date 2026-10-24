import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/currency.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/pos_cart.dart';
import 'package:warqatek/utils/money_utils.dart';

void main() {
  group('MoneyUtils Canonical Monetary Precision', () {
    test('standard financial round-half-up with IEEE 754 precision adjustment', () {
      expect(MoneyUtils.round(103.33333333333333), 103.33);
      expect(MoneyUtils.round(66.66999999999999), 66.67);
      expect(MoneyUtils.round(0.00333333333333), 0.0);
      expect(MoneyUtils.round(33.335), 33.34);
      expect(MoneyUtils.round(33.334), 33.33);
      expect(MoneyUtils.round(0.005), 0.01);
      expect(MoneyUtils.round(0.004), 0.0);
      expect(MoneyUtils.round(-0.0), 0.0);

      // IEEE 754 binary edge cases where float is stored slightly below .005
      expect(MoneyUtils.round(1.005), 1.01);
      expect(MoneyUtils.round(2.005), 2.01);
      expect(MoneyUtils.round(10.055), 10.06);
      expect(MoneyUtils.round(12.345), 12.35);
    });

    test('minor units conversion and bidirectional preservation', () {
      expect(MoneyUtils.toMinorUnits(103.33), 10333);
      expect(MoneyUtils.fromMinorUnits(10333), 103.33);
      expect(MoneyUtils.toMinorUnits(0.05), 5);
      expect(MoneyUtils.fromMinorUnits(5), 0.05);
      expect(MoneyUtils.toMinorUnits(0.0), 0);
      expect(MoneyUtils.fromMinorUnits(0), 0.0);
    });

    test('overpayment detection avoids false positives on float jitter and catches real overpayments', () {
      // Exact payment
      expect(MoneyUtils.isOverpayment(100.0, 100.0), isFalse);
      // Binary float jitter (e.g. remaining stored as 66.66999999999999)
      expect(MoneyUtils.isOverpayment(66.67, 66.66999999999999), isFalse);
      expect(MoneyUtils.isOverpayment(33.34000000000001, 33.34), isFalse);

      // Genuine overpayment of 1 minor unit (0.01) must be strictly detected
      expect(MoneyUtils.isOverpayment(66.68, 66.67), isTrue);
      expect(MoneyUtils.isOverpayment(100.01, 100.0), isTrue);
      expect(MoneyUtils.isOverpayment(0.01, 0.0), isTrue);
    });

    test('calculateRemaining clamps to zero and rounds to minor units', () {
      expect(MoneyUtils.calculateRemaining(100.0, 33.33), 66.67);
      expect(MoneyUtils.calculateRemaining(103.33333333333333, 103.33), 0.0);
      expect(MoneyUtils.calculateRemaining(50.0, 50.0), 0.0);
      expect(MoneyUtils.calculateRemaining(50.0, 60.0), 0.0); // clamped
    });

    test('isPaidInFull matches minor units equality', () {
      expect(MoneyUtils.isPaidInFull(100.0, 100.0), isTrue);
      expect(MoneyUtils.isPaidInFull(103.33, 103.33333333333333), isTrue);
      expect(MoneyUtils.isPaidInFull(99.99, 100.0), isFalse);
    });

    test('custom decimal digits support for 3-decimal and 0-decimal currencies', () {
      // 3 decimals (e.g., KWD / BHD / OMR)
      expect(MoneyUtils.round(12.3456, 3), 12.346);
      expect(MoneyUtils.toMinorUnits(12.345, 3), 12345);
      expect(MoneyUtils.fromMinorUnits(12345, 3), 12.345);
      expect(MoneyUtils.isOverpayment(12.346, 12.345, 3), isTrue);
      expect(MoneyUtils.isOverpayment(12.345, 12.345, 3), isFalse);

      // 0 decimals (e.g., JPY)
      expect(MoneyUtils.round(1500.6, 0), 1501.0);
      expect(MoneyUtils.toMinorUnits(1500.0, 0), 1500);
      expect(MoneyUtils.isOverpayment(1501.0, 1500.0, 0), isTrue);

      // Currency model decimal digits resolver
      expect(Currency.decimalDigitsForCode('SDG'), 2);
      expect(Currency.decimalDigitsForCode('SAR'), 2);
      expect(Currency.decimalDigitsForCode('USD'), 2);
      expect(Currency.decimalDigitsForCode(''), 2);
      expect(Currency.decimalDigitsForCode(null), 2);
    });
  });

  group('DocumentStatus.fromPayment Canonical Precision', () {
    test('exact payment produces paid status', () {
      expect(DocumentStatus.fromPayment(100.0, 100.0), DocumentStatus.paid);
      expect(DocumentStatus.fromPayment(103.33, 103.33), DocumentStatus.paid);
    });

    test('displayed payment against unrounded float total resolves to paid', () {
      // Total has recurring float 103.33333333333333, user pays displayed 103.33
      expect(
        DocumentStatus.fromPayment(103.33, 103.33333333333333),
        DocumentStatus.paid,
      );
      // Remaining was 66.66999999999999, user paid 66.67
      expect(
        DocumentStatus.fromPayment(66.67, 66.66999999999999),
        DocumentStatus.paid,
      );
    });

    test('partial payment produces partiallyPaid', () {
      expect(DocumentStatus.fromPayment(33.33, 100.0), DocumentStatus.partiallyPaid);
      expect(DocumentStatus.fromPayment(0.01, 100.0), DocumentStatus.partiallyPaid);
    });

    test('zero payment produces issued', () {
      expect(DocumentStatus.fromPayment(0.0, 100.0), DocumentStatus.issued);
      // Below half of 1 minor unit (0.004) rounds to 0 -> issued
      expect(DocumentStatus.fromPayment(0.004, 100.0), DocumentStatus.issued);
    });

    test('zero-total document is paid when paid == 0', () {
      expect(DocumentStatus.fromPayment(0.0, 0.0), DocumentStatus.paid);
    });
  });

  group('Invoice Calculations & Fractional Tax Scenarios', () {
    test('fractional tax amount yields rounded totals and allows exact settlement', () {
      // 1 item @ 100.00 with 3.333% tax
      final totals = DocumentService.calculateInvoiceTotals(
        items: [
          const DocumentItemInput(description: 'Service', quantity: 1, price: 100.0),
        ],
        discount: 0,
        taxRate: 3.333,
        pricesIncludeTax: false,
      );

      // Tax = 100 * 3.333% = 3.333 -> rounded to 3.33
      expect(totals.subtotal, 100.0);
      expect(totals.taxAmount, 3.33);
      expect(totals.total, 103.33);

      // User pays displayed total 103.33
      final paid = 103.33;
      final remaining = MoneyUtils.calculateRemaining(totals.total, paid);
      final status = DocumentStatus.fromPayment(paid, totals.total);

      expect(remaining, 0.0);
      expect(status, DocumentStatus.paid);
    });

    test('partial payment followed by displayed remaining balance settles to zero', () {
      const total = 100.0;
      // Step 1: User pays 33.33
      const firstPayment = 33.33;
      final remainingAfterFirst = MoneyUtils.calculateRemaining(total, firstPayment);
      final statusAfterFirst = DocumentStatus.fromPayment(firstPayment, total);

      expect(remainingAfterFirst, 66.67);
      expect(statusAfterFirst, DocumentStatus.partiallyPaid);

      // Step 2: User pays displayed remaining balance (66.67)
      const secondPayment = 66.67;
      expect(MoneyUtils.isOverpayment(secondPayment, remainingAfterFirst), isFalse);

      final totalPaid = MoneyUtils.round(firstPayment + secondPayment);
      final remainingFinal = MoneyUtils.calculateRemaining(total, totalPaid);
      final statusFinal = DocumentStatus.fromPayment(totalPaid, total);

      expect(totalPaid, 100.0);
      expect(remainingFinal, 0.0);
      expect(statusFinal, DocumentStatus.paid);
    });

    test('genuine overpayment is strictly rejected by policy', () {
      const remaining = 66.67;
      // Attempt to pay 66.68
      expect(MoneyUtils.isOverpayment(66.68, remaining), isTrue);
      // Attempt to pay 70.00
      expect(MoneyUtils.isOverpayment(70.0, remaining), isTrue);
    });

    test('repeated fractional payments settle document exactly without residual drift', () {
      const total = 100.0;
      var remaining = total;
      var cumulativePaid = 0.0;

      final payments = [33.33, 33.33, 33.34];
      for (final p in payments) {
        expect(MoneyUtils.isOverpayment(p, remaining), isFalse);
        cumulativePaid = MoneyUtils.round(cumulativePaid + p);
        remaining = MoneyUtils.calculateRemaining(total, cumulativePaid);
      }

      expect(cumulativePaid, 100.0);
      expect(remaining, 0.0);
      expect(DocumentStatus.fromPayment(cumulativePaid, total), DocumentStatus.paid);
    });

    test('multi-line tax-exclusive invoice with fractional splits', () {
      final items = [
        const DocumentItemInput(description: 'Line 1', quantity: 3, price: 33.33), // 99.99
        const DocumentItemInput(description: 'Line 2', quantity: 1, price: 10.01), // 10.01
      ];
      final totals = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 5.0,
        taxRate: 15.0,
        pricesIncludeTax: false,
      );

      // Subtotal = 99.99 + 10.01 = 110.00
      // Discount = 5.00 -> Net base = 105.00
      // Tax = 105.00 * 15% = 15.75
      // Total = 105.00 + 15.75 = 120.75
      expect(totals.subtotal, 110.0);
      expect(totals.taxAmount, 15.75);
      expect(totals.total, 120.75);
    });

    test('multi-line tax-inclusive invoice with embedded tax extraction', () {
      final items = [
        const DocumentItemInput(description: 'Item 1', quantity: 1, price: 115.0),
        const DocumentItemInput(description: 'Item 2', quantity: 2, price: 57.50), // 115.0
      ];
      final totals = DocumentService.calculateInvoiceTotals(
        items: items,
        discount: 30.0,
        taxRate: 15.0,
        pricesIncludeTax: true,
      );

      // Subtotal = 115 + 115 = 230.00
      // Discount = 30.00 -> Total = 200.00
      // Tax extracted from 200.00 @ 15%: 200 * 15 / 115 = 26.0869... -> 26.09
      expect(totals.subtotal, 230.0);
      expect(totals.taxAmount, 26.09);
      expect(totals.total, 200.0);
    });

    test('discounts combined with tax and fractional quantities', () {
      // 2.5 kg @ $15.50 = $38.75
      const item = DocumentItemInput(description: 'Bulk item', quantity: 2.5, price: 15.50);
      expect(item.total, 38.75);

      final totals = DocumentService.calculateInvoiceTotals(
        items: [item],
        discount: 8.75, // Net base = 30.00
        taxRate: 10.0,
        pricesIncludeTax: false,
      );

      // Tax = 30.00 * 10% = 3.00
      // Total = 30.00 + 3.00 = 33.00
      expect(totals.subtotal, 38.75);
      expect(totals.taxAmount, 3.00);
      expect(totals.total, 33.00);
    });

    test('PosCart change calculation never returns negative or jittered cents', () {
      expect(PosCart.changeFor(total: 103.33, received: 103.33), 0.0);
      expect(PosCart.changeFor(total: 103.33, received: 103.33000000000001), 0.0);
      expect(PosCart.changeFor(total: 103.33, received: 105.0), 1.67);
      expect(PosCart.changeFor(total: 103.33, received: 100.0), 0.0);
    });
  });

  group('Document & DocumentItem Model Serialization Round-Trip', () {
    test('preserves monetary totals and decimal values exactly', () {
      final doc = Document(
        id: 42,
        type: 'invoice',
        documentNumber: 'INV-0042',
        date: DateTime.parse('2026-10-24T10:00:00Z'),
        subtotal: 110.0,
        discount: 5.0,
        taxRate: 15.0,
        taxAmount: 15.75,
        total: 120.75,
        paid: 120.75,
        remaining: 0.0,
        status: DocumentStatus.paid,
        currencyCode: 'SAR',
      );

      final map = doc.toMap();
      final restored = Document.fromMap(map);

      expect(restored.id, 42);
      expect(restored.subtotal, 110.0);
      expect(restored.discount, 5.0);
      expect(restored.taxAmount, 15.75);
      expect(restored.total, 120.75);
      expect(restored.paid, 120.75);
      expect(restored.remaining, 0.0);
      expect(restored.status, DocumentStatus.paid);
      expect(restored.currencyCode, 'SAR');
    });

    test('DocumentItem serialization round-trip with line total and cost', () {
      const item = DocumentItem(
        id: 1,
        documentId: 42,
        description: 'Test Item',
        quantity: 2.5,
        price: 15.50,
        total: 38.75,
        taxable: true,
        taxRate: 10.0,
        unitCost: 10.0,
        totalCost: 25.0,
      );

      final map = item.toMap();
      final restored = DocumentItem.fromMap(map);

      expect(restored.quantity, 2.5);
      expect(restored.price, 15.50);
      expect(restored.total, 38.75);
      expect(restored.taxRate, 10.0);
      expect(restored.unitCost, 10.0);
      expect(restored.totalCost, 25.0);
    });
  });

  group('Phase 2: Document Discount Allocation & Product Performance Net Revenue Reconciliation', () {
    test('equal line items split document discount equally', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 200.0,
        docDiscount: 50.0,
        lineAmounts: [100.0, 100.0],
      );

      expect(netRevenues, [75.0, 75.0]);
      expect(netRevenues.fold(0.0, (a, b) => a + b), 150.0);
    });

    test('proportional discount allocation across unequal lines', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 300.0,
        docDiscount: 60.0,
        lineAmounts: [100.0, 200.0],
      );

      expect(netRevenues, [80.0, 160.0]);
      expect(netRevenues.fold(0.0, (a, b) => a + b), 240.0);
    });

    test('Hamilton-Hare largest-remainder preserves exact total on rounding residuals', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 30.0,
        docDiscount: 10.0,
        lineAmounts: [10.0, 10.0, 10.0],
      );

      expect(netRevenues, [6.66, 6.67, 6.67]);
      final sum = MoneyUtils.round(netRevenues.fold(0.0, (a, b) => a + b));
      expect(sum, 20.00);
    });

    test('zero document subtotal is safely handled without division by zero', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 0.0,
        docDiscount: 10.0,
        lineAmounts: [0.0, 0.0],
      );

      expect(netRevenues, [0.0, 0.0]);
      expect(netRevenues.fold(0.0, (a, b) => a + b), 0.0);
    });

    test('fully discounted document yields exactly zero net revenue for all lines', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 200.0,
        docDiscount: 200.0,
        lineAmounts: [120.0, 80.0],
      );

      expect(netRevenues, [0.0, 0.0]);
      expect(netRevenues.fold(0.0, (a, b) => a + b), 0.0);
    });

    test('over-discounted document clamps discount to subtotal and yields zero net revenue', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 150.0,
        docDiscount: 200.0,
        lineAmounts: [100.0, 50.0],
      );

      expect(netRevenues, [0.0, 0.0]);
      expect(netRevenues.fold(0.0, (a, b) => a + b), 0.0);
    });

    test('fractional line amounts with penny remainder reconcile exactly to doc net total', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 100.0,
        docDiscount: 25.0,
        lineAmounts: [33.33, 33.33, 33.34],
      );

      final totalNet = MoneyUtils.round(netRevenues.fold(0.0, (a, b) => a + b));
      expect(totalNet, 75.0);
    });

    test('3-decimal currency discount allocation reconciles exactly to millimes', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 30.0,
        docDiscount: 5.0,
        lineAmounts: [10.0, 20.0],
        decimalDigits: 3,
      );

      expect(netRevenues, [8.333, 16.667]);
      final sum = MoneyUtils.round(netRevenues.fold(0.0, (a, b) => a + b), 3);
      expect(sum, 25.0);
    });

    test('0-decimal currency discount allocation reconciles without decimals', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 3000.0,
        docDiscount: 500.0,
        lineAmounts: [1000.0, 2000.0],
        decimalDigits: 0,
      );

      expect(netRevenues, [833.0, 1667.0]);
      final sum = netRevenues.fold(0.0, (a, b) => a + b);
      expect(sum, 2500.0);
    });

    test('1. Two 50,000,000 SDG lines with 50,000,000 SDG discount allocates 25,000,000 per line without 64-bit int overflow', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 100000000.0,
        docDiscount: 50000000.0,
        lineAmounts: [50000000.0, 50000000.0],
      );

      // Product = (5e9 * 5e9) = 2.5e19, which exceeds 64-bit int max (9.22e18).
      // BigInt arithmetic safely prevents wrapping.
      expect(netRevenues, [25000000.0, 25000000.0]);
      expect(netRevenues[0], 25000000.0);
      expect(netRevenues[1], 25000000.0);
      expect(netRevenues.fold(0.0, (a, b) => a + b), 50000000.0);
    });

    test('2. Large unequal line amounts with non-zero allocation residual preserve exact minor unit sum', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 100000000.0,
        docDiscount: 10000000.0,
        lineAmounts: [33333333.33, 33333333.33, 33333333.34],
      );

      expect(netRevenues.length, 3);
      final sum = MoneyUtils.round(netRevenues.fold(0.0, (a, b) => a + b));
      expect(sum, 90000000.0);
      for (var i = 0; i < 3; i++) {
        expect(netRevenues[i] <= [33333333.33, 33333333.33, 33333333.34][i], isTrue);
      }
    });

    test('3. Deterministic largest-remainder tie-breaking for equal remainders on large amounts', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 30000000.0,
        docDiscount: 10000000.0,
        lineAmounts: [10000000.0, 10000000.0, 10000000.0],
      );

      // Discount is 10,000,000.00 / 3 = 3,333,333.3333...
      // Line index 0 wins the 1-cent residual: discount is 3,333,333.34 -> net is 6,666,666.66
      // Lines 1 and 2 get discount 3,333,333.33 -> net is 6,666,666.67
      expect(netRevenues, [6666666.66, 6666666.67, 6666666.67]);
      final sum = MoneyUtils.round(netRevenues.fold(0.0, (a, b) => a + b));
      expect(sum, 20000000.0);
    });

    test('4. Values close to supported range (trillions) calculate safely without precision loss or overflow', () {
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 1000000000000.0,
        docDiscount: 400000000000.0,
        lineAmounts: [500000000000.0, 500000000000.0],
      );

      expect(netRevenues, [300000000000.0, 300000000000.0]);
      expect(netRevenues.fold(0.0, (a, b) => a + b), 600000000000.0);
    });

    test('5. Line allocated discount never exceeds line amount even under extreme inputs', () {
      final lines = [0.01, 1000000.0, 50000000.0];
      final netRevenues = MoneyUtils.allocateDocumentDiscount(
        docSubtotal: 51000000.01,
        docDiscount: 51000000.00,
        lineAmounts: lines,
      );

      for (var i = 0; i < lines.length; i++) {
        expect(netRevenues[i] >= 0.0, isTrue);
        expect(netRevenues[i] <= lines[i], isTrue);
      }
      final sum = MoneyUtils.round(netRevenues.fold(0.0, (a, b) => a + b));
      expect(sum, 0.01);
    });
  });
}
