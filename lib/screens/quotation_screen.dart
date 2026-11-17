import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../features/wholesale/wholesale_feature.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../services/document_service.dart';
import '../widgets/app_amount_text.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_totals_card.dart';
import '../widgets/contact_autocomplete_field.dart';
import '../widgets/discount_input_field.dart';
import '../widgets/document_item_form.dart';
import 'document_detail_screen.dart';
import '../widgets/responsive.dart';
import '../utils/date_format_utils.dart';
import '../utils/error_utils.dart';
import '../utils/number_input.dart';
import '../widgets/amount_field.dart';
import '../widgets/app_date_picker.dart';

class QuotationScreen extends StatefulWidget {
  const QuotationScreen({super.key});

  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _validityKey = GlobalKey();
  final _validityFocusNode = FocusNode();
  final _notesController = TextEditingController();
  final _validityController = TextEditingController(text: '7');
  double _discount = 0.0;
  bool _saving = false;

  final List<TextEditingController> _productNames = [];
  final List<TextEditingController> _desc = [];
  final List<TextEditingController> _qty = [];
  final List<TextEditingController> _price = [];
  final List<bool> _taxable = [];
  final List<int?> _productIds = [];
  final List<double?> _taxRates = [];
  final List<String?> _pricingCategories = [];
  final List<bool> _isManualPriceList = [];
  final List<Product?> _cachedProducts = [];
  final List<String?> _saleUnits = [];
  final List<double> _conversionFactors = [];
  final Map<int, List<ProductUnit>> _unitsCache = {};
  Map<int, double> _profileRates = {};

