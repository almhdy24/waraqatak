import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../services/document_service.dart';
import '../utils/error_utils.dart';
import '../utils/money_utils.dart';
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

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

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
        (_discountController.text != '0' && _discountController.text.isNotEmpty) ||
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
        _descriptionControllers[index].text.isNotEmpty || _productIds[index] != null;
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

  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _paid => double.tryParse(_paidController.text) ?? 0;

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
      quantity: double.tryParse(_quantityControllers[i].text) ?? 0,
      price: double.tryParse(_priceControllers[i].text) ?? 0,
      taxable: _taxableList[i],
      productId: _productIds[i],
      taxRate: _taxRates[i],
    ),
  );

  Future<void> _save({bool isDraft = false}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_business == null) return;

    if (_descriptionControllers.isEmpty) {
      AppSnackBar.show(
        context,
        AppLocalizations.of(context).pleaseAddItems,
        severity: AppSnackBarSeverity.warning,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final docId = await DocumentService.createDocument(
        type: 'purchase',
        business: _business!,
        contact: _selectedContact,
        items: _buildItems(),
        discount: _discount,
        paid: _paid,
        notes: _notesController.text,
        date: DateTime.now(),
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
    final subtotal = totals.subtotal;
    final discount = _discount;
    final total = totals.total;
    final paid = _paid;
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
                    minimumSize: const Size(110, AppDesignTokens.minTouchTarget),
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
            padding: const EdgeInsets.all(16),
            children: [
              ContactAutocompleteField(
                label: l10n.supplier,
                type: 'supplier',
                initialContact: _selectedContact,
                onContactChanged: (contact) => _selectedContact = contact,
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
                        _taxRates[index] = _profileRates[product.taxProfileId];
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
              TextFormField(
                controller: _discountController,
                decoration: InputDecoration(
                  labelText: l10n.discount,
                  prefixIcon: const Icon(Icons.percent_rounded, size: 20),
                ),
                textInputAction: TextInputAction.next,
                onTap: () {
                  if (_discountController.text.isNotEmpty) {
                    _discountController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _discountController.text.length,
                    );
                  }
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidController,
                decoration: InputDecoration(
                  labelText: l10n.paid,
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                  helperText: l10n.remainingBalanceHelper,
                ),
                textInputAction: TextInputAction.next,
                onTap: () {
                  if (_paidController.text.isNotEmpty) {
                    _paidController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _paidController.text.length,
                    );
                  }
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : () => _save(),
                  child: _saving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(l10n.savePurchase),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : () => _save(isDraft: true),
                child: Text(l10n.saveDraft),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
