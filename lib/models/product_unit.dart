/// Model representing a secondary measurement unit for a product.
library;

/// Represents an alternate packaging or measurement unit for a [Product].
class ProductUnit {
  /// Unique database ID.
  final int? id;

  /// Foreign key referencing the parent product.
  final int productId;

  /// Display name of the unit (e.g. "Box", "Carton", "Dozen").
  final String unitName;

  /// Multiplier to convert 1 of this unit to base units (e.g. 12 for dozen).
  final double conversionFactor;

  /// Base-currency selling price for this unit.
  final double? salePrice;

  /// Base-currency wholesale selling price for this unit.
  final double? wholesalePrice;

  /// Whether this unit is the default selection when selling.
  final bool isDefaultSale;

  /// Reference sale price in [referenceCurrency].
  final double? referenceSalePrice;

  /// Reference wholesale price in [referenceCurrency].
  final double? referenceWholesalePrice;

  /// The reference currency code (must match parent product's price_currency).
  final String? referenceCurrency;

  /// Whether this unit has any reference prices assigned.
  bool get hasReferencePrices =>
      referenceSalePrice != null || referenceWholesalePrice != null;

  /// Creates a [ProductUnit].
  const ProductUnit({
    this.id,
    required this.productId,
    required this.unitName,
    required this.conversionFactor,
    this.salePrice,
    this.wholesalePrice,
    this.isDefaultSale = false,
    this.referenceSalePrice,
    this.referenceWholesalePrice,
    this.referenceCurrency,
  });

  /// Converts this [ProductUnit] into a database map.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'unit_name': unitName,
        'conversion_factor': conversionFactor,
        'sale_price': salePrice,
        'wholesale_price': wholesalePrice,
        'is_default_sale': isDefaultSale ? 1 : 0,
        'reference_sale_price': referenceSalePrice,
        'reference_wholesale_price': referenceWholesalePrice,
        'reference_currency': referenceCurrency,
      };

  /// Constructs a [ProductUnit] from a database row.
  factory ProductUnit.fromMap(Map<String, dynamic> map) => ProductUnit(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        unitName: map['unit_name'] as String? ?? '',
        conversionFactor: (map['conversion_factor'] as num?)?.toDouble() ?? 1.0,
        salePrice: (map['sale_price'] as num?)?.toDouble(),
        wholesalePrice: (map['wholesale_price'] as num?)?.toDouble(),
        isDefaultSale: (map['is_default_sale'] as int? ?? 0) == 1,
        referenceSalePrice: (map['reference_sale_price'] as num?)?.toDouble(),
        referenceWholesalePrice:
            (map['reference_wholesale_price'] as num?)?.toDouble(),
        referenceCurrency: map['reference_currency'] as String?,
      );

  /// Creates a copy of this [ProductUnit] with modified fields.
  ProductUnit copyWith({
    int? id,
    int? productId,
    String? unitName,
    double? conversionFactor,
    double? salePrice,
    double? wholesalePrice,
    bool? isDefaultSale,
    double? referenceSalePrice,
    double? referenceWholesalePrice,
    String? referenceCurrency,
    bool clearReferenceSalePrice = false,
    bool clearReferenceWholesalePrice = false,
    bool clearReferenceCurrency = false,
  }) =>
      ProductUnit(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        unitName: unitName ?? this.unitName,
        conversionFactor: conversionFactor ?? this.conversionFactor,
        salePrice: salePrice ?? this.salePrice,
        wholesalePrice: wholesalePrice ?? this.wholesalePrice,
        isDefaultSale: isDefaultSale ?? this.isDefaultSale,
        referenceSalePrice: clearReferenceSalePrice
            ? null
            : (referenceSalePrice ?? this.referenceSalePrice),
        referenceWholesalePrice: clearReferenceWholesalePrice
            ? null
            : (referenceWholesalePrice ?? this.referenceWholesalePrice),
        referenceCurrency: clearReferenceCurrency
            ? null
            : (referenceCurrency ?? this.referenceCurrency),
      );
}
