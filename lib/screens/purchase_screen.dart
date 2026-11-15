import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../models/payment_method.dart';
import '../services/document_service.dart';
import '../utils/error_utils.dart';
import '../utils/money_utils.dart';
import '../utils/number_input.dart';
import '../widgets/amount_field.dart';
import '../widgets/app_amount_text.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_totals_card.dart';
import '../widgets/contact_autocomplete_field.dart';
import '../widgets/document_item_form.dart';
import 'document_detail_screen.dart';
import '../widgets/responsive.dart';

class PurchaseScreen extends StatefulWidget {
  final Contact? preselectedContact;
  const PurchaseScreen({super.key, this.preselectedContact});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

enum PurchasePaymentOption { fullyPaid, partial, credit }

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  PurchasePaymentOption _paymentOption = PurchasePaymentOption.fullyPaid;
  String _paymentMethod = 'cash';
  List<PaymentMethod> _enabledMethods = [];

  final List<TextEditingController> _descriptionControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _priceControllers = [];
  final List<bool> _taxableList = [];
  final List<int?> _productIds = [];
  final List<double?> _taxRates = [];
  Map<int, double> _profileRates = {};

  Business? _business;
  Contact? _selectedContact;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
    _addItem();
    if (widget.preselectedContact != null) {
      _selectedContact = widget.preselectedContact;
    }
    _discountController.addListener(() => setState(() {}));
    _paidController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _discountController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    for (final c in _descriptionControllers) {
      c.dispose();
    }
    for (final c in _quantityControllers) {
      c.dispose();
    }
    for (final c in _priceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    final business = await DatabaseHelper.instance.getFirstBusiness();
    final profiles = await DatabaseHelper.instance.getTaxProfiles(
      activeOnly: true,
    );
    final methods = await DatabaseHelper.instance.getEnabledPaymentMethods();
    if (!mounted) return;
    setState(() {
      _business = business;
      _profileRates = {
        for (final p in profiles)
          if (p.id != null) p.id!: p.rate,
      };
      _enabledMethods = methods;
      if (methods.isNotEmpty && !methods.any((m) => m.key == _paymentMethod)) {
        _paymentMethod = methods.first.key;
      }
    });
  }

