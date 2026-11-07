import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/customer_statement.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_payment.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/customer_statement_service.dart';

void main() {
  const customer = Contact(id: 1, name: 'مختار الطيب', phone: '0912345678', type: 'customer');
  final d1 = DateTime(2026, 3, 1);
  final d2 = DateTime(2026, 3, 5);
  final d3 = DateTime(2026, 3, 10);
  final d4 = DateTime(2026, 3, 15);
  final dEnd = DateTime(2026, 3, 31, 23, 59, 59);

  Document inv(int id, DateTime date, {required double total, double paid = 0.0, String status = DocumentStatus.issued}) {
    return Document(
      id: id,
      type: 'invoice',
      documentNumber: 'INV-$id',
      date: date,
      contactId: 1,
      subtotal: total,
      discount: 0,
      taxRate: 0,
      taxAmount: 0,
      total: total,
      paid: paid,
      remaining: (total - paid).clamp(0.0, double.infinity),
      status: status,
      currencyCode: 'SDG',
    );
  }

  Document rec(int id, DateTime date, {required double total, String status = DocumentStatus.issued}) {
    return Document(
      id: id,
      type: 'payment_receipt',
      documentNumber: 'REC-$id',
      date: date,
      contactId: 1,
      subtotal: total,
      discount: 0,
      taxRate: 0,
      taxAmount: 0,
      total: total,
      paid: total,
      remaining: 0,
      status: status,
      currencyCode: 'SDG',
    );
  }

  DocumentPayment payRow(int id, int docId, double amount, DateTime date, {int? receiptId, String origin = PaymentOrigin.receipt}) {
    return DocumentPayment(
      id: id,
      documentId: docId,
      amount: amount,
      date: date,
      receiptDocumentId: receiptId,
      paymentOrigin: origin,
    );
  }

  group('CustomerStatementService - FIFO Allocation & Multi-Target Tests', () {
    test('1. Multiple partial receipts against one invoice', () {
      final invoice = inv(10, d1, total: 1000, paid: 600);
      final r1 = rec(101, d2, total: 200);
      final r2 = rec(102, d3, total: 400);

      final payments = [
        payRow(1, 10, 200, d2, receiptId: 101),
        payRow(2, 10, 400, d3, receiptId: 102),
      ];

      final stmt = CustomerStatementService.generateStatement(
        contact: customer,
        documents: [invoice, r1, r2],
        payments: payments,
        from: d1,
        to: dEnd,
      );

      expect(stmt.entries.length, 3);
      // Entry 0: Invoice debit 1000
      expect(stmt.entries[0].type, StatementEntryType.invoice);
      expect(stmt.entries[0].debit, 1000);
      expect(stmt.entries[0].runningBalance, 1000);

      // Entry 1: REC-101 credit 200
      expect(stmt.entries[1].type, StatementEntryType.receipt);
      expect(stmt.entries[1].documentNumber, 'REC-101');
      expect(stmt.entries[1].credit, 200);
      expect(stmt.entries[1].runningBalance, 800);

      // Entry 2: REC-102 credit 400
      expect(stmt.entries[2].type, StatementEntryType.receipt);
      expect(stmt.entries[2].documentNumber, 'REC-102');
      expect(stmt.entries[2].credit, 400);
      expect(stmt.entries[2].runningBalance, 400);

      expect(stmt.closingBalance, 400);
    });

    test('2. One voucher allocated across multiple invoices', () {
      final inv1 = inv(1, d1, total: 300, paid: 300);
      final inv2 = inv(2, d2, total: 500, paid: 200);
      final rSingle = rec(50, d3, total: 500);

      // Voucher 50 settles 300 on inv1 and 200 on inv2
      final payments = [
        payRow(1, 1, 300, d3, receiptId: 50),
        payRow(2, 2, 200, d3, receiptId: 50),
      ];

      final stmt = CustomerStatementService.generateStatement(
        contact: customer,
        documents: [inv1, inv2, rSingle],
        payments: payments,
        from: d1,
        to: dEnd,
      );

      expect(stmt.entries.length, 4);
      // Invoice 1: debit 300 (balance 300)
      expect(stmt.entries[0].documentNumber, 'INV-1');
      expect(stmt.entries[0].debit, 300);
      expect(stmt.entries[0].runningBalance, 300);

      // Invoice 2: debit 500 (balance 800)
      expect(stmt.entries[1].documentNumber, 'INV-2');
      expect(stmt.entries[1].debit, 500);
      expect(stmt.entries[1].runningBalance, 800);

      // Allocation 1 to INV-1: credit 300
      expect(stmt.entries[2].documentNumber, 'REC-50');
      expect(stmt.entries[2].credit, 300);

      // Allocation 2 to INV-2: credit 200
      expect(stmt.entries[3].documentNumber, 'REC-50');
      expect(stmt.entries[3].credit, 200);

      expect(stmt.closingBalance, 300);
    });

    test('3. Reversal of a multi-allocated voucher restores balance', () {
      final inv1 = inv(1, d1, total: 300, paid: 0);
      final inv2 = inv(2, d2, total: 500, paid: 0);
      final rCancelled = rec(50, d3, total: 500, status: DocumentStatus.cancelled);

      final payments = [
        payRow(1, 1, 300, d3, receiptId: 50),
        payRow(2, 2, 200, d3, receiptId: 50),
        payRow(3, 1, -300, d4, receiptId: 50, origin: PaymentOrigin.reversal),
        payRow(4, 2, -200, d4, receiptId: 50, origin: PaymentOrigin.reversal),
      ];

      final stmt = CustomerStatementService.generateStatement(
        contact: customer,
        documents: [inv1, inv2, rCancelled],
        payments: payments,
        from: d1,
        to: dEnd,
      );

      // Debits: inv1 (300), inv2 (500), rev1 (300), rev2 (200) = 1300
      // Credits: rec1 (300), rec2 (200) = 500
      // Net closing balance = 800
      final totalDebit = stmt.entries.fold<double>(0, (sum, e) => sum + e.debit);
      final totalCredit = stmt.entries.fold<double>(0, (sum, e) => sum + e.credit);
      expect(stmt.closingBalance, 800);
      expect(totalDebit, 1300);
      expect(totalCredit, 500);
    });

    test('4. Correct upfront payment calculation and ordering', () {
      final invoice = inv(1, d1, total: 1000, paid: 400);
      final payments = [
        payRow(1, 1, 400, d1, origin: PaymentOrigin.upfront),
      ];

      final stmt = CustomerStatementService.generateStatement(
        contact: customer,
        documents: [invoice],
        payments: payments,
        from: d1,
        to: dEnd,
      );

      expect(stmt.entries.length, 2);
      expect(stmt.entries[0].type, StatementEntryType.invoice);
      expect(stmt.entries[0].debit, 1000);
      expect(stmt.entries[0].runningBalance, 1000);

      expect(stmt.entries[1].type, StatementEntryType.initialPayment);
      expect(stmt.entries[1].credit, 400);
      expect(stmt.entries[1].runningBalance, 600);
      expect(stmt.closingBalance, 600);
    });

    test('5. Historical invoices without payment rows fallback correctly', () {
      final invoice = inv(1, d1, total: 1000, paid: 350);

      // No document_payments rows
      final stmt = CustomerStatementService.generateStatement(
        contact: customer,
        documents: [invoice],
        payments: const [],
        from: d1,
        to: dEnd,
      );

      expect(stmt.entries.length, 2);
      expect(stmt.entries[0].type, StatementEntryType.invoice);
      expect(stmt.entries[0].debit, 1000);
      expect(stmt.entries[1].type, StatementEntryType.initialPayment);
      expect(stmt.entries[1].credit, 350);
      expect(stmt.closingBalance, 650);
    });

    test('6. Invariant: upfront + active allocations - reversals == paid', () {
      final invoice = inv(1, d1, total: 2000, paid: 700);
      final rActive = rec(10, d2, total: 500);
      final rCancelled = rec(20, d3, total: 300, status: DocumentStatus.cancelled);

      final payments = [
        payRow(1, 1, 200, d1, origin: PaymentOrigin.upfront),
        payRow(2, 1, 500, d2, receiptId: 10),
        payRow(3, 1, 300, d3, receiptId: 20),
        payRow(4, 1, -300, d4, receiptId: 20, origin: PaymentOrigin.reversal),
      ];

      final stmt = CustomerStatementService.generateStatement(
        contact: customer,
        documents: [invoice, rActive, rCancelled],
        payments: payments,
        from: d1,
        to: dEnd,
      );

      // Upfront (200) + active (500) + cancelled (300) = 1000 credits
      // Reversals = 300 debits
      // Net paid effect = 1000 - 300 = 700 == invoice.paid
      expect(stmt.closingBalance, 1300); // 2000 - 700 = 1300 remaining
    });
  });
}
