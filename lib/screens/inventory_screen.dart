import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../services/inventory_service.dart';
import 'barcode_scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product>? _products;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _products = null;
      _error = null;
    });
    try {
      List<Product> products;
      if (_query.isNotEmpty) {
        final all = await DatabaseHelper.instance.searchProducts(_query);
        products = all.where((p) => p.isProduct).toList();
      } else {
        products = await DatabaseHelper.instance.getAllProducts(type: 'product');
      }
      if (!mounted) return;
      setState(() => _products = products);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || barcode.isEmpty || !mounted) return;

    final results = await DatabaseHelper.instance.searchActiveProducts(barcode);
    final product = results.where((p) => p.barcode == barcode).firstOrNull
        ?? (results.isNotEmpty ? results.first : null);

    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).barcodeNotFound)),
      );
      return;
    }
    setState(() {
      _query = product.barcode ?? product.name;
      _products = [product];
    });
  }

  Future<void> _showAdjustDialog(Product product) async {
    final l10n = AppLocalizations.of(context);
    final deltaController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final delta = double.tryParse(deltaController.text) ?? 0;
          final newQty = product.stockQuantity + delta;
          return AlertDialog(
            title: Text(l10n.stockAdjustment),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${l10n.stockQuantity}: ${product.stockQuantity.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                TextField(
                  controller: deltaController,
                  decoration: InputDecoration(
                    labelText: l10n.adjustmentDelta,
                    helperText: delta != 0
                        ? '${l10n.newStockQuantity}: ${newQty.toStringAsFixed(0)}'
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  autofocus: true,
                  onChanged: (_) => setDialog(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: l10n.adjustmentReason),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () async {
                  final d = double.tryParse(deltaController.text);
                  if (d == null || d == 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(l10n.invalidAmount)),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await InventoryService.adjust(
                      productId: product.id!,
                      delta: d,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.operationSuccessful)),
                    );
                    _load();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.operationFailed}: $e')),
                    );
                  }
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
    deltaController.dispose();
    notesController.dispose();
  }

  Future<void> _showMovements(Product product) async {
    final l10n = AppLocalizations.of(context);
    final movements = await InventoryService.getMovements(product.id!);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${product.name} — ${l10n.stockMovements}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: movements.isEmpty
                  ? Center(child: Text(l10n.noMovements))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: movements.length,
                      itemBuilder: (_, i) {
                        final m = movements[i];
                        final isIn = m.quantity > 0;
                        return ListTile(
                          leading: Icon(
                            isIn ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIn ? Colors.green : Colors.red,
                          ),
                          title: Text(_movementTypeLabel(m.type, l10n)),
                          subtitle: m.notes != null ? Text(m.notes!) : null,
                          trailing: Text(
                            (isIn ? '+' : '') + m.quantity.toStringAsFixed(2),
                            style: TextStyle(
                              color: isIn ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _movementTypeLabel(String type, AppLocalizations l10n) {
    return switch (type) {
      'opening'     => l10n.openingStock,
      'purchase'    => l10n.purchase,
      'sale'        => l10n.invoice,
      'adjustment'  => l10n.stockAdjustment,
      'cancellation'=> l10n.cancelledCount,
      _             => type,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventory),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: l10n.scanToLocate,
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _query = ''; _load(); },
                      )
                    : null,
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          Expanded(child: _buildList(context, l10n)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(l10n.operationFailed),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    if (_products == null) return const Center(child: CircularProgressIndicator());

    final products = _products!;
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(l10n.noProducts, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final stockOut = product.stockQuantity <= 0;
          final stockLow = !stockOut && product.minStock > 0 &&
              product.stockQuantity <= product.minStock;
          final stockOk = !stockOut && !stockLow;

          final statusColor = stockOut
              ? Theme.of(context).colorScheme.error
              : stockLow ? Colors.orange : Colors.green;
          final statusLabel = stockOut
              ? l10n.outOfStock
              : stockLow ? l10n.lowStock : l10n.inStock;
          final stockIcon = stockOut
              ? Icons.cancel_outlined
              : stockLow ? Icons.warning_amber_outlined : Icons.check_circle_outline;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: stockOut
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.3)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: ListTile(
              leading: Icon(stockIcon, color: statusColor),
              title: Text(product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Row(children: [
                Text(
                  '${l10n.stockQuantity}: ${product.stockQuantity.toStringAsFixed(0)}'
                  '${product.minStock > 0 ? " / ${l10n.minStock}: ${product.minStock.toStringAsFixed(0)}" : ""}',
                  style: TextStyle(color: stockOut ? statusColor : null, fontSize: 12),
                ),
                const Spacer(),
                if (!stockOk)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(fontSize: 10, color: statusColor,
                            fontWeight: FontWeight.w600)),
                  ),
              ]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history, size: 20),
                    tooltip: l10n.stockMovements,
                    onPressed: () => _showMovements(product),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, size: 20),
                    tooltip: l10n.adjustStock,
                    onPressed: () => _showAdjustDialog(product),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Needed for firstOrNull on non-nullable list
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
