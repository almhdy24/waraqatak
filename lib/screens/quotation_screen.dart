import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../services/document_service.dart';
import '../widgets/app_amount_text.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_totals_card.dart';
import '../widgets/contact_autocomplete_field.dart';
import '../widgets/document_item_form.dart';
import 'document_detail_screen.dart';
import '../widgets/responsive.dart';

class QuotationScreen extends StatefulWidget {
  const QuotationScreen({super.key});

  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _validityController = TextEditingController(text: '7');
  bool _saving = false;

  final List<TextEditingController> _desc = [];
  final List<TextEditingController> _qty = [];
  final List<TextEditingController> _price = [];
  final List<bool> _taxable = [];
  final List<int?> _productIds = [];
  final List<double?> _taxRates = [];
  Map<int, double> _profileRates = {};

  Business? _business;
  Contact? _contact;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
    _addItem();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _validityController.dispose();
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
      _desc.add(TextEditingController());
      _qty.add(TextEditingController(text: '1'));
      _price.add(TextEditingController());
      _taxable.add(true);
      _productIds.add(null);
      _taxRates.add(null);
    });
  }

  bool get _isDirty {
    return _contact != null ||
        _notesController.text.isNotEmpty ||
        (_validityController.text != '7' && _validityController.text.isNotEmpty) ||
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
    final hasContent = _desc[index].text.isNotEmpty || _productIds[index] != null;
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
      _desc[index].dispose();
      _qty[index].dispose();
      _price[index].dispose();
      _desc.removeAt(index);
      _qty.removeAt(index);
      _price.removeAt(index);
      _taxable.removeAt(index);
      _productIds.removeAt(index);
      _taxRates.removeAt(index);
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
      discount: 0,
      taxRate: effectiveTaxRate,
      pricesIncludeTax:
          (_business?.taxesEnabled ?? false) &&
          (_business?.pricesIncludeTax ?? false),
      decimalDigits: decimalDigits,
    );
  }

  List<DocumentItemInput> _buildItems() => List.generate(
    _desc.length,
    (i) => DocumentItemInput(
      description: _desc[i].text.trim(),
      quantity: double.tryParse(_qty[i].text) ?? 1,
      price: double.tryParse(_price[i].text) ?? 0,
      taxable: _taxable[i],
      productId: _productIds[i],
      taxRate: _taxRates[i],
    ),
  );

  Future<void> _save({bool isDraft = false}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_business == null) return;

    if (_desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).pleaseAddItems)),
      );
      return;
    }

    setState(() => _saving = true);

    final int validityDays = int.tryParse(_validityController.text) ?? 7;
    final DateTime documentDate = DateTime.now();
    final DateTime validUntil = documentDate.add(Duration(days: validityDays));

    try {
      final docId = await DocumentService.createDocument(
        type: 'quotation',
        business: _business!,
        contact: _contact,
        items: _buildItems(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context).operationFailed}: $e'),
        ),
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
                      AppAmountText(
                        amount: totals.total,
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
              padding: const EdgeInsets.all(16),
              children: [
                ContactAutocompleteField(
                  label: l10n.customer,
                  type: 'customer',
                  onContactChanged: (c) => _contact = c,
                ),
                const SizedBox(height: 16),
                AppSectionHeader(title: l10n.items, count: _desc.length),
                const SizedBox(height: 8),
                ...List.generate(
                  _desc.length,
                  (i) => DocumentItemForm(
                    descriptionController: _desc[i],
                    quantityController: _qty[i],
                    priceController: _price[i],
                    taxable: _taxable[i],
                    taxRate: _taxRates[i],
                    productId: _productIds[i],
                    onProductChanged: (productId) {
                      setState(() => _productIds[i] = productId);
                    },
                    onProductSelected: (product) {
                      setState(() {
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
                AppTotalsCard(
                  subtotal: totals.subtotal,
                  discount: 0,
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
                TextFormField(
                  controller: _validityController,
                  decoration: InputDecoration(
                    labelText: l10n.validityDays,
                    prefixIcon: const Icon(
                      Icons.calendar_month_outlined,
                      size: 20,
                    ),
                  ),
                  keyboardType: TextInputType.number,
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
                        : Text(l10n.save),
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
