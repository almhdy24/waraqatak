import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/customer_statement.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/posting_service.dart';
import 'package:warqatek/services/customer_statement_service.dart';

void main() {
  group('ACC-09: Customer Advances & Deposits (Account 2130)', () {
    test('1. Standalone customer advance receipt credits Account 2130 (Customer Deposits) and preserves contactId', () {
      final receiptDoc = Document(
        id: 1,
        type: 'payment_receipt',
        documentNumber: 'REC-ADV-001',
        date: DateTime(2026, 3, 1),
        contactId: 42,
        subtotal: 5000.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 5000.0,
        paid: 5000.0,
        remaining: 0.0,
        paymentMethod: 'cash',
        status: DocumentStatus.issued,
        currencyCode: 'SDG',
        notes: 'Customer deposit advance for future order',
      );

      final drafts = PostingService.postDocumentIssued(
        doc: receiptDoc,
        items: const [],
        products: const {},
        origin: 'receipt',
        nextEntryNo: (prefix) => '$prefix-001',
      );

      expect(drafts, isNotEmpty);
      final recEntry = drafts.first;
      expect(recEntry.lines.length, 2);

      final drLine = recEntry.lines.firstWhere((l) => l.debitMinor > 0);
      final crLine = recEntry.lines.firstWhere((l) => l.creditMinor > 0);

      // Debit Cash 1110, Credit Customer Deposits 2130
      expect(drLine.accountCode, equals(Accounts.cash.code));
      expect(drLine.debitMinor, equals(500000));

      expect(crLine.accountCode, equals(Accounts.customerDeposits.code)); // 2130
      expect(crLine.creditMinor, equals(500000));
      expect(crLine.contactId, equals(42));

      // Invariant: Debit == Credit exactly
      expect(drLine.debitMinor, equals(crLine.creditMinor));

      // Parity with derived reference ledger
      final derivedEntries = LedgerBuilder.build(
        LedgerInput(
          documents: [receiptDoc],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
          payments: const [],
        ),
      );
      expect(derivedEntries, isNotEmpty);
      final derivedCreditLine = derivedEntries.first.lines.firstWhere((l) => l.credit > 0);
      expect(derivedCreditLine.account.code, equals(Accounts.customerDeposits.code));
      expect(derivedCreditLine.contactId, equals(42));
    });

    test('2. Unallocated receipt with no customer credits Account 4900 (Other Income)', () {
      final genericReceipt = Document(
        id: 2,
        type: 'payment_receipt',
        documentNumber: 'REC-GEN-001',
        date: DateTime(2026, 3, 2),
        contactId: null,
        subtotal: 100.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 100.0,
        paid: 100.0,
        remaining: 0.0,
        paymentMethod: 'cash',
        status: DocumentStatus.issued,
        currencyCode: 'SDG',
      );

      final drafts = PostingService.postDocumentIssued(
        doc: genericReceipt,
        items: const [],
        products: const {},
        origin: 'receipt',
        nextEntryNo: (prefix) => '$prefix-002',
      );

      final crLine = drafts.first.lines.firstWhere((l) => l.creditMinor > 0);
      expect(crLine.accountCode, equals(Accounts.otherIncome.code)); // 4900
    });

    test('3. Allocated receipt credits Account 1130 (Accounts Receivable)', () {
      final allocatedReceipt = Document(
        id: 3,
        type: 'payment_receipt',
        documentNumber: 'REC-ALLOC-001',
        date: DateTime(2026, 3, 3),
        contactId: 42,
        subtotal: 200.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 200.0,
        paid: 200.0,
        remaining: 0.0,
        paymentMethod: 'cash',
        status: DocumentStatus.issued,
        currencyCode: 'SDG',
      );

      final drafts = PostingService.postDocumentIssued(
        doc: allocatedReceipt,
        items: const [],
        products: const {},
        isAllocated: true,
        origin: 'receipt',
        nextEntryNo: (prefix) => '$prefix-003',
      );

      final crLine = drafts.first.lines.firstWhere((l) => l.creditMinor > 0);
      expect(crLine.accountCode, equals(Accounts.receivables.code)); // 1130
    });

    test('4. Receipt on cancelled invoice credits Account 2130 (Customer Deposits)', () {
      final parentInvoice = Document(
        id: 10,
        type: 'invoice',
        documentNumber: 'INV-CANCELLED-001',
        date: DateTime(2026, 3, 4),
        contactId: 42,
        subtotal: 1000.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 1000.0,
        paid: 1000.0,
        remaining: 0.0,
        paymentMethod: 'cash',
        status: DocumentStatus.cancelled,
        currencyCode: 'SDG',
      );

      final linkedReceipt = Document(
        id: 4,
        type: 'payment_receipt',
        documentNumber: 'REC-CANCELLED-001',
        date: DateTime(2026, 3, 4),
        contactId: 42,
        relatedDocumentId: 10,
        subtotal: 1000.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 1000.0,
        paid: 1000.0,
        remaining: 0.0,
        paymentMethod: 'cash',
        status: DocumentStatus.issued,
        currencyCode: 'SDG',
      );

      final drafts = PostingService.postDocumentIssued(
        doc: linkedReceipt,
        items: const [],
        products: const {},
        parentDoc: parentInvoice,
        origin: 'receipt',
        nextEntryNo: (prefix) => '$prefix-004',
      );

      final crLine = drafts.first.lines.firstWhere((l) => l.creditMinor > 0);
      expect(crLine.accountCode, equals(Accounts.customerDeposits.code)); // 2130
    });

    test('5. CustomerStatementService includes unallocated advance deposits as credit entries', () {
      final advanceReceipt = Document(
        id: 5,
        type: 'payment_receipt',
        documentNumber: 'REC-ADV-005',
        date: DateTime(2026, 3, 5),
        contactId: 42,
        subtotal: 300.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 300.0,
        paid: 300.0,
        remaining: 0.0,
        paymentMethod: 'cash',
        status: DocumentStatus.issued,
        currencyCode: 'SDG',
      );

      final statement = CustomerStatementService.generateStatement(
        contact: const Contact(id: 42, name: 'عميل الدفعة المقدمة', type: 'customer'),
        documents: [advanceReceipt],
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        businessCurrencyCode: 'SDG',
        payments: const [],
      );

      expect(statement.entries, isNotEmpty);
      final entry = statement.entries.first;
      expect(entry.type, equals(StatementEntryType.receipt));
      expect(entry.credit, equals(300.0));
      expect(statement.closingBalance, equals(-300.0)); // Credit balance in customer's favor
    });
  });
}
