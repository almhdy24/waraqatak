import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../services/document_service.dart';
import '../widgets/contact_autocomplete_field.dart';
import '../widgets/document_item_form.dart';
import 'document_detail_screen.dart';

class InvoiceScreen extends StatefulWidget {
  final Contact? preselectedContact;
  const InvoiceScreen({super.key, this.preselectedContact});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
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
    // الاستماع لتغير الخصم والمدفوع لتحديث الإجمالي لحظياً
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

  double get _discount {
    return double.tryParse(_discountController.text) ?? 0;
  }

  double get _paid {
    return double.tryParse(_paidController.text) ?? 0;
  }

  ({double subtotal, double taxAmount, double total}) get _totals {
    final items = List.generate(
      _descriptionControllers.length,
      (index) => DocumentItemInput(
        description: _descriptionControllers[index].text,
        quantity: double.tryParse(_quantityControllers[index].text) ?? 0,
        price: double.tryParse(_priceControllers[index].text) ?? 0,
        taxable: _taxableList[index],
        productId: _productIds[index],
      ),
    );
    return DocumentService.calculateInvoiceTotals(
      items: items,
      discount: _discount,
      taxRate: _business?.taxRate ?? 0,
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_business == null) return;

    setState(() => _saving = true);

    final items = <DocumentItemInput>[];
    for (int i = 0; i < _descriptionControllers.length; i++) {
      items.add(DocumentItemInput(
        description: _descriptionControllers[i].text.trim(),
        quantity: double.parse(_quantityControllers[i].text),
        price: double.parse(_priceControllers[i].text),
        taxable: _taxableList[i],
        productId: _productIds[i],
      ));
    }

    try {
      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: _business!,
        contact: _selectedContact,
        items: items,
        discount: _discount,
        paid: _paid,
        notes: _notesController.text,
        date: DateTime.now(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: docId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).operationFailed}: $e')),
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
      appBar: AppBar(title: Text(l10n.invoice), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ContactAutocompleteField(
              label: l10n.customer,
              type: 'customer',
              initialContact: _selectedContact,
              onContactChanged: (contact) => _selectedContact = contact,
            ),
            const SizedBox(height: 16),
            Text(l10n.products, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...List.generate(
              _descriptionControllers.length,
              (index) => DocumentItemForm(
                descriptionController: _descriptionControllers[index],
                quantityController: _quantityControllers[index],
                priceController: _priceControllers[index],
                taxable: _taxableList[index],
                productId: _productIds[index],
                onProductChanged: (productId) {
                  setState(() => _productIds[index] = productId);
                },
                onTaxableChanged: (value) {
                  setState(() => _taxableList[index] = value ?? true);
                },
                onDelete: () => _removeItem(index),
                onChanged: () => setState(() {}), // ✅ تحديث فوري
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: Text(l10n.products),
            ),
            const Divider(),
            // ملخص مباشر
            Text('${l10n.subtotal}: ${NumberFormat('#,##0.00').format(subtotal)}'),
            Text('${l10n.discount}: ${NumberFormat('#,##0.00').format(discount)}'),
            Text('${l10n.tax} (${_business?.taxRate ?? 0}%): ${NumberFormat('#,##0.00').format(totals.taxAmount)}'),
            Text('${l10n.total}: ${NumberFormat('#,##0.00').format(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${l10n.paid}: ${NumberFormat('#,##0.00').format(paid)}'),
            Text('${l10n.remaining}: ${NumberFormat('#,##0.00').format(remaining)}', style: TextStyle(color: remaining > 0 ? Theme.of(context).colorScheme.error : Colors.green)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discountController,
              decoration: InputDecoration(labelText: l10n.discount),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextFormField(
              controller: _paidController,
              decoration: InputDecoration(labelText: l10n.paid),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(labelText: l10n.notes),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                child: _saving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
