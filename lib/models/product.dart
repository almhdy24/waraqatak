class Product {
  static const String typeProduct = 'product';
  static const String typeService = 'service';

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
  final int? taxProfileId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isService => type == typeService;
  bool get isProduct => type == typeProduct;

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
    this.taxProfileId,
    this.createdAt,
    this.updatedAt,
  });

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
        'tax_profile_id': taxProfileId,
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
        taxProfileId: map['tax_profile_id'] as int?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
      );
}
