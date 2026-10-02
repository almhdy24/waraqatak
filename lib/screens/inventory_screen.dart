import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../services/inventory_service.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/responsive.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product>? _products;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _error;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        products =
            await DatabaseHelper.instance.getAllProducts(type: 'product');
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

    final results =
        await DatabaseHelper.instance.searchActiveProducts(barcode);
    final product =
        results.where((p) => p.barcode == barcode).firstOrNull ??
            (results.isNotEmpty ? results.first : null);

    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).barcodeNotFound)));
      return;
    }
    _searchCtrl.text = product.barcode ?? product.name;
    setState(() {
      _query = _searchCtrl.text;
      _products = [product];
    });
  }

  Future<void> _showAdjustDialog(Product product) async {
    final l10n = AppLocalizations.of(context);
    final deltaCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            final delta = double.tryParse(deltaCtrl.text) ?? 0;
            final newQty = product.stockQuantity + delta;
            final isAdd = delta > 0;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.stockAdjustment,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(product.name,
                      style: TextStyle(
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),

                  // Current / new qty display
                  Row(
                    children: [
                      Expanded(
                        child: _QtyBox(
                          label: l10n.stockQuantity,
                          value: product.stockQuantity.toStringAsFixed(0),
                          color: Colors.grey,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.arrow_forward,
                            color: delta != 0
                                ? (isAdd ? Colors.green : Colors.red)
                                : Colors.grey),
                      ),
                      Expanded(
                        child: _QtyBox(
                          label: l10n.newStockQuantity,
                          value: delta != 0
                              ? newQty.toStringAsFixed(0)
                              : '—',
                          color: delta != 0
                              ? (newQty >= 0 ? Colors.green : Colors.red)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: deltaCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.adjustmentDelta,
                      prefixIcon: const Icon(Icons.tune),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    autofocus: true,
                    onChanged: (_) => setSheet(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.adjustmentReason,
                      prefixIcon: const Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        final d = double.tryParse(deltaCtrl.text);
                        if (d == null || d == 0) return;
                        Navigator.pop(ctx);
                        try {
                          await InventoryService.adjust(
                            productId: product.id!,
                            delta: d,
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(l10n.operationSuccessful)));
                          _load();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '${l10n.operationFailed}: $e')));
                        }
                      },
                      style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    deltaCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _showMovements(Product product) async {
    final l10n = AppLocalizations.of(context);
    final movements = await InventoryService.getMovements(product.id!);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(l10n.stockMovements,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Divider(height: 1, color: Theme.of(ctx).colorScheme.outlineVariant),
            Expanded(
              child: movements.isEmpty
                  ? Center(child: Text(l10n.noMovements))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: movements.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = movements[i];
                        final isIn = m.quantity > 0;
                        final color =
                            isIn ? Colors.green : Colors.red;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      color.withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isIn
                                      ? Icons.add_rounded
                                      : Icons.remove_rounded,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _movementTypeLabel(m.type, l10n),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                    if (m.notes != null)
                                      Text(m.notes!,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors
                                                  .grey.shade500)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isIn ? '+' : ''}${m.quantity.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: color),
                                  ),
                                  Text(
                                      _dateFmt.format(m.date),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade400),
                                    ),
                                ],
                              ),
                            ],
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

  String _movementTypeLabel(String type, AppLocalizations l10n) =>
      switch (type) {
        'opening' => l10n.openingStock,
        'purchase' => l10n.purchase,
        'sale' => l10n.invoice,
        'adjustment' => l10n.stockAdjustment,
        'cancellation' => l10n.cancelledCount,
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final products = _products ?? [];
    final outCount = products.where((p) => p.stockQuantity <= 0).length;
    final lowCount = products
        .where((p) =>
            p.stockQuantity > 0 &&
            p.minStock > 0 &&
            p.stockQuantity <= p.minStock)
        .length;

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
      body: ResponsiveCenter(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _query = '';
                          _load();
                        })
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),

          // Summary strip
          if (_products != null && _products!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  _SummaryChip(
                    icon: Icons.inventory_2_outlined,
                    label:
                        '${_products!.length} ${l10n.trackedProducts}',
                    color: cs.primary,
                  ),
                  if (lowCount > 0) ...[
                    const SizedBox(width: 8),
                    _SummaryChip(
                      icon: Icons.warning_amber_rounded,
                      label: '$lowCount ${l10n.lowStock}',
                      color: Colors.orange,
                    ),
                  ],
                  if (outCount > 0) ...[
                    const SizedBox(width: 8),
                    _SummaryChip(
                      icon: Icons.cancel_outlined,
                      label: '$outCount ${l10n.outOfStock}',
                      color: cs.error,
                    ),
                  ],
                ],
              ),
            ),

          Expanded(child: _buildList(context, l10n, cs)),
        ],
      )),
    );
  }

  Widget _buildList(
      BuildContext context, AppLocalizations l10n, ColorScheme cs) {
    if (_error != null) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(l10n.operationFailed),
              const SizedBox(height: 12),
              FilledButton.tonal(
                  onPressed: _load, child: Text(l10n.retry)),
            ]),
      );
    }

    if (_products == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final products = _products!;
    if (products.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warehouse_outlined,
                  size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(l10n.noProducts,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 15)),
            ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final p = products[i];
          final stockOut = p.stockQuantity <= 0;
          final stockLow = !stockOut &&
              p.minStock > 0 &&
              p.stockQuantity <= p.minStock;
          final color = stockOut
              ? cs.error
              : stockLow
                  ? Colors.orange
                  : Colors.green;
          final statusLabel = stockOut
              ? l10n.outOfStock
              : stockLow
                  ? l10n.lowStock
                  : l10n.inStock;

          final pct = p.minStock > 0
              ? (p.stockQuantity / (p.minStock * 2)).clamp(0.0, 1.0)
              : (p.stockQuantity > 0 ? 1.0 : 0.0);

          return Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: stockOut
                      ? cs.error.withValues(alpha: 0.35)
                      : cs.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      stockOut
                          ? Icons.cancel_outlined
                          : stockLow
                              ? Icons.warning_amber_outlined
                              : Icons.check_circle_outline,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(statusLabel,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: color,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              p.stockQuantity.toStringAsFixed(0),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: color),
                            ),
                            if (p.minStock > 0)
                              Text(
                                ' / ${p.minStock.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor: Colors.grey.shade200,
                            valueColor:
                                AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history, size: 20),
                        tooltip: l10n.stockMovements,
                        onPressed: () => _showMovements(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, size: 20),
                        tooltip: l10n.adjustStock,
                        onPressed: () => _showAdjustDialog(p),
                      ),
                    ],
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

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SummaryChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _QtyBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _QtyBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ]),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
