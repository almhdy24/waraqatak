import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../models/tax_profile.dart';
import '../models/currency.dart';
import '../services/document_service.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../services/pdf_service.dart';
import '../services/pos_cart.dart';
import '../services/product_service.dart';
import '../utils/error_utils.dart';
import '../utils/format_utils.dart';
import '../utils/number_input.dart';
import '../widgets/amount_field.dart';
import '../utils/print_settings.dart';
import '../widgets/app_amount_text.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_snackbar.dart';
import 'barcode_scanner_screen.dart';
import 'document_detail_screen.dart';

/// Point-of-sale style screen: tap products (or scan) into a cart, take
/// payment and print a receipt in a few taps. Each sale is a regular invoice
/// settled in full with the chosen payment method (stock, receipts and
/// reports work exactly as for invoices created from the invoice screen).
class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});

  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen> {
  final _cart = PosCart();
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _receivedCtrl = TextEditingController();

  Business? _business;
  List<Product> _products = [];
  Map<int, List<ProductUnit>> _productUnits = {};
  List<PaymentMethod> _methods = [];
  String? _method;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  String _query = '';

  static final _money = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _receivedCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadFailed && mounted) {
      setState(() {
        _loadFailed = false;
        _loading = true;
      });
    }
    try {
      final db = DatabaseHelper.instance;
      final results = await Future.wait([
        db.getFirstBusiness(),
        ProductService.getAllProducts(activeOnly: true),
        db.getEnabledPaymentMethods(),
        db.getAllProductUnits(),
        db.getTaxProfiles(),
      ]);
      final entitlement = await LicenseService.instance.checkEntitlement();
      if (!mounted) return;
      final business = results[0] as Business?;
      final methods = results[2] as List<PaymentMethod>;
      final units = results[3] as Map<int, List<ProductUnit>>;
      final taxProfilesList = results[4] as List<TaxProfile>;
      final taxProfilesMap = {
        for (final p in taxProfilesList)
          if (p.id != null) p.id!: p,
      };
      setState(() {
        _business = business;
        _products = results[1] as List<Product>;
        _methods = methods;
        _productUnits = units;
        _cart.setEnforceStock(
          FeatureAccess.canAccess(Feature.inventory, entitlement),
        );
        _cart.setWholesalePricingEnabled(
          business?.wholesalePricingEnabled ?? false,
        );
        if (business != null) {
          _cart.setDecimalDigits(
            Currency.decimalDigitsForCode(business.currencyCode),
          );
          _cart.setTaxConfiguration(
            taxesEnabled: business.taxesEnabled,
            businessTaxRate: business.effectiveTaxRate,
            taxProfiles: taxProfilesMap,
          );
        }
        _method ??=
            methods.where((m) => m.isDefault).map((m) => m.key).firstOrNull ??
            methods.firstOrNull?.key;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  String _fmt(double v) =>
      '${_money.format(v)} ${_business?.currencySymbol ?? ''}'.trim();

  List<Product> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              (p.code?.toLowerCase().contains(q) ?? false) ||
              (p.barcode?.toLowerCase() == q),
        )
        .toList();
  }

  ({double subtotal, double taxAmount, double total}) get _totals =>
      _cart.totals(
        taxRate: _business?.effectiveTaxRate ?? 0,
        pricesIncludeTax:
            (_business?.taxesEnabled ?? false) &&
            (_business?.pricesIncludeTax ?? false),
        taxesEnabled: _business?.taxesEnabled ?? false,
      );

  void _toast(String msg) {
    AppSnackBar.show(context, msg);
  }

  void _addProduct(Product p, {double quantity = 1}) {
    final l10n = AppLocalizations.of(context);
    final units = p.id != null
        ? (_productUnits[p.id!] ?? const <ProductUnit>[])
        : const <ProductUnit>[];
    final defaultUnit = units.where((u) => u.isDefaultSale).firstOrNull;
    final err = _cart.add(p, quantity: quantity, unit: defaultUnit);
    if (err == PosCartError.outOfStock) {
      _toast(l10n.posNotEnoughStock(p.name));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {});
  }

  Future<void> _promptAddQuantity(Product p) async {
    final l10n = AppLocalizations.of(context);
    final units = p.id != null
        ? (_productUnits[p.id!] ?? const <ProductUnit>[])
        : const <ProductUnit>[];
    final defaultUnit = units.where((u) => u.isDefaultSale).firstOrNull;
    final unitLabel = defaultUnit?.unitName ?? p.unit ?? '';

    final qtyCtrl = TextEditingController(text: '1');
    qtyCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: qtyCtrl.text.length,
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.name),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.itemQuantity,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AmountField(
                controller: qtyCtrl,
                autofocus: true,
                maxDecimals: 4,
                showMultipliers: false,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixText: unitLabel.isNotEmpty ? unitLabel : null,
                ),
                validator: (val) {
                  final parsed = NumberInput.parse(val);
                  if (parsed == null || parsed <= 0) {
                    return l10n.invalidQuantity;
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() == true) {
                    Navigator.pop(ctx, true);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final qty = NumberInput.parse(qtyCtrl.text);
      if (qty != null && qty > 0) {
        _addProduct(p, quantity: qty);
      }
    }
  }

  Future<void> _promptDirectQuantity(
    int index,
    void Function(VoidCallback) update,
  ) async {
    final l10n = AppLocalizations.of(context);
    final line = _cart.lines[index];
    final p = line.product;
    final unitLabel = line.unit?.unitName ?? p.unit ?? '';
    final qtyCtrl = TextEditingController(
      text: FormatUtils.formatQuantity(line.quantity),
    );
    qtyCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: qtyCtrl.text.length,
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.name),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.itemQuantity,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AmountField(
                controller: qtyCtrl,
                autofocus: true,
                maxDecimals: 4,
                showMultipliers: false,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixText: unitLabel.isNotEmpty ? unitLabel : null,
                ),
                validator: (val) {
                  final parsed = NumberInput.parse(val);
                  if (parsed == null || parsed <= 0) {
                    return l10n.invalidQuantity;
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() == true) {
                    Navigator.pop(ctx, true);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newQty = NumberInput.parse(qtyCtrl.text);
      if (newQty != null && newQty > 0) {
        update(() => _setQty(index, newQty));
      }
    }
  }

  void _setQty(int index, double qty) {
    final l10n = AppLocalizations.of(context);
    final name = _cart.lines[index].product.name;
    if (_cart.setQuantity(index, qty) == PosCartError.outOfStock) {
      _toast(l10n.posNotEnoughStock(name));
    }
    _syncDiscountField();
    setState(() {});
  }

  void _syncDiscountField() {
    final d = _cart.discount;
    final shown = NumberInput.parse(_discountCtrl.text) ?? 0;
    if (shown != d) {
      _discountCtrl.text = d == 0
          ? ''
          : NumberInput.formatForInput(d, maxDecimals: 4);
    }
  }

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context);
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    _addByCode(code, l10n);
  }

  /// Search field "enter": an exact barcode/code match goes to the cart.
  void _addByCode(String code, AppLocalizations l10n) {
    final c = code.trim().toLowerCase();
    final match = _products.where(
      (p) => p.barcode?.toLowerCase() == c || p.code?.toLowerCase() == c,
    );
    if (match.isEmpty) {
      _toast(l10n.posProductNotFound);
      return;
    }
    _addProduct(match.first);
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  Future<bool> _onWillPop() async {
    if (_cart.isEmpty || _saving) return true;
    final l10n = AppLocalizations.of(context);
    return AppConfirmDialog.show(
      context,
      title: l10n.unsavedChangesTitle,
      message: l10n.unsavedChangesMessage,
      confirmLabel: l10n.discardChanges,
      isDestructive: true,
    );
  }

  Future<void> _clearCart() async {
    final l10n = AppLocalizations.of(context);
    if (_cart.isEmpty) return;
    final ok = await AppConfirmDialog.show(
      context,
      title: l10n.posClearCart,
      message: l10n.posClearCartConfirm,
      confirmLabel: l10n.posClearCart,
      isDestructive: true,
    );
    if (ok) _resetSale();
  }

  void _resetSale() {
    setState(() {
      _cart.clear();
      _discountCtrl.clear();
      _receivedCtrl.clear();
    });
  }

  Future<void> _completeSale() async {
    final l10n = AppLocalizations.of(context);
    final business = _business;
    if (_saving || _cart.isEmpty || business == null || _method == null) return;
    final total = _totals.total;
    final received = NumberInput.parse(_receivedCtrl.text);
    if (received != null && received > 0 && received < total) {
      _toast(l10n.posReceivedLessThanTotal);
      return;
    }

    setState(() => _saving = true);
    try {
      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: _cart.toItemInputs(),
        discount: _cart.discount,
        date: DateTime.now(),
        payNowMethod: _method,
        contact: _cart.customer,
      );
      if (!mounted) return;
      final change = received == null
          ? 0.0
          : PosCart.changeFor(
              total: total,
              received: received,
              decimalDigits: _cart.decimalDigits,
            );
      HapticFeedback.mediumImpact();
      if (MediaQuery.sizeOf(context).width < 840) {
        Navigator.of(
          context,
        ).popUntil((r) => r is! PopupRoute); // close cart sheet
      }
      await _showDone(docId, total: total, change: change);
      _resetSale();
      await _load(); // stock changed
    } catch (e) {
      if (!mounted) return;
      _toast(ErrorUtils.toFriendlyMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showDone(
    int docId, {
    required double total,
    required double change,
  }) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SaleDoneDialog(
        total: _fmt(total),
        change: change > 0 ? _fmt(change) : null,
        onPrint: () => _printReceipt(docId),
        onShare: () => _shareReceipt(docId),
        onView: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentDetailScreen(documentId: docId),
            ),
          );
        },
        onNewSale: () => Navigator.pop(ctx),
        l10n: l10n,
      ),
    );
  }

  Future<({Document doc, List<DocumentItem> items})?> _loadDoc(
    int docId,
  ) async {
    final db = DatabaseHelper.instance;
    final doc = await db.getDocumentById(docId);
    if (doc == null) return null;
    return (doc: doc, items: await db.getDocumentItems(docId));
  }

  Future<void> _printReceipt(int docId) async {
    final l10n = AppLocalizations.of(context);
    try {
      final data = await _loadDoc(docId);
      if (data == null || _business == null) return;
      final bytes = await PdfService.generateDocumentPdf(
        doc: data.doc,
        business: _business!,
        items: data.items,
        l10n: l10n,
        paperSize: PaperSize.thermal80mm,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${data.doc.documentNumber}.pdf',
      );
    } catch (e) {
      if (mounted) _toast('${l10n.operationFailed}: $e');
    }
  }

  Future<void> _shareReceipt(int docId) async {
    final l10n = AppLocalizations.of(context);
    try {
      final data = await _loadDoc(docId);
      if (data == null || _business == null) return;
      await PdfService.sharePdf(
        doc: data.doc,
        business: _business!,
        items: data.items,
        l10n: l10n,
        paperSize: PaperSize.thermal80mm,
      );
    } catch (e) {
      if (mounted) _toast('${l10n.operationFailed}: $e');
    }
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;

    return PopScope(
      canPop: _cart.isEmpty || _saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final proceed = await _onWillPop();
        if (proceed && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.posQuickSale),
          actions: [
            IconButton(
              tooltip: l10n.scanBarcode,
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _scan,
            ),
            IconButton(
              tooltip: l10n.posClearCart,
              icon: const Icon(Icons.remove_shopping_cart_outlined),
              onPressed: _cart.isEmpty ? null : _clearCart,
            ),
          ],
        ),
        body: _loading
            ? const AppLoadingView()
            : _business == null
            ? Center(child: Text(l10n.posSetupBusinessFirst))
            : wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _productPicker(l10n)),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 400, child: _cartPanel(l10n)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: _productPicker(l10n)),
                  _cartBar(l10n),
                ],
              ),
      ),
    );
  }

  Widget _productPicker(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final products = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.posSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _addByCode(v, l10n);
            },
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _products.isEmpty
                          ? l10n.noProducts
                          : l10n.posProductNotFound,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              : Builder(
                  builder: (context) {
                    final textScale = MediaQuery.textScalerOf(
                      context,
                    ).scale(1.0);
                    final tileHeight = (116.0 * textScale.clamp(1.0, 1.6))
                        .roundToDouble();
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        mainAxisExtent: tileHeight,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, i) => _ProductTile(
                        product: products[i],
                        inCart: products[i].id == null
                            ? 0
                            : _cart.quantityOf(products[i].id!),
                        price: _fmt(products[i].salePrice),
                        l10n: l10n,
                        enforceStock: _cart.enforceStock,
                        onTap: () => _addProduct(products[i]),
                        onLongPress: () => _promptAddQuantity(products[i]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _cartBar(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final total = _totals.total;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
          boxShadow: AppDesignTokens.softShadow(context),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.posItemsCount(
                        FormatUtils.formatQuantity(_cart.itemCount),
                      ),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    AppAmountText(
                      amount: total,
                      currencySymbol: _business?.currencySymbol ?? '',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _cart.isEmpty ? null : () => _openCartSheet(l10n),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(130, AppDesignTokens.minTouchTarget),
                ),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(l10n.posViewCart),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCartSheet(AppLocalizations l10n) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.85,
            child: _cartPanel(
              l10n,
              refresh: () {
                setSheet(() {});
                setState(() {});
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editLine(int index, void Function(VoidCallback) update) async {
    final l10n = AppLocalizations.of(context);
    final line = _cart.lines[index];
    final p = line.product;
    final units = p.id != null
        ? (_productUnits[p.id!] ?? const <ProductUnit>[])
        : const <ProductUnit>[];
    final wholesaleEnabled = _business?.wholesalePricingEnabled ?? false;

    ProductUnit? selectedUnit = line.unit;
    String selectedCategory = line.pricingCategory ?? Contact.categoryRetail;
    final qtyCtrl = TextEditingController(
      text: FormatUtils.formatQuantity(line.quantity),
    );
    final priceCtrl = TextEditingController(
      text: NumberInput.formatForInput(line.unitPrice, maxDecimals: 4),
    );
    bool isCustomPrice = line.priceOverride != null;

    double currentQty() => NumberInput.parse(qtyCtrl.text) ?? line.quantity;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(p.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (units.isNotEmpty) ...[
                  Text(
                    l10n.salesUnit,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(p.unit ?? l10n.baseUnit),
                        selected: selectedUnit == null,
                        onSelected: (sel) {
                          if (sel) {
                            setDialog(() {
                              selectedUnit = null;
                              if (!isCustomPrice) {
                                final resPrice =
                                    DocumentService.resolveLinePrice(
                                      product: p,
                                      availableUnits: units,
                                      unit: null,
                                      targetCategory: selectedCategory,
                                      quantity: currentQty(),
                                      wholesalePricingEnabled: wholesaleEnabled,
                                    );
                                priceCtrl.text = NumberInput.formatForInput(
                                  resPrice,
                                  maxDecimals: 4,
                                );
                              }
                            });
                          }
                        },
                      ),
                      for (final u in units)
                        ChoiceChip(
                          label: Text(u.unitName),
                          selected:
                              selectedUnit?.id == u.id &&
                              selectedUnit?.unitName == u.unitName,
                          onSelected: (sel) {
                            if (sel) {
                              setDialog(() {
                                selectedUnit = u;
                                if (!isCustomPrice) {
                                  final resPrice =
                                      DocumentService.resolveLinePrice(
                                        product: p,
                                        availableUnits: units,
                                        unit: u,
                                        targetCategory: selectedCategory,
                                        quantity: currentQty(),
                                        wholesalePricingEnabled:
                                            wholesaleEnabled,
                                      );
                                  priceCtrl.text = NumberInput.formatForInput(
                                    resPrice,
                                    maxDecimals: 4,
                                  );
                                }
                              });
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (wholesaleEnabled) ...[
                  Text(
                    l10n.pricingCategory,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.retail),
                        selected: selectedCategory == Contact.categoryRetail,
                        onSelected: (sel) {
                          if (sel) {
                            setDialog(() {
                              selectedCategory = Contact.categoryRetail;
                              if (!isCustomPrice) {
                                final resPrice =
                                    DocumentService.resolveLinePrice(
                                      product: p,
                                      availableUnits: units,
                                      unit: selectedUnit,
                                      targetCategory: selectedCategory,
                                      quantity: currentQty(),
                                      wholesalePricingEnabled: wholesaleEnabled,
                                    );
                                priceCtrl.text = NumberInput.formatForInput(
                                  resPrice,
                                  maxDecimals: 4,
                                );
                              }
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: Text(l10n.wholesale),
                        selected: selectedCategory == Contact.categoryWholesale,
                        onSelected: (sel) {
                          if (sel) {
                            setDialog(() {
                              selectedCategory = Contact.categoryWholesale;
                              if (!isCustomPrice) {
                                final resPrice =
                                    DocumentService.resolveLinePrice(
                                      product: p,
                                      availableUnits: units,
                                      unit: selectedUnit,
                                      targetCategory: selectedCategory,
                                      quantity: currentQty(),
                                      wholesalePricingEnabled: wholesaleEnabled,
                                    );
                                priceCtrl.text = NumberInput.formatForInput(
                                  resPrice,
                                  maxDecimals: 4,
                                );
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  l10n.itemQuantity,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                AmountField(
                  controller: qtyCtrl,
                  maxDecimals: 4,
                  showMultipliers: false,
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: selectedUnit?.unitName ?? p.unit ?? '',
                  ),
                  onChanged: (val) {
                    if (!isCustomPrice) {
                      final enteredQty = NumberInput.parse(val);
                      if (enteredQty != null && enteredQty > 0) {
                        setDialog(() {
                          final resPrice = DocumentService.resolveLinePrice(
                            product: p,
                            availableUnits: units,
                            unit: selectedUnit,
                            targetCategory: selectedCategory,
                            quantity: enteredQty,
                            wholesalePricingEnabled: wholesaleEnabled,
                          );
                          priceCtrl.text = NumberInput.formatForInput(
                            resPrice,
                            maxDecimals: 4,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.unitPrice,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                AmountField(
                  controller: priceCtrl,
                  maxDecimals: 4,
                  showMultipliers: true,
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: _business?.currencySymbol ?? '',
                    suffixIcon: isCustomPrice
                        ? IconButton(
                            tooltip: l10n.reset,
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: () {
                              setDialog(() {
                                isCustomPrice = false;
                                final resPrice =
                                    DocumentService.resolveLinePrice(
                                      product: p,
                                      availableUnits: units,
                                      unit: selectedUnit,
                                      targetCategory: selectedCategory,
                                      quantity: currentQty(),
                                      wholesalePricingEnabled: wholesaleEnabled,
                                    );
                                priceCtrl.text = NumberInput.formatForInput(
                                  resPrice,
                                  maxDecimals: 4,
                                );
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    final entered = NumberInput.parse(val.trim());
                    if (entered != null) {
                      isCustomPrice = true;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final overridePrice = isCustomPrice
          ? NumberInput.parse(priceCtrl.text.trim())
          : null;
      final newQty = NumberInput.parse(qtyCtrl.text.trim()) ?? line.quantity;
      update(() {
        final err = _cart.updateLine(
          index,
          quantity: newQty,
          unit: selectedUnit,
          clearUnit: selectedUnit == null,
          pricingCategory: selectedCategory,
          priceOverride: overridePrice,
          clearPriceOverride: !isCustomPrice,
        );
        if (err == PosCartError.outOfStock) {
          _toast(l10n.posNotEnoughStock(p.name));
        }
      });
    }
  }

  Widget _cartPanel(AppLocalizations l10n, {VoidCallback? refresh}) {
    final cs = Theme.of(context).colorScheme;
    void update(VoidCallback f) {
      f();
      refresh?.call();
      setState(() {});
    }

    final t = _totals;
    final received = NumberInput.parse(_receivedCtrl.text);
    final change = received == null
        ? 0.0
        : PosCart.changeFor(total: t.total, received: received);

    if (_cart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 56, color: cs.outline),
              const SizedBox(height: 8),
              Text(
                l10n.posCartEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_business?.wholesalePricingEnabled == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.retail),
                  selected: _cart.pricingCategory == Contact.categoryRetail,
                  onSelected: (_) => update(
                    () => _cart.setPricingCategory(Contact.categoryRetail),
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(l10n.wholesale),
                  selected: _cart.pricingCategory == Contact.categoryWholesale,
                  onSelected: (_) => update(
                    () => _cart.setPricingCategory(Contact.categoryWholesale),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _cart.lines.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final line = _cart.lines[i];
              final unitLabel = line.unit?.unitName ?? line.product.unit ?? '';
              final tierLabel =
                  (_business?.wholesalePricingEnabled == true &&
                      line.pricingCategory == Contact.categoryWholesale)
                  ? ' (${l10n.wholesalePricing})'
                  : '';
              return ListTile(
                dense: true,
                onTap: () => _editLine(i, update),
                title: Text(
                  line.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${_fmt(line.unitPrice)} × ${FormatUtils.formatQuantity(line.quantity)} $unitLabel$tierLabel = ${_fmt(line.total)}',
                ),
                trailing: _QtyStepper(
                  quantity: line.quantity,
                  onMinus: () => update(() => _setQty(i, line.quantity - 1)),
                  onPlus: () => update(() => _setQty(i, line.quantity + 1)),
                  onTapQuantity: () => _promptDirectQuantity(i, update),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AmountField(
                      controller: _discountCtrl,
                      maxDecimals: 4,
                      showMultipliers: true,
                      decoration: InputDecoration(
                        labelText: l10n.discount,
                        isDense: true,
                      ),
                      onChanged: (v) => update(
                        () => _cart.discount = NumberInput.parse(v) ?? 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AmountField(
                      controller: _receivedCtrl,
                      maxDecimals: 4,
                      showMultipliers: true,
                      decoration: InputDecoration(
                        labelText: l10n.posAmountReceived,
                        isDense: true,
                      ),
                      onChanged: (_) => update(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_methods.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final m in _methods)
                      ChoiceChip(
                        label: Text(m.label(l10n.langCode)),
                        selected: _method == m.key,
                        onSelected: (_) => update(() => _method = m.key),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              _totalRow(l10n.subtotal, _fmt(t.subtotal)),
              if (_cart.discount > 0)
                _totalRow(l10n.discount, '- ${_fmt(_cart.discount)}'),
              if (t.taxAmount > 0) _totalRow(l10n.tax, _fmt(t.taxAmount)),
              _totalRow(l10n.grandTotal, _fmt(t.total), big: true),
              if (change > 0)
                _totalRow(
                  l10n.posChange,
                  _fmt(change),
                  color: AppDesignTokens.semanticSuccess(context),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving || _method == null ? null : _completeSale,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    '${l10n.posCompleteSale} · ${_fmt(t.total)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalRow(
    String label,
    String value, {
    bool big = false,
    Color? color,
  }) {
    final style = TextStyle(
      fontSize: big ? 18 : 13.5,
      fontWeight: big ? FontWeight.bold : FontWeight.w500,
      color: color ?? (big ? Theme.of(context).colorScheme.primary : null),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final double inCart;
  final String price;
  final AppLocalizations l10n;
  final bool enforceStock;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ProductTile({
    required this.product,
    required this.inCart,
    required this.price,
    required this.l10n,
    this.enforceStock = true,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tracks = PosCart.tracksStock(product);
    final available = tracks ? product.stockQuantity - inCart : double.infinity;
    final soldOut = tracks && available <= 0;
    final isBlocked = enforceStock && soldOut;
    return Material(
      color: inCart > 0 ? cs.primary.withValues(alpha: 0.08) : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: inCart > 0 ? cs.primary : cs.outlineVariant,
          width: inCart > 0 ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isBlocked ? null : onTap,
        onLongPress: isBlocked ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: soldOut ? cs.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                  if (inCart > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        FormatUtils.formatQuantity(inCart),
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    !tracks
                        ? l10n.posService
                        : soldOut
                        ? l10n.outOfStock
                        : l10n.posInStock(
                            FormatUtils.formatQuantity(available),
                          ),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: soldOut ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final double quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback? onTapQuantity;

  const _QtyStepper({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    this.onTapQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            constraints: const BoxConstraints(
              minWidth: AppDesignTokens.minTouchTarget,
              minHeight: AppDesignTokens.minTouchTarget,
            ),
            icon: Icon(
              quantity <= 1 ? Icons.delete_outline : Icons.remove,
              size: 20,
            ),
            tooltip: quantity <= 1 ? AppLocalizations.of(context).delete : null,
            onPressed: onMinus,
          ),
          InkWell(
            onTap: onTapQuantity,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                FormatUtils.formatQuantity(quantity),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(
              minWidth: AppDesignTokens.minTouchTarget,
              minHeight: AppDesignTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.add, size: 20),
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }
}

class _SaleDoneDialog extends StatelessWidget {
  final String total;
  final String? change;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback onView;
  final VoidCallback onNewSale;
  final AppLocalizations l10n;

  const _SaleDoneDialog({
    required this.total,
    required this.change,
    required this.onPrint,
    required this.onShare,
    required this.onView,
    required this.onNewSale,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 52),
      title: Text(l10n.posSaleCompleted),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            total,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.posChange}: $change',
              style: TextStyle(
                fontSize: 16,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_outlined),
                  label: Text(l10n.posPrintReceipt),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined),
                  label: Text(l10n.posShare),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: onView, child: Text(l10n.posViewInvoice)),
        FilledButton(onPressed: onNewSale, child: Text(l10n.posNewSale)),
      ],
    );
  }
}
