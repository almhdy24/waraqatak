import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../models/currency.dart';
import '../../models/date_range_filter.dart';
import '../../models/payment_method.dart';
import '../../utils/currency_utils.dart';
import '../document_detail_screen.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/app_amount_text.dart';
import '../../widgets/app_status_colors.dart';
import 'report_date_filter.dart';
import '../../widgets/responsive.dart';

class PaymentsReportScreen extends StatefulWidget {
  const PaymentsReportScreen({super.key});

  @override
  State<PaymentsReportScreen> createState() => _PaymentsReportScreenState();
}

class _PaymentsReportScreenState extends State<PaymentsReportScreen> {
  DateRangeFilter _range = DateRangeFilter.thisMonth();
  List<Map<String, dynamic>>? _rows;
  Business? _business;
  Map<String, PaymentMethod> _methodsMap = {};
  String? _error;

  static final _numFmt = NumberFormat('#,##0.##');
  static final _dateFmt = DateFormat('dd/MM/yy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      final results = await Future.wait([
        DatabaseHelper.instance.getPaymentReport(
          from: _range.from,
          to: _range.to,
        ),
        DatabaseHelper.instance.getPaymentMethods(),
        DatabaseHelper.instance.getFirstBusiness(),
      ]);
      if (!mounted) return;
      final rows = results[0] as List<Map<String, dynamic>>;
      final methods = results[1] as List<PaymentMethod>;
      final business = results[2] as Business?;
      setState(() {
        _rows = rows;
        _methodsMap = {for (final m in methods) m.key: m};
        _business = business;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final baseCurrency = _business?.currencyCode ?? 'SDG';
    final baseSymbol = _business?.currencySymbol ?? 'ج.س';

    final totalsByCurrency = <String, ({double inAmount, double outAmount})>{};
    if (_rows != null) {
      for (final r in _rows!) {
        final c = (r['currency_code'] as String?)?.trim() ?? 'SDG';
        final code = c.isNotEmpty ? c : 'SDG';
        final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
        final isIn =
            r['doc_type'] == 'invoice' || r['doc_type'] == 'payment_receipt';
        final prev = totalsByCurrency[code] ?? (inAmount: 0.0, outAmount: 0.0);
        totalsByCurrency[code] = (
          inAmount: prev.inAmount + (isIn ? amt : 0.0),
          outAmount: prev.outAmount + (!isIn ? amt : 0.0),
        );
      }
    }

    final baseTotals =
        totalsByCurrency[baseCurrency] ?? (inAmount: 0.0, outAmount: 0.0);
    final legacyEntries = totalsByCurrency.entries
        .where((e) => e.key != baseCurrency)
        .toList();

    return ScreenAccessGate(
      screenType: PaymentsReportScreen,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.paymentsReport), centerTitle: true),
        body: ResponsiveCenter(
          child: Column(
            children: [
              ReportDateFilter(
                range: _range,
                onChanged: (r) {
                  setState(() => _range = r);
                  _load();
                },
              ),
              if (_rows != null && _rows!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _chip(
                            '${l10n.receivedPayments} ($baseSymbol)',
                            baseTotals.inAmount,
                            AppStatusColors.fg(context, AppStatus.success),
                          ),
                          const SizedBox(width: 8),
                          _chip(
                            '${l10n.madePayments} ($baseSymbol)',
                            baseTotals.outAmount,
                            AppStatusColors.fg(context, AppStatus.warning),
                          ),
                        ],
                      ),
                      if (legacyEntries.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.legacyForeignPaymentsNotice,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...legacyEntries.map((entry) {
                                  final code = entry.key;
                                  final symbol = Currency.symbolForCode(code);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        _chip(
                                          '${l10n.receivedPayments} ($symbol)',
                                          entry.value.inAmount,
                                          AppStatusColors.fg(
                                            context,
                                            AppStatus.success,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _chip(
                                          '${l10n.madePayments} ($symbol)',
                                          entry.value.outAmount,
                                          AppStatusColors.fg(
                                            context,
                                            AppStatus.warning,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(child: _buildList(context, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color)),
            Text(
              _numFmt.format(value),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.operationFailed),
            FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (_rows == null) return const Center(child: CircularProgressIndicator());
    final cs = Theme.of(context).colorScheme;
    if (_rows!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payments_outlined, size: 64, color: cs.outline),
              const SizedBox(height: 12),
              Text(
                l10n.noDataForPeriod,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _rows!.length,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (ctx, i) {
        final row = _rows![i];
        final amount = (row['amount'] as num).toDouble();
        final isIn =
            row['doc_type'] == 'invoice' ||
            row['doc_type'] == 'payment_receipt';
        final color = isIn
            ? AppStatusColors.fg(context, AppStatus.success)
            : AppStatusColors.fg(context, AppStatus.warning);
        final method = row['payment_method'] as String?;
        final cCode = (row['currency_code'] as String?)?.trim() ?? '';
        final sym = cCode.isNotEmpty ? ' ${Currency.symbolForCode(cCode)}' : '';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            onTap: row['document_id'] != null
                ? () => _openDocument(context, row['document_id'] as int)
                : null,
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(
                isIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    row['document_number'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                AppAmountText(
                  amount: amount,
                  currencySymbol: sym.trim(),
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      row['recipient_name'] as String? ?? '',
                      if (method != null)
                        _methodsMap[method]?.label(
                              AppLocalizations.of(ctx).langCode,
                            ) ??
                            CurrencyUtils.getPaymentMethodLabel(
                              method,
                              AppLocalizations.of(ctx),
                            ),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  _dateFmt.format(DateTime.parse(row['date'] as String)),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDocument(BuildContext context, int docId) async {
    final doc = await DatabaseHelper.instance.getDocumentById(docId);
    if (!context.mounted) return;
    if (doc == null) {
      final l10n = AppLocalizations.of(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.documentNotFound),
          content: Text(l10n.documentNotFoundDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(documentId: docId),
      ),
    );
    if (mounted) _load();
  }
}
