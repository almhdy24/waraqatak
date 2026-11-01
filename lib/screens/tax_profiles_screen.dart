import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/tax_profile.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';

class TaxProfilesScreen extends StatefulWidget {
  const TaxProfilesScreen({super.key});

  @override
  State<TaxProfilesScreen> createState() => _TaxProfilesScreenState();
}

class _TaxProfilesScreenState extends State<TaxProfilesScreen> {
  List<TaxProfile>? _profiles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await DatabaseHelper.instance.getTaxProfiles();
    if (!mounted) return;
    setState(() => _profiles = profiles);
  }

  Future<void> _showForm({TaxProfile? profile}) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl =
        TextEditingController(text: profile?.name ?? '');
    final rateCtrl = TextEditingController(
        text: profile != null ? profile.rate.toString() : '');
    final notesCtrl = TextEditingController(text: profile?.notes ?? '');

    String selectedType = profile?.type ?? 'vat';
    String selectedMode =
        profile?.calculationMode ?? TaxProfile.modeExclusive;
    bool isDefault = profile?.isDefault ?? false;
    bool isActive = profile?.isActive ?? true;

    final types = {
      'vat': l10n.taxTypeVat,
      'sales_tax': l10n.taxTypeSalesTax,
      'service_charge': l10n.taxTypeServiceCharge,
      'other': l10n.taxTypeOther,
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
              profile == null ? l10n.addTaxProfile : l10n.editTaxProfile),
          contentPadding:
              const EdgeInsets.fromLTRB(24, 16, 24, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.taxProfileName),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration:
                      InputDecoration(labelText: l10n.taxProfileType),
                  items: types.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rateCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.taxProfileRate),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMode,
                  decoration:
                      InputDecoration(labelText: l10n.calculationMode),
                  items: [
                    DropdownMenuItem(
                      value: TaxProfile.modeExclusive,
                      child: Text(l10n.taxProfileExclusive),
                    ),
                    DropdownMenuItem(
                      value: TaxProfile.modeInclusive,
                      child: Text(l10n.taxProfileInclusive),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialog(() => selectedMode = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(labelText: l10n.notes),
                  maxLines: 2,
                ),
                SwitchListTile(
                  value: isDefault,
                  title: Text(l10n.taxProfileDefault),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialog(() => isDefault = v),
                ),
                SwitchListTile(
                  value: isActive,
                  title: Text(l10n.active),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialog(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final rate = double.tryParse(rateCtrl.text.trim());
                if (name.isEmpty || rate == null || rate < 0) {
                  AppSnackBar.show(
                    ctx,
                    l10n.invalidAmount,
                    severity: AppSnackBarSeverity.warning,
                  );
                  return;
                }
                Navigator.pop(ctx);
                final p = TaxProfile(
                  id: profile?.id,
                  name: name,
                  type: selectedType,
                  rate: rate,
                  isActive: isActive,
                  isDefault: isDefault,
                  calculationMode: selectedMode,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                );
                if (profile == null) {
                  await DatabaseHelper.instance.insertTaxProfile(p);
                } else {
                  await DatabaseHelper.instance.updateTaxProfile(p);
                }
                _load();
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    rateCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _delete(TaxProfile profile) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteProfile),
        content: Text(profile.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteTaxProfile(profile.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.taxProfiles),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
      body: ResponsiveCenter(child: _profiles == null
          ? const Center(child: CircularProgressIndicator())
          : _profiles!.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.percent_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(l10n.noTaxProfiles,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _profiles!.length,
                  itemBuilder: (_, i) {
                    final p = _profiles![i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          child: Text(
                            '${p.rate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            if (p.isDefault) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.taxProfileDefault,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (!p.isActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(l10n.inactive,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          p.calculationMode == TaxProfile.modeInclusive
                              ? l10n.taxProfileInclusive
                              : l10n.taxProfileExclusive,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showForm(profile: p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color:
                                  Theme.of(context).colorScheme.error,
                              onPressed: () => _delete(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )),
    );
  }
}
