import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/contact.dart';
import '../utils/error_utils.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';

class ContactFormScreen extends StatefulWidget {
  final Contact? contact;
  final String? initialType;
  const ContactFormScreen({super.key, this.contact, this.initialType});

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  String _type = 'customer';
  String _pricingCategory = Contact.categoryRetail;
  bool _wholesalePricingEnabled = false;
  bool _active = true;
  bool _saving = false;

  bool get _isDirty {
    if (widget.contact == null) {
      return _nameController.text.isNotEmpty ||
          _phoneController.text.isNotEmpty ||
          _emailController.text.isNotEmpty ||
          _addressController.text.isNotEmpty ||
          _notesController.text.isNotEmpty;
    }
    final c = widget.contact!;
    return _nameController.text != c.name ||
        _phoneController.text != (c.phone ?? '') ||
        _emailController.text != (c.email ?? '') ||
        _addressController.text != (c.address ?? '') ||
        _notesController.text != (c.notes ?? '') ||
        _type != c.type ||
        _pricingCategory != c.pricingCategory ||
        _active != c.active;
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

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _nameController.text = widget.contact!.name;
      _phoneController.text = widget.contact!.phone ?? '';
      _emailController.text = widget.contact!.email ?? '';
      _addressController.text = widget.contact!.address ?? '';
      _notesController.text = widget.contact!.notes ?? '';
      _type = widget.contact!.type;
      _pricingCategory = widget.contact!.pricingCategory;
      _active = widget.contact!.active;
    } else if (widget.initialType != null) {
      _type = widget.initialType!;
    }
    _loadWholesaleStatus();
  }

  Future<void> _loadWholesaleStatus() async {
    final b = await DatabaseHelper.instance.getFirstBusiness();
    if (mounted) {
      setState(() => _wholesalePricingEnabled = b?.wholesalePricingEnabled ?? false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final contact = Contact(
      id: widget.contact?.id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      type: _type,
      pricingCategory:
          _type == 'customer' ? _pricingCategory : Contact.categoryRetail,
      active: _active,
    );

    try {
      if (contact.id == null) {
        await DatabaseHelper.instance.insertContact(contact);
      } else {
        await DatabaseHelper.instance.updateContact(contact);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: AppLocalizations.of(context)),
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
    final isEdit = widget.contact != null;
    final isSupplier = _type == 'supplier';
    final title = isEdit
        ? (isSupplier ? l10n.editSupplier : l10n.editCustomer)
        : (isSupplier ? l10n.addSupplier : l10n.addCustomer);

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
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
        ),
        body: ResponsiveCenter(child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: isSupplier ? l10n.supplier : l10n.customer,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: l10n.phone,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: l10n.address,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: l10n.notes,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      items: [
                        DropdownMenuItem(value: 'customer', child: Text(l10n.customer)),
                        DropdownMenuItem(value: 'supplier', child: Text(l10n.supplier)),
                      ],
                      onChanged: (value) => setState(() => _type = value!),
                      decoration: InputDecoration(
                        labelText: l10n.type,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (_type == 'customer' && _wholesalePricingEnabled) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _pricingCategory,
                        decoration: InputDecoration(
                          labelText: l10n.pricingCategory,
                          helperText: l10n.pricingCategoryCustomerDesc,
                          prefixIcon: const Icon(Icons.price_change_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: Contact.categoryRetail,
                            child: Text(l10n.retail),
                          ),
                          DropdownMenuItem(
                            value: Contact.categoryWholesale,
                            child: Text(l10n.wholesale),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _pricingCategory = val);
                        },
                      ),
                    ],
                    if (isEdit) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text(_active ? l10n.active : l10n.inactive),
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
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
                ),
                child: _saving
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                      )
                    : Text(
                        isEdit
                            ? l10n.saveChanges
                            : (isSupplier ? l10n.saveSupplier : l10n.saveCustomer),
                      ),
              ),
            ),
          ],
        ),
      )),
      ),
    );
  }
}
