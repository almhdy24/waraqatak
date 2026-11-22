/// Screen for managing exchange rates, rounding rule, and reference currency definitions.
library;

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../features/reference_currency/reference_currency_feature.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/currency.dart';
import '../models/exchange_rate.dart';
import '../services/feature_access.dart';
import '../services/reference_pricing_service.dart';
import '../utils/error_utils.dart';
import '../utils/format_utils.dart';
import '../utils/number_input.dart';
import '../utils/reference_pricing_math.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/pro_upgrade_sheet.dart';
import '../widgets/responsive.dart';

/// Screen displaying reference-currency exchange rates and conversion settings.
class ExchangeRatesScreen extends StatefulWidget {
  /// Creates the exchange rates management screen.
  const ExchangeRatesScreen({super.key});

  @override
  State<ExchangeRatesScreen> createState() => _ExchangeRatesScreenState();
}

class _ExchangeRatesScreenState extends State<ExchangeRatesScreen> {
  bool _loading = true;
  bool _isRepricing = false;
  Business? _business;
  List<ExchangeRate> _rates = [];
  int _rounding = ReferencePricingMath.defaultRounding;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (!ReferenceCurrencyFeature.isAvailable) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final business = await DatabaseHelper.instance.getFirstBusiness();
      if (business == null) {
        if (!mounted) return;
        setState(() {
          _business = null;
          _loading = false;
        });
        return;
      }

      final rates = await ReferencePricingService.getRates();
      final rounding = await ReferencePricingService.getRounding();

