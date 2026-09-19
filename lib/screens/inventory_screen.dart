import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../services/inventory_service.dart';

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

  Future<void> _showAdjustDialog(Product product) async {
    final l10n = AppLocalizations.of(context);
    final deltaController = TextEditingController();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.stockAdjustment),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${product.name}: ${product.stockQuantity.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: deltaController,
              decoration: InputDecoration(labelText: l10n.adjustmentDelta),
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: InputDecoration(labelText: l10n.notes),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final delta = double.tryParse(deltaController.text);
      if (delta == null || delta == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).invalidAmount)),
        );
        return;
      }
      try {
        await InventoryService.adjust(
          productId: product.id!,
          delta: delta,
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).operationSuccessful)),
        );
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).operationFailed}: $e')),
        );
      }
    }
  }

  Future<void> _showMovements(Product product) async {
    final l10n = AppLocalizations.of(context);
    final movements = await InventoryService.getMovements(product.id!);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
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
                          title: Text(m.type),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventory), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      return Center(child: Text(l10n.noProducts));
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final stockOk = product.stockQuantity > product.minStock;
        final stockLow = product.stockQuantity > 0 && product.stockQuantity <= product.minStock;
        final stockOut = product.stockQuantity <= 0;

        Color stockColor = stockOk ? Colors.green : (stockLow ? Colors.orange : Colors.red);
        IconData stockIcon = stockOk
            ? Icons.check_circle_outline
            : (stockLow ? Icons.warning_amber_outlined : Icons.cancel_outlined);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(stockIcon, color: stockColor),
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${l10n.stockQuantity}: ${product.stockQuantity.toStringAsFixed(0)}'
              '${product.minStock > 0 ? " / ${l10n.minStock}: ${product.minStock.toStringAsFixed(0)}" : ""}',
              style: TextStyle(color: stockOut ? Colors.red : null),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: l10n.stockMovements,
                  onPressed: () => _showMovements(product),
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: l10n.adjustStock,
                  onPressed: () => _showAdjustDialog(product),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
