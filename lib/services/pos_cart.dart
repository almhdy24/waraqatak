import '../models/product.dart';
import '../utils/money_utils.dart';
import 'document_service.dart';

/// One product line in the quick-sale cart.
class PosCartLine {
  final Product product;
  final double quantity;
  final double? taxRate;

  const PosCartLine(this.product, this.quantity, {this.taxRate});

  double get total => MoneyUtils.round(quantity * product.salePrice);

  PosCartLine withQuantity(double q) =>
      PosCartLine(product, q, taxRate: taxRate);
}

/// Why a product could not be added or its quantity raised.
enum PosCartError { outOfStock }

/// Quick-sale cart: pure logic, no UI or database.
///
/// Mirrors how the invoice screen turns a product into a line (sale price,
/// product taxability, business tax rate), and enforces the same stock rule
/// as the database (stocked products cannot go below zero; services have no
/// stock).
class PosCart {
  final List<PosCartLine> _lines = [];
  double _discount = 0;

  List<PosCartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;
  double get itemCount => _lines.fold(0, (s, l) => s + l.quantity);
  double get subtotal => _lines.fold(0, (s, l) => s + l.total);
  double get discount => _discount;

  static bool tracksStock(Product p) => p.type == Product.typeProduct;

  double quantityOf(int productId) => _lines
      .where((l) => l.product.id == productId)
      .fold(0, (s, l) => s + l.quantity);

  /// Adds one unit of [product] (or [quantity] units). Returns an error
  /// instead of exceeding available stock.
  PosCartError? add(Product product, {double quantity = 1, double? taxRate}) {
    final i = _lines.indexWhere((l) => l.product.id == product.id);
    final current = i < 0 ? 0.0 : _lines[i].quantity;
    final next = current + quantity;
    if (tracksStock(product) && next > product.stockQuantity) {
      return PosCartError.outOfStock;
    }
    final lineRate = taxRate ?? (product.isTaxable ? null : 0.0);
    if (i < 0) {
      _lines.add(PosCartLine(product, next, taxRate: lineRate));
    } else {
      _lines[i] = _lines[i].withQuantity(next);
    }
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
    final p = _lines[index].product;
    if (tracksStock(p) && quantity > p.stockQuantity) {
      return PosCartError.outOfStock;
    }
    _lines[index] = _lines[index].withQuantity(quantity);
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
            price: l.product.salePrice,
            taxable: l.product.isTaxable,
            productId: l.product.id,
            taxRate: l.taxRate,
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
