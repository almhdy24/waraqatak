import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/payment_allocator.dart';

void main() {
  group('PaymentAllocator.planFifo (Pure Unit Tests)', () {
    const d1 = OpenDocumentBalance(id: 1, remaining: 100.0);
    const d2 = OpenDocumentBalance(id: 2, remaining: 200.0);
    const d3 = OpenDocumentBalance(id: 3, remaining: 300.0);

    test('open [100, 200, 300] with amount 250 -> allocations (id1:100, id2:150)', () {
      final allocs = PaymentAllocator.planFifo(
        open: [d1, d2, d3],
        amount: 250.0,
        decimalDigits: 2,
      );
      expect(allocs.length, 2);
      expect(allocs[0].documentId, 1);
      expect(allocs[0].amount, 100.0);
      expect(allocs[1].documentId, 2);
      expect(allocs[1].amount, 150.0);
    });

    test('amount 600 -> three allocations of 100, 200, 300', () {
      final allocs = PaymentAllocator.planFifo(
        open: [d1, d2, d3],
        amount: 600.0,
        decimalDigits: 2,
      );
      expect(allocs.length, 3);
      expect(allocs[0].documentId, 1);
      expect(allocs[0].amount, 100.0);
      expect(allocs[1].documentId, 2);
      expect(allocs[1].amount, 200.0);
      expect(allocs[2].documentId, 3);
      expect(allocs[2].amount, 300.0);
    });

    test("amount 601 -> throws 'Payment exceeds outstanding balance'", () {
      expect(
        () => PaymentAllocator.planFifo(
          open: [d1, d2, d3],
          amount: 601.0,
          decimalDigits: 2,
        ),
        throwsA(
          isA<PaymentAllocationException>().having(
            (e) => e.message,
            'message',
            'Payment exceeds outstanding balance',
          ),
        ),
      );
    });

    test("empty list -> throws 'No open documents for this contact'", () {
      expect(
        () => PaymentAllocator.planFifo(
          open: [],
          amount: 100.0,
          decimalDigits: 2,
        ),
        throwsA(
          isA<PaymentAllocationException>().having(
            (e) => e.message,
            'message',
            'No open documents for this contact',
          ),
        ),
      );
    });

    test('documents with remaining 0 are skipped', () {
      const dZero = OpenDocumentBalance(id: 4, remaining: 0.0);
      final allocs = PaymentAllocator.planFifo(
        open: [dZero, d1],
        amount: 50.0,
        decimalDigits: 2,
      );
      expect(allocs.length, 1);
      expect(allocs[0].documentId, 1);
      expect(allocs[0].amount, 50.0);
    });

    test('amount 0.1 + 0.2 style rounding: open [0.3], amount 0.1+0.2 -> one allocation of 0.3, no exception', () {
      const dPointThree = OpenDocumentBalance(id: 10, remaining: 0.3);
      final allocs = PaymentAllocator.planFifo(
        open: [dPointThree],
        amount: 0.1 + 0.2,
        decimalDigits: 2,
      );
      expect(allocs.length, 1);
      expect(allocs[0].documentId, 10);
      expect(allocs[0].amount, 0.3);
    });

    test('amount <= 0 -> throws', () {
      expect(
        () => PaymentAllocator.planFifo(
          open: [d1],
          amount: 0.0,
          decimalDigits: 2,
        ),
        throwsA(
          isA<PaymentAllocationException>().having(
            (e) => e.message,
            'message',
            'Payment amount must be greater than zero',
          ),
        ),
      );
      expect(
        () => PaymentAllocator.planFifo(
          open: [d1],
          amount: -10.0,
          decimalDigits: 2,
        ),
        throwsA(isA<PaymentAllocationException>()),
      );
    });
  });
}
