import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/currency.dart';

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

  String _currencyCode = 'SDG'; // ✅ الجديد
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
          content: Text(
            '${AppLocalizations.of(context).operationFailed}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker().pickFiles(
        type: FileType.image,
        allowCompression: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('No data');
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
        SnackBar(
          content: Text(AppLocalizations.of(context).logoLoadFailed),
        ),
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

    final business = Business(
      id: _existing?.id,
      name: _nameController.text.trim(),
      ownerName: _ownerController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
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
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Logo section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.businessLogo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    if (_logoPath != null && File(_logoPath!).existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(_logoPath!),
                            width: 80, height: 80, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.business,
                            size: 40, color: Colors.grey),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.upload_file),
                          label: Text(l10n.changeLogo),
                        ),
                        if (_logoPath != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _removeLogo,
                            child: Text(l10n.removeLogo),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Business info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.businessName),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ownerController,
                      decoration: InputDecoration(labelText: l10n.ownerName),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: l10n.phone),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(labelText: l10n.address),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: l10n.email),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final emailRegExp =
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        return emailRegExp.hasMatch(v.trim())
                            ? null
                            : l10n.invalidAmount;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.settings,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    // Currency dropdown
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
                      decoration: InputDecoration(labelText: l10n.currency),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taxRateController,
                      decoration: InputDecoration(labelText: l10n.taxRate),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final rate = double.tryParse(v ?? '');
                        if (rate == null || rate < 0 || rate > 100) {
                          return l10n.invalidAmount;
                        }
                        return null;
                      },
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
                    foregroundColor: Colors.white),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
