import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/date_range_filter.dart';
import '../../models/document.dart';
import '../../models/document_status.dart';
import '../document_detail_screen.dart';
import 'report_date_filter.dart';
import '../../widgets/responsive.dart';

class PurchasesReportScreen extends StatefulWidget {
  const PurchasesReportScreen({super.key});

  @override
  State<PurchasesReportScreen> createState() => _PurchasesReportScreenState();
}

class _PurchasesReportScreenState extends State<PurchasesReportScreen> {
  DateRangeFilter _range = DateRangeFilter.thisMonth();
  List<Document>? _docs;
  String? _error;

  static final _numFmt = NumberFormat('#,##0.##');
  static final _dateFmt = DateFormat('dd/MM/yy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _docs = null; _error = null; });
    try {
      final docs = await DatabaseHelper.instance.getDocumentsInPeriod(
        type: 'purchase',
        from: _range.from,
        to: _range.to,
      );
      if (!mounted) return;
      setState(() => _docs = docs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final finalized = _docs?.where((d) => d.status != DocumentStatus.cancelled).toList() ?? [];
    final cancelled = _docs?.where((d) => d.status == DocumentStatus.cancelled).toList() ?? [];
    final totalPurchases = finalized.fold(0.0, (s, d) => s + d.total);
    final totalPaid = finalized.fold(0.0, (s, d) => s + d.paid);
    final totalRemaining = finalized.fold(0.0, (s, d) => s + d.remaining);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchasesReport), centerTitle: true),
      body: ResponsiveCenter(child: Column(
        children: [
          ReportDateFilter(
            range: _range,
            onChanged: (r) { setState(() => _range = r); _load(); },
          ),
          if (_docs != null && _docs!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _chip(l10n.totalPurchasesAmt, totalPurchases, Colors.orange),
                  const SizedBox(width: 8),
                  _chip(l10n.totalPaid, totalPaid, Colors.teal),
                  const SizedBox(width: 8),
                  _chip(l10n.totalOutstanding, totalRemaining,
                      Theme.of(context).colorScheme.error),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                Text('${l10n.finalized}: ${finalized.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 12),
                if (cancelled.isNotEmpty)
                  Text('${l10n.cancelledCount}: ${cancelled.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ],
          Expanded(child: _buildList(context, l10n)),
        ],
      )),
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
    if (_docs == null) return const Center(child: CircularProgressIndicator());
    if (_docs!.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(l10n.noDataForPeriod, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
        ]),
      ));
    }

    return ListView.builder(
      itemCount: _docs!.length,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (ctx, i) {
        final doc = _docs![i];
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
              Text('${_numFmt.format(doc.total)} ${doc.currencySymbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            subtitle: Row(children: [
              Expanded(child: Text(doc.recipientName ?? '', style: const TextStyle(fontSize: 12))),
              Text(_dateFmt.format(doc.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
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
