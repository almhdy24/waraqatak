import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/date_range_filter.dart';
import '../../models/document_status.dart';
import '../../services/inventory_costing_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../document_detail_screen.dart';
import 'report_date_filter.dart';
import '../../widgets/responsive.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

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
    setState(() { _sales = null; _error = null; });
    try {
      final sales = await InventoryCostingService.instance.getSalesReportWithCost(
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

    final finalized = _sales!.where((s) => s.document.status != DocumentStatus.cancelled).toList();
    final totalSales = finalized.fold(0.0, (s, item) => s + item.document.total);
    final totalCogs = finalized.fold(0.0, (s, item) => s + item.cogs);
    final totalProfit = finalized.fold(0.0, (s, item) => s + item.grossProfit);
    final totalPaid = finalized.fold(0.0, (s, item) => s + item.document.paid);
    final totalRemaining = finalized.fold(0.0, (s, item) => s + item.document.remaining);
    final hasIncompleteCost = finalized.any((s) => !s.isCostReliable);

    final columns = [
      PdfReportColumn(title: l10n.date, flex: 1.2),
      PdfReportColumn(title: l10n.invoice, flex: 1.5),
      PdfReportColumn(title: l10n.customer, flex: 2.0),
      PdfReportColumn(title: l10n.salesValue, flex: 1.3, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.cogs, flex: 1.3, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.grossProfit, flex: 1.3, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.paid, flex: 1.2, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.remaining, flex: 1.2, align: pw.TextAlign.right),
    ];

    final rows = _sales!.map((item) {
      final doc = item.document;
      final isCancelled = doc.status == DocumentStatus.cancelled;
      final profitStr = isCancelled
          ? '—'
          : (item.isCostReliable ? _numFmt.format(item.grossProfit) : '${_numFmt.format(item.grossProfit)}*');

      return [
        _dateFmt.format(doc.date),
        doc.documentNumber,
        doc.recipientName ?? '—',
        isCancelled ? l10n.cancelledCount : _numFmt.format(doc.total),
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
          value: _numFmt.format(totalSales),
        ),
        PdfReportSummaryCard(
          label: l10n.cogs,
          value: _numFmt.format(totalCogs),
        ),
        PdfReportSummaryCard(
          label: l10n.grossProfit,
          value: _numFmt.format(totalProfit),
        ),
        PdfReportSummaryCard(
          label: l10n.totalPaid,
          value: _numFmt.format(totalPaid),
        ),
      ],
      columns: columns,
      rows: rows,
      totalsRow: [
        l10n.total,
        '',
        '',
        _numFmt.format(totalSales),
        _numFmt.format(totalCogs),
        _numFmt.format(totalProfit),
        _numFmt.format(totalPaid),
        _numFmt.format(totalRemaining),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.operationFailed}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final finalized = _sales?.where((s) => s.document.status != DocumentStatus.cancelled).toList() ?? [];
    final cancelled = _sales?.where((s) => s.document.status == DocumentStatus.cancelled).toList() ?? [];
    final totalSales = finalized.fold(0.0, (s, item) => s + item.document.total);
    final totalCogs = finalized.fold(0.0, (s, item) => s + item.cogs);
    final totalProfit = finalized.fold(0.0, (s, item) => s + item.grossProfit);
    final totalPaid = finalized.fold(0.0, (s, item) => s + item.document.paid);
    final totalRemaining = finalized.fold(0.0, (s, item) => s + item.document.remaining);
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
      body: ResponsiveCenter(child: Column(
        children: [
          ReportDateFilter(
            range: _range,
            onChanged: (r) { setState(() => _range = r); _load(); },
          ),
          if (_sales != null && _sales!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _summaryChip(l10n.totalSales, totalSales, Colors.green),
                  const SizedBox(width: 8),
                  _summaryChip(l10n.cogs, totalCogs, Colors.blueGrey),
                  const SizedBox(width: 8),
                  _summaryChip(l10n.grossProfit, totalProfit, Colors.teal),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  _summaryChip(l10n.totalPaid, totalPaid, Colors.teal),
                  const SizedBox(width: 8),
                  _summaryChip(l10n.totalOutstanding, totalRemaining,
                      Theme.of(context).colorScheme.error),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(children: [
                Text('${l10n.finalized}: ${finalized.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 12),
                if (cancelled.isNotEmpty)
                  Text('${l10n.cancelledCount}: ${cancelled.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                if (hasIncompleteCost) ...[
                  Icon(Icons.info_outline, size: 13, color: Colors.amber.shade800),
                  const SizedBox(width: 4),
                  Text(l10n.costIncomplete,
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900)),
                ],
              ]),
            ),
          ],
          Expanded(child: _buildList(context, l10n)),
        ],
      )),
    );
  }

  Widget _summaryChip(String label, double value, Color color) {
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
            Text(_numFmt.format(value),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(l10n.operationFailed),
        FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
      ]));
    }
    if (_sales == null) return const Center(child: CircularProgressIndicator());
    if (_sales!.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.trending_up_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(l10n.noDataForPeriod, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
        ]),
      ));
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
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: ListTile(
            title: Row(children: [
              Expanded(child: Text(doc.documentNumber,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ))),
              if (!isCancelled && !item.isCostReliable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade700, width: 0.5),
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
              Text('${_numFmt.format(doc.total)} ${doc.currencySymbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(child: Text(doc.recipientName ?? '', style: const TextStyle(fontSize: 12))),
                  Text(_dateFmt.format(doc.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                if (!isCancelled) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(
                      '${l10n.grossProfit}: ${_numFmt.format(item.grossProfit)} ${doc.currencySymbol}',
                      style: TextStyle(
                        fontSize: 11,
                        color: item.grossProfit >= 0 ? Colors.teal.shade700 : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.isCostReliable && item.recognizedRevenue > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${item.profitMargin.toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ]),
                ],
              ],
            ),
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: doc.id!)),
            ).then((_) => _load()),
          ),
        );
      },
    );
  }
}
