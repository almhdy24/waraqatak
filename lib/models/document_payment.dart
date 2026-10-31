class PaymentOrigin {
  static const String upfront = 'upfront';
  static const String receipt = 'receipt';
  static const String reversal = 'reversal';
}

class DocumentPayment {
  final int? id;
  final int documentId;
  final double amount;
  final String? paymentMethod;
  final DateTime date;
  final String? notes;
  final int? receiptDocumentId;
  final String? paymentOrigin;

  const DocumentPayment({
    this.id,
    required this.documentId,
    required this.amount,
    this.paymentMethod,
    required this.date,
    this.notes,
    this.receiptDocumentId,
    this.paymentOrigin,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'document_id': documentId,
        'amount': amount,
        'payment_method': paymentMethod,
        'date': date.toIso8601String(),
        'notes': notes,
        'receipt_document_id': receiptDocumentId,
        'payment_origin': paymentOrigin,
      };

  factory DocumentPayment.fromMap(Map<String, dynamic> map) => DocumentPayment(
        id: map['id'] as int?,
        documentId: map['document_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String?,
        date: DateTime.parse(map['date'] as String),
        notes: map['notes'] as String?,
        receiptDocumentId: map['receipt_document_id'] as int?,
        paymentOrigin: map['payment_origin'] as String?,
      );
}
