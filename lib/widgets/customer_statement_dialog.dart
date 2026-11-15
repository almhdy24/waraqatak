import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/customer_statement.dart';
import '../models/document.dart';
import '../services/customer_statement_service.dart';
import '../services/pdf_service.dart';
import '../utils/format_utils.dart';
import 'app_date_picker.dart';
import 'app_snackbar.dart';

enum StatementPeriodPreset { thisMonth, last7Days, allTime, custom }

class CustomerStatementDialog extends StatefulWidget {
  final Contact contact;

  const CustomerStatementDialog({super.key, required this.contact});

  static Future<void> show(BuildContext context, {required Contact contact}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerStatementDialog(contact: contact),
    );
  }

  @override
  State<CustomerStatementDialog> createState() =>
      _CustomerStatementDialogState();
}

class _CustomerStatementDialogState extends State<CustomerStatementDialog> {
  Business? _business;
  List<Document>? _allDocuments;
  List<String> _availableCurrencies = [];
  String _selectedCurrency = 'SDG';

  StatementPeriodPreset _preset = StatementPeriodPreset.thisMonth;
  late DateTime _from;
  late DateTime _to;

  CustomerStatement? _statement;
  bool _loading = true;
  bool _generatingPdf = false;
  String? _error;

  static final _numFmt = NumberFormat('#,##0.##');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _initDates();
    _loadData();
  }

  void _initDates() {
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final results = await Future.wait([
        db.getFirstBusiness(),
        db.getDocumentsByContact(widget.contact.id!),
      ]);

      _business = results[0] as Business?;
      _allDocuments = results[1] as List<Document>;

      final fallback = _business?.currencyCode ?? 'SDG';
      _availableCurrencies = CustomerStatementService.getAvailableCurrencies(
        _allDocuments ?? const [],
        fallbackCurrency: fallback,
      );

      _selectedCurrency = fallback;

      _computeStatement();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeStatement() {
    if (_allDocuments == null) return;
    final fallback = _business?.currencyCode ?? 'SDG';
    _statement = CustomerStatementService.generateStatement(
      contact: widget.contact,
      documents: _allDocuments!,
      from: _from,
      to: _to,
      currencyCode: _selectedCurrency,
      businessCurrencyCode: fallback,
    );
  }

  void _onPresetChanged(StatementPeriodPreset preset) async {
    final now = DateTime.now();
    DateTime newFrom;
    DateTime newTo = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (preset) {
      case StatementPeriodPreset.thisMonth:
        newFrom = DateTime(now.year, now.month, 1);
        break;
      case StatementPeriodPreset.last7Days:
        newFrom = DateTime(now.year, now.month, now.day - 6);
        break;
      case StatementPeriodPreset.allTime:
        newFrom = DateTime(2020, 1, 1);
        break;
      case StatementPeriodPreset.custom:
        final picked = await AppDatePicker.showRange(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: DateTimeRange(start: _from, end: _to),
        );
        if (picked != null) {
          newFrom = picked.start;
          newTo = DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
            999,
          );
        } else {
          return;
        }
        break;
    }

    setState(() {
      _preset = preset;
      _from = newFrom;
      _to = newTo;
      _computeStatement();
    });
  }

  Future<void> _previewPdf() async {
    if (_statement == null || _business == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _generatingPdf = true);
    try {
      final bytes = await PdfService.generateCustomerStatementPdf(
        statement: _statement!,
        business: _business!,
        l10n: l10n,
      );
      if (!mounted) return;
      final baseName =
          'statement_${widget.contact.name}_${_dateFmt.format(_to)}';
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: '${safeFileName(baseName)}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        '${l10n.operationFailed}: $e',
        severity: AppSnackBarSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _shareWhatsApp() async {
    if (_statement == null || _business == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _generatingPdf = true);
    try {
      await PdfService.shareCustomerStatementPdf(
        statement: _statement!,
        business: _business!,
        l10n: l10n,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        '${l10n.operationFailed}: $e',
        severity: AppSnackBarSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Row(
              children: [
                Icon(Icons.assignment_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.customerStatement} — ${widget.contact.name}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('${l10n.operationFailed}: $_error')),
              )
            else ...[
              // Period Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _presetChip(
                      label: l10n.thisMonth,
                      selected: _preset == StatementPeriodPreset.thisMonth,
                      onTap: () =>
                          _onPresetChanged(StatementPeriodPreset.thisMonth),
                    ),
                    const SizedBox(width: 6),
                    _presetChip(
                      label: l10n.last7Days,
                      selected: _preset == StatementPeriodPreset.last7Days,
                      onTap: () =>
                          _onPresetChanged(StatementPeriodPreset.last7Days),
                    ),
                    const SizedBox(width: 6),
                    _presetChip(
                      label: l10n.allTime,
                      selected: _preset == StatementPeriodPreset.allTime,
                      onTap: () =>
                          _onPresetChanged(StatementPeriodPreset.allTime),
                    ),
                    const SizedBox(width: 6),
                    _presetChip(
                      label: _preset == StatementPeriodPreset.custom
                          ? '${_dateFmt.format(_from)} – ${_dateFmt.format(_to)}'
                          : l10n.customRange,
                      selected: _preset == StatementPeriodPreset.custom,
                      onTap: () =>
                          _onPresetChanged(StatementPeriodPreset.custom),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Legacy currency notice (if multiple exist)
              if (_availableCurrencies.length > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.langCode == 'ar'
                              ? 'كشف الحساب يعرض العملة الأساسية ($_selectedCurrency). الوثائق القديمة بعملات أخرى مستبعدة.'
                              : 'Statement shows base currency ($_selectedCurrency). Legacy foreign currency documents are excluded.',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Discrepancy warning banner
              if (_statement != null && _statement!.hasDiscrepancy)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.statementWarningTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Summary Box
              if (_statement != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statItem(
                            label: l10n.openingBalance,
                            value: _numFmt.format(_statement!.openingBalance),
                            symbol: _statement!.currencySymbol,
                            color: cs.onSurface,
                          ),
                          _statItem(
                            label: l10n.totalInvoiced,
                            value: _numFmt.format(_statement!.totalInvoiced),
                            symbol: _statement!.currencySymbol,
                            color: cs.primary,
                          ),
                          _statItem(
                            label: l10n.totalPaid,
                            value: _numFmt.format(_statement!.totalPaid),
                            symbol: _statement!.currencySymbol,
                            color: Colors.green.shade700,
                          ),
                          _statItem(
                            label: l10n.closingBalance,
                            value: _numFmt.format(_statement!.closingBalance),
                            symbol: _statement!.currencySymbol,
                            color: _statement!.closingBalance > 0
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            isBold: true,
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text(
                        _statement!.entries.isEmpty
                            ? l10n.noTransactionsInPeriod
                            : '${_statement!.entries.length} ${l10n.recentDocuments}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generatingPdf ? null : _previewPdf,
                      icon: _generatingPdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(l10n.previewPdf),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _generatingPdf ? null : _shareWhatsApp,
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l10n.shareWhatsApp),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _presetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    required String symbol,
    required Color color,
    bool isBold = false,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          '$value $symbol',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
