import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/tax_profile.dart';
import 'tax_profiles_screen.dart';
import '../widgets/responsive.dart';

class FinancialSettingsScreen extends StatefulWidget {
  const FinancialSettingsScreen({super.key});

  @override
  State<FinancialSettingsScreen> createState() =>
      _FinancialSettingsScreenState();
}

class _FinancialSettingsScreenState extends State<FinancialSettingsScreen> {
  Business? _business;
  List<TaxProfile> _profiles = [];
  bool _saving = false;

  // Legal identity controllers
  final _legalNameCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _taxRegCtrl = TextEditingController();
  final _commercialRegCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  // Document settings controllers
  final _invoiceTitleCtrl = TextEditingController();
  final _legalFooterCtrl = TextEditingController();

  // Tax settings state
  bool _taxesEnabled = false;
  bool _pricesIncludeTax = false;
  int? _defaultTaxProfileId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _legalNameCtrl.dispose();
    _taxIdCtrl.dispose();
    _taxRegCtrl.dispose();
    _commercialRegCtrl.dispose();
    _branchCtrl.dispose();
    _invoiceTitleCtrl.dispose();
    _legalFooterCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final business = await DatabaseHelper.instance.getFirstBusiness();
    final profiles = await DatabaseHelper.instance.getTaxProfiles(activeOnly: true);
    if (!mounted) return;
    setState(() {
      _business = business;
      _profiles = profiles;
      if (business != null) {
        _legalNameCtrl.text = business.legalName ?? '';
        _taxIdCtrl.text = business.taxId ?? '';
        _taxRegCtrl.text = business.taxReg ?? '';
        _commercialRegCtrl.text = business.commercialReg ?? '';
        _branchCtrl.text = business.branch ?? '';
        _invoiceTitleCtrl.text = business.invoiceTitle ?? '';
        _legalFooterCtrl.text = business.legalFooter ?? '';
        _taxesEnabled = business.taxesEnabled;
        _pricesIncludeTax = business.pricesIncludeTax;
        _defaultTaxProfileId = business.defaultTaxProfileId;
      }
    });
  }

  Future<void> _save() async {
    if (_business == null) return;
    setState(() => _saving = true);
    try {
      final updated = Business(
        id: _business!.id,
        name: _business!.name,
        ownerName: _business!.ownerName,
        phone: _business!.phone,
        address: _business!.address,
        email: _business!.email,
        logoPath: _business!.logoPath,
        currencyCode: _business!.currencyCode,
        taxRate: _business!.taxRate,
        legalName: _legalNameCtrl.text.trim().isEmpty
            ? null
            : _legalNameCtrl.text.trim(),
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        taxReg: _taxRegCtrl.text.trim().isEmpty
            ? null
            : _taxRegCtrl.text.trim(),
        commercialReg: _commercialRegCtrl.text.trim().isEmpty
            ? null
            : _commercialRegCtrl.text.trim(),
        branch: _branchCtrl.text.trim().isEmpty
            ? null
            : _branchCtrl.text.trim(),
        taxesEnabled: _taxesEnabled,
        pricesIncludeTax: _pricesIncludeTax,
        defaultTaxProfileId: _defaultTaxProfileId,
        invoiceTitle: _invoiceTitleCtrl.text.trim().isEmpty
            ? null
            : _invoiceTitleCtrl.text.trim(),
        legalFooter: _legalFooterCtrl.text.trim().isEmpty
            ? null
            : _legalFooterCtrl.text.trim(),
      );
      await DatabaseHelper.instance.updateBusiness(updated);
      if (!mounted) return;
      setState(() {
        _business = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).operationSuccessful)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).operationFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_business == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.financialSettings), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.financialSettings),
        centerTitle: true,
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
        ],
      ),
      body: ResponsiveCenter(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Legal Identity ──
          _sectionHeader(l10n.legalIdentity, Icons.badge_outlined),
          _field(_legalNameCtrl, l10n.legalName),
          _field(_taxIdCtrl, l10n.taxId),
          _field(_taxRegCtrl, l10n.taxReg),
          _field(_commercialRegCtrl, l10n.commercialReg),
          _field(_branchCtrl, l10n.branch),
          const SizedBox(height: 24),

          // ── Tax Settings ──
          _sectionHeader(l10n.taxSettings, Icons.percent_outlined),
          SwitchListTile(
            value: _taxesEnabled,
            title: Text(l10n.taxesEnabled),
            subtitle: Text(l10n.taxesEnabledDesc),
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _taxesEnabled = v),
          ),
          if (_taxesEnabled) ...[
            SwitchListTile(
              value: _pricesIncludeTax,
              title: Text(l10n.pricesIncludeTax),
              subtitle: Text(l10n.pricesIncludeTaxDesc),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _pricesIncludeTax = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _profiles.any((p) => p.id == _defaultTaxProfileId)
                  ? _defaultTaxProfileId
                  : null,
              decoration: InputDecoration(
                labelText: l10n.defaultTaxProfile,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<int?>(
                    value: null, child: Text(l10n.noDefaultProfile)),
                ..._profiles.map((p) => DropdownMenuItem<int?>(
                    value: p.id,
                    child: Text('${p.name} (${p.rate.toStringAsFixed(0)}%)'))),
              ],
              onChanged: (v) => setState(() => _defaultTaxProfileId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.manage_accounts_outlined),
              label: Text(l10n.taxProfiles),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TaxProfilesScreen()),
                );
                _load();
              },
            ),
          ],
          const SizedBox(height: 24),

          // ── Document Settings ──
          _sectionHeader(l10n.documentSettings, Icons.description_outlined),
          _field(_invoiceTitleCtrl, l10n.invoiceTitle,
              hint: l10n.invoiceTitleDesc),
          _field(_legalFooterCtrl, l10n.legalFooter,
              hint: l10n.legalFooterDesc, maxLines: 3),
          const SizedBox(height: 32),
        ],
      )),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Theme.of(context).colorScheme.primary,
              )),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        maxLines: maxLines,
      ),
    );
  }
}
