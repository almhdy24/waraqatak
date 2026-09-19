import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  final int refreshToken;
  const ProductsScreen({super.key, this.refreshToken = 0});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product>? _products;
  String _query = '';
  String? _typeFilter; // null = all, 'product', 'service'
  String? _error;

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
        products = await DatabaseHelper.instance.getAllProducts(type: _typeFilter);
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
    final referenced = await DatabaseHelper.instance.isProductReferenced(product.id!);

    if (referenced) {
      if (!mounted) return;
      final deactivate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.deactivateProduct),
          content: Text(l10n.deactivateProductMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.deactivateProduct),
            ),
          ],
        ),
      );
      if (deactivate == true && mounted) {
        await ProductService.setActive(product.id!, active: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.productDeactivated)),
        );
        _load();
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteProductMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DatabaseHelper.instance.deleteProduct(product.id!);
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
    }
  }

  Future<void> _toggleActive(Product product) async {
    final l10n = AppLocalizations.of(context);
    await ProductService.setActive(product.id!, active: !product.isActive);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(product.isActive ? l10n.productDeactivated : l10n.productActivated),
      ),
    );
    _load();
  }

  void _editProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.products), centerTitle: true),
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
              onChanged: (value) {
                _query = value;
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(l10n.allTypes, null, l10n),
                  const SizedBox(width: 6),
                  _filterChip(l10n.productsOnly, Product.typeProduct, l10n),
                  const SizedBox(width: 6),
                  _filterChip(l10n.servicesOnly, Product.typeService, l10n),
                ],
              ),
            ),
          ),
          Expanded(child: _buildList(context, l10n)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_products',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          ).then((_) => _load());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterChip(String label, String? type, AppLocalizations l10n) {
    final selected = _typeFilter == type;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _typeFilter = type);
        _load();
      },
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

    if (_products == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final products = _products!;
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(l10n.noProducts),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isService = product.isService;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Opacity(
            opacity: product.isActive ? 1.0 : 0.55,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isService ? Icons.build_outlined : Icons.inventory_2_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: product.isActive ? null : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            if (!product.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).inactive,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                        if (product.code != null && product.code!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${AppLocalizations.of(context).sku}: ${product.code}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                        if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('${AppLocalizations.of(context).barcode}: ${product.barcode}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${AppLocalizations.of(context).unitPrice}: ${product.salePrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (!isService) ...[
                          const SizedBox(height: 8),
                          _buildStockRow(product, AppLocalizations.of(context)),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: AppLocalizations.of(context).edit,
                        onPressed: () => _editProduct(product),
                      ),
                      IconButton(
                        icon: Icon(
                          product.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: product.isActive ? Colors.orange : Colors.green,
                        ),
                        tooltip: product.isActive
                            ? AppLocalizations.of(context).deactivateProduct
                            : AppLocalizations.of(context).activateProduct,
                        onPressed: () => _toggleActive(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: AppLocalizations.of(context).delete,
                        onPressed: () => _handleDelete(product),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockRow(Product product, AppLocalizations l10n) {
    final status = _stockStatus(product, l10n);
    final percent = _stockPercent(product);
    return Row(
      children: [
        Icon(status.icon, size: 16, color: status.color),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              color: status.color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(product.stockQuantity.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  ({String label, Color color, IconData icon}) _stockStatus(
      Product product, AppLocalizations l10n) {
    if (product.stockQuantity <= 0) {
      return (label: l10n.outOfStock, color: Colors.red, icon: Icons.cancel_outlined);
    } else if (product.stockQuantity <= product.minStock) {
      return (label: l10n.lowStock, color: Colors.orange, icon: Icons.warning_amber_outlined);
    } else {
      return (label: l10n.stock, color: Colors.green, icon: Icons.check_circle_outline);
    }
  }

  double _stockPercent(Product product) {
    if (product.minStock <= 0) return product.stockQuantity > 0 ? 1.0 : 0.0;
    return (product.stockQuantity / product.minStock).clamp(0.0, 1.0);
  }
}