  Business? _business;
  Contact? _contact;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
    _addItem();
    _validityController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _validityFocusNode.dispose();
    _notesController.dispose();
    _validityController.dispose();
    for (final c in _productNames) {
      c.dispose();
    }
    for (final c in _desc) {
      c.dispose();
    }
    for (final c in _qty) {
      c.dispose();
    }
    for (final c in _price) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    final business = await DatabaseHelper.instance.getFirstBusiness();
    final profiles = await DatabaseHelper.instance.getTaxProfiles(
      activeOnly: true,
    );
    if (!mounted) return;
    setState(() {
      _business = business;
      _profileRates = {
        for (final p in profiles)
          if (p.id != null) p.id!: p.rate,
      };
    });
  }

  void _addItem() {
    setState(() {
      _productNames.add(TextEditingController());
      _desc.add(TextEditingController());
      _qty.add(TextEditingController(text: '1'));
      _price.add(TextEditingController());
      _taxable.add(true);
      _productIds.add(null);
      _taxRates.add(null);
      _pricingCategories.add(null);
      _isManualPriceList.add(false);
      _cachedProducts.add(null);
      _saleUnits.add(null);
      _conversionFactors.add(1.0);
    });
  }

  bool get _isDirty {
    return _contact != null ||
        _notesController.text.isNotEmpty ||
        (_validityController.text != '7' &&
            _validityController.text.isNotEmpty) ||
        _productNames.any((c) => c.text.isNotEmpty) ||
        _desc.any((c) => c.text.isNotEmpty) ||
        _productIds.any((id) => id != null) ||
        _desc.length > 1;
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty || _saving) return true;
    final l10n = AppLocalizations.of(context);
    return AppConfirmDialog.show(
      context,
      title: l10n.unsavedChangesTitle,
      message: l10n.unsavedChangesMessage,
      confirmLabel: l10n.discardChanges,
      isDestructive: true,
    );
  }

  Future<void> _removeItem(int index) async {
    final hasContent =
        _productNames[index].text.isNotEmpty ||
        _desc[index].text.isNotEmpty ||
        _productIds[index] != null;
    if (hasContent) {
      final l10n = AppLocalizations.of(context);
      final proceed = await AppConfirmDialog.show(
        context,
        title: l10n.confirmDeleteLine,
        message: l10n.deleteLineWarning,
        isDestructive: true,
      );
      if (!proceed) return;
    }
    if (!mounted) return;
    final nameCtrl = _productNames.removeAt(index);
    final descCtrl = _desc.removeAt(index);
    final qtyCtrl = _qty.removeAt(index);
    final priceCtrl = _price.removeAt(index);
    setState(() {
      _taxable.removeAt(index);
      _productIds.removeAt(index);
      _taxRates.removeAt(index);
      _pricingCategories.removeAt(index);
      _isManualPriceList.removeAt(index);
      _cachedProducts.removeAt(index);
      _saleUnits.removeAt(index);
      _conversionFactors.removeAt(index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      descCtrl.dispose();
      qtyCtrl.dispose();
      priceCtrl.dispose();
    });
  }

  ({double subtotal, double taxAmount, double total}) get _totals {
    final items = _buildItems();
    final decimalDigits = Currency.decimalDigitsForCode(
      _business?.currencyCode,
    );
    final effectiveTaxRate = (_business?.taxesEnabled ?? false)
        ? (_business?.taxRate ?? 0)
        : 0.0;
    return DocumentService.calculateInvoiceTotals(
      items: items,
      discount: _discount,
      taxRate: effectiveTaxRate,
      pricesIncludeTax:
          (_business?.taxesEnabled ?? false) &&
          (_business?.pricesIncludeTax ?? false),
      decimalDigits: decimalDigits,
    );
  }

  List<DocumentItemInput> _buildItems() => List.generate(_desc.length, (i) {
    final name = i < _productNames.length ? _productNames[i].text.trim() : '';
    final desc = _desc[i].text.trim();
    final effectiveDesc = (name.isNotEmpty && desc.isNotEmpty && name != desc)
        ? '$name\n$desc'
        : (name.isNotEmpty ? name : desc);
    final q = NumberInput.parse(_qty[i].text) ?? 1;
    final factor = i < _conversionFactors.length ? _conversionFactors[i] : 1.0;
    final unit = i < _saleUnits.length ? _saleUnits[i] : null;
    return DocumentItemInput(
      description: effectiveDesc,
      quantity: q,
      price: NumberInput.parse(_price[i].text) ?? 0,
      taxable: _taxable[i],
      productId: _productIds[i],
      taxRate: _taxRates[i],
      pricingCategory: i < _pricingCategories.length
          ? _pricingCategories[i]
          : null,
      saleUnit: unit,
      unitConversionFactor: factor,
      baseQuantity: q * factor,
    );
  });

  Future<void> _save({bool isDraft = false}) async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      final days = NumberInput.parse(_validityController.text)?.toInt();
      if (days == null || days < 1) {
        if (_validityKey.currentContext != null) {
          Scrollable.ensureVisible(
            _validityKey.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        _validityFocusNode.requestFocus();
      }
      return;
    }
    if (_business == null) return;

    if (_desc.isEmpty) {
      AppSnackBar.show(
        context,
        AppLocalizations.of(context).pleaseAddItems,
        severity: AppSnackBarSeverity.warning,
      );
      return;
    }

    setState(() => _saving = true);

    final int rawDays =
        NumberInput.parse(_validityController.text)?.toInt() ?? 7;
    final int validityDays = rawDays > 0 ? rawDays : 7;
    final DateTime documentDate = DateTime.now();
    final DateTime validUntil = documentDate.add(Duration(days: validityDays));

    try {
      final docId = await DocumentService.createDocument(
        type: 'quotation',
        business: _business!,
        contact: _contact,
        items: _buildItems(),
        discount: _discount,
        notes: _notesController.text,
        date: documentDate,
        validUntil: validUntil,
        isDraft: isDraft,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentDetailScreen(documentId: docId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(
          e,
          l10n: AppLocalizations.of(context),
        ),
        severity: AppSnackBarSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totals = _totals;
    return PopScope(
      canPop: !_isDirty || _saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final proceed = await _onWillPop();
        if (proceed && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.quotation), centerTitle: true),
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              boxShadow: AppDesignTokens.softShadow(context),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.total,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: AppAmountText(
                          amount: totals.total,
                          currencySymbol: _business?.currencySymbol ?? '',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saving ? null : () => _save(isDraft: true),
                  child: Text(l10n.saveDraft),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : () => _save(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      110,
                      AppDesignTokens.minTouchTarget,
                    ),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
        body: ResponsiveCenter(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsetsDirectional.all(16),
              children: [
                ContactAutocompleteField(
                  label: l10n.customer,
                  type: 'customer',
                  initialContact: _contact,
                  onContactChanged: (contact) async {
                    setState(() => _contact = contact);
                    if (WholesaleFeature.isEnabledForBusiness(_business)) {
                      final newCat =
                          contact?.pricingCategory ?? Contact.categoryRetail;
                      for (int i = 0; i < _desc.length; i++) {
                        final p = i < _cachedProducts.length
                            ? _cachedProducts[i]
                            : null;
                        if (i < _isManualPriceList.length &&
                            !_isManualPriceList[i] &&
                            p != null) {
                          _pricingCategories[i] = newCat;
                          final q = NumberInput.parse(_qty[i].text) ?? 1.0;
                          final currentP = NumberInput.parse(_price[i].text);
                          List<ProductUnit> units =
                              _unitsCache[p.id] ?? const [];
                          if (units.isEmpty && p.id != null) {
                            try {
                              units = await DatabaseHelper.instance
                                  .getProductUnits(p.id!);
                              _unitsCache[p.id!] = units;
                            } catch (_) {}
                          }
                          final resolved = DocumentService.resolveLinePrice(
                            product: p,
                            availableUnits: units,
                            quantity: q,
                            currentPrice: currentP,
                            saleUnit: _saleUnits[i],
                            unitConversionFactor: _conversionFactors[i],
                            pricingCategory: _pricingCategories[i],
                            targetCategory: newCat,
                            isManualPrice: _isManualPriceList[i],
                            wholesalePricingEnabled: true,
                          );
                          _price[i].text = NumberInput.formatForInput(
                            resolved,
                            maxDecimals: 4,
                          );
                        }
                      }
                      if (mounted) setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 16),
                AppSectionHeader(title: l10n.items, count: _desc.length),
                const SizedBox(height: 8),
                ...List.generate(
                  _desc.length,
                  (i) => DocumentItemForm(
                    key: ObjectKey(_desc[i]),
                    productNameController:
                        i < _productNames.length ? _productNames[i] : null,
                    descriptionController: _desc[i],
                    quantityController: _qty[i],
                    priceController: _price[i],
                    taxable: _taxable[i],
                    taxRate: _taxRates[i],
                    productId: _productIds[i],
                    wholesalePricingEnabled:
                        WholesaleFeature.isEnabledForBusiness(_business),
                    pricingCategory: _pricingCategories[i],
                    onPricingCategoryChanged: (cat) {
                      setState(() => _pricingCategories[i] = cat);
                    },
                    customerPricingCategory:
                        _contact?.pricingCategory ?? Contact.categoryRetail,
                    isManualPrice: _isManualPriceList[i],
                    onManualPriceChanged: (manual) {
                      setState(() => _isManualPriceList[i] = manual);
                    },
                    saleUnit: _saleUnits[i],
                    onSaleUnitChanged: (unit) {
                      setState(() => _saleUnits[i] = unit);
                    },
                    unitConversionFactor: _conversionFactors[i],
                    onConversionFactorChanged: (factor) {
                      setState(() => _conversionFactors[i] = factor);
                    },
                    onProductChanged: (productId) {
                      setState(() => _productIds[i] = productId);
                    },
                    onProductSelected: (product) {
                      setState(() {
                        _cachedProducts[i] = product;
                        if (product == null) {
                          _taxRates[i] = null;
                        } else if (!product.isTaxable) {
                          _taxable[i] = false;
                          _taxRates[i] = 0.0;
                        } else if (product.taxProfileId != null) {
                          _taxRates[i] = _profileRates[product.taxProfileId];
                        } else {
                          _taxRates[i] = null;
                        }
                      });
                      if (product?.id != null) {
                        DatabaseHelper.instance
                            .getProductUnits(product!.id!)
                            .then((u) {
                              _unitsCache[product.id!] = u;
                            });
                      }
                    },
                    onTaxableChanged: (value) {
                      setState(() => _taxable[i] = value ?? true);
                    },
                    onDelete: () => _removeItem(i),
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text(l10n.addItem),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDesignTokens.buttonRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DiscountInputField(
                  subtotal: totals.subtotal,
                  currencySymbol: _business?.currencySymbol ?? '',
                  decimalDigits: Currency.decimalDigitsForCode(
                    _business?.currencyCode,
                  ),
                  initialDiscount: _discount,
                  onDiscountChanged: (d) => setState(() => _discount = d),
                ),
                const SizedBox(height: 16),
                AppTotalsCard(
                  subtotal: totals.subtotal,
                  discount: _discount,
                  taxAmount: totals.taxAmount,
                  taxRate: _business?.taxRate ?? 0,
                  total: totals.total,
                  paid: 0,
                  remaining: 0,
                  currencySymbol: _business?.currencySymbol ?? '',
                  showPaymentRow: false,
                  isTaxInclusive: _business?.pricesIncludeTax ?? false,
                  netTaxableBase: (_business?.pricesIncludeTax ?? false)
                      ? (totals.total - totals.taxAmount)
                      : null,
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (ctx) {
                    final days =
                        NumberInput.parse(_validityController.text)?.toInt() ??
                        7;
                    final effectiveDays = days > 0 ? days : 7;
                    final expiryDate =
                        DateTime.now().add(Duration(days: effectiveDays));
                    return AmountField(
                      key: _validityKey,
                      controller: _validityController,
                      focusNode: _validityFocusNode,
                      maxDecimals: 0,
                      showMultipliers: false,
                      validator: (v) {
                        final d = NumberInput.parse(v ?? '')?.toInt();
                        if (d == null || d <= 0) {
                          return l10n.errorValidityMinDays;
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: l10n.validityDays,
                        hintText: l10n.validityHint,
                        helperText:
                            '${l10n.validUntil}: ${AppDateUtils.formatDate(expiryDate)}',
                        helperStyle: TextStyle(
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: IconButton(
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                          ),
                          tooltip: l10n.selectDate,
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await AppDatePicker.show(
                              context: ctx,
                              initialDate: expiryDate,
                              firstDate: now.add(const Duration(days: 1)),
                              lastDate: now.add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              final diff = DocumentService.calendarDaysBetween(
                                now,
                                picked,
                              );
                              final pickedDays = diff > 0 ? diff : 1;
                              _validityController.text = pickedDays.toString();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: l10n.notes,
                    prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
