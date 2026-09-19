import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import 'inventory_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  final int refreshToken;
  const ProductsScreen({super.key, this.refreshToken = 0});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product>? _products;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _typeFilter;
  String? _error;

  static final _priceFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
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
        products = await DatabaseHelper.instance.searchProducts(_query);
        if (_typeFilter != null) {
          products = products.where((p) => p.type == _typeFilter).toList();
        }
      } else {
        products =
            await DatabaseHelper.instance.getAllProducts(type: _typeFilter);
      }
      if (!mounted) return;
      setState(() => _products = products);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _handleDelete(Product product) async {
    final l10n = AppLocalizations.of(context);
    final referenced =
        await DatabaseHelper.instance.isProductReferenced(product.id!);

    if (!mounted) return;

    if (referenced) {
      final deactivate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deactivateProduct),
          content: Text(l10n.deactivateProductMessage),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.deactivateProduct)),
          ],
        ),
      );
      if (deactivate == true && mounted) {
        await ProductService.setActive(product.id!, active: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.productDeactivated)));
        _load();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteProductMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DatabaseHelper.instance.deleteProduct(product.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.operationSuccessful)));
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.operationFailed}: $e')));
      }
    }
  }

  Future<void> _toggleActive(Product product) async {
    final l10n = AppLocalizations.of(context);
    await ProductService.setActive(product.id!, active: !product.isActive);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          product.isActive ? l10n.productDeactivated : l10n.productActivated),
    ));
    _load();
  }

  void _editProduct(Product product) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
      ).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products),
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
      body: Column(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                _filterChip(l10n.allTypes, null),
                const SizedBox(width: 6),
                _filterChip(l10n.productsOnly, Product.typeProduct),
                const SizedBox(width: 6),
                _filterChip(l10n.servicesOnly, Product.typeService),
              ],
            ),
          ),
          Expanded(child: _buildList(context, l10n, cs)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_products',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductFormScreen()),
        ).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: Text(l10n.products),
      ),
    );
  }

  Widget _filterChip(String label, String? type) {
    final selected = _typeFilter == type;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() => _typeFilter = type);
        _load();
      },
    );
  }

  Widget _buildList(
      BuildContext context, AppLocalizations l10n, ColorScheme cs) {
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(l10n.operationFailed),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
        ]),
      );
    }
    if (_products == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final products = _products!;
    if (products.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inventory_2_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(l10n.noProducts,
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _ProductCard(
          product: products[i],
          priceFmt: _priceFmt,
          onEdit: () => _editProduct(products[i]),
          onToggleActive: () => _toggleActive(products[i]),
          onDelete: () => _handleDelete(products[i]),
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final NumberFormat priceFmt;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.priceFmt,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isService = product.isService;

    final stockOut = !isService && product.stockQuantity <= 0;
    final stockLow = !isService && !stockOut &&
        product.minStock > 0 &&
        product.stockQuantity <= product.minStock;

    final stockColor = stockOut
        ? cs.error
        : stockLow
            ? Colors.orange
            : Colors.green;

    return Opacity(
      opacity: product.isActive ? 1.0 : 0.6,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: stockOut
                  ? cs.error.withValues(alpha: 0.35)
                  : cs.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon swatch
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isService
                          ? Colors.blue.withValues(alpha: 0.12)
                          : cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isService
                          ? Icons.build_circle_outlined
                          : Icons.inventory_2_outlined,
                      size: 22,
                      color: isService
                          ? Colors.blue.shade700
                          : cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  decoration: product.isActive
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                                maxLines: 2,
                              ),
                            ),
                            if (!product.isActive) ...[
                              const SizedBox(width: 6),
                              _badge(l10n.inactive, Colors.grey),
                            ] else if (stockOut)
                              _badge(l10n.outOfStock, cs.error)
                            else if (stockLow)
                              _badge(l10n.lowStock, Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(spacing: 10, children: [
                          if (product.code != null &&
                              product.code!.isNotEmpty)
                            _metaChip(
                                Icons.tag, '${l10n.sku}: ${product.code}'),
                          if (product.barcode != null &&
                              product.barcode!.isNotEmpty)
                            _metaChip(Icons.qr_code,
                                product.barcode!),
                        ]),
                      ],
                    ),
                  ),

                  // Action menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 20, color: cs.onSurfaceVariant),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'toggle') onToggleActive();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(l10n.edit),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: ListTile(
                          dense: true,
                          leading: Icon(product.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          title: Text(product.isActive
                              ? l10n.deactivateProduct
                              : l10n.activateProduct),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          title: Text(l10n.delete,
                              style:
                                  const TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Price row + stock bar
              Row(
                children: [
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        priceFmt.format(product.salePrice),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      Text(l10n.unitPrice,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                  if (!isService) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 13, color: stockColor),
                              const SizedBox(width: 4),
                              Text(
                                product.stockQuantity
                                    .toStringAsFixed(0),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: stockColor),
                              ),
                              if (product.minStock > 0) ...[
                                Text(' / ',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400)),
                                Text(
                                  product.minStock.toStringAsFixed(0),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _stockPercent(product),
                              minHeight: 5,
                              backgroundColor: Colors.grey.shade200,
                              valueColor:
                                  AlwaysStoppedAnimation(stockColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.build_circle_outlined,
                              size: 13, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                          Text(l10n.servicesOnly,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade600)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _stockPercent(Product p) {
    if (p.minStock <= 0) return p.stockQuantity > 0 ? 1.0 : 0.0;
    return (p.stockQuantity / (p.minStock * 2)).clamp(0.0, 1.0);
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w700)),
      );

  Widget _metaChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.grey.shade500),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      );
}
