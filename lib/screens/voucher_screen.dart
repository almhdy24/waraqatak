import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../services/document_service.dart';
import '../models/payment_method.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/contact_autocomplete_field.dart';
import 'document_detail_screen.dart';
import '../widgets/responsive.dart';

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
  List<PaymentMethod> _enabledMethods = [];
  Business? _business;
  Contact? _selectedContact;
  String? _contactName;
  bool _saving = false;

  bool get isReceipt => widget.type == VoucherType.paymentReceipt;

  bool get _isDirty =>
      _selectedContact != null ||
      _amountController.text.isNotEmpty ||
      _reasonController.text.isNotEmpty;

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
    final methods = await DatabaseHelper.instance.getEnabledPaymentMethods();
    if (!mounted) return;
    setState(() {
      _business = business;
      _enabledMethods = methods;
      if (!methods.any((m) => m.key == _paymentMethod)) {
        _paymentMethod = methods.isNotEmpty ? methods.first.key : 'cash';
      }
    });
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

    if (!_enabledMethods.any((m) => m.key == _paymentMethod)) {
      _paymentMethod = _enabledMethods.isNotEmpty ? _enabledMethods.first.key : 'cash';
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
      AppSnackBar.show(
        context,
        '${AppLocalizations.of(context).operationFailed}: $e',
        severity: AppSnackBarSeverity.error,
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

    final allowedMethods = _enabledMethods;

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
        appBar: AppBar(title: Text(title), centerTitle: true),
        body: ResponsiveCenter(child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
              ),
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
              ),
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
              ),
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
                        return _paymentChip(method.key, method.label(l10n.langCode));
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
              ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.buttonRadius),
                  ),
                ),
                child: _saving
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      )),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: _paymentMethod == value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _paymentMethod == value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }

}