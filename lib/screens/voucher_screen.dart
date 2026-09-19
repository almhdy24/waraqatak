import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../services/document_service.dart';
import '../utils/currency_utils.dart';
import '../widgets/contact_autocomplete_field.dart';
import 'document_detail_screen.dart';

enum VoucherType { paymentReceipt, expenseVoucher }

class VoucherScreen extends StatefulWidget {
  final VoucherType type;
  const VoucherScreen({super.key, required this.type});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  String _paymentMethod = 'cash';
  List<String> _configuredMethods = CurrencyUtils.defaultMethods;
  Map<String, String> _customMethodLabels = {};
  Business? _business;
  Contact? _selectedContact;
  String? _contactName;
  bool _saving = false;

  bool get isReceipt => widget.type == VoucherType.paymentReceipt;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    final business = await DatabaseHelper.instance.getFirstBusiness();
    final methods = await CurrencyUtils.getConfiguredMethods();
    final customLabels = await CurrencyUtils.getCustomMethods();
    if (!mounted) return;
    setState(() {
      _business = business;
      _configuredMethods = methods;
      _customMethodLabels = customLabels;
    });
    _ensureValidPaymentMethod();
  }

  void _ensureValidPaymentMethod() {
    if (!_configuredMethods.contains(_paymentMethod)) {
      setState(() {
        _paymentMethod = _configuredMethods.isNotEmpty ? _configuredMethods.first : 'cash';
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_business == null) return;
    setState(() => _saving = true);

    final amount = double.tryParse(_amountController.text) ?? 0;
    Contact? contact;
    if (_selectedContact != null) {
      contact = _selectedContact;
    } else if (_contactName != null && _contactName!.trim().isNotEmpty) {
      contact = Contact(name: _contactName!.trim(), type: isReceipt ? 'customer' : 'supplier');
    }

    // Ensure payment method is valid
    if (!_configuredMethods.contains(_paymentMethod)) {
      _paymentMethod = _configuredMethods.isNotEmpty ? _configuredMethods.first : 'cash';
    }

    try {
      final docId = await DocumentService.createDocument(
        type: isReceipt ? 'payment_receipt' : 'expense_voucher',
        business: _business!,
        contact: contact,
        items: const [],
        paid: amount,
        notes: _reasonController.text.trim(),
        date: DateTime.now(),
        paymentMethod: _paymentMethod,
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
    final isReceipt = this.isReceipt;
    final title = isReceipt ? l10n.paymentReceipt : l10n.expenseVoucher;
    final contactLabel = isReceipt ? l10n.receivedFrom : l10n.paidTo;
    final contactType = isReceipt ? 'customer' : 'supplier';
    final contactHint = isReceipt ? l10n.customer : l10n.supplier;

    final allowedMethods = _configuredMethods;

    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
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
                    Text(contactLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ContactAutocompleteField(
                      label: contactHint,
                      type: contactType,
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
                    Text(l10n.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.amount,
                        prefixIcon: const Icon(Icons.money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        final amount = double.tryParse(v ?? '');
                        if (amount == null || amount <= 0) return l10n.invalidAmount;
                        return null;
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
                    Text(l10n.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allowedMethods.map((method) {
                        return _paymentChip(
                            method, CurrencyUtils.getPaymentMethodLabel(method, l10n,
                                customLabels: _customMethodLabels));
                      }).toList(),
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
                    Text(l10n.reason, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: l10n.reason,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
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
                child: _saving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _paymentMethod == value,
      onSelected: (selected) {
        if (selected) setState(() => _paymentMethod = value);
      },
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: _paymentMethod == value ? Theme.of(context).colorScheme.primary : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _paymentMethod == value ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
        ),
      ),
    );
  }

}