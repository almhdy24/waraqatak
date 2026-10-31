class DocumentItem {
  final int? id;
  final int documentId;
  final int? productId;
  final String description;
  final double quantity;
  final double price;
  final double total;
  final bool taxable;
  final double? taxRate; // snapshot at creation; null = use business default
  final double? unitCost; // snapshot cost per unit at document issuance
  final double? totalCost; // quantity * unitCost (COGS for invoice items)
  final String? pricingCategory; // snapshot at creation: 'retail' | 'wholesale' | null (legacy/manual)
  final String? saleUnit; // name of selected sales unit, e.g. 'carton'
  final double unitConversionFactor; // 1 sale_unit = X base units; default 1.0
  final double? baseQuantity; // effective physical quantity in product's base unit

  const DocumentItem({
    this.id,
    required this.documentId,
    this.productId,
    required this.description,
    required this.quantity,
    required this.price,
    required this.total,
    this.taxable = true,
    this.taxRate,
    this.unitCost,
    this.totalCost,
    this.pricingCategory,
    this.saleUnit,
    this.unitConversionFactor = 1.0,
    this.baseQuantity,
  });

  double get effectiveBaseQuantity =>
      baseQuantity ?? (quantity * unitConversionFactor);

  Map<String, dynamic> toMap() => {
        'id': id,
        'document_id': documentId,
        'product_id': productId,
        'description': description,
        'quantity': quantity,
        'price': price,
        'total': total,
        'taxable': taxable ? 1 : 0,
        'tax_rate': taxRate,
        'unit_cost': unitCost,
        'total_cost': totalCost,
        'pricing_category': pricingCategory,
        'sale_unit': saleUnit,
        'unit_conversion_factor': unitConversionFactor,
        'base_quantity': effectiveBaseQuantity,
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
        taxRate: (map['tax_rate'] as num?)?.toDouble(),
        unitCost: (map['unit_cost'] as num?)?.toDouble(),
        totalCost: (map['total_cost'] as num?)?.toDouble(),
        pricingCategory: map['pricing_category'] as String?,
        saleUnit: map['sale_unit'] as String?,
        unitConversionFactor:
            (map['unit_conversion_factor'] as num?)?.toDouble() ?? 1.0,
        baseQuantity: (map['base_quantity'] as num?)?.toDouble(),
      );
}
