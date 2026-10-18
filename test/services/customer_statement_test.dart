import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/customer_statement.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/customer_statement_service.dart';

void main() {
  const customer = Contact(id: 1, name: 'أحمد التاجر', phone: '0912345678', type: 'customer');
  final day1 = DateTime(2026, 1, 1);
  final day5 = DateTime(2026, 1, 5);
  final day10 = DateTime(2026, 1, 10);
  final day15 = DateTime(2026, 1, 15);
  final day20 = DateTime(2026, 1, 20);
  final day31 = DateTime(2026, 1, 31, 23, 59, 59);

  Document inv(
    int id,
    DateTime date, {
    required double total,
    double paid = 0.0,
    String status = DocumentStatus.issued,
    String currency = 'SDG',
    int? contactId = 1,
  }) {
    return Document(
      id: id,
      type: 'invoice',
      documentNumber: 'INV-$id',
      date: date,
      contactId: contactId,
      subtotal: total,
      discount: 0,
      taxRate: 0,
      taxAmount: 0,
      total: total,
      paid: paid,
      remaining: (total - paid).clamp(0.0, double.infinity),
      status: status,
      currencyCode: currency,
    );
  }

  Document rec(
    int id,
    DateTime date, {
    required int invoiceId,
    required double amount,
    String status = DocumentStatus.issued,
    String currency = 'SDG',
    int? contactId = 1,
  }) {
    return Document(
      id: id,
      type: 'payment_receipt',
      documentNumber: 'REC-$id',
      date: date,
      contactId: contactId,
      subtotal: amount,
      discount: 0,
      taxRate: 0,
      taxAmount: 0,
      total: amount,
      paid: amount,
      remaining: 0,
      relatedDocumentId: invoiceId,
      status: status,
      currencyCode: currency,
    );
  }

  group('CustomerStatementService - Accounting Integrity', () {
    test('1. Normal invoice with no payment', () {
      final docs = [
        inv(1, day5, total: 1000, paid: 0),
      ];

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
      );

      expect(statement.openingBalance, 0.0);
      expect(statement.entries.length, 1);
      expect(statement.entries[0].type, StatementEntryType.invoice);
      expect(statement.entries[0].debit, 1000.0);
      expect(statement.entries[0].credit, 0.0);
      expect(statement.entries[0].runningBalance, 1000.0);
      expect(statement.totalInvoiced, 1000.0);
      expect(statement.totalPaid, 0.0);
      expect(statement.closingBalance, 1000.0);
      expect(statement.closingBalance, docs[0].remaining);
    });

    test('2. Invoice with initial down-payment at creation time', () {
      final docs = [
        inv(1, day5, total: 1000, paid: 200, status: DocumentStatus.partiallyPaid),
      ];

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
      );

      expect(statement.openingBalance, 0.0);
      expect(statement.entries.length, 2);
      // Deterministic sort: invoice debit first, then initial payment credit
      expect(statement.entries[0].type, StatementEntryType.invoice);
      expect(statement.entries[0].debit, 1000.0);
      expect(statement.entries[0].runningBalance, 1000.0);

      expect(statement.entries[1].type, StatementEntryType.initialPayment);
      expect(statement.entries[1].credit, 200.0);
      expect(statement.entries[1].runningBalance, 800.0);

      expect(statement.totalInvoiced, 1000.0);
      expect(statement.totalPaid, 200.0);
      expect(statement.closingBalance, 800.0);
      expect(statement.closingBalance, docs[0].remaining);
    });

    test('3. One or more subsequent receipts', () {
      final docs = [
        inv(1, day5, total: 1000, paid: 700, status: DocumentStatus.partiallyPaid),
        rec(10, day10, invoiceId: 1, amount: 300),
        rec(11, day15, invoiceId: 1, amount: 200),
      ];
      // initialPaid = 700 - (300 + 200) = 200

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
      );

      expect(statement.openingBalance, 0.0);
      expect(statement.entries.length, 4);

      // Entry 0: Invoice 1000 (day 5)
      expect(statement.entries[0].type, StatementEntryType.invoice);
      expect(statement.entries[0].debit, 1000.0);
      expect(statement.entries[0].runningBalance, 1000.0);

      // Entry 1: Initial Payment 200 (day 5)
      expect(statement.entries[1].type, StatementEntryType.initialPayment);
      expect(statement.entries[1].credit, 200.0);
      expect(statement.entries[1].runningBalance, 800.0);

      // Entry 2: Receipt 10 (day 10, amount 300)
      expect(statement.entries[2].type, StatementEntryType.receipt);
      expect(statement.entries[2].credit, 300.0);
      expect(statement.entries[2].runningBalance, 500.0);

      // Entry 3: Receipt 11 (day 15, amount 200)
      expect(statement.entries[3].type, StatementEntryType.receipt);
      expect(statement.entries[3].credit, 200.0);
      expect(statement.entries[3].runningBalance, 300.0);

      expect(statement.totalInvoiced, 1000.0);
      expect(statement.totalPaid, 700.0);
      expect(statement.closingBalance, 300.0);
      expect(statement.closingBalance, docs[0].remaining);
    });

    test('4. Period boundary and Opening Balance calculation', () {
      final docs = [
        inv(1, day5, total: 1000, paid: 500, status: DocumentStatus.partiallyPaid),
        rec(10, day10, invoiceId: 1, amount: 300), // Day 10 (before period)
        rec(11, day20, invoiceId: 1, amount: 200), // Day 20 (inside period)
      ];
      // initialPaid = 500 - (300 + 200) = 0.
      // Prior transactions (before day 15):
      // - Invoice 1000 on day 5 (debit 1000)
      // - Receipt 10 on day 10 (credit 300)
      // Opening Balance on day 15 = 1000 - 300 = 700.

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day15,
        to: day31,
      );

      expect(statement.openingBalance, 700.0);
      expect(statement.entries.length, 1); // Only Receipt 11 is in period [day15, day31]
      expect(statement.entries[0].type, StatementEntryType.receipt);
      expect(statement.entries[0].credit, 200.0);
      expect(statement.entries[0].runningBalance, 500.0); // 700 - 200 = 500
      expect(statement.closingBalance, 500.0);
      expect(statement.closingBalance, docs[0].remaining);
    });

    test('5. Draft and cancelled invoices are strictly excluded', () {
      final docs = [
        inv(1, day5, total: 1000, paid: 0, status: DocumentStatus.draft),
        inv(2, day10, total: 2000, paid: 0, status: DocumentStatus.cancelled),
        inv(3, day15, total: 500, paid: 0, status: DocumentStatus.issued),
      ];

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
      );

      expect(statement.openingBalance, 0.0);
      expect(statement.entries.length, 1);
      expect(statement.entries[0].documentNumber, 'INV-3');
      expect(statement.entries[0].debit, 500.0);
      expect(statement.closingBalance, 500.0);
      expect(statement.closingBalance, docs[2].remaining);
    });

    test('6. Cancelled receipt is excluded from active payments', () {
      final docs = [
        inv(1, day5, total: 1000, paid: 0, status: DocumentStatus.issued),
        rec(10, day10, invoiceId: 1, amount: 400, status: DocumentStatus.cancelled),
      ];

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
      );

      expect(statement.entries.length, 1);
      expect(statement.entries[0].type, StatementEntryType.invoice);
      expect(statement.closingBalance, 1000.0);
      expect(statement.closingBalance, docs[0].remaining);
    });

    test('7. Active receipts linked to cancelled invoices are moved to explanatory section', () {
      final docs = [
        inv(1, day5, total: 1000, paid: 400, status: DocumentStatus.cancelled),
        rec(10, day10, invoiceId: 1, amount: 400, status: DocumentStatus.issued),
        inv(2, day15, total: 600, paid: 0, status: DocumentStatus.issued),
      ];

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
      );

      // Main calculation: Invoice 1 is cancelled, so its debit and receipt 10 are excluded from balance!
      // Only Invoice 2 (600) is in main balance.
      expect(statement.entries.length, 1);
      expect(statement.entries[0].documentNumber, 'INV-2');
      expect(statement.closingBalance, 600.0);
      expect(statement.closingBalance, docs[2].remaining);

      // Explanatory section: Receipt 10 is listed for audit transparency
      expect(statement.hasCancelledInvoiceReceipts, isTrue);
      expect(statement.cancelledInvoiceReceipts.length, 1);
      expect(statement.cancelledInvoiceReceipts[0].receiptNumber, 'REC-10');
      expect(statement.cancelledInvoiceReceipts[0].amount, 400.0);
      expect(statement.cancelledInvoiceReceipts[0].cancelledInvoiceNumber, 'INV-1');
    });

    test('8. Multi-currency isolation', () {
      final docs = [
        inv(1, day5, total: 100000, paid: 20000, currency: 'SDG'),
        inv(2, day10, total: 500, paid: 100, currency: 'USD'),
      ];

      final sdgStatement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
        currencyCode: 'SDG',
      );

      expect(sdgStatement.currencyCode, 'SDG');
      expect(sdgStatement.entries.length, 2); // Invoice 1 + down payment
      expect(sdgStatement.closingBalance, 80000.0);
      expect(sdgStatement.closingBalance, docs[0].remaining);

      final usdStatement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
        currencyCode: 'USD',
      );

      expect(usdStatement.currencyCode, 'USD');
      expect(usdStatement.entries.length, 2); // Invoice 2 + down payment
      expect(usdStatement.closingBalance, 400.0);
      expect(usdStatement.closingBalance, docs[1].remaining);
    });

    test('9. Inconsistent records (paid < sum(receipts)) with reconciliation adjustment', () {
      // User edited invoice and lowered paid to 200, but active receipts total 500!
      // initialPaid = 200 - 500 = -300.
      final docs = [
        inv(1, day5, total: 1000, paid: 200, status: DocumentStatus.partiallyPaid),
        rec(10, day10, invoiceId: 1, amount: 500),
      ];
      // In database, doc.remaining = 1000 - 200 = 800.

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
      );

      // Must detect discrepancy warning
      expect(statement.hasDiscrepancy, isTrue);
      expect(statement.warnings.length, 1);
      expect(statement.warnings[0].invoiceNumber, 'INV-1');
      expect(statement.warnings[0].storedPaid, 200.0);
      expect(statement.warnings[0].receiptsTotal, 500.0);
      expect(statement.warnings[0].discrepancy, 300.0);

      // Must NOT clamp to zero! Adds explicit debit reconciliation adjustment of 300:
      // Entries:
      // 0: Invoice 1000 (Debit) -> Balance: 1000
      // 1: Adjustment 300 (Debit) -> Balance: 1300
      // 2: Receipt 500 (Credit) -> Balance: 800
      expect(statement.entries.length, 3);
      expect(statement.entries[0].type, StatementEntryType.invoice);
      expect(statement.entries[0].debit, 1000.0);

      expect(statement.entries[1].type, StatementEntryType.reconciliationAdjustment);
      expect(statement.entries[1].debit, 300.0);
      expect(statement.entries[1].isAdjustment, isTrue);

      expect(statement.entries[2].type, StatementEntryType.receipt);
      expect(statement.entries[2].credit, 500.0);

      // Invariant: closingBalance must reconcile to stored invoice.remaining (800)
      expect(statement.closingBalance, 800.0);
      expect(statement.closingBalance, docs[0].remaining);
    });

    test('10. Deterministic tie-breaking for identical timestamps', () {
      // Invoice and payment at the exact same millisecond
      final timestamp = DateTime(2026, 1, 10, 14, 30, 0);
      final docs = [
        inv(1, timestamp, total: 500, paid: 500, status: DocumentStatus.paid),
      ];

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
      );

      expect(statement.entries.length, 2);
      // Invoice (debit) must appear strictly before payment (credit)
      expect(statement.entries[0].debit > 0, isTrue);
      expect(statement.entries[0].runningBalance, 500.0);
      expect(statement.entries[1].credit > 0, isTrue);
      expect(statement.entries[1].runningBalance, 0.0);
    });

    test('11. Available currencies detector', () {
      final docs = [
        inv(1, day5, total: 100, currency: 'SDG'),
        inv(2, day10, total: 200, currency: 'USD'),
        inv(3, day15, total: 300, currency: 'SAR'),
        inv(4, day20, total: 400, currency: 'SDG'),
      ];

      final currencies = CustomerStatementService.getAvailableCurrencies(docs);
      expect(currencies, ['SAR', 'SDG', 'USD']);
    });
  });
}
