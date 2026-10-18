import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../services/document_service.dart';
import '../utils/error_utils.dart';
import '../widgets/contact_autocomplete_field.dart';
import '../widgets/document_item_form.dart';
import 'document_detail_screen.dart';
import '../widgets/responsive.dart';

class _TotalsCard extends StatelessWidget {
  final AppLocalizations l10n;
  final String currencySymbol;
  final double taxRate;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double total;
  final double paid;
  final double remaining;

  const _TotalsCard({
    required this.l10n,
    required this.currencySymbol,
    required this.taxRate,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.total,
    required this.paid,
    required this.remaining,
  });

  String _fmt(double v) => '${NumberFormat('#,##0.00').format(v)} $currencySymbol';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            _row(l10n.subtotal, _fmt(subtotal)),
            if (discount > 0) _row(l10n.discount, '- ${_fmt(discount)}', color: cs.error),
            if (taxRate > 0) _row('${l10n.tax} ($taxRate%)', _fmt(taxAmount)),
            const Divider(height: 16),
            _row(l10n.total, _fmt(total), bold: true, color: cs.primary),
            _row(l10n.paid, _fmt(paid)),
            _row(
              l10n.remaining,
              _fmt(remaining),
              bold: true,
              color: remaining > 0 ? cs.error : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
      fontSize: bold ? 15 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
    return DocumentService.calculateInvoiceTotals(
      items: items,
      discount: _discount,
      taxRate: _business?.taxRate ?? 0,
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
    final remaining = total - paid;

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
            Text(l10n.items, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: Text(l10n.addItem),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _discountController,
              decoration: InputDecoration(labelText: l10n.discount),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _paidController,
              decoration: InputDecoration(labelText: l10n.paid),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(labelText: l10n.notes),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _TotalsCard(
              l10n: l10n,
              currencySymbol: _business?.currencySymbol ?? '',
              taxRate: _business?.taxRate ?? 0,
              subtotal: subtotal,
              discount: discount,
              taxAmount: totals.taxAmount,
              total: total,
              paid: paid,
              remaining: remaining,
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
