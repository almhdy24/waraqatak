import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/payment_method.dart';
import '../utils/currency_utils.dart';
import '../utils/error_utils.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<PaymentMethod> _methods = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final methods = await DatabaseHelper.instance.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorUtils.toFriendlyMessage(e, AppLocalizations.of(context));
      });
    }
  }

  Future<void> _toggleEnabled(PaymentMethod method) async {
    final l10n = AppLocalizations.of(context);
    if (method.isEnabled) {
      final enabledCount = _methods.where((m) => m.isEnabled).length;
      if (enabledCount <= 1) {
        AppSnackBar.show(context, l10n.cannotDisableLastMethod,
            severity: AppSnackBarSeverity.warning);
        return;
      }
      if (method.isDefault) {
        AppSnackBar.show(context, l10n.cannotDisableDefaultMethod,
            severity: AppSnackBarSeverity.warning);
        return;
      }
    }
    try {
      await DatabaseHelper.instance.setPaymentMethodEnabled(
        method.key,
        enabled: !method.isEnabled,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, ErrorUtils.toFriendlyMessage(e, l10n),
          severity: AppSnackBarSeverity.error);
      return;
    }
    await _load();
  }

  Future<void> _setDefault(PaymentMethod method) async {
    await DatabaseHelper.instance.setPaymentMethodDefault(method.key);
    await _load();
  }

  Future<void> _addCustom() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<({String ar, String en})>(
      context: context,
      builder: (_) => _CustomPaymentMethodDialog(
        title: l10n.addPaymentMethod,
      ),
    );
    if (result == null || !mounted) return;
    final ar = result.ar;
    final en = result.en;
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
    final result = await showDialog<({String ar, String en})>(
      context: context,
      builder: (_) => _CustomPaymentMethodDialog(
        title: l10n.editPaymentMethod,
        initialAr: method.labelAr,
        initialEn: method.labelEn,
      ),
    );
    if (result == null || !mounted) return;
    final ar = result.ar;
    final en = result.en;
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
    final inUse = await DatabaseHelper.instance.isPaymentMethodUsedInDocuments(
      method.key,
    );
    if (!mounted) return;
    if (inUse) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.cannotDeletePaymentMethodTitle),
          content: Text(l10n.paymentMethodInUseCannotDelete),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _toggleEnabled(method);
              },
              child: Text(l10n.disableMethodAction),
            ),
          ],
        ),
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
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
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

    if (_error != null && _methods.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.paymentMethods), centerTitle: true),
        body: AppErrorState(message: _error!, onRetry: _load),
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
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.only(top: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.predefinedMethods,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            ...predefined.map(
              (method) => _MethodTile(
                method: method,
                l10n: l10n,
                onToggle: () => _toggleEnabled(method),
                onSetDefault: method.isEnabled && !method.isDefault
                    ? () => _setDefault(method)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Icon(
                    Icons.add_card_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.customMethods,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (custom.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  l10n.noCustomMethods,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ...custom.map(
              (method) => _MethodTile(
                method: method,
                l10n: l10n,
                onToggle: () => _toggleEnabled(method),
                onSetDefault: method.isEnabled && !method.isDefault
                    ? () => _setDefault(method)
                    : null,
                onEdit: () => _editCustom(method),
                onDelete: () => _deleteCustom(method),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
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
    final cs = Theme.of(context).colorScheme;
    final label = CurrencyUtils.getPaymentMethodLabel(
      method.key,
      l10n,
      customLabelAr: method.isPredefined ? null : method.labelAr,
      customLabelEn: method.isPredefined ? null : method.labelEn,
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: method.isDefault
              ? cs.primary.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Switch(value: method.isEnabled, onChanged: (_) => onToggle()),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: method.isDefault
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: method.isEnabled ? cs.onSurface : cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (method.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.defaultMethod,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              )
            else if (!method.isEnabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.methodStatusDisabled,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
        trailing: (onSetDefault != null || onEdit != null || onDelete != null)
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                onSelected: (val) {
                  if (val == 'default') onSetDefault?.call();
                  if (val == 'edit') onEdit?.call();
                  if (val == 'delete') onDelete?.call();
                },
                itemBuilder: (ctx) => [
                  if (onSetDefault != null)
                    PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          const Icon(Icons.star_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.setAsDefault),
                        ],
                      ),
                    ),
                  if (onEdit != null)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.edit),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: cs.error),
                          const SizedBox(width: 8),
                          Text(l10n.delete, style: TextStyle(color: cs.error)),
                        ],
                      ),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

class _CustomPaymentMethodDialog extends StatefulWidget {
  final String title;
  final String? initialAr;
  final String? initialEn;

  const _CustomPaymentMethodDialog({
    required this.title,
    this.initialAr,
    this.initialEn,
  });

  @override
  State<_CustomPaymentMethodDialog> createState() =>
      _CustomPaymentMethodDialogState();
}

class _CustomPaymentMethodDialogState
    extends State<_CustomPaymentMethodDialog> {
  late final TextEditingController _arCtrl;
  late final TextEditingController _enCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _arCtrl = TextEditingController(text: widget.initialAr);
    _enCtrl = TextEditingController(text: widget.initialEn);
  }

  @override
  void dispose() {
    _arCtrl.dispose();
    _enCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _arCtrl,
              decoration: InputDecoration(
                labelText: l10n.methodLabelAr,
                hintText: l10n.paymentMethodHintAr,
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              textDirection: TextDirection.rtl,
              autofocus: true,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _enCtrl,
              decoration: InputDecoration(
                labelText: l10n.methodLabelEn,
                hintText: l10n.paymentMethodHintEn,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final ar = _arCtrl.text.trim();
            final en = _enCtrl.text.trim();
            if (ar.isEmpty && en.isEmpty) {
              setState(() {
                _errorText = l10n.methodNameRequired;
              });
              return;
            }
            Navigator.pop(context, (ar: ar, en: en));
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

