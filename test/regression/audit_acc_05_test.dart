import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/customer_statement.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_payment.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/customer_statement_service.dart';

void main() {
  const customer = Contact(
    id: 1,
    name: 'Customer A',
    phone: '0123456789',
    type: 'customer',
  );

  final d1 = DateTime(2026, 3, 1);
  final d2 = DateTime(2026, 3, 5);
  final dEnd = DateTime(2026, 3, 31, 23, 59, 59);

  test('ACC-05 Regression: Customer statements must include unallocated payment receipts and advances', () {
    // 1. Customer has an invoice for 500 SDG
    final invoice = Document(
      id: 1,
      type: 'invoice',
      documentNumber: 'INV-001',
      date: d1,
      contactId: customer.id,
      subtotal: 500.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 500.0,
      paid: 500.0,
      remaining: 0.0,
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );

    // 2. Customer pays 800 SDG via payment receipt REC-001 (500 allocated, 300 unallocated advance)
    final receipt = Document(
      id: 10,
      type: 'payment_receipt',
      documentNumber: 'REC-001',
      date: d2,
      contactId: customer.id,
      subtotal: 800.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 800.0,
      paid: 800.0,
      remaining: 0.0,
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );

    // 3. Modern payment rows: only 500 allocated to INV-001
    final payments = [
      DocumentPayment(
        id: 101,
        documentId: 1,
        amount: 500.0,
        date: d2,
        paymentMethod: 'cash',
        receiptDocumentId: 10,
        paymentOrigin: PaymentOrigin.receipt,
      ),
    ];

    // 4. Generate statement
    final statement = CustomerStatementService.generateStatement(
      contact: customer,
      documents: [invoice, receipt],
      payments: payments,
      from: d1,
      to: dEnd,
    );

    // ACC-05 BUG: In CustomerStatementService.generateStatement, the modern path
    // iterates strictly over eligibleInvoices. The remaining 300 SDG unallocated
    // credit on REC-001 is omitted, so closing balance reports 0.0 instead of -300.0 SDG.
    expect(
      statement.closingBalance,
      equals(-300.0),
      reason: 'ACC-05: Customer statement closing balance must reflect unallocated credit (-300.0 SDG)',
    );

    final hasUnallocatedEntry = statement.entries.any(
      (e) => e.type == StatementEntryType.receipt && (e.credit == 300.0 || (e.credit == 800.0 && e.documentNumber == 'REC-001')),
    );
    expect(
      hasUnallocatedEntry,
      isTrue,
      reason: 'ACC-05: Unallocated receipt credit must appear as an entry on customer statement',
    );
  });
}
