class Product {
  static const String typeProduct = 'product';
  static const String typeService = 'service';

  static const String costStatusKnown = 'known';
  static const String costStatusUnknown = 'unknown';

  final int? id;
  final String name;
  final String type;
  final String? code;
  final String? barcode;
  final String? unit;
  final double salePrice;
  final double purchasePrice;
  final double stockQuantity;
  final double minStock;
  final bool isTaxable;
  final bool isActive;
  final String? notes;
  final String? category;
  final int? taxProfileId;
  final double? averageCost;
  final String costStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isService => type == typeService;
  bool get isProduct => type == typeProduct;
  bool get isCostKnown => costStatus == costStatusKnown && averageCost != null;

  const Product({
    this.id,
    required this.name,
    this.type = typeProduct,
    this.code,
    this.barcode,
    this.unit,
    required this.salePrice,
    this.purchasePrice = 0,
    this.stockQuantity = 0,
    this.minStock = 0,
    this.isTaxable = true,
    this.isActive = true,
    this.notes,
    this.category,
    this.taxProfileId,
    this.averageCost,
    this.costStatus = costStatusUnknown,
    this.createdAt,
    this.updatedAt,
  });

  Product copyWith({
    int? id,
    String? name,
    String? type,
    String? code,
    String? barcode,
    String? unit,
    double? salePrice,
    double? purchasePrice,
    double? stockQuantity,
    double? minStock,
    bool? isTaxable,
    bool? isActive,
    String? notes,
    String? category,
    int? taxProfileId,
    double? averageCost,
    String? costStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        code: code ?? this.code,
        barcode: barcode ?? this.barcode,
        unit: unit ?? this.unit,
        salePrice: salePrice ?? this.salePrice,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        minStock: minStock ?? this.minStock,
        isTaxable: isTaxable ?? this.isTaxable,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        category: category ?? this.category,
        taxProfileId: taxProfileId ?? this.taxProfileId,
        averageCost: averageCost ?? this.averageCost,
        costStatus: costStatus ?? this.costStatus,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'code': code,
        'barcode': barcode,
        'unit': unit,
        'sale_price': salePrice,
        'purchase_price': purchasePrice,
        'stock_quantity': stockQuantity,
        'min_stock': minStock,
        'is_taxable': isTaxable ? 1 : 0,
        'is_active': isActive ? 1 : 0,
        'notes': notes,
        'category': category,
        'tax_profile_id': taxProfileId,
        'average_cost': averageCost,
        'cost_status': costStatus,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String? ?? typeProduct,
        code: map['code'] as String?,
        barcode: map['barcode'] as String?,
        unit: map['unit'] as String?,
        salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0,
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
        stockQuantity: (map['stock_quantity'] as num?)?.toDouble() ?? 0,
        minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
        isTaxable: (map['is_taxable'] as int?) == 1,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        notes: map['notes'] as String?,
        category: map['category'] as String?,
        taxProfileId: map['tax_profile_id'] as int?,
        averageCost: (map['average_cost'] as num?)?.toDouble(),
        costStatus: map['cost_status'] as String? ?? costStatusUnknown,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
      );
}
