import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../services/document_service.dart';
import '../utils/error_utils.dart';
import '../utils/money_utils.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_section_header.dart';
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
    for (final c in _descriptionControllers) { c.dispose(); }
    for (final c in _quantityControllers) { c.dispose(); }
    for (final c in _priceControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (!mounted) return;
    setState(() => _business = business);
  }

  void _addItem() {
    setState(() {
      _descriptionControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController(text: '1'));
      _priceControllers.add(TextEditingController());
      _taxableList.add(true);
      _productIds.add(null);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _descriptionControllers[index].dispose();
      _quantityControllers[index].dispose();
      _priceControllers[index].dispose();
      _descriptionControllers.removeAt(index);
      _quantityControllers.removeAt(index);
      _priceControllers.removeAt(index);
      _taxableList.removeAt(index);
      _productIds.removeAt(index);
    });
  }

  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _paid => double.tryParse(_paidController.text) ?? 0;

  ({double subtotal, double taxAmount, double total}) get _totals {
    final items = List.generate(
      _descriptionControllers.length,
      (i) => DocumentItemInput(
        description: _descriptionControllers[i].text,
        quantity: double.tryParse(_quantityControllers[i].text) ?? 0,
        price: double.tryParse(_priceControllers[i].text) ?? 0,
        taxable: _taxableList[i],
        productId: _productIds[i],
      ),
    );
    final decimalDigits = Currency.decimalDigitsForCode(_business?.currencyCode);
    return DocumentService.calculateInvoiceTotals(
      items: items,
      discount: _discount,
      taxRate: _business?.taxRate ?? 0,
      pricesIncludeTax: _business?.pricesIncludeTax ?? false,
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
        ),
      );

  Future<void> _save({bool isDraft = false}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_business == null) return;

    if (_descriptionControllers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).pleaseAddItems)),
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
        MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: docId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e, l10n: AppLocalizations.of(context)))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final totals = _totals;
    final subtotal = totals.subtotal;
    final discount = _discount;
    final total = totals.total;
    final paid = _paid;
    final decimalDigits = Currency.decimalDigitsForCode(_business?.currencyCode);
    final remaining = MoneyUtils.calculateRemaining(total, paid, decimalDigits);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchase), centerTitle: true),
      body: ResponsiveCenter(child: Form(
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
                productId: _productIds[index],
                usePurchasePrice: true,
                onProductChanged: (productId) => setState(() => _productIds[index] = productId),
                onTaxableChanged: (value) => setState(() => _taxableList[index] = value ?? true),
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
                  borderRadius: BorderRadius.circular(AppDesignTokens.buttonRadius),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.paymentDetails,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _discountController,
              decoration: InputDecoration(
                labelText: l10n.discount,
                prefixIcon: const Icon(Icons.percent_rounded, size: 20),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _paidController,
              decoration: InputDecoration(
                labelText: l10n.paid,
                prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                helperText: l10n.remainingBalanceHelper,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.buttonRadius),
                  ),
                ),
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
      )),
    );
  }
}
