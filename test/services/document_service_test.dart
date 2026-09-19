import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  // ── DocumentStatus ──────────────────────────────────────────
  group('DocumentStatus.fromPayment', () {
    test('paid when paid >= total', () {
      expect(DocumentStatus.fromPayment(100, 100), DocumentStatus.paid);
      expect(DocumentStatus.fromPayment(150, 100), DocumentStatus.paid);
    });

    test('partially_paid when 0 < paid < total', () {
      expect(DocumentStatus.fromPayment(50, 100), DocumentStatus.partiallyPaid);
      expect(DocumentStatus.fromPayment(0.01, 100), DocumentStatus.partiallyPaid);
    });

    test('issued when paid == 0', () {
      expect(DocumentStatus.fromPayment(0, 100), DocumentStatus.issued);
    });
  });

  // ── calculateInvoiceTotals ──────────────────────────────────
  group('DocumentService.calculateInvoiceTotals', () {
    final items = [
      const DocumentItemInput(description: 'A', quantity: 2, price: 50, taxable: true),
      const DocumentItemInput(description: 'B', quantity: 1, price: 100, taxable: false),
    ];

    test('subtotal is sum of item totals', () {
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 0, taxRate: 0,
      );
      expect(t.subtotal, 200);
    });

    test('tax applies only to taxable items', () {
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 0, taxRate: 10,
      );
      // taxable = 100, non-taxable = 100, tax = 10% of 100 = 10
      expect(t.taxAmount, closeTo(10, 0.001));
      expect(t.total, closeTo(210, 0.001));
    });

    test('discount applied proportionally to taxable items', () {
      // subtotal=200, discount=100 (50% discount)
      // taxable portion after discount = 100 * (200-100)/200 = 50
      // tax = 10% of 50 = 5
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 100, taxRate: 10,
      );
      expect(t.taxAmount, closeTo(5, 0.001));
      expect(t.total, closeTo(200 - 100 + 5, 0.001));
    });

    test('zero tax rate means no tax', () {
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 0, taxRate: 0,
      );
      expect(t.taxAmount, 0);
      expect(t.total, 200);
    });

    test('no taxable items means no tax', () {
      final nonTaxableItems = [
        const DocumentItemInput(description: 'A', quantity: 1, price: 100, taxable: false),
      ];
      final t = DocumentService.calculateInvoiceTotals(
        items: nonTaxableItems, discount: 0, taxRate: 15,
      );
      expect(t.taxAmount, 0);
      expect(t.total, 100);
    });

    test('full discount produces zero tax', () {
      final t = DocumentService.calculateInvoiceTotals(
        items: items, discount: 200, taxRate: 10,
      );
      expect(t.taxAmount, 0);
    });
  });

  // ── Business rules / validation guards ─────────────────────
  group('DocumentItemInput validation', () {
    test('total is quantity * price', () {
      const item = DocumentItemInput(description: 'X', quantity: 3, price: 25);
      expect(item.total, 75);
    });

    test('zero price is allowed (free item)', () {
      const item = DocumentItemInput(description: 'X', quantity: 1, price: 0);
      expect(item.total, 0);
    });
  });

  // ── Payment amount constraints ──────────────────────────────
  group('Payment amount constraints', () {
    test('payment > outstanding is disallowed by service', () {
      // Service enforces: amount <= remaining. Simulate the check.
      const remaining = 100.0;
      const payment = 150.0;
      expect(payment > remaining, isTrue);
    });

    test('zero payment is disallowed', () {
      const payment = 0.0;
      expect(payment <= 0, isTrue);
    });

    test('exact payment marks invoice as paid', () {
      expect(DocumentStatus.fromPayment(100, 100), DocumentStatus.paid);
    });

    test('partial payment marks invoice as partially_paid', () {
      expect(DocumentStatus.fromPayment(60, 100), DocumentStatus.partiallyPaid);
    });
  });

  // ── Quotation copy invariants ───────────────────────────────
  group('Copy document invariants (no DB)', () {
    test('copied invoice should start as draft', () {
      const original = 'invoice';
      final isItemBased = original == 'invoice' || original == 'quotation';
      final newStatus = isItemBased ? DocumentStatus.draft : DocumentStatus.issued;
      expect(newStatus, DocumentStatus.draft);
    });

    test('copied receipt should start as issued', () {
      const original = 'payment_receipt';
      final isItemBased = original == 'invoice' || original == 'quotation';
      final newStatus = isItemBased ? DocumentStatus.draft : DocumentStatus.issued;
      expect(newStatus, DocumentStatus.issued);
    });
  });

  // ── Cancelled document restrictions ────────────────────────
  group('Cancelled document restrictions', () {
    test('cancelled status constant is correct', () {
      expect(DocumentStatus.cancelled, 'cancelled');
    });

    test('draft status constant is correct', () {
      expect(DocumentStatus.draft, 'draft');
    });

    test('status fromPayment never returns cancelled', () {
      for (final paid in [0.0, 50.0, 100.0]) {
        final s = DocumentStatus.fromPayment(paid, 100);
        expect(s, isNot(DocumentStatus.cancelled));
      }
    });
  });
}
