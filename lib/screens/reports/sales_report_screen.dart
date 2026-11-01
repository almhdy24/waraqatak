import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/currency.dart';
import '../../models/date_range_filter.dart';
import '../../models/document_status.dart';
import '../../services/inventory_costing_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../../widgets/app_design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_loading_view.dart';
import '../document_detail_screen.dart';
import 'report_date_filter.dart';
import '../../widgets/responsive.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  /// Aggregates sales, COGS, trusted profit, paid, and remaining amounts by currency.
  /// Cancelled documents are ignored.
  static Map<String, ({
    double sales,
    double cogs,
    double trustedProfit,
    double paid,
    double remaining,
    bool hasIncompleteCost,
  })> aggregateByCurrency(List<SaleProfitSummary> sales) {
    final result = <String, ({
      double sales,
      double cogs,
      double trustedProfit,
      double paid,
      double remaining,
      bool hasIncompleteCost,
    })>{};
    for (final s in sales) {
      if (s.document.status == DocumentStatus.cancelled) continue;
      final code = s.document.currencyCode;
      final prev = result[code] ?? (
        sales: 0.0,
        cogs: 0.0,
        trustedProfit: 0.0,
        paid: 0.0,
        remaining: 0.0,
        hasIncompleteCost: false,
      );
      result[code] = (
        sales: prev.sales + s.document.total,
        cogs: prev.cogs + s.cogs,
        trustedProfit: prev.trustedProfit + (s.trustedGrossProfit ?? 0.0),
        paid: prev.paid + s.document.paid,
        remaining: prev.remaining + s.document.remaining,
        hasIncompleteCost: prev.hasIncompleteCost || !s.isCostReliable,
      );
    }
    return result;
  }

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateRangeFilter _range = DateRangeFilter.thisMonth();
  List<SaleProfitSummary>? _sales;
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
      _sales = null;
      _error = null;
    });
    try {
      final sales = await InventoryCostingService.instance
          .getSalesReportWithCost(
            from: _range.from,
            to: _range.to,
            includeCancelled: true,
          );
      if (!mounted) return;
      setState(() => _sales = sales);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _exportPdf() async {
    final l10n = AppLocalizations.of(context);
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null || _sales == null) return;

    final finalized = _sales!
        .where((s) => s.document.status != DocumentStatus.cancelled)
        .toList();
    final currencies = finalized.map((s) => s.document.currencyCode).toSet();
    final salesByCurrency = SalesReportScreen.aggregateByCurrency(finalized);

    final totalSales = finalized.fold(
      0.0,
      (s, item) => s + item.document.total,
    );
    final totalCogs = finalized.fold(0.0, (s, item) => s + item.cogs);
    // Only include gross profit from fully-costed invoices in aggregate totals.
    // Invoices with unknown cost contribute null (trustedGrossProfit) and are
    // excluded from the sum so the header never shows an overstated figure.
    final totalTrustedProfit = finalized.fold(
      0.0,
      (s, item) => s + (item.trustedGrossProfit ?? 0.0),
    );
    final totalPaid = finalized.fold(0.0, (s, item) => s + item.document.paid);
    final totalRemaining = finalized.fold(
      0.0,
      (s, item) => s + item.document.remaining,
    );
    final hasIncompleteCost = finalized.any((s) => !s.isCostReliable);

    final columns = [
      PdfReportColumn(title: l10n.date, flex: 1.2),
      PdfReportColumn(title: l10n.invoice, flex: 1.5),
      PdfReportColumn(title: l10n.customer, flex: 2.0),
      PdfReportColumn(
        title: l10n.salesValue,
        flex: 1.3,
        align: pw.TextAlign.right,
      ),
      PdfReportColumn(title: l10n.cogs, flex: 1.3, align: pw.TextAlign.right),
      PdfReportColumn(
        title: l10n.grossProfit,
        flex: 1.3,
        align: pw.TextAlign.right,
      ),
      PdfReportColumn(title: l10n.paid, flex: 1.2, align: pw.TextAlign.right),
      PdfReportColumn(
        title: l10n.remaining,
        flex: 1.2,
        align: pw.TextAlign.right,
      ),
    ];

    final rows = _sales!.map((item) {
      final doc = item.document;
      final isCancelled = doc.status == DocumentStatus.cancelled;
      final profitStr = isCancelled
          ? '—'
          : (item.isCostReliable ? _numFmt.format(item.grossProfit) : '—');

      return [
        _dateFmt.format(doc.date),
        doc.documentNumber,
        doc.recipientName ?? '—',
        isCancelled
            ? l10n.cancelledCount
            : '${_numFmt.format(doc.total)} ${doc.currencySymbol}',
        isCancelled ? '—' : _numFmt.format(item.cogs),
        profitStr,
        isCancelled ? '—' : _numFmt.format(doc.paid),
        isCancelled ? '—' : _numFmt.format(doc.remaining),
      ];
    }).toList();

    final data = PdfReportData(
      title: l10n.salesReport,
      dateRange: _range.label(l10n),
      warningNotice: hasIncompleteCost ? l10n.unknownCostNotice : null,
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.totalSales,
          value: currencies.length > 1
              ? salesByCurrency.entries
                    .map((e) => '${_numFmt.format(e.value.sales)} ${e.key}')
                    .join(' · ')
              : _numFmt.format(totalSales),
        ),
        PdfReportSummaryCard(
          label: l10n.cogs,
          value: currencies.length > 1
              ? salesByCurrency.entries
                    .map((e) => '${_numFmt.format(e.value.cogs)} ${e.key}')
                    .join(' · ')
              : _numFmt.format(totalCogs),
        ),
        PdfReportSummaryCard(
          label: l10n.grossProfit,
          // Only sum gross profit from fully-costed invoices.
          value: currencies.length > 1
              ? salesByCurrency.entries
                    .map(
                      (e) =>
                          '${_numFmt.format(e.value.trustedProfit)}${e.value.hasIncompleteCost ? '*' : ''} ${e.key}',
                    )
                    .join(' · ')
              : (hasIncompleteCost
                    ? '${_numFmt.format(totalTrustedProfit)}*'
                    : _numFmt.format(totalTrustedProfit)),
        ),
        PdfReportSummaryCard(
          label: l10n.totalPaid,
          value: currencies.length > 1
              ? salesByCurrency.entries
                    .map((e) => '${_numFmt.format(e.value.paid)} ${e.key}')
                    .join(' · ')
              : _numFmt.format(totalPaid),
        ),
      ],
      columns: columns,
      rows: rows,
      totalsRow: [
        l10n.total,
        '',
        '',
        currencies.length > 1
            ? salesByCurrency.entries
                  .map((e) => '${_numFmt.format(e.value.sales)} ${e.key}')
                  .join('\n')
            : _numFmt.format(totalSales),
        currencies.length > 1
            ? salesByCurrency.entries
                  .map((e) => '${_numFmt.format(e.value.cogs)} ${e.key}')
                  .join('\n')
            : _numFmt.format(totalCogs),
        currencies.length > 1
            ? salesByCurrency.entries
                  .map(
                    (e) =>
                        '${_numFmt.format(e.value.trustedProfit)}${e.value.hasIncompleteCost ? '*' : ''} ${e.key}',
                  )
                  .join('\n')
            : (hasIncompleteCost
                  ? '${_numFmt.format(totalTrustedProfit)}*'
                  : _numFmt.format(totalTrustedProfit)),
        currencies.length > 1
            ? salesByCurrency.entries
                  .map((e) => '${_numFmt.format(e.value.paid)} ${e.key}')
                  .join('\n')
            : _numFmt.format(totalPaid),
        currencies.length > 1
            ? salesByCurrency.entries
                  .map((e) => '${_numFmt.format(e.value.remaining)} ${e.key}')
                  .join('\n')
            : _numFmt.format(totalRemaining),
      ],
    );

    try {
      await PdfService.printOrShareReportPdf(
        business: business,
        l10n: l10n,
        data: data,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.operationFailed}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final finalized =
        _sales
            ?.where((s) => s.document.status != DocumentStatus.cancelled)
            .toList() ??
        [];
    final cancelled =
        _sales
            ?.where((s) => s.document.status == DocumentStatus.cancelled)
            .toList() ??
        [];
    final currencies = finalized.map((s) => s.document.currencyCode).toSet();
    final salesByCurrency = SalesReportScreen.aggregateByCurrency(finalized);
    final totalSales = finalized.fold(
      0.0,
      (s, item) => s + item.document.total,
    );
    final totalCogs = finalized.fold(0.0, (s, item) => s + item.cogs);
    // Only include gross profit from fully-costed invoices in aggregate totals.
    final totalTrustedProfit = finalized.fold(
      0.0,
      (s, item) => s + (item.trustedGrossProfit ?? 0.0),
    );
    final totalPaid = finalized.fold(0.0, (s, item) => s + item.document.paid);
    final totalRemaining = finalized.fold(
      0.0,
      (s, item) => s + item.document.remaining,
    );
    final hasIncompleteCost = finalized.any((s) => !s.isCostReliable);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.salesReport),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.printOrShareReport,
            onPressed: _sales != null && _sales!.isNotEmpty ? _exportPdf : null,
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
                _load();
              },
            ),
            if (_sales != null && _sales!.isNotEmpty) ...[
              if (currencies.length <= 1) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      _summaryChip(
                        l10n.totalSales,
                        totalSales,
                        Colors.green,
                        symbol: currencies.isNotEmpty
                            ? Currency.symbolForCode(currencies.first)
                            : '',
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        l10n.cogs,
                        totalCogs,
                        Colors.blueGrey,
                        symbol: currencies.isNotEmpty
                            ? Currency.symbolForCode(currencies.first)
                            : '',
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        l10n.grossProfit,
                        totalTrustedProfit,
                        Colors.teal,
                        symbol: currencies.isNotEmpty
                            ? Currency.symbolForCode(currencies.first)
                            : '',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    children: [
                      _summaryChip(
                        l10n.totalPaid,
                        totalPaid,
                        Colors.teal,
                        symbol: currencies.isNotEmpty
                            ? Currency.symbolForCode(currencies.first)
                            : '',
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        l10n.totalOutstanding,
                        totalRemaining,
                        Theme.of(context).colorScheme.error,
                        symbol: currencies.isNotEmpty
                            ? Currency.symbolForCode(currencies.first)
                            : '',
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Multi-currency segregated summary
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.currency_exchange,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.totalSales,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${currencies.length} ${l10n.currency}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...salesByCurrency.entries.map((e) {
                          final sym = Currency.symbolForCode(e.key);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      e.key,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${l10n.totalSales}: ${_numFmt.format(e.value.sales)} $sym',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${l10n.cogs}: ${_numFmt.format(e.value.cogs)} $sym • ${l10n.grossProfit}: ${_numFmt.format(e.value.trustedProfit)}${e.value.hasIncompleteCost ? '*' : ''} $sym',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${l10n.paid}: ${_numFmt.format(e.value.paid)} $sym • ${l10n.totalOutstanding}: ${_numFmt.format(e.value.remaining)} $sym',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      '${l10n.finalized}: ${finalized.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    if (cancelled.isNotEmpty)
                      Text(
                        '${l10n.cancelledCount}: ${cancelled.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    const Spacer(),
                    if (hasIncompleteCost) ...[
                      Icon(
                        Icons.info_outline,
                        size: 13,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.costIncomplete,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            Expanded(child: _buildList(context, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(
    String label,
    double value,
    Color color, {
    String symbol = '',
  }) {
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
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              symbol.isNotEmpty
                  ? '${_numFmt.format(value)} $symbol'
                  : _numFmt.format(value),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_error != null) {
      return AppErrorState(
        message: l10n.operationFailed,
        onRetry: _load,
      );
    }
    if (_sales == null) return const AppLoadingView();
    if (_sales!.isEmpty) {
      return AppEmptyState(
        icon: Icons.trending_up_rounded,
        title: l10n.noReportData,
        description: l10n.noDataForPeriod,
      );
    }

    return ListView.builder(
      itemCount: _sales!.length,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (ctx, i) {
        final item = _sales![i];
        final doc = item.document;
        final isCancelled = doc.status == DocumentStatus.cancelled;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.documentNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (!isCancelled && !item.isCostReliable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.amber.shade700,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      l10n.costIncomplete,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  '${_numFmt.format(doc.total)} ${doc.currencySymbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.recipientName ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      _dateFmt.format(doc.date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                if (!isCancelled) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        item.isCostReliable
                            ? '${l10n.grossProfit}: ${_numFmt.format(item.grossProfit)} ${doc.currencySymbol}'
                            : '${l10n.grossProfit}: —',
                        style: TextStyle(
                          fontSize: 11,
                          color: (item.isCostReliable && item.grossProfit >= 0)
                              ? Colors.teal.shade700
                              : (item.isCostReliable
                                    ? Colors.red
                                    : Colors.grey),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.isCostReliable &&
                          item.recognizedRevenue > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${item.profitMargin.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => DocumentDetailScreen(documentId: doc.id!),
              ),
            ).then((_) => _load()),
          ),
        );
      },
    );
  }
}
