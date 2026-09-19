import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../utils/currency_utils.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<String> _enabled = [];
  Map<String, String> _custom = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await CurrencyUtils.getConfiguredMethods();
    final custom = await CurrencyUtils.getCustomMethods();
    if (!mounted) return;
    setState(() {
      _enabled = List.from(prefs);
      _custom = Map.from(custom);
      _loading = false;
    });
  }

  Future<void> _save() async {
    await CurrencyUtils.saveConfiguredMethods(_enabled);
    await CurrencyUtils.saveCustomMethods(_custom);
  }

  void _togglePredefined(String key) {
    setState(() {
      if (_enabled.contains(key)) {
        _enabled.remove(key);
      } else {
        _enabled.add(key);
      }
    });
    _save();
  }

  Future<void> _addOrEditCustom({String? existingKey}) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: existingKey != null ? _custom[existingKey] : '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingKey == null ? l10n.addPaymentMethod : l10n.editPaymentMethod),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.methodName),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    final label = controller.text.trim();
    if (label.isEmpty) return;

    if (existingKey != null) {
      setState(() => _custom[existingKey] = label);
      await CurrencyUtils.renameCustomMethod(existingKey, label);
    } else {
      final key = await CurrencyUtils.addCustomMethod(label);
      setState(() {
        _custom[key] = label;
        _enabled.add(key);
      });
    }
    await _save();
  }

  Future<void> _deleteCustom(String key) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteMethod),
        content: Text('${l10n.delete}: ${_custom[key] ?? key}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _custom.remove(key);
      _enabled.remove(key);
    });
    await CurrencyUtils.removeCustomMethod(key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.paymentMethods), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final enabledPredefined = _enabled.where(CurrencyUtils.allMethods.contains).toSet();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentMethods), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _addOrEditCustom,
        tooltip: l10n.addPaymentMethod,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l10n.predefinedMethods,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...CurrencyUtils.allMethods.map((key) {
            final isEnabled = enabledPredefined.contains(key);
            return SwitchListTile(
              title: Text(CurrencyUtils.getPaymentMethodLabel(key, l10n)),
              value: isEnabled,
              onChanged: (_) => _togglePredefined(key),
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l10n.customMethods,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          if (_custom.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.noCustomMethods,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ..._custom.entries.map((e) {
            final isActive = _enabled.contains(e.key);
            return ListTile(
              title: Text(e.value),
              leading: Switch(
                value: isActive,
                onChanged: (_) => _togglePredefined(e.key),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _addOrEditCustom(existingKey: e.key),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20,
                      color: Theme.of(context).colorScheme.error),
                  onPressed: () => _deleteCustom(e.key),
                ),
              ]),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
