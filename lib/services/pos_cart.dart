import '../models/contact.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../utils/money_utils.dart';
import 'document_service.dart';

/// One product line in the quick-sale cart.
class PosCartLine {
  final Product product;
  final double quantity;
  final double? taxRate;
  final ProductUnit? unit;
  final String? pricingCategory;
  final double? priceOverride;
  final bool wholesalePricingEnabled;

  const PosCartLine(
    this.product,
    this.quantity, {
    this.taxRate,
    this.unit,
    this.pricingCategory,
    this.priceOverride,
    this.wholesalePricingEnabled = false,
  });

  /// Automatically resolves price according to tier/unit/quantity rules,
  /// or returns [priceOverride] if manually modified by user.
  double get unitPrice {
    return DocumentService.resolveLinePrice(
      product: product,
      unit: unit,
      saleUnit: unit?.unitName,
      unitConversionFactor: unit?.conversionFactor,
      pricingCategory: pricingCategory ?? Contact.categoryRetail,
      targetCategory: pricingCategory ?? Contact.categoryRetail,
      quantity: quantity,
      currentPrice: priceOverride,
      isManualPrice: priceOverride != null,
      wholesalePricingEnabled: wholesalePricingEnabled,
    );
  }

  /// Physical quantity in base inventory units.
  double get baseQuantity => quantity * (unit?.conversionFactor ?? 1.0);

  double get total => MoneyUtils.round(quantity * unitPrice);

  double totalFor(int digits) => MoneyUtils.round(quantity * unitPrice, digits);

  PosCartLine withQuantity(double q) => PosCartLine(
        product,
        q,
        taxRate: taxRate,
        unit: unit,
        pricingCategory: pricingCategory,
        priceOverride: priceOverride,
        wholesalePricingEnabled: wholesalePricingEnabled,
      );

  PosCartLine copyWith({
    Product? product,
    double? quantity,
    double? taxRate,
    ProductUnit? unit,
    bool clearUnit = false,
    String? pricingCategory,
    double? priceOverride,
    bool clearPriceOverride = false,
    bool? wholesalePricingEnabled,
  }) {
    return PosCartLine(
      product ?? this.product,
      quantity ?? this.quantity,
      taxRate: taxRate ?? this.taxRate,
      unit: clearUnit ? null : (unit ?? this.unit),
      pricingCategory: pricingCategory ?? this.pricingCategory,
      priceOverride:
          clearPriceOverride ? null : (priceOverride ?? this.priceOverride),
      wholesalePricingEnabled:
          wholesalePricingEnabled ?? this.wholesalePricingEnabled,
    );
  }
}

/// Why a product could not be added or its quantity raised.
enum PosCartError { outOfStock }

/// Quick-sale cart: pure logic, no UI or database.
///
/// Mirrors how the invoice screen turns a product into a line (sale price,
/// product taxability, business tax rate, wholesale rules, units), and
/// enforces physical stock validation using base units.
class PosCart {
  final List<PosCartLine> _lines = [];
  double _discount = 0;
  String _pricingCategory = Contact.categoryRetail;
  Contact? _customer;
  bool _wholesalePricingEnabled = false;
  int _decimalDigits = 2;
  int get decimalDigits => _decimalDigits;
  void setDecimalDigits(int digits) {
    _decimalDigits = digits;
    _clampDiscount();
  }

  List<PosCartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;
  double get itemCount => _lines.fold(0, (s, l) => s + l.quantity);
  double get subtotal => _lines.fold(0, (s, l) => s + l.totalFor(_decimalDigits));
  double get discount => _discount;
  String get pricingCategory => _pricingCategory;
  Contact? get customer => _customer;
  bool get wholesalePricingEnabled => _wholesalePricingEnabled;

  static bool tracksStock(Product p) => p.type == Product.typeProduct;

  double quantityOf(int productId) => _lines
      .where((l) => l.product.id == productId)
      .fold(0, (s, l) => s + l.quantity);

  double baseQuantityOf(int productId) => _lines
      .where((l) => l.product.id == productId)
      .fold(0, (s, l) => s + l.baseQuantity);

  void configure({
    bool? wholesalePricingEnabled,
    Contact? customer,
    String? pricingCategory,
  }) {
    if (wholesalePricingEnabled != null) {
      _wholesalePricingEnabled = wholesalePricingEnabled;
    }
    if (customer != null) {
      _customer = customer;
      _pricingCategory = customer.pricingCategory;
    } else if (pricingCategory != null) {
      _pricingCategory = pricingCategory;
    }
    _repriceLines();
  }

  void setCustomer(Contact? customer) {
    _customer = customer;
    if (customer != null) {
      _pricingCategory = customer.pricingCategory;
    }
    _repriceLines();
  }

  void setPricingCategory(String category) {
    _pricingCategory = category;
    _repriceLines();
  }

  void setWholesalePricingEnabled(bool enabled) {
    _wholesalePricingEnabled = enabled;
    _repriceLines();
  }

