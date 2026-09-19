import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../services/document_service.dart';
import '../widgets/contact_autocomplete_field.dart';
import '../widgets/document_item_form.dart';
import 'document_detail_screen.dart';

class QuotationScreen extends StatefulWidget {
  const QuotationScreen({super.key});

  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _validityController = TextEditingController(text: '7');

  final List<TextEditingController> _desc = [];
  final List<TextEditingController> _qty = [];
  final List<TextEditingController> _price = [];
  final List<bool> _taxable = [];
  final List<int?> _productIds = [];

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
    if (!mounted) return;
    setState(() => _business = business);
  }

  void _addItem() {
    setState(() {
      _desc.add(TextEditingController());
      _qty.add(TextEditingController(text: '1'));
      _price.add(TextEditingController());
      _taxable.add(true);
      _productIds.add(null);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _desc[index].dispose();
      _qty[index].dispose();
      _price[index].dispose();
      _desc.removeAt(index);
      _qty.removeAt(index);
      _price.removeAt(index);
      _taxable.removeAt(index);
      _productIds.removeAt(index);
    });
  }

  List<DocumentItemInput> _buildItems() => List.generate(
        _desc.length,
        (i) => DocumentItemInput(
          description: _desc[i].text.trim(),
          quantity: double.parse(_qty[i].text),
          price: double.parse(_price[i].text),
          taxable: _taxable[i],
          productId: _productIds[i],
        ),
      );

  Future<void> _save({bool isDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_business == null) return;

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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: docId)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).operationFailed}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.quotation), centerTitle: true),
      body: Form(
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
            ...List.generate(_desc.length, (i) => DocumentItemForm(
              descriptionController: _desc[i],
              quantityController: _qty[i],
              priceController: _price[i],
              taxable: _taxable[i],
              productId: _productIds[i],
              onProductChanged: (productId) {
                setState(() => _productIds[i] = productId);
              },
              onTaxableChanged: (value) {
                setState(() => _taxable[i] = value ?? true);
              },
              onDelete: () => _removeItem(i),
            )),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: Text(l10n.products),
            ),
            const Divider(),
            TextFormField(
              controller: _validityController,
              decoration: InputDecoration(labelText: l10n.validityDays),
              keyboardType: TextInputType.number,
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
                onPressed: () => _save(),
                style: FilledButton.styleFrom(foregroundColor: Colors.white),
                child: Text(l10n.save),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _save(isDraft: true),
              child: Text(l10n.saveDraft),
            ),
          ],
        ),
      ),
    );
  }
}