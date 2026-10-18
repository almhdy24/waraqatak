class StockMovement {
  static const String typeOpening = 'opening';
  static const String typePurchase = 'purchase';
  static const String typeSale = 'sale';
  static const String typeCancellation = 'cancellation';
  static const String typeAdjustment = 'adjustment';

  static const String costStatusKnown = 'known';
  static const String costStatusReconstructed = 'reconstructed';
  static const String costStatusUnknown = 'unknown';

  final int? id;
  final int productId;
  final String type;
  final double quantity; // positive = stock in, negative = stock out
  final int? referenceDocumentId;
  final DateTime date;
  final String? notes;
  final String? productName;
  final String? productUnit;
  final double? unitCost;
  final double? totalCost;
  final String costStatus;
  final String? provenance;

  const StockMovement({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.referenceDocumentId,
    required this.date,
    this.notes,
    this.productName,
    this.productUnit,
    this.unitCost,
    this.totalCost,
    this.costStatus = costStatusUnknown,
    this.provenance,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'type': type,
        'quantity': quantity,
        'reference_document_id': referenceDocumentId,
        'date': date.toIso8601String(),
        'notes': notes,
        'unit_cost': unitCost,
        'total_cost': totalCost,
        'cost_status': costStatus,
        'provenance': provenance,
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        type: map['type'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        referenceDocumentId: map['reference_document_id'] as int?,
        date: DateTime.parse(map['date'] as String),
        notes: map['notes'] as String?,
        productName: map['product_name'] as String?,
        productUnit: map['product_unit'] as String?,
        unitCost: (map['unit_cost'] as num?)?.toDouble(),
        totalCost: (map['total_cost'] as num?)?.toDouble(),
        costStatus: map['cost_status'] as String? ?? costStatusUnknown,
        provenance: map['provenance'] as String?,
      );

  StockMovement copyWith({
    int? id,
    int? productId,
    String? type,
    double? quantity,
    int? referenceDocumentId,
    DateTime? date,
    String? notes,
    String? productName,
    String? productUnit,
    double? unitCost,
    double? totalCost,
    String? costStatus,
    String? provenance,
  }) {
    return StockMovement(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      referenceDocumentId: referenceDocumentId ?? this.referenceDocumentId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      productName: productName ?? this.productName,
      productUnit: productUnit ?? this.productUnit,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      costStatus: costStatus ?? this.costStatus,
      provenance: provenance ?? this.provenance,
    );
  }
}