      if (!mounted) return;
      setState(() {
        _business = business;
        _rates = rates;
        _rounding = rounding;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(
          e,
          l10n: AppLocalizations.of(context),
        ),
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  String get _baseSymbol {
    final code = _business?.currencyCode ?? 'SDG';
    return Currency.fromCode(code).symbol;
  }

  Future<void> _onRoundingChanged(int? newRounding) async {
    if (newRounding == null || newRounding == _rounding) return;
    final l10n = AppLocalizations.of(context);

    try {
      await ReferencePricingService.setRounding(newRounding);
      setState(() => _rounding = newRounding);

      if (!mounted) return;
      final shouldRecalculate = await AppConfirmDialog.show(
        context,
        title: l10n.roundingRule,
        message: l10n.roundingChangedRecalculatePrompt,
        confirmLabel: l10n.recalculateAll,
        cancelLabel: l10n.cancel,
      );

      if (shouldRecalculate) {
        await _runRecalculateAll();
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  Future<void> _runRecalculateAll() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isRepricing = true);
    try {
      final result = await ReferencePricingService.recalculateAll();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        l10n.repriceDone(result.affectedProducts, result.affectedUnits),
        severity: AppSnackBarSeverity.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isRepricing = false);
      }
    }
  }

  Future<void> _confirmRecalculateAll() async {
    final l10n = AppLocalizations.of(context);
    try {
      final preview = await ReferencePricingService.previewRecalculateAll();
      if (!mounted) return;
      final confirmed = await AppConfirmDialog.show(
        context,
        title: l10n.repriceConfirmTitle,
        message: l10n.repriceConfirmBody(
          preview.affectedProducts,
          preview.affectedUnits,
        ),
        confirmLabel: l10n.recalculateAll,
        cancelLabel: l10n.cancel,
      );
      if (confirmed) {
        await _runRecalculateAll();
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  Future<void> _editRate(ExchangeRate entry) async {
    final l10n = AppLocalizations.of(context);
    final rateCtrl = TextEditingController(
      text: NumberInput.formatForInput(entry.rate, maxDecimals: 6),
    );

    final newRateStr = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${entry.nameAr} (${entry.code})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: rateCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.exchangeRate,
                prefixText: '1 ${entry.code} = ',
                suffixText: _baseSymbol,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = ReferencePricingMath.parseRate(rateCtrl.text);
              if (parsed == null) {
                AppSnackBar.show(
                  ctx,
                  l10n.refErrInvalidRate,
                  severity: AppSnackBarSeverity.warning,
                );
                return;
              }
              Navigator.pop(ctx, rateCtrl.text);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    rateCtrl.dispose();

    if (newRateStr == null) return;
    final parsedRate = ReferencePricingMath.parseRate(newRateStr);
    if (parsedRate == null) return;
    if (parsedRate == entry.rate) return;

    if (!mounted) return;
    try {
      final preview = await ReferencePricingService.previewRateChange(
        entry.code,
        parsedRate,
      );

      final sampleLines = StringBuffer();
      sampleLines.writeln(
        l10n.repriceConfirmBody(
          preview.affectedProducts,
          preview.affectedUnits,
        ),
      );
      if (preview.samples.isNotEmpty) {
        sampleLines.writeln();
        for (final s in preview.samples) {
          sampleLines.writeln(
            '• ${s.name}: ${s.oldBase} -> ${s.newBase} $_baseSymbol',
          );
        }
      }

      if (!mounted) return;
      final confirmed = await AppConfirmDialog.show(
        context,
        title: l10n.repriceConfirmTitle,
        message: sampleLines.toString().trim(),
        confirmLabel: l10n.save,
        cancelLabel: l10n.cancel,
      );

      if (!confirmed) return;

      setState(() => _isRepricing = true);
      final result = await ReferencePricingService.updateRateAndReprice(
        entry.code,
        parsedRate,
      );

      if (!mounted) return;
      AppSnackBar.show(
        context,
        l10n.repriceDone(result.affectedProducts, result.affectedUnits),
        severity: AppSnackBarSeverity.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isRepricing = false);
      }
    }
  }

  Future<void> _showAddCurrencySheet() async {
    final baseCode = _business?.currencyCode ?? 'SDG';
    final existingCodes = _rates.map((r) => r.code).toSet();

    final availableBuiltIn = ReferenceCurrencyCatalog.builtIn
        .where((c) => c.code != baseCode && !existingCodes.contains(c.code))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _AddCurrencySheet(
        baseSymbol: _baseSymbol,
        availableBuiltIn: availableBuiltIn,
        onAdd: (entry) async {
          Navigator.pop(sheetCtx);
          try {
            await ReferencePricingService.addCurrencyWithRate(entry);
            if (!mounted) return;
            await _load();
          } catch (e) {
            if (!mounted) return;
            AppSnackBar.show(
              context,
              ErrorUtils.getFriendlyErrorMessage(
                e,
                l10n: AppLocalizations.of(context),
              ),
              severity: AppSnackBarSeverity.error,
            );
          }
        },
      ),
    );
  }

  Future<void> _toggleActive(ExchangeRate rate) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ReferencePricingService.setCurrencyActive(
        rate.code,
        !rate.isActive,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  Future<void> _deleteCustom(ExchangeRate rate) async {
    final l10n = AppLocalizations.of(context);
    try {
      final deleted = await ReferencePricingService.deleteCustomCurrency(
        rate.code,
      );
      if (!deleted) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          l10n.currencyInUse,
          severity: AppSnackBarSeverity.warning,
        );
      } else {
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!ReferenceCurrencyFeature.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.exchangeRates)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDesignTokens.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.exchangeRates,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.proFeaturesActivation,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: Text(l10n.enterActivationKeyAction),
                  onPressed: () async {
                    final activated = await ProUpgradeSheet.show(
                      context,
                      feature: Feature.referenceCurrency,
                    );
                    if (activated && mounted) {
                      _load();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.exchangeRates)),
        body: const AppLoadingView(),
      );
    }

    if (_business == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.exchangeRates)),
        body: AppEmptyState(
          icon: Icons.business,
          title: l10n.setupBusinessFirst,
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(l10n.exchangeRates),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.recalculateAll,
                onPressed: _confirmRecalculateAll,
              ),
            ],
          ),
          body: ResponsiveCenter(
            maxWidth: 700,
            child: Padding(
              padding: const EdgeInsets.all(AppDesignTokens.space16),
              child: ListView(
                children: [
                  // Rounding settings card
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
                            l10n.roundingRule,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            key: ValueKey('rounding_dropdown_$_rounding'),
                            initialValue: _rounding,
                            items: [
                              DropdownMenuItem(
                                value: 0,
                                child: Text(l10n.roundingNone),
                              ),
                              const DropdownMenuItem(
                                value: 1,
                                child: Text('1'),
                              ),
                              const DropdownMenuItem(
                                value: 5,
                                child: Text('5'),
                              ),
                              const DropdownMenuItem(
                                value: 10,
                                child: Text('10'),
                              ),
                              const DropdownMenuItem(
                                value: 50,
                                child: Text('50'),
                              ),
                              const DropdownMenuItem(
                                value: 100,
                                child: Text('100'),
                              ),
                            ],
                            onChanged: _onRoundingChanged,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rates list
                  if (_rates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: AppEmptyState(
                        icon: Icons.currency_exchange,
                        title: l10n.exchangeRates,
                        description: l10n.exchangeRatesDesc,
                      ),
                    )
                  else
                    ..._rates.map(
                      (rate) => _buildRateTile(context, rate, l10n),
                    ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddCurrencySheet,
            icon: const Icon(Icons.add),
            label: Text(l10n.addCurrency),
          ),
        ),

        // Blocking indeterminate overlay during repricing
        if (_isRepricing)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: const Center(child: AppLoadingView()),
            ),
          ),
      ],
    );
  }

  Widget _buildRateTile(
    BuildContext context,
    ExchangeRate rate,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        onTap: () => _editRate(rate),
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Text(
            rate.symbol.isNotEmpty ? rate.symbol : rate.code,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${rate.nameAr} (${rate.code})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (!rate.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.archiveCurrency,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '1 ${rate.code} = ${rate.rate} $_baseSymbol',
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
            ),
            const SizedBox(height: 2),
            Text(
              FormatUtils.formatDate(rate.updatedAt),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (val) {
            if (val == 'archive') {
              _toggleActive(rate);
            } else if (val == 'delete') {
              _deleteCustom(rate);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'archive',
              child: Text(
                rate.isActive ? l10n.archiveCurrency : l10n.unarchiveCurrency,
              ),
            ),
            if (rate.isCustom)
              PopupMenuItem(
                value: 'delete',
                child: Text(l10n.delete, style: TextStyle(color: cs.error)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddCurrencySheet extends StatefulWidget {
  final String baseSymbol;
  final List<ReferenceCurrencyItem> availableBuiltIn;
  final ValueChanged<ExchangeRate> onAdd;

  const _AddCurrencySheet({
    required this.baseSymbol,
    required this.availableBuiltIn,
    required this.onAdd,
  });

  @override
  State<_AddCurrencySheet> createState() => _AddCurrencySheetState();
}

class _AddCurrencySheetState extends State<_AddCurrencySheet> {
  bool _isCustom = false;
  bool _isSubmitting = false;
  ReferenceCurrencyItem? _selectedBuiltIn;

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _symbolCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _symbolCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting) return;

    final l10n = AppLocalizations.of(context);
    final rate = ReferencePricingMath.parseRate(_rateCtrl.text);
    if (rate == null) {
      AppSnackBar.show(
        context,
        l10n.refErrInvalidRate,
        severity: AppSnackBarSeverity.warning,
      );
      return;
    }

    if (_isCustom) {
      final code = _codeCtrl.text.trim().toUpperCase();
      final name = _nameCtrl.text.trim();
      final symbol = _symbolCtrl.text.trim();

      final codeReg = RegExp(r'^[A-Z]{2,5}$');
      if (!codeReg.hasMatch(code)) {
        AppSnackBar.show(
          context,
          l10n.currencyCodeInvalid,
          severity: AppSnackBarSeverity.warning,
        );
        return;
      }
      if (name.isEmpty || symbol.isEmpty) {
        AppSnackBar.show(
          context,
          l10n.currencyFieldsRequired,
          severity: AppSnackBarSeverity.warning,
        );
        return;
      }

      setState(() => _isSubmitting = true);
      final entry = ExchangeRate(
        code: code,
        nameAr: name,
        symbol: symbol,
        rate: rate,
        isCustom: true,
        updatedAt: DateTime.now(),
      );
      widget.onAdd(entry);
    } else {
      if (_selectedBuiltIn == null) {
        AppSnackBar.show(
          context,
          l10n.selectCurrencyFirst,
          severity: AppSnackBarSeverity.warning,
        );
        return;
      }

      setState(() => _isSubmitting = true);
      final item = _selectedBuiltIn!;
      final entry = ExchangeRate(
        code: item.code,
        nameAr: item.nameAr,
        nameEn: item.nameEn,
        symbol: item.symbol,
        rate: rate,
        isCustom: false,
        updatedAt: DateTime.now(),
      );
      widget.onAdd(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.addCurrency,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isCustom = !_isCustom),
                  child: Text(
                    _isCustom ? l10n.pricingCurrency : l10n.customCurrency,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_isCustom) ...[
              if (widget.availableBuiltIn.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.customCurrency,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                DropdownButtonFormField<ReferenceCurrencyItem>(
                  key: ValueKey('builtin_$_selectedBuiltIn'),
                  initialValue: _selectedBuiltIn,
                  decoration: InputDecoration(
                    labelText: l10n.pricingCurrency,
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.availableBuiltIn.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text('${item.nameAr} (${item.code})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBuiltIn = val;
                      if (val != null) {
                        _codeCtrl.text = val.code;
                        _nameCtrl.text = val.nameAr;
                        _symbolCtrl.text = val.symbol;
                      }
                    });
                  },
                ),
            ] else ...[
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.currencyCode,
                  helperText: l10n.currencyCodeHelper,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.currencyNameArField,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _symbolCtrl,
                decoration: InputDecoration(
                  labelText: l10n.currencySymbol,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.exchangeRate,
                prefixText: _isCustom
                    ? '1 ${_codeCtrl.text.isNotEmpty ? _codeCtrl.text : "CODE"} = '
                    : '1 ${_selectedBuiltIn?.code ?? "CODE"} = ',
                suffixText: widget.baseSymbol,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
