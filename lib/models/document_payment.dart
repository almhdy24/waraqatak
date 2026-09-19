class DocumentPayment {
  final int? id;
  final int documentId;
  final double amount;
  final String? paymentMethod;
  final DateTime date;
  final String? notes;

  const DocumentPayment({
    this.id,
    required this.documentId,
    required this.amount,
    this.paymentMethod,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'document_id': documentId,
        'amount': amount,
        'payment_method': paymentMethod,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory DocumentPayment.fromMap(Map<String, dynamic> map) => DocumentPayment(
        id: map['id'] as int?,
        documentId: map['document_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String?,
        date: DateTime.parse(map['date'] as String),
        notes: map['notes'] as String?,
      );
}
