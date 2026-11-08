/// Product model representing an item in catalog.
library;

/// Represents a product or service in the catalog.
class Product {
  /// Type identifier for physical goods with tracked inventory.
  static const String typeProduct = 'product';

  /// Type identifier for non-inventory services.
  static const String typeService = 'service';

  /// Cost status indicating unit cost is tracked and authoritative.
  static const String costStatusKnown = 'known';

  /// Cost status indicating unit cost is unknown.
  static const String costStatusUnknown = 'unknown';

  /// Unique database ID.
  final int? id;

  /// Display name.
  final String name;

  /// Product type ('product' or 'service').
  final String type;

  /// Optional SKU or internal product code.
  final String? code;

  /// Optional barcode string.
  final String? barcode;

  /// Base measurement unit name (e.g. piece, kg).
  final String? unit;

  /// Base-currency selling price.
  final double salePrice;

  /// Base-currency wholesale selling price.
  final double? wholesalePrice;

  /// Minimum quantity required for wholesale pricing.
  final double? wholesaleMinQuantity;

  /// Base-currency purchase cost.
  final double purchasePrice;

  /// Current physical stock quantity.
  final double stockQuantity;

  /// Low stock warning threshold.
  final double minStock;

  /// Whether sales tax applies to this product.
  final bool isTaxable;

  /// Whether product is active for selection.
  final bool isActive;

  /// General notes.
  final String? notes;

  /// Product category tag.
  final String? category;

  /// Associated tax profile foreign key.
  final int? taxProfileId;

  /// Moving average unit cost in base currency.
  final double? averageCost;

  /// Costing status ('known' or 'unknown').
  final String costStatus;

  /// Pricing reference currency code (null if priced directly in base currency).
  final String? priceCurrency;

  /// Reference sale price in [priceCurrency].
  final double? referenceSalePrice;

  /// Reference wholesale price in [priceCurrency].
  final double? referenceWholesalePrice;

  /// Reference purchase price in [priceCurrency].
  final double? referencePurchasePrice;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last modification timestamp.
  final DateTime? updatedAt;

  /// Whether this item is a service.
  bool get isService => type == typeService;

  /// Whether this item is a physical product.
  bool get isProduct => type == typeProduct;

  /// Whether moving average cost is known and valid.
  bool get isCostKnown => costStatus == costStatusKnown && averageCost != null;

  /// Whether this product is priced using a reference currency.
  bool get hasReferencePricing => priceCurrency != null;

  /// Creates a [Product].
  const Product({
    this.id,
    required this.name,
    this.type = typeProduct,
    this.code,
    this.barcode,
    this.unit,
    required this.salePrice,
    this.wholesalePrice,
    this.wholesaleMinQuantity,
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
    this.priceCurrency,
    this.referenceSalePrice,
    this.referenceWholesalePrice,
    this.referencePurchasePrice,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a copy of this [Product] with modified fields.
  Product copyWith({
    int? id,
    String? name,
    String? type,
    String? code,
    String? barcode,
    String? unit,
    double? salePrice,
    double? wholesalePrice,
    double? wholesaleMinQuantity,
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
    String? priceCurrency,
    double? referenceSalePrice,
    double? referenceWholesalePrice,
    double? referencePurchasePrice,
    bool clearPriceCurrency = false,
    bool clearReferenceSalePrice = false,
    bool clearReferenceWholesalePrice = false,
    bool clearReferencePurchasePrice = false,
    bool clearWholesalePrice = false,
    bool clearWholesaleMinQuantity = false,
    bool clearAverageCost = false,
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
        wholesalePrice: clearWholesalePrice
            ? null
            : (wholesalePrice ?? this.wholesalePrice),
        wholesaleMinQuantity: clearWholesaleMinQuantity
            ? null
            : (wholesaleMinQuantity ?? this.wholesaleMinQuantity),
        purchasePrice: purchasePrice ?? this.purchasePrice,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        minStock: minStock ?? this.minStock,
        isTaxable: isTaxable ?? this.isTaxable,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        category: category ?? this.category,
        taxProfileId: taxProfileId ?? this.taxProfileId,
        averageCost:
            clearAverageCost ? null : (averageCost ?? this.averageCost),
        costStatus: costStatus ?? this.costStatus,
        priceCurrency: clearPriceCurrency ? null : (priceCurrency ?? this.priceCurrency),
        referenceSalePrice:
            clearReferenceSalePrice ? null : (referenceSalePrice ?? this.referenceSalePrice),
        referenceWholesalePrice: clearReferenceWholesalePrice
            ? null
            : (referenceWholesalePrice ?? this.referenceWholesalePrice),
        referencePurchasePrice: clearReferencePurchasePrice
            ? null
            : (referencePurchasePrice ?? this.referencePurchasePrice),
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Returns a copy of this product with sensitive cost and wholesale fields redacted.
  Product redacted({
    bool redactCost = false,
    bool redactWholesale = false,
  }) {
    if (!redactCost && !redactWholesale) return this;
    return copyWith(
      purchasePrice: redactCost ? 0.0 : purchasePrice,
      averageCost: redactCost ? null : averageCost,
      clearAverageCost: redactCost,
      costStatus: redactCost ? costStatusUnknown : costStatus,
      referencePurchasePrice: redactCost ? null : referencePurchasePrice,
      clearReferencePurchasePrice: redactCost,
      wholesalePrice: redactWholesale ? null : wholesalePrice,
      clearWholesalePrice: redactWholesale,
      wholesaleMinQuantity: redactWholesale ? null : wholesaleMinQuantity,
      clearWholesaleMinQuantity: redactWholesale,
      referenceWholesalePrice: redactWholesale ? null : referenceWholesalePrice,
      clearReferenceWholesalePrice: redactWholesale,
    );
  }

  /// Converts this [Product] to a database map.
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'code': code,
        'barcode': barcode,
        'unit': unit,
        'sale_price': salePrice,
        'wholesale_price': wholesalePrice,
        'wholesale_min_quantity': wholesaleMinQuantity,
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
        'price_currency': priceCurrency,
        'reference_sale_price': referenceSalePrice,
        'reference_wholesale_price': referenceWholesalePrice,
        'reference_purchase_price': referencePurchasePrice,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Constructs a [Product] from a database row.
  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String? ?? typeProduct,
        code: map['code'] as String?,
        barcode: map['barcode'] as String?,
        unit: map['unit'] as String?,
        salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0,
        wholesalePrice: (map['wholesale_price'] as num?)?.toDouble(),
        wholesaleMinQuantity:
            (map['wholesale_min_quantity'] as num?)?.toDouble(),
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
        priceCurrency: map['price_currency'] as String?,
        referenceSalePrice: (map['reference_sale_price'] as num?)?.toDouble(),
        referenceWholesalePrice:
            (map['reference_wholesale_price'] as num?)?.toDouble(),
        referencePurchasePrice:
            (map['reference_purchase_price'] as num?)?.toDouble(),
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
      );
}
