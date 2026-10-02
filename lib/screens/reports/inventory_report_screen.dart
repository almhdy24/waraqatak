import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/product.dart';
import '../inventory_screen.dart';
import '../../widgets/responsive.dart';

class InventoryReportScreen extends StatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> {
  List<Product>? _products;
  String? _error;

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _products = null; _error = null; });
    try {
      final products = await DatabaseHelper.instance.getAllProducts(activeOnly: true);
      if (!mounted) return;
      setState(() => _products = products
        ..sort((a, b) {
          final aOut = a.stockQuantity <= 0;
          final bOut = b.stockQuantity <= 0;
          final aLow = a.minStock > 0 && a.stockQuantity <= a.minStock;
          final bLow = b.minStock > 0 && b.stockQuantity <= b.minStock;
          if (aOut != bOut) return aOut ? -1 : 1;
          if (aLow != bLow) return aLow ? -1 : 1;
          return a.name.compareTo(b.name);
        }),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final outOfStock = _products?.where((p) => p.stockQuantity <= 0).length ?? 0;
    final lowStock = _products?.where(
        (p) => p.minStock > 0 && p.stockQuantity > 0 && p.stockQuantity <= p.minStock).length ?? 0;
    final total = _products?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventoryReport),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.warehouse_outlined),
            tooltip: l10n.inventory,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InventoryScreen()),
            ).then((_) => _load()),
          ),
        ],
      ),
      body: ResponsiveCenter(child: Column(
        children: [
          if (_products != null && _products!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  _chip(l10n.trackedProducts, total, Colors.blue),
                  const SizedBox(width: 8),
                  _chip(l10n.lowStock, lowStock, Colors.orange),
                  const SizedBox(width: 8),
                  _chip(l10n.outOfStock, outOfStock,
                      Theme.of(context).colorScheme.error),
                ],
              ),
            ),
          Expanded(child: _buildList(context, l10n)),
        ],
      )),
    );
  }

  Widget _chip(String label, int value, Color color) {
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
            Text('$value',
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
    if (_products == null) return const Center(child: CircularProgressIndicator());
    if (_products!.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(l10n.noReportData, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
        ]),
      ));
    }

    return ListView.builder(
      itemCount: _products!.length,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (ctx, i) {
        final p = _products![i];
        final isOut = p.stockQuantity <= 0;
        final isLow = p.minStock > 0 && p.stockQuantity > 0 && p.stockQuantity <= p.minStock;
        final statusColor = isOut
            ? Theme.of(context).colorScheme.error
            : isLow
                ? Colors.orange
                : Colors.green;
        final statusLabel = isOut
            ? l10n.outOfStock
            : isLow
                ? l10n.lowStock
                : '';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: ListTile(
            title: Row(children: [
              Expanded(child: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              Text(_numFmt.format(p.stockQuantity),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isOut ? Theme.of(context).colorScheme.error : null)),
            ]),
            subtitle: Row(children: [
              Expanded(child: Text(
                p.minStock > 0
                    ? '${l10n.lowStockThreshold}: ${_numFmt.format(p.minStock)}'
                    : '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              )),
              if (statusLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(fontSize: 10, color: statusColor,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
        );
      },
    );
  }
}
