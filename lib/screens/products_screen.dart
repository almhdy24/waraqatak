import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
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
      final db = DatabaseHelper.instance;
      List<Product> products;
      if (_query.isNotEmpty) {
        products = await db.searchProducts(_query);
      } else {
        products = await db.getAllProducts();
      }

      if (!mounted) return;
      setState(() {
        _products = products;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final l10n = AppLocalizations.of(context);
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
        final db = DatabaseHelper.instance;
        if (await db.isProductReferenced(product.id!)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.productUsedInDocuments)),
          );
          return;
        }
        await db.deleteProduct(product.id!);
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

  void _editProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _query = value;
                _load();
              },
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

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.operationFailed),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(l10n.cancel)),
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
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
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
        final stockStatus = _getStockStatus(product, l10n);
        final stockPercent = _getStockPercent(product);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (product.code != null && product.code!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.productCode}: ${product.code}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.unitPrice}: ${product.salePrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(stockStatus.icon, size: 18, color: stockStatus.color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: stockPercent,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                color: stockStatus.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            product.stockQuantity.toStringAsFixed(0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stockStatus.label,
                        style: TextStyle(
                          color: stockStatus.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.edit,
                      onPressed: () => _editProduct(product),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: l10n.delete,
                      onPressed: () => _deleteProduct(product),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ({String label, Color color, IconData icon}) _getStockStatus(
      Product product, AppLocalizations l10n) {
    if (product.stockQuantity <= 0) {
      return (
        label: l10n.outOfStock,
        color: Colors.red,
        icon: Icons.cancel_outlined
      );
    } else if (product.stockQuantity <= product.minStock) {
      return (
        label: l10n.lowStock,
        color: Colors.orange,
        icon: Icons.warning_amber_outlined
      );
    } else {
      return (
        label: l10n.stock,
        color: Colors.green,
        icon: Icons.check_circle_outline
      );
    }
  }

  double _getStockPercent(Product product) {
    if (product.minStock <= 0) {
      return product.stockQuantity > 0 ? 1.0 : 0.0;
    }
    final ratio = product.stockQuantity / product.minStock;
    return ratio.clamp(0.0, 1.0);
  }
}