  void _addItem() {
    setState(() {
      _descriptionControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController(text: '1'));
      _priceControllers.add(TextEditingController());
      _taxableList.add(true);
      _productIds.add(null);
      _taxRates.add(null);
    });
  }

  bool get _isDirty {
    return _selectedContact != null ||
        _notesController.text.isNotEmpty ||
        (_discountController.text != '0' &&
            _discountController.text.isNotEmpty) ||
        (_paidController.text != '0' && _paidController.text.isNotEmpty) ||
        _descriptionControllers.any((c) => c.text.isNotEmpty) ||
        _productIds.any((id) => id != null) ||
        _descriptionControllers.length > 1;
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
        _descriptionControllers[index].text.isNotEmpty ||
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
    setState(() {
      _descriptionControllers[index].dispose();
      _quantityControllers[index].dispose();
      _priceControllers[index].dispose();
      _descriptionControllers.removeAt(index);
      _quantityControllers.removeAt(index);
      _priceControllers.removeAt(index);
      _taxableList.removeAt(index);
      _productIds.removeAt(index);
      _taxRates.removeAt(index);
    });
  }

  double get _discount => NumberInput.parse(_discountController.text) ?? 0;
  double _paidFor(double total) => switch (_paymentOption) {
    PurchasePaymentOption.fullyPaid => total,
    PurchasePaymentOption.credit => 0.0,
    PurchasePaymentOption.partial => NumberInput.parse(_paidController.text) ?? 0,
  };

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

  List<DocumentItemInput> _buildItems() => List.generate(
    _descriptionControllers.length,
    (i) => DocumentItemInput(
      description: _descriptionControllers[i].text.trim(),
      quantity: NumberInput.parse(_quantityControllers[i].text) ?? 0,
      price: NumberInput.parse(_priceControllers[i].text) ?? 0,
      taxable: _taxableList[i],
      productId: _productIds[i],
      taxRate: _taxRates[i],
    ),
  );

  Future<void> _save({bool isDraft = false}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_business == null) return;
    final l10n = AppLocalizations.of(context);

    if (_descriptionControllers.isEmpty) {
      AppSnackBar.show(
        context,
        l10n.pleaseAddItems,
        severity: AppSnackBarSeverity.warning,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final totals = _totals;
      final decimalDigits = Currency.decimalDigitsForCode(
        _business?.currencyCode,
      );
      final remaining = MoneyUtils.calculateRemaining(
        totals.total,
        _paidFor(totals.total),
        decimalDigits,
      );

      if ((_paymentOption == PurchasePaymentOption.credit || remaining > 0) &&
          _selectedContact == null &&
          !isDraft) {
        AppSnackBar.show(
          context,
          l10n.supplierRequiredForCreditPurchase,
          severity: AppSnackBarSeverity.warning,
        );
        return;
      }

      final docId = await DocumentService.createDocument(
        type: 'purchase',
        business: _business!,
        contact: _selectedContact,
        items: _buildItems(),
        discount: _discount,
        paid: _paidFor(totals.total),
        notes: _notesController.text,
        date: DateTime.now(),
        isDraft: isDraft,
        paymentMethod: _paymentOption == PurchasePaymentOption.credit
            ? null
            : _paymentMethod,
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
    final subtotal = totals.subtotal;
    final discount = _discount;
    final total = totals.total;

    final paid = _paidFor(total);
    final decimalDigits = Currency.decimalDigitsForCode(
      _business?.currencyCode,
    );
    final remaining = MoneyUtils.calculateRemaining(total, paid, decimalDigits);

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
        appBar: AppBar(title: Text(l10n.purchase), centerTitle: true),
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
                      AppAmountText(
                        amount: total,
                        currencySymbol: _business?.currencySymbol ?? '',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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
                      : Text(l10n.savePurchase),
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
                  label: l10n.supplier,
                  type: 'supplier',
                  initialContact: _selectedContact,
                  onContactChanged: (contact) => setState(() => _selectedContact = contact),
                ),
                const SizedBox(height: 16),
                AppSectionHeader(
                  title: l10n.items,
                  count: _descriptionControllers.length,
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  _descriptionControllers.length,
                  (index) => DocumentItemForm(
                    descriptionController: _descriptionControllers[index],
                    quantityController: _quantityControllers[index],
                    priceController: _priceControllers[index],
                    taxable: _taxableList[index],
                    taxRate: _taxRates[index],
                    productId: _productIds[index],
                    usePurchasePrice: true,
                    onProductChanged: (productId) =>
                        setState(() => _productIds[index] = productId),
                    onProductSelected: (product) {
                      setState(() {
                        if (product == null) {
                          _taxRates[index] = null;
                        } else if (!product.isTaxable) {
                          _taxableList[index] = false;
                          _taxRates[index] = 0.0;
                        } else if (product.taxProfileId != null) {
                          _taxRates[index] =
                              _profileRates[product.taxProfileId];
                        } else {
                          _taxRates[index] = null;
                        }
                      });
                    },
                    onTaxableChanged: (value) =>
                        setState(() => _taxableList[index] = value ?? true),
                    onDelete: () => _removeItem(index),
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
                const SizedBox(height: 20),
                Text(
                  l10n.paymentDetails,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<PurchasePaymentOption>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: PurchasePaymentOption.fullyPaid,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.paidStatus,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                    ),
                    ButtonSegment(
                      value: PurchasePaymentOption.partial,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.statusPartiallyPaid,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      icon: const Icon(Icons.pie_chart_outline, size: 16),
                    ),
                    ButtonSegment(
                      value: PurchasePaymentOption.credit,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.unpaidStatus,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      icon: const Icon(Icons.hourglass_empty_rounded, size: 16),
                    ),
                  ],
                  selected: {_paymentOption},
                  onSelectionChanged: (set) {
                    final opt = set.first;
                    setState(() {
                      _paymentOption = opt;
                      if (opt == PurchasePaymentOption.fullyPaid) {
                        _paidController.text = NumberInput.formatForInput(
                          _totals.total,
                          maxDecimals: 4,
                        );
                      } else if (opt == PurchasePaymentOption.credit) {
                        _paidController.text = '0';
                      } else if (opt == PurchasePaymentOption.partial) {
                        if (_paidController.text == '0' ||
                            _paidController.text.isEmpty) {
                          _paidController.text = NumberInput.formatForInput(
                            _totals.total,
                            maxDecimals: 4,
                          );
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                AmountField(
                  controller: _discountController,
                  decoration: InputDecoration(
                    labelText: l10n.discount,
                    prefixIcon: const Icon(Icons.percent_rounded, size: 20),
                  ),
                  textInputAction: TextInputAction.next,
                  maxDecimals: 4,
                  showMultipliers: true,
                  onTap: () {
                    if (_discountController.text.isNotEmpty) {
                      _discountController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _discountController.text.length,
                      );
                    }
                  },
                ),
                if (_paymentOption == PurchasePaymentOption.partial) ...[
                  const SizedBox(height: 12),
                  AmountField(
                    controller: _paidController,
                    decoration: InputDecoration(
                      labelText: l10n.paid,
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                      helperText: l10n.remainingBalanceHelper,
                    ),
                    textInputAction: TextInputAction.next,
                    maxDecimals: 4,
                    showMultipliers: true,
                    onTap: () {
                      if (_paidController.text.isNotEmpty) {
                        _paidController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _paidController.text.length,
                        );
                      }
                    },
                  ),
                ],
                if (_paymentOption != PurchasePaymentOption.credit &&
                    _enabledMethods.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.paymentMethod,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _enabledMethods.map((m) {
                      return ChoiceChip(
                        label: Text(m.label(l10n.langCode)),
                        selected: _paymentMethod == m.key,
                        onSelected: (_) =>
                            setState(() => _paymentMethod = m.key),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: l10n.notes,
                    prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                AppTotalsCard(
                  subtotal: subtotal,
                  discount: discount,
                  taxAmount: totals.taxAmount,
                  taxRate: _business?.taxRate ?? 0,
                  total: total,
                  paid: paid,
                  remaining: remaining,
                  currencySymbol: _business?.currencySymbol ?? '',
                  isTaxInclusive: _business?.pricesIncludeTax ?? false,
                  netTaxableBase: (_business?.pricesIncludeTax ?? false)
                      ? (total - totals.taxAmount)
                      : null,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
