class Product {
  final int? id;
  final String name;
  final String? code;
  final double salePrice;
  final double purchasePrice;
  final double stockQuantity;
  final double minStock;
  final bool isTaxable;
  final String? notes;

  const Product({
    this.id,
    required this.name,
    this.code,
    required this.salePrice,
    this.purchasePrice = 0,
    this.stockQuantity = 0,
    this.minStock = 0,
    this.isTaxable = true,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'sale_price': salePrice,
        'purchase_price': purchasePrice,
        'stock_quantity': stockQuantity,
        'min_stock': minStock,
        'is_taxable': isTaxable ? 1 : 0,
        'notes': notes,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        code: map['code'] as String?,
        salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0,
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
        stockQuantity: (map['stock_quantity'] as num?)?.toDouble() ?? 0,
        minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
        isTaxable: (map['is_taxable'] as int?) == 1,
        notes: map['notes'] as String?,
      );
}