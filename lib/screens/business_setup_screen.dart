import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/currency.dart';
import 'financial_settings_screen.dart';
import 'payment_methods_screen.dart';
import '../widgets/responsive.dart';

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0');

  String _currencyCode = 'SDG';
  String? _logoPath;
  Business? _existing;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final business = await DatabaseHelper.instance.getFirstBusiness();
      if (!mounted) return;
      setState(() {
        _existing = business;
        if (business != null) {
          _nameController.text = business.name;
          _ownerController.text = business.ownerName;
          _phoneController.text = business.phone;
          _addressController.text = business.address;
          _emailController.text = business.email ?? '';
          _taxRateController.text = business.taxRate.toString();
          _logoPath = business.logoPath;
          _currencyCode = business.currencyCode;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context).operationFailed}: $e'),
        ),
      );
    }
  }

  Future<void> _pickLogo() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('No data');
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedFile = File('${directory.path}/$fileName');
      await savedFile.writeAsBytes(bytes);
      if (_logoPath != null && File(_logoPath!).existsSync()) {
        await File(_logoPath!).delete();
      }
      if (!mounted) return;
      setState(() => _logoPath = savedFile.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).logoLoadFailed)),
      );
    }
  }

  void _removeLogo() {
    if (_logoPath != null && File(_logoPath!).existsSync()) {
      File(_logoPath!).deleteSync();
    }
    setState(() => _logoPath = null);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final business = _existing != null
        ? _existing!.copyWith(
            name: _nameController.text.trim(),
            ownerName: _ownerController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            logoPath: _logoPath,
            currencyCode: _currencyCode,
            taxRate:
                double.tryParse(_taxRateController.text) ?? _existing!.taxRate,
          )
        : Business(
            name: _nameController.text.trim(),
            ownerName: _ownerController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            logoPath: _logoPath,
            currencyCode: _currencyCode,
            taxRate: double.tryParse(_taxRateController.text) ?? 0,
          );

    try {
      if (business.id == null) {
        await DatabaseHelper.instance.insertBusiness(business);
      } else {
        await DatabaseHelper.instance.updateBusiness(business);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
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
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessData), centerTitle: true),
      body: ResponsiveCenter(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Section 1: Business Identity & Contact ──
              _sectionHeader(l10n.basicInfo, Icons.business_outlined),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.businessName,
                          prefixIcon: const Icon(
                            Icons.storefront_outlined,
                            size: 20,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? l10n.required
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ownerController,
                        decoration: InputDecoration(
                          labelText: l10n.ownerName,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            size: 20,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? l10n.required
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: l10n.phone,
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            size: 20,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? l10n.required
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: l10n.address,
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? l10n.required
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: l10n.email,
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            size: 20,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final emailRegExp = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          );
                          return emailRegExp.hasMatch(v.trim())
                              ? null
                              : l10n.invalidAmount;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Section 2: Logo & Visual Branding ──
              _sectionHeader(l10n.visualBranding, Icons.image_outlined),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_logoPath != null && File(_logoPath!).existsSync())
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_logoPath!),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.business_outlined,
                            size: 36,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.businessLogo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(Icons.upload_file, size: 18),
                                  label: Text(l10n.changeLogo),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                if (_logoPath != null)
                                  TextButton(
                                    onPressed: _removeLogo,
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    child: Text(l10n.removeLogo),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Section 3: Financial Defaults & Currency ──
              _sectionHeader(
                l10n.financialDefaults,
                Icons.account_balance_outlined,
              ),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _currencyCode,
                        items: Currency.supportedCurrencies.map((currency) {
                          return DropdownMenuItem<String>(
                            value: currency.code,
                            child: Text(
                              '${currency.nameAr} (${currency.symbol})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _currencyCode = value!);
                        },
                        decoration: InputDecoration(
                          labelText: l10n.currency,
                          prefixIcon: const Icon(
                            Icons.currency_exchange,
                            size: 20,
                          ),
                          helperText: l10n.currencyScopeNote,
                          helperMaxLines: 2,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.receipt_long_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          l10n.legalAndTaxInfo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          _existing?.taxesEnabled == true
                              ? '${l10n.taxesEnabledActive} • ${l10n.taxId}: ${_existing?.taxId ?? l10n.notConfigured}'
                              : '${l10n.taxesDisabledInactive} • ${l10n.taxSettingsManagedInFinancial}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          l10n.isArabic
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FinancialSettingsScreen(),
                            ),
                          );
                          _load();
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.payments_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          l10n.paymentMethods,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          l10n.configurePaymentMethods,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          l10n.isArabic
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentMethodsScreen(),
                          ),
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
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
