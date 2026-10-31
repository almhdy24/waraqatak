import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/currency.dart';
import '../../models/date_range_filter.dart';
import '../../models/payment_method.dart';
import '../../utils/currency_utils.dart';
import '../document_detail_screen.dart';
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
    setState(() { _rows = null; _error = null; });
    try {
      final rows = await DatabaseHelper.instance.getPaymentReport(
        from: _range.from,
        to: _range.to,
      );
      final methods = await DatabaseHelper.instance.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _methodsMap = {for (final m in methods) m.key: m};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final totalsByCurrency = <String, ({double inAmount, double outAmount})>{};
    if (_rows != null) {
      for (final r in _rows!) {
        final c = (r['currency_code'] as String?)?.trim() ?? 'SDG';
        final code = c.isNotEmpty ? c : 'SDG';
        final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
        final isIn = r['doc_type'] == 'invoice';
        final prev = totalsByCurrency[code] ?? (inAmount: 0.0, outAmount: 0.0);
        totalsByCurrency[code] = (
          inAmount: prev.inAmount + (isIn ? amt : 0.0),
          outAmount: prev.outAmount + (!isIn ? amt : 0.0),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentsReport), centerTitle: true),
      body: ResponsiveCenter(child: Column(
        children: [
          ReportDateFilter(
            range: _range,
            onChanged: (r) { setState(() => _range = r); _load(); },
          ),
          if (totalsByCurrency.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: totalsByCurrency.entries.map((entry) {
                  final code = entry.key;
                  final symbol = Currency.symbolForCode(code);
                  final inAmt = entry.value.inAmount;
                  final outAmt = entry.value.outAmount;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        _chip('${l10n.receivedPayments} ($symbol)', inAmt, Colors.green),
                        const SizedBox(width: 8),
                        _chip('${l10n.madePayments} ($symbol)', outAmt, Colors.orange),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
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
    if (_rows == null) return const Center(child: CircularProgressIndicator());
    if (_rows!.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(l10n.noDataForPeriod, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
        ]),
      ));
    }

    return ListView.builder(
      itemCount: _rows!.length,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (ctx, i) {
        final row = _rows![i];
        final amount = (row['amount'] as num).toDouble();
        final isIn = row['doc_type'] == 'invoice';
        final color = isIn ? Colors.green : Colors.orange;
        final method = row['payment_method'] as String?;
        final cCode = (row['currency_code'] as String?)?.trim() ?? '';
        final sym = cCode.isNotEmpty ? ' ${Currency.symbolForCode(cCode)}' : '';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: ListTile(
            onTap: row['document_id'] != null
                ? () => _openDocument(context, row['document_id'] as int)
                : null,
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
                  color: color, size: 20),
            ),
            title: Row(children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      row['document_number'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${_numFmt.format(amount)}$sym',
                  style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            ]),
            subtitle: Row(children: [
              Expanded(child: Text(
                [
                  row['recipient_name'] as String? ?? '',
                  if (method != null)
                    _methodsMap[method]?.label(AppLocalizations.of(ctx).langCode) ??
                        CurrencyUtils.getPaymentMethodLabel(
                          method,
                          AppLocalizations.of(ctx),
                        ),
                ].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(fontSize: 12),
              )),
              Text(_dateFmt.format(DateTime.parse(row['date'] as String)),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
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
