class StockMovement {
  static const String typeOpening = 'opening';
  static const String typePurchase = 'purchase';
  static const String typeSale = 'sale';
  static const String typeCancellation = 'cancellation';
  static const String typeAdjustment = 'adjustment';

  final int? id;
  final int productId;
  final String type;
  final double quantity; // positive = stock in, negative = stock out
  final int? referenceDocumentId;
  final DateTime date;
  final String? notes;

  const StockMovement({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.referenceDocumentId,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'type': type,
        'quantity': quantity,
        'reference_document_id': referenceDocumentId,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        type: map['type'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        referenceDocumentId: map['reference_document_id'] as int?,
        date: DateTime.parse(map['date'] as String),
        notes: map['notes'] as String?,
      );
}
