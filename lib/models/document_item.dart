class DocumentItem {
  final int? id;
  final int documentId;
  final int? productId;
  final String description;
  final double quantity;
  final double price;
  final double total;
  final bool taxable;

  const DocumentItem({
    this.id,
    required this.documentId,
    this.productId,
    required this.description,
    required this.quantity,
    required this.price,
    required this.total,
    this.taxable = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'document_id': documentId,
        'product_id': productId,
        'description': description,
        'quantity': quantity,
        'price': price,
        'total': total,
        'taxable': taxable ? 1 : 0,
      };

  factory DocumentItem.fromMap(Map<String, dynamic> map) => DocumentItem(
        id: map['id'] as int?,
        documentId: (map['document_id'] as num).toInt(),
        productId: map['product_id'] as int?,
        description: map['description'] as String,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        price: (map['price'] as num?)?.toDouble() ?? 0,
        total: (map['total'] as num?)?.toDouble() ?? 0,
        taxable: (map['taxable'] as int?) == 1,
      );
}