import 'contact.dart';
import 'currency.dart';

enum StatementEntryType {
  invoice,
  initialPayment,
  receipt,
  reconciliationAdjustment,
}

class StatementEntry {
  final DateTime date;
  final String documentNumber;
  final String description;
  final StatementEntryType type;
  final double debit;
  final double credit;
  final double runningBalance;
  final int? documentId;
  final int? relatedDocumentId;
  final bool isAdjustment;

  const StatementEntry({
    required this.date,
    required this.documentNumber,
    required this.description,
    required this.type,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    this.documentId,
    this.relatedDocumentId,
    this.isAdjustment = false,
  });

  bool get isDebit => debit > 0;
  bool get isCredit => credit > 0;
}

class StatementWarning {
  final String invoiceNumber;
  final int invoiceId;
  final double storedPaid;
  final double receiptsTotal;
  final double discrepancy;

  const StatementWarning({
    required this.invoiceNumber,
    required this.invoiceId,
    required this.storedPaid,
    required this.receiptsTotal,
    required this.discrepancy,
  });
}

class CancelledInvoiceReceipt {
  final int receiptId;
  final String receiptNumber;
  final DateTime date;
  final double amount;
  final String? paymentMethod;
  final int cancelledInvoiceId;
  final String cancelledInvoiceNumber;

  const CancelledInvoiceReceipt({
    required this.receiptId,
    required this.receiptNumber,
    required this.date,
    required this.amount,
    this.paymentMethod,
    required this.cancelledInvoiceId,
    required this.cancelledInvoiceNumber,
  });
}

class CustomerStatement {
  final Contact contact;
  final String currencyCode;
  final String currencySymbol;
  final DateTime from;
  final DateTime to;
  final double openingBalance;
  final List<StatementEntry> entries;
  final double totalInvoiced;
  final double totalPaid;
  final double totalAdjustments;
  final double closingBalance;
  final List<StatementWarning> warnings;
  final List<CancelledInvoiceReceipt> cancelledInvoiceReceipts;

  const CustomerStatement({
    required this.contact,
    required this.currencyCode,
    required this.currencySymbol,
    required this.from,
    required this.to,
    required this.openingBalance,
    required this.entries,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.totalAdjustments,
    required this.closingBalance,
    this.warnings = const [],
    this.cancelledInvoiceReceipts = const [],
  });

  bool get hasDiscrepancy => warnings.isNotEmpty;
  bool get hasCancelledInvoiceReceipts => cancelledInvoiceReceipts.isNotEmpty;

  static String symbolFor(String code) => Currency.symbolForCode(code);
}
