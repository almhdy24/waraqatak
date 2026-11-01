class ProductUnit {
  final int? id;
  final int productId;
  final String unitName;
  final double conversionFactor;
  final double? salePrice;
  final double? wholesalePrice;
  final bool isDefaultSale;

  const ProductUnit({
    this.id,
    required this.productId,
    required this.unitName,
    required this.conversionFactor,
    this.salePrice,
    this.wholesalePrice,
    this.isDefaultSale = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'unit_name': unitName,
        'conversion_factor': conversionFactor,
        'sale_price': salePrice,
        'wholesale_price': wholesalePrice,
        'is_default_sale': isDefaultSale ? 1 : 0,
      };

  factory ProductUnit.fromMap(Map<String, dynamic> map) => ProductUnit(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        unitName: map['unit_name'] as String? ?? '',
        conversionFactor: (map['conversion_factor'] as num?)?.toDouble() ?? 1.0,
        salePrice: (map['sale_price'] as num?)?.toDouble(),
        wholesalePrice: (map['wholesale_price'] as num?)?.toDouble(),
        isDefaultSale: (map['is_default_sale'] as int? ?? 0) == 1,
      );

  ProductUnit copyWith({
    int? id,
    int? productId,
    String? unitName,
    double? conversionFactor,
    double? salePrice,
    double? wholesalePrice,
    bool? isDefaultSale,
  }) =>
      ProductUnit(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        unitName: unitName ?? this.unitName,
        conversionFactor: conversionFactor ?? this.conversionFactor,
        salePrice: salePrice ?? this.salePrice,
        wholesalePrice: wholesalePrice ?? this.wholesalePrice,
        isDefaultSale: isDefaultSale ?? this.isDefaultSale,
      );
}
