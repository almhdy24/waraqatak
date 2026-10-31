import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/currency.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../customer_detail_screen.dart';
import '../../widgets/responsive.dart';

class CustomerReportScreen extends StatefulWidget {
  const CustomerReportScreen({super.key});

  @override
  State<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends State<CustomerReportScreen> {
  List<Map<String, dynamic>>? _rows;
  String? _error;
  String _currencySymbol = '';

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _rows = null; _error = null; });
    try {
      final business = await DatabaseHelper.instance.getFirstBusiness();
      final currency = business?.currencyCode ?? 'SDG';
      _currencySymbol = Currency.symbolForCode(currency);
      final rows = await DatabaseHelper.instance.getContactBalances(
        'customer',
        'invoice',
        currencyCode: currency,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _exportPdf() async {
    final l10n = AppLocalizations.of(context);
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null || _rows == null) return;

    final totalOutstanding = _rows!.fold(0.0,
        (s, r) => s + (r['outstanding'] as num).toDouble());

    final columns = [
      PdfReportColumn(title: l10n.customer, flex: 2.2),
      PdfReportColumn(title: l10n.phone, flex: 1.5),
      PdfReportColumn(title: l10n.total, flex: 1.3, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.paid, flex: 1.3, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.remaining, flex: 1.3, align: pw.TextAlign.right),
    ];

    final rows = _rows!.map((r) {
      return [
        r['name'] as String? ?? '—',
        r['phone'] as String? ?? '—',
        _numFmt.format((r['total'] as num).toDouble()),
        _numFmt.format((r['paid'] as num).toDouble()),
        _numFmt.format((r['outstanding'] as num).toDouble()),
      ];
    }).toList();

    final data = PdfReportData(
      title: l10n.customerReport,
      dateRange: DateFormat('dd/MM/yyyy').format(DateTime.now()),
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.totalOutstanding,
          value: _numFmt.format(totalOutstanding),
        ),
      ],
      columns: columns,
      rows: rows,
      totalsRow: [
        l10n.total,
        '',
        '',
        '',
        _numFmt.format(totalOutstanding),
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

    final totalOutstanding = _rows?.fold(0.0,
        (s, r) => s + (r['outstanding'] as num).toDouble()) ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customerReport),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.printOrShareReport,
            onPressed: _rows != null && _rows!.isNotEmpty ? _exportPdf : null,
          ),
        ],
      ),
      body: ResponsiveCenter(child: Column(
        children: [
          if (_rows != null && _rows!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.allTimeBalance,
                          style: TextStyle(fontSize: 10,
                              color: Theme.of(context).colorScheme.error)),
                      Text(l10n.totalOutstanding,
                          style: TextStyle(fontSize: 10,
                              color: Theme.of(context).colorScheme.error)),
                      Text('${_numFmt.format(totalOutstanding)} $_currencySymbol',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.error)),
                    ]),
                  ),
                ),
              ]),
            ),
          Expanded(child: _buildList(context, l10n)),
        ],
      )),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(l10n.operationFailed),
        FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
      ]));
    }
    if (_rows == null) return const Center(child: CircularProgressIndicator());
    if (_rows!.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(l10n.noReportData, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
        ]),
      ));
    }

    return ListView.builder(
      itemCount: _rows!.length,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (ctx, i) {
        final row = _rows![i];
        final outstanding = (row['outstanding'] as num).toDouble();
        final total = (row['total_amount'] as num).toDouble();
        final docCount = row['doc_count'] as int;
        final hasDebt = outstanding > 0;
        final debtColor = hasDebt
            ? Theme.of(context).colorScheme.error
            : Colors.green;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: ListTile(
            title: Row(children: [
              Expanded(child: Text(row['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              if (hasDebt)
                Text(_numFmt.format(outstanding),
                    style: TextStyle(fontWeight: FontWeight.w600, color: debtColor)),
            ]),
            subtitle: Text(
              '${l10n.invoiceCount}: $docCount · ${l10n.totalSales}: ${_numFmt.format(total)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: hasDebt ? null : const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 18),
            onTap: () async {
              final contactId = row['contact_id'] as int;
              final contact = await DatabaseHelper.instance.getContactById(contactId);
              if (contact == null || !ctx.mounted) return;
              Navigator.push(ctx,
                MaterialPageRoute(
                  builder: (_) => CustomerDetailScreen(contact: contact),
                ),
              ).then((_) => _load());
            },
          ),
        );
      },
    );
  }
}
