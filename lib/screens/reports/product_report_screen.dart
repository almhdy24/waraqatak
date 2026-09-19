import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/date_range_filter.dart';
import 'report_date_filter.dart';

class ProductReportScreen extends StatefulWidget {
  const ProductReportScreen({super.key});

  @override
  State<ProductReportScreen> createState() => _ProductReportScreenState();
}

class _ProductReportScreenState extends State<ProductReportScreen> {
  DateRangeFilter _range = DateRangeFilter.thisMonth();
  List<Map<String, dynamic>>? _rows;
  String? _error;

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _rows = null; _error = null; });
    try {
      final rows = await DatabaseHelper.instance.getProductReport(
        from: _range.from,
        to: _range.to,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final totalSalesValue = _rows?.fold(0.0,
        (s, r) => s + (r['sales_value'] as num).toDouble()) ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.productReport), centerTitle: true),
      body: Column(
        children: [
          ReportDateFilter(
            range: _range,
            onChanged: (r) { setState(() => _range = r); _load(); },
          ),
          if (_rows != null && _rows!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                _chip(l10n.totalSales, totalSalesValue, Colors.green),
              ]),
            ),
          Expanded(child: _buildList(context, l10n)),
        ],
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
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
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
        final salesQty = (row['sales_qty'] as num).toDouble();
        final salesValue = (row['sales_value'] as num).toDouble();
        final purchaseQty = (row['purchase_qty'] as num).toDouble();
        final stockQty = (row['stock_quantity'] as num).toDouble();

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(row['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                  Text('${l10n.stockStatus}: ${_numFmt.format(stockQty)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  _statCell(l10n.salesQty, _numFmt.format(salesQty), Colors.green),
                  const SizedBox(width: 16),
                  _statCell(l10n.salesValue, _numFmt.format(salesValue), Colors.green),
                  const SizedBox(width: 16),
                  _statCell(l10n.purchasedQty, _numFmt.format(purchaseQty), Colors.orange),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statCell(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