  void _repriceLines() {
    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      _lines[i] = line.copyWith(
        pricingCategory:
            _customer != null ? _customer!.pricingCategory : _pricingCategory,
        wholesalePricingEnabled: _wholesalePricingEnabled,
      );
    }
    _clampDiscount();
  }

  /// Adds [product] to the cart with optional sales [unit] and pricing tier.
  /// Validates available stock in base units.
  PosCartError? add(
    Product product, {
    double quantity = 1,
    ProductUnit? unit,
    String? pricingCategory,
    double? priceOverride,
    double? taxRate,
    bool? wholesalePricingEnabled,
  }) {
    final effectiveWholesaleEnabled =
        wholesalePricingEnabled ?? _wholesalePricingEnabled;
    final effectiveCategory =
        pricingCategory ?? (_customer?.pricingCategory ?? _pricingCategory);
    final factor = unit?.conversionFactor ?? 1.0;
    final addedBaseQty = quantity * factor;

    // Check if line with same unit and pricing category already exists without override
    final i = _lines.indexWhere((l) =>
        l.product.id == product.id &&
        l.unit?.id == unit?.id &&
        l.unit?.unitName == unit?.unitName &&
        l.pricingCategory == effectiveCategory &&
        l.priceOverride == priceOverride);

    final currentTotalBase =
        product.id != null ? baseQuantityOf(product.id!) : 0.0;
    if (tracksStock(product) &&
        (currentTotalBase + addedBaseQty) > product.stockQuantity) {
      return PosCartError.outOfStock;
    }

    final lineRate = taxRate ?? (product.isTaxable ? null : 0.0);
    if (i < 0) {
      _lines.add(PosCartLine(
        product,
        quantity,
        taxRate: lineRate,
        unit: unit,
        pricingCategory: effectiveCategory,
        priceOverride: priceOverride,
        wholesalePricingEnabled: effectiveWholesaleEnabled,
      ));
    } else {
      _lines[i] = _lines[i].withQuantity(_lines[i].quantity + quantity);
    }
    _clampDiscount();
    return null;
  }

  /// Sets the quantity of the line at [index]; zero or less removes it.
  PosCartError? setQuantity(int index, double quantity) {
    if (index < 0 || index >= _lines.length) return null;
    if (quantity <= 0) {
      _lines.removeAt(index);
      _clampDiscount();
      return null;
    }
    final line = _lines[index];
    final p = line.product;
    final otherLinesBase = _lines
        .asMap()
        .entries
        .where((e) => e.key != index && e.value.product.id == p.id)
        .fold(0.0, (s, e) => s + e.value.baseQuantity);
    final factor = line.unit?.conversionFactor ?? 1.0;
    final nextBase = quantity * factor;
    if (tracksStock(p) && (otherLinesBase + nextBase) > p.stockQuantity) {
      return PosCartError.outOfStock;
    }
    _lines[index] = line.withQuantity(quantity);
    _clampDiscount();
    return null;
  }

  /// Modifies line attributes (e.g. sales unit, tier, or manual price override).
  PosCartError? updateLine(
    int index, {
    double? quantity,
    ProductUnit? unit,
    bool clearUnit = false,
    String? pricingCategory,
    double? priceOverride,
    bool clearPriceOverride = false,
  }) {
    if (index < 0 || index >= _lines.length) return null;
    final line = _lines[index];
    final p = line.product;
    final newQty = quantity ?? line.quantity;
    if (newQty <= 0) {
      _lines.removeAt(index);
      _clampDiscount();
      return null;
    }
    final newUnit = clearUnit ? null : (unit ?? line.unit);
    final factor = newUnit?.conversionFactor ?? 1.0;
    final nextBase = newQty * factor;
    final otherLinesBase = _lines
        .asMap()
        .entries
        .where((e) => e.key != index && e.value.product.id == p.id)
        .fold(0.0, (s, e) => s + e.value.baseQuantity);
    if (tracksStock(p) && (otherLinesBase + nextBase) > p.stockQuantity) {
      return PosCartError.outOfStock;
    }

    _lines[index] = line.copyWith(
      quantity: newQty,
      unit: newUnit,
      clearUnit: clearUnit,
      pricingCategory: pricingCategory ?? line.pricingCategory,
      priceOverride: priceOverride ?? line.priceOverride,
      clearPriceOverride: clearPriceOverride,
    );
    _clampDiscount();
    return null;
  }

  void removeAt(int index) => setQuantity(index, 0);

  void clear() {
    _lines.clear();
    _discount = 0;
  }

  /// Discount is kept between 0 and the subtotal.
  set discount(double value) {
    _discount = value.isNaN ? 0 : value;
    _clampDiscount();
  }

  void _clampDiscount() {
    if (_discount < 0) _discount = 0;
    if (_discount > subtotal) _discount = subtotal;
  }

  List<DocumentItemInput> toItemInputs() => [
        for (final l in _lines)
          DocumentItemInput(
            description: l.product.name,
            quantity: l.quantity,
            price: l.unitPrice,
            taxable: l.product.isTaxable,
            productId: l.product.id,
            taxRate: l.taxRate,
            pricingCategory: l.pricingCategory,
            saleUnit: l.unit?.unitName ?? l.product.unit,
            unitConversionFactor: l.unit?.conversionFactor ?? 1.0,
            baseQuantity: l.baseQuantity,
            decimalDigits: _decimalDigits,
          ),
      ];

  /// Totals using the same rules as invoices.
  ({double subtotal, double taxAmount, double total}) totals({
    required double taxRate,
    required bool pricesIncludeTax,
  }) =>
      DocumentService.calculateInvoiceTotals(
        items: toItemInputs(),
        discount: _discount,
        taxRate: taxRate,
        pricesIncludeTax: pricesIncludeTax,
        decimalDigits: _decimalDigits,
      );

  /// Change to give back for a cash payment of [received] (never negative).
  static double changeFor({
    required double total,
    required double received,
    int decimalDigits = 2,
  }) {
    if (MoneyUtils.isOverpayment(received, total, decimalDigits)) {
      return MoneyUtils.calculateRemaining(received, total, decimalDigits);
    }
    return 0.0;
  }
}
