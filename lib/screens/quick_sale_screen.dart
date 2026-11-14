import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:printing/printing.dart';

import '../core/catalog_events.dart';
import '../features/wholesale/wholesale_feature.dart';

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
import '../utils/arabic_search_utils.dart';
import '../utils/error_utils.dart';
import '../utils/format_utils.dart';
import '../utils/money_utils.dart';
import '../utils/number_input.dart';
import '../utils/quick_sale_settings.dart';
import '../widgets/amount_field.dart';
import '../utils/print_settings.dart';
import '../widgets/app_amount_text.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/contact_autocomplete_field.dart';
import '../widgets/pos_product_tile.dart';
import 'barcode_scanner_screen.dart';
import 'document_detail_screen.dart';

/// Point-of-sale style screen: tap products (or scan) into a cart, take
/// payment and print a receipt in a few taps. Each sale is a regular invoice
/// settled in full with the chosen payment method (stock, receipts and
/// reports work exactly as for invoices created from the invoice screen).
class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});

  /// Computes dynamic smart cash suggestions:
  /// - Exact total
  /// - Convenient rounded amounts using denominations [500, 1000, 5000, 10000]
  ///   (or [1, 5, 10, 20, 50, 100] for decimal currencies with total < 100)
  /// - Distinct / deduplicated
  /// - Up to 4 suggestions
  static List<double> computeCashSuggestions({
    required double total,
    required int decimalDigits,
    List<int> denominations = const [500, 1000, 5000, 10000],
  }) {
    if (total <= 0) return const [];
    final results = <double>{};
    final exact = MoneyUtils.round(total, decimalDigits);
    results.add(exact);

    final List<num> effectiveDenominations;
    if (total < 100 && decimalDigits > 0) {
      effectiveDenominations = const [1, 5, 10, 20, 50, 100];
    } else {
      effectiveDenominations = denominations;
    }

    for (final d in effectiveDenominations) {
      if (d <= 0) continue;
      final multiple = ((total / d).floor() + 1) * d.toDouble();
      if (multiple > total) {
        results.add(MoneyUtils.round(multiple, decimalDigits));
      }
    }

    final sorted = results.toList()..sort();
    return sorted.take(4).toList();
  }

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
    CatalogEvents.pricesChanged.addListener(_onCatalogChanged);
    _load();
  }

  @override
  void dispose() {
    CatalogEvents.pricesChanged.removeListener(_onCatalogChanged);
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _receivedCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCatalogChanged() async {
    if (!mounted) return;
    await _load();
    if (!_cart.isEmpty && mounted) {
      _toast(AppLocalizations.of(context).catalogUpdatedCartKept);
    }
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
          WholesaleFeature.isEnabledForBusiness(business),
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
    final q = _query.trim();
    if (q.isEmpty) return _products;
    return _products
        .where(
          (p) =>
              ArabicSearchUtils.matches(p.name, q) ||
              (p.code != null && ArabicSearchUtils.matches(p.code, q)) ||
              (p.barcode != null && ArabicSearchUtils.matches(p.barcode, q)),
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

    if (!mounted) return;
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

    if (!mounted) return;
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

  /// Search field "enter": prioritized match goes to cart.
  /// 1. Exact barcode match.
  /// 2. Exact product code match.
  /// 3. If exactly one filtered product remains, add it.
  /// 4. If multiple results remain, preserve the results for manual selection.
  /// 5. Show product-not-found message only when no matching result exists.
  void _addByCode(String code, AppLocalizations l10n) {
    final raw = code.trim();
    if (raw.isEmpty) return;
    final lower = raw.toLowerCase();

    // 1. Exact barcode match
    final barcodeMatch = _products.where(
      (p) => p.barcode != null && p.barcode!.trim().toLowerCase() == lower,
    );
    if (barcodeMatch.isNotEmpty) {
      _addProduct(barcodeMatch.first);
      _searchCtrl.clear();
      setState(() => _query = '');
      FocusScope.of(context).unfocus();
      return;
    }

    // 2. Exact product code match
    final codeMatch = _products.where(
      (p) => p.code != null && p.code!.trim().toLowerCase() == lower,
    );
    if (codeMatch.isNotEmpty) {
      _addProduct(codeMatch.first);
      _searchCtrl.clear();
      setState(() => _query = '');
      FocusScope.of(context).unfocus();
      return;
    }

    // 3. If exactly one filtered product remains, add it
    final filtered = _filtered;
    if (filtered.length == 1) {
      _addProduct(filtered.first);
      _searchCtrl.clear();
      setState(() => _query = '');
      FocusScope.of(context).unfocus();
      return;
    }

    // 4. If multiple results remain, preserve results for manual selection
    if (filtered.length > 1) {
      FocusScope.of(context).unfocus();
      return;
    }

    // 5. Show product-not-found message only when no matching result exists
    _toast(l10n.posProductNotFound);
  }

  Future<void> _selectCustomer(
    AppLocalizations l10n, [
    VoidCallback? refresh,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.customer,
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ContactAutocompleteField(
                initialContact: _cart.customer,
                label: l10n.customer,
                type: 'customer',
                onContactChanged: (contact) {
                  setState(() {
                    _cart.setCustomer(contact);
                  });
                  refresh?.call();
                  Navigator.pop(ctx);
                },
              ),
              if (_cart.customer != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _cart.setCustomer(null);
                    });
                    refresh?.call();
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.person_remove_outlined),
                  label: Text(l10n.clear),
                ),
              ],
            ],
          ),
        );
      },
    );
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
    if (!mounted) return;
    if (ok) _resetSale();
  }

  void _resetSale() {
    setState(() {
      _cart.clear();
      _cart.setCustomer(null);
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

    // Credit sales validation:
    final isPartialOrZero = received != null && received < total;
    if (isPartialOrZero && _cart.customer == null) {
      _toast(l10n.customerRequiredForCreditSale);
      return;
    }

    setState(() => _saving = true);
    try {
      final double actualPaid;
      final String? payNowMethod;
      final String? paymentMethod;

      if (received == null || received >= total) {
        // Full settlement
        actualPaid = 0;
        payNowMethod = _method;
        paymentMethod = null;
      } else {
        // Credit sale: partial or unpaid
        actualPaid = math.max(0.0, received);
        payNowMethod = null;
        paymentMethod = actualPaid > 0 ? _method : null;
      }

      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: _cart.toItemInputs(),
        discount: _cart.discount,
        paid: actualPaid,
        date: DateTime.now(),
        payNowMethod: payNowMethod,
        paymentMethod: paymentMethod,
        contact: _cart.customer,
      );
      if (!mounted) return;
      final change = (received != null && received > total)
          ? PosCart.changeFor(
              total: total,
              received: received,
              decimalDigits: _cart.decimalDigits,
            )
          : 0.0;
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
      if (!mounted) return;
      if (data == null || _business == null) return;
      await PdfService.sharePdf(
        doc: data.doc,
        business: _business!,
        items: data.items,
        l10n: l10n,
        paperSize: PaperSize.thermal80mm,
      );
      if (!mounted) return;
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
            ListenableBuilder(
              listenable: QuickSaleSettings.instance,
              builder: (context, _) {
                final showImages = QuickSaleSettings.instance.showProductImages;
                return IconButton(
                  tooltip: showImages
                      ? l10n.posHideProductImages
                      : l10n.posShowProductImages,
                  icon: Icon(
                    showImages
                        ? Icons.image_outlined
                        : Icons.image_not_supported_outlined,
                  ),
                  onPressed: () {
                    QuickSaleSettings.instance.setShowProductImages(
                      !showImages,
                    );
                  },
                );
              },
            ),
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
              : ListenableBuilder(
                  listenable: QuickSaleSettings.instance,
                  builder: (context, _) {
                    final showImages =
                        QuickSaleSettings.instance.showProductImages;
                    final textScale = MediaQuery.textScalerOf(
                      context,
                    ).scale(1.0);
                    final tileHeight = posTileExtent(
                      showImage: showImages,
                      textScale: textScale,
                    ).roundToDouble();
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        mainAxisExtent: tileHeight,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, i) {
                        final p = products[i];
                        final tracks = PosCart.tracksStock(p);
                        final inCart = p.id == null
                            ? 0.0
                            : _cart.quantityOf(p.id!);
                        final available = tracks
                            ? p.stockQuantity - inCart
                            : double.infinity;
                        final soldOut = tracks && available <= 0;
                        final isBlocked = _cart.enforceStock && soldOut;
                        return PosProductTile(
                          product: p,
                          cartQuantity: inCart.round(),
                          showImage: showImages,
                          price: _fmt(p.salePrice),
                          availableQuantity: available,
                          isSoldOut: soldOut,
                          isBlocked: isBlocked,
                          onTap: () => _addProduct(p),
                          onLongPress: () => _promptAddQuantity(p),
                        );
                      },
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
    final wholesaleEnabled = WholesaleFeature.isEnabledForBusiness(_business);

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
    final suggestions = QuickSaleScreen.computeCashSuggestions(
      total: t.total,
      decimalDigits: _cart.decimalDigits,
    );

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: InputChip(
                    avatar: Icon(
                      _cart.customer != null
                          ? Icons.person
                          : Icons.person_add_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _cart.customer?.name ?? l10n.selectCustomer,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: _cart.customer != null,
                    onPressed: () => _selectCustomer(l10n, refresh),
                    onDeleted: _cart.customer != null
                        ? () => update(() => _cart.setCustomer(null))
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (WholesaleFeature.isEnabledForBusiness(_business))
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
                  (WholesaleFeature.isEnabledForBusiness(_business) &&
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
                      showMultipliers: false,
                      decoration: InputDecoration(
                        labelText: l10n.posAmountReceived,
                        isDense: true,
                      ),
                      onChanged: (_) => update(() {}),
                    ),
                  ),
                ],
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestions.map((s) {
                      final isExact = (s - t.total).abs() < 0.0001;
                      return ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          isExact ? '${_fmt(s)} (${l10n.exact})' : _fmt(s),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => update(() {
                          _receivedCtrl.text = NumberInput.formatForInput(s);
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
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
              if (received != null &&
                  received < t.total &&
                  _cart.customer != null)
                _totalRow(
                  l10n.remaining,
                  _fmt(t.total - received),
                  color: Theme.of(context).colorScheme.error,
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
