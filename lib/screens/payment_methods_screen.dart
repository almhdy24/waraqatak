import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/payment_method.dart';
import '../utils/currency_utils.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<PaymentMethod> _methods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final methods = await DatabaseHelper.instance.getPaymentMethods();
    if (!mounted) return;
    setState(() {
      _methods = methods;
      _loading = false;
    });
  }

  Future<void> _toggleEnabled(PaymentMethod method) async {
    await DatabaseHelper.instance
        .setPaymentMethodEnabled(method.key, enabled: !method.isEnabled);
    await _load();
  }

  Future<void> _setDefault(PaymentMethod method) async {
    await DatabaseHelper.instance.setPaymentMethodDefault(method.key);
    await _load();
  }

  Future<void> _addCustom() async {
    final l10n = AppLocalizations.of(context);
    final arCtrl = TextEditingController();
    final enCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addPaymentMethod),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: arCtrl,
              decoration: InputDecoration(labelText: l10n.methodLabelAr),
              textDirection: TextDirection.rtl,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: enCtrl,
              decoration: InputDecoration(labelText: l10n.methodLabelEn),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save)),
        ],
      ),
    );
    arCtrl.dispose();
    enCtrl.dispose();
    if (confirmed != true || !mounted) return;
    final ar = arCtrl.text.trim();
    final en = enCtrl.text.trim();
    if (ar.isEmpty && en.isEmpty) return;
    final key = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    await DatabaseHelper.instance.insertCustomPaymentMethod(
      key: key,
      labelAr: ar.isNotEmpty ? ar : en,
      labelEn: en.isNotEmpty ? en : ar,
    );
    await _load();
  }

  Future<void> _editCustom(PaymentMethod method) async {
    final l10n = AppLocalizations.of(context);
    final arCtrl = TextEditingController(text: method.labelAr);
    final enCtrl = TextEditingController(text: method.labelEn);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editPaymentMethod),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: arCtrl,
              decoration: InputDecoration(labelText: l10n.methodLabelAr),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: enCtrl,
              decoration: InputDecoration(labelText: l10n.methodLabelEn),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save)),
        ],
      ),
    );
    arCtrl.dispose();
    enCtrl.dispose();
    if (confirmed != true || !mounted) return;
    final ar = arCtrl.text.trim();
    final en = enCtrl.text.trim();
    if (ar.isEmpty && en.isEmpty) return;
    await DatabaseHelper.instance.updatePaymentMethodLabel(
      method.id!,
      ar.isNotEmpty ? ar : en,
      en.isNotEmpty ? en : ar,
    );
    await _load();
  }

  Future<void> _deleteCustom(PaymentMethod method) async {
    final l10n = AppLocalizations.of(context);
    final inUse =
        await DatabaseHelper.instance.isPaymentMethodUsedInDocuments(method.key);
    if (!mounted) return;
    if (inUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cannotDeleteMethodInUse)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteMethod),
        content: Text('${l10n.delete}: ${method.label(l10n.langCode)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
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
    await DatabaseHelper.instance.deletePaymentMethod(method.id!);
    await _load();
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

    final predefined = _methods.where((m) => m.isPredefined).toList();
    final custom = _methods.where((m) => !m.isPredefined).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentMethods), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustom,
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
          ...predefined.map((method) => _MethodTile(
                method: method,
                l10n: l10n,
                onToggle: () => _toggleEnabled(method),
                onSetDefault: method.isEnabled && !method.isDefault
                    ? () => _setDefault(method)
                    : null,
              )),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l10n.customMethods,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          if (custom.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.noCustomMethods,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ...custom.map((method) => _MethodTile(
                method: method,
                l10n: l10n,
                onToggle: () => _toggleEnabled(method),
                onSetDefault: method.isEnabled && !method.isDefault
                    ? () => _setDefault(method)
                    : null,
                onEdit: () => _editCustom(method),
                onDelete: () => _deleteCustom(method),
              )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final PaymentMethod method;
  final AppLocalizations l10n;
  final VoidCallback onToggle;
  final VoidCallback? onSetDefault;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MethodTile({
    required this.method,
    required this.l10n,
    required this.onToggle,
    this.onSetDefault,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final label = CurrencyUtils.getPaymentMethodLabel(
      method.key,
      l10n,
      customLabelAr: method.isPredefined ? null : method.labelAr,
      customLabelEn: method.isPredefined ? null : method.labelEn,
    );

    return ListTile(
      leading: Switch(value: method.isEnabled, onChanged: (_) => onToggle()),
      title: Row(
        children: [
          Text(label),
          if (method.isDefault) ...[
            const SizedBox(width: 6),
            Chip(
              label: Text(l10n.defaultMethod,
                  style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onSetDefault != null)
            IconButton(
              icon: const Icon(Icons.star_border, size: 20),
              tooltip: l10n.setAsDefault,
              onPressed: onSetDefault,
            ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: Theme.of(context).colorScheme.error),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
