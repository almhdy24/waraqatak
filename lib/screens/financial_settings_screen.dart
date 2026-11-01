import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/currency.dart';
import '../models/tax_profile.dart';
import '../services/document_service.dart';
import '../utils/format_utils.dart';
import 'tax_profiles_screen.dart';
import '../widgets/app_confirm_dialog.dart';
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
  bool _wholesalePricingEnabled = false;

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
    final profiles = await DatabaseHelper.instance.getTaxProfiles(
      activeOnly: true,
    );
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
        _wholesalePricingEnabled = business.wholesalePricingEnabled;
      }
    });
  }

  Future<void> _save() async {
    if (_business == null) return;
    setState(() => _saving = true);
    try {
      final selectedProfile = _profiles
          .where((p) => p.id == _defaultTaxProfileId)
          .firstOrNull;
      final effectiveRate = selectedProfile?.rate ?? _business!.taxRate;

      final updated = Business(
        id: _business!.id,
        name: _business!.name,
        ownerName: _business!.ownerName,
        phone: _business!.phone,
        address: _business!.address,
        email: _business!.email,
        logoPath: _business!.logoPath,
        currencyCode: _business!.currencyCode,
        taxRate: effectiveRate,
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
        wholesalePricingEnabled: _wholesalePricingEnabled,
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
          content: Text(AppLocalizations.of(context).operationSuccessful),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).operationFailed)),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section 1: Tax System Settings ──
            _sectionHeader(l10n.taxSettings, Icons.percent_outlined),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.taxesStatus,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.taxesEnabledDesc,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _taxesEnabled,
                          onChanged: (v) => setState(() => _taxesEnabled = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _taxesEnabled
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.5)
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _taxesEnabled
                                ? Icons.check_circle_outline
                                : Icons.block_outlined,
                            size: 14,
                            color: _taxesEnabled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _taxesEnabled
                                ? l10n.taxesEnabledActive
                                : l10n.taxesDisabledInactive,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _taxesEnabled
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_taxesEnabled) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.taxZeroRatedVsDisabled,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (_taxesEnabled) ...[
              // Pricing Mode Card
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
                      SwitchListTile(
                        value: _pricesIncludeTax,
                        title: Text(
                          l10n.pricesIncludeTax,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _pricesIncludeTax
                              ? l10n.taxInclusiveExplained
                              : l10n.taxExclusiveExplained,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _pricesIncludeTax = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Default Tax Profile Card
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
                      Text(
                        l10n.defaultTaxProfile,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int?>(
                        initialValue:
                            _profiles.any((p) => p.id == _defaultTaxProfileId)
                            ? _defaultTaxProfileId
                            : null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(l10n.noDefaultProfile),
                          ),
                          ..._profiles.map(
                            (p) => DropdownMenuItem<int?>(
                              value: p.id,
                              child: Text(
                                '${p.name} (${FormatUtils.formatTaxRate(p.rate)})',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _defaultTaxProfileId = v),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.productTaxOverrideNote,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.manage_accounts_outlined,
                          size: 18,
                        ),
                        label: Text(l10n.taxProfiles),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TaxProfilesScreen(),
                            ),
                          );
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Live Calculation Preview
              _buildTaxLivePreview(l10n),
            ],
            const SizedBox(height: 14),

            // Wholesale & Retail Pricing Card
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
                    SwitchListTile(
                      value: _wholesalePricingEnabled,
                      title: Text(
                        l10n.wholesalePricing,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        l10n.wholesalePricingDesc,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) async {
                        if (!v && _wholesalePricingEnabled) {
                          final proceed = await AppConfirmDialog.show(
                            context,
                            title: l10n.wholesalePricing,
                            message: l10n.wholesalePricingDisableWarning,
                            confirmLabel: l10n.disableAction,
                            isDestructive: false,
                          );
                          if (!proceed) return;
                        }
                        setState(() => _wholesalePricingEnabled = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Section 2: Legal Identity & Tax Registration ──
            _sectionHeader(l10n.legalIdentity, Icons.badge_outlined),
            _field(_legalNameCtrl, l10n.legalName),
            _field(_taxIdCtrl, l10n.taxId),
            _field(_taxRegCtrl, l10n.taxReg),
            _field(_commercialRegCtrl, l10n.commercialReg),
            _field(_branchCtrl, l10n.branch),
            const SizedBox(height: 24),

            // ── Section 3: Document Settings ──
            _sectionHeader(l10n.documentSettings, Icons.description_outlined),
            _field(
              _invoiceTitleCtrl,
              l10n.invoiceTitle,
              hint: l10n.invoiceTitleDesc,
            ),
            _field(
              _legalFooterCtrl,
              l10n.legalFooter,
              hint: l10n.legalFooterDesc,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
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

  Widget _buildTaxLivePreview(AppLocalizations l10n) {
    final selectedProfile = _profiles
        .where((p) => p.id == _defaultTaxProfileId)
        .firstOrNull;
    final rate = selectedProfile?.rate ?? _business?.taxRate ?? 0.0;
    final decimalDigits = Currency.decimalDigitsForCode(
      _business?.currencyCode,
    );
    final sym = _business?.currencySymbol ?? '';

    // Sample calculation using authoritative DocumentService logic:
    const sampleItem = DocumentItemInput(
      description: 'Sample',
      quantity: 1,
      price: 100,
    );
    final totals = DocumentService.calculateInvoiceTotals(
      items: [sampleItem],
      discount: 10,
      taxRate: rate,
      pricesIncludeTax: _pricesIncludeTax,
      decimalDigits: decimalDigits,
    );

    final netBase = totals.total - totals.taxAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.taxLivePreview,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _pricesIncludeTax ? l10n.pricesIncludeTax : l10n.tax,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.taxLivePreviewDesc,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 16),
          _previewRow(
            _pricesIncludeTax ? l10n.taxSampleEnteredPrice : l10n.subtotal,
            '100.00 $sym',
          ),
          const SizedBox(height: 3),
          _previewRow(l10n.discount, '-10.00 $sym'),
          const SizedBox(height: 3),
          _previewRow(
            _pricesIncludeTax ? l10n.netTaxableBase : l10n.taxSampleNetBase,
            '${netBase.toStringAsFixed(2)} $sym',
          ),
          const SizedBox(height: 3),
          _previewRow(
            _pricesIncludeTax
                ? '${l10n.taxIncluded} (${FormatUtils.formatTaxRate(rate)})'
                : '${l10n.tax} (${FormatUtils.formatTaxRate(rate)})',
            '${totals.taxAmount.toStringAsFixed(2)} $sym',
          ),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.taxSampleTotalPayable,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                '${totals.total.toStringAsFixed(2)} $sym',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
