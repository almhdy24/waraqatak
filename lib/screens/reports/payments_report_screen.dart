import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../models/currency.dart';
import '../../models/date_range_filter.dart';
import '../../models/payment_method.dart';
import '../../services/csv_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../../utils/currency_utils.dart';
import '../document_detail_screen.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/app_amount_text.dart';
import '../../widgets/app_percentage_bar.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_status_colors.dart';
import '../../widgets/report_export_menu.dart';
import 'report_date_filter.dart';
import 'reports_date_scope.dart';
import '../../widgets/responsive.dart';

class PaymentsReportScreen extends StatefulWidget {
  const PaymentsReportScreen({super.key});

  @override
  State<PaymentsReportScreen> createState() => _PaymentsReportScreenState();
}

class _PaymentsReportScreenState extends State<PaymentsReportScreen> {
  DateRangeFilter _range = ReportsDateNotifier.instance.range;
  List<Map<String, dynamic>>? _rows;
  List<Map<String, dynamic>>? _methodFlows;
  Business? _business;
  Map<String, PaymentMethod> _methodsMap = {};
  String? _error;
  int _querySeq = 0;

  static final _numFmt = NumberFormat('#,##0.##');
  static final _dateFmt = DateFormat('dd/MM/yy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_querySeq;
    setState(() {
      _rows = null;
      _methodFlows = null;
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
        DatabaseHelper.instance.getPaymentMethodCashFlow(
          from: _range.from,
          to: _range.to,
        ),
      ]);
      if (!mounted || seq != _querySeq) return;
      final rows = results[0] as List<Map<String, dynamic>>;
      final methods = results[1] as List<PaymentMethod>;
      final business = results[2] as Business?;
      final flows = results[3] as List<Map<String, dynamic>>;
      setState(() {
        _rows = rows;
        _methodsMap = {for (final m in methods) m.key: m};
        _business = business;
        _methodFlows = flows;
      });
    } catch (e) {
      if (!mounted || seq != _querySeq) return;
      setState(() => _error = e.toString());
    }
  }

  PdfReportData _buildPdfData(
    AppLocalizations l10n,
    String baseCurrency,
    double inAmt,
    double outAmt,
  ) {
    final rows = _rows ?? [];
    return PdfReportData(
      title: l10n.paymentsReport,
      dateRange: _range.label(l10n),
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.receivedPayments,
          value: '${_numFmt.format(inAmt)} $baseCurrency',
        ),
        PdfReportSummaryCard(
          label: l10n.madePayments,
          value: '${_numFmt.format(outAmt)} $baseCurrency',
        ),
        PdfReportSummaryCard(
          label: l10n.netCash,
          value: '${_numFmt.format(inAmt - outAmt)} $baseCurrency',
        ),
      ],
      columns: [
        PdfReportColumn(title: l10n.date, flex: 1.2),
        PdfReportColumn(title: l10n.entityLabel, flex: 2.2),
        PdfReportColumn(title: l10n.paymentMethod, flex: 1.5),
        PdfReportColumn(title: l10n.status, flex: 1.2),
        PdfReportColumn(
          title: l10n.amount,
          flex: 1.8,
          align: pw.TextAlign.right,
        ),
      ],
      rows: rows.map((r) {
        final dt = DateTime.tryParse(r['date'] as String? ?? '');
        final dateStr = dt != null
            ? _dateFmt.format(dt)
            : (r['date']?.toString() ?? '');
        final party = (r['recipient_name'] as String?)?.trim();
        final partyStr = (party != null && party.isNotEmpty) ? party : '—';
        final methodKey = r['method'] as String?;
        final methodLabel = methodKey != null
            ? (_methodsMap[methodKey]?.label(l10n.langCode) ??
                  CurrencyUtils.getPaymentMethodLabel(methodKey, l10n))
            : '—';
        final isIn =
            r['doc_type'] == 'invoice' || r['doc_type'] == 'payment_receipt';
        final typeStr = isIn ? l10n.receivedPayments : l10n.madePayments;
        final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
        final curr = (r['currency_code'] as String?)?.trim() ?? baseCurrency;
        return [
          dateStr,
          partyStr,
          methodLabel,
          typeStr,
          '${_numFmt.format(amt)} $curr',
        ];
      }).toList(),
    );
  }

  Future<void> _exportPdf(
    AppLocalizations l10n,
    String baseCurrency,
    double inAmt,
    double outAmt,
  ) async {
    final business =
        _business ?? await DatabaseHelper.instance.getFirstBusiness();
    if (business == null) return;
    final data = _buildPdfData(l10n, baseCurrency, inAmt, outAmt);
    try {
      await PdfService.printOrShareReportPdf(
        business: business,
        l10n: l10n,
        data: data,
        fileName: 'payments_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          l10n.operationFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _sharePdf(
    AppLocalizations l10n,
    String baseCurrency,
    double inAmt,
    double outAmt,
  ) async {
    final business =
        _business ?? await DatabaseHelper.instance.getFirstBusiness();
    if (business == null) return;
    final data = _buildPdfData(l10n, baseCurrency, inAmt, outAmt);
    try {
      await PdfService.shareReportPdf(
        business: business,
        l10n: l10n,
        data: data,
        fileName: 'payments_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          l10n.operationFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _shareWhatsApp(
    AppLocalizations l10n,
    String baseCurrency,
    double inAmt,
    double outAmt,
  ) async {
    final text =
        '${l10n.paymentsReport} · ${_range.label(l10n)}\n'
        '${l10n.receivedPayments}: ${_numFmt.format(inAmt)} $baseCurrency\n'
        '${l10n.madePayments}: ${_numFmt.format(outAmt)} $baseCurrency\n'
        '${l10n.netCash}: ${_numFmt.format(inAmt - outAmt)} $baseCurrency';
    await PdfService.shareText(text: text);
  }

  Future<void> _exportCsv(AppLocalizations l10n, String baseCurrency) async {
    final rows = _rows ?? [];
    final headers = [
      l10n.date,
      l10n.entityLabel,
      l10n.paymentMethod,
      l10n.status,
      l10n.amount,
      l10n.currency,
    ];
    final csvRows = rows.map((r) {
      final dt = DateTime.tryParse(r['date'] as String? ?? '');
      final party = (r['recipient_name'] as String?)?.trim() ?? '';
      final methodKey = r['method'] as String?;
      final methodLabel = methodKey != null
          ? (_methodsMap[methodKey]?.label(l10n.langCode) ??
                CurrencyUtils.getPaymentMethodLabel(methodKey, l10n))
          : '';
      final isIn =
          r['doc_type'] == 'invoice' || r['doc_type'] == 'payment_receipt';
      final typeStr = isIn ? 'in' : 'out';
      final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
      final curr = (r['currency_code'] as String?)?.trim() ?? baseCurrency;
      return [dt ?? r['date'], party, methodLabel, typeStr, amt, curr];
    }).toList();

    try {
      final bytes = CsvService.instance.exportReportToCsv(
        headers: headers,
        rows: csvRows,
      );
      await PdfService.shareCsv(
        bytes: bytes,
        fileName:
            'payments_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          l10n.operationFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  void _openExportMenu(
    BuildContext context,
    AppLocalizations l10n,
    String baseCurrency,
    double inAmt,
    double outAmt,
  ) {
    ReportExportMenu.show(
      context: context,
      title: l10n.paymentsReport,
      onPrintPdf: () => _exportPdf(l10n, baseCurrency, inAmt, outAmt),
      onSharePdf: () => _sharePdf(l10n, baseCurrency, inAmt, outAmt),
      onShareWhatsApp: () => _shareWhatsApp(l10n, baseCurrency, inAmt, outAmt),
      onExportCsv: () => _exportCsv(l10n, baseCurrency),
    );
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
        appBar: AppBar(
          title: Text(l10n.paymentsReport),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: l10n.printOrShareReport,
              onPressed:
                  _rows != null &&
                      _rows!.isNotEmpty &&
                      ReportExportMenu.canExport()
                  ? () => _openExportMenu(
                      context,
                      l10n,
                      baseCurrency,
                      baseTotals.inAmount,
                      baseTotals.outAmount,
                    )
                  : null,
            ),
          ],
        ),
        body: ResponsiveCenter(
          child: Column(
            children: [
              ReportDateFilter(
                range: _range,
                onChanged: (r) {
                  setState(() => _range = r);
                  ReportsDateScope.update(context, r);
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
                      if (_methodFlows != null && _methodFlows!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _methodFlows!.map((mf) {
                              final methodKey =
                                  mf['method'] as String? ?? 'cash';
                              final inAmt =
                                  (mf['in_amount'] as num?)?.toDouble() ?? 0.0;
                              final outAmt =
                                  (mf['out_amount'] as num?)?.toDouble() ?? 0.0;
                              final netAmt =
                                  (mf['net_amount'] as num?)?.toDouble() ?? 0.0;
                              final label =
                                  _methodsMap[methodKey]?.label(
                                    l10n.langCode,
                                  ) ??
                                  CurrencyUtils.getPaymentMethodLabel(
                                    methodKey,
                                    l10n,
                                  );
                              return Container(
                                margin: const EdgeInsetsDirectional.only(
                                  end: 8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${l10n.netCash}: ${_numFmt.format(netAmt)} $baseSymbol',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: netAmt >= 0
                                            ? AppStatusColors.fg(
                                                context,
                                                AppStatus.success,
                                              )
                                            : AppStatusColors.fg(
                                                context,
                                                AppStatus.danger,
                                              ),
                                      ),
                                    ),
                                    Text(
                                      '+${_numFmt.format(inAmt)} / -${_numFmt.format(outAmt)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AppPercentageBar(
                            segments: _methodFlows!.asMap().entries.map((
                              entry,
                            ) {
                              final idx = entry.key;
                              final mf = entry.value;
                              final methodKey =
                                  mf['method'] as String? ?? 'cash';
                              final inAmt =
                                  (mf['in_amount'] as num?)?.toDouble() ?? 0.0;
                              final label =
                                  _methodsMap[methodKey]?.label(
                                    l10n.langCode,
                                  ) ??
                                  CurrencyUtils.getPaymentMethodLabel(
                                    methodKey,
                                    l10n,
                                  );
                              final colors = [
                                Theme.of(context).colorScheme.primary,
                                AppStatusColors.fg(context, AppStatus.success),
                                AppStatusColors.fg(context, AppStatus.warning),
                                AppStatusColors.fg(context, AppStatus.info),
                                Theme.of(context).colorScheme.tertiary,
                              ];
                              return PercentageSegment(
                                label: label,
                                value: inAmt,
                                color: colors[idx % colors.length],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
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

        final rawDocId = row['document_id'] ?? row['id'];
        final docId = rawDocId is num
            ? rawDocId.toInt()
            : (rawDocId is String ? int.tryParse(rawDocId) : null);

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
            onTap: docId != null ? () => _openDocument(context, docId) : null,
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
