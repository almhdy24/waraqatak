import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../services/document_service.dart';
import '../widgets/contact_autocomplete_field.dart';
import 'document_detail_screen.dart';

class CustomDocumentScreen extends StatefulWidget {
  const CustomDocumentScreen({super.key});

  @override
  State<CustomDocumentScreen> createState() => _CustomDocumentScreenState();
}

class _CustomDocumentScreenState extends State<CustomDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Business? _business;
  Contact? _selectedContact;
  String? _contactName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (!mounted) return;
    setState(() => _business = business);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_business == null) return;
    setState(() => _saving = true);

    final amount = double.tryParse(_amountController.text) ?? 0;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final notes = _notesController.text.trim();

    final String fullNotes = [
      if (title.isNotEmpty) '${AppLocalizations.of(context).title}: $title',
      if (content.isNotEmpty) content,
      if (notes.isNotEmpty) notes,
    ].join('\n');

    Contact? contact;
    if (_selectedContact != null) {
      contact = _selectedContact;
    } else if (_contactName != null && _contactName!.trim().isNotEmpty) {
      contact = Contact(name: _contactName!.trim(), type: 'customer');
    }

    try {
      final docId = await DocumentService.createDocument(
        type: 'custom',
        business: _business!,
        contact: contact,
        items: const [],
        paid: amount,
        notes: fullNotes,
        date: _selectedDate,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: docId)));
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.customDocument), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(hintText: l10n.title, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ContactAutocompleteField(
                      label: l10n.customer,
                      type: 'customer',
                      onContactChanged: (contact) {
                        setState(() {
                          _selectedContact = contact;
                          _contactName = contact?.name;
                        });
                      },
                      onTextChanged: (value) {
                        setState(() {
                          _contactName = value;
                          if (_selectedContact?.name != value) _selectedContact = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.content, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contentController,
                      maxLines: 5,
                      decoration: InputDecoration(hintText: l10n.content, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: l10n.amount, prefixIcon: const Icon(Icons.money), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final amount = double.tryParse(v);
                              if (amount == null || amount < 0) return l10n.invalidAmount;
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate))),
                              TextButton(onPressed: () async {
                                final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                if (picked != null && mounted) setState(() => _selectedDate = picked);
                              }, child: Text(l10n.edit)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.notes, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(controller: _notesController, maxLines: 2, decoration: InputDecoration(hintText: l10n.notes, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  ],
                ),
              ),
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