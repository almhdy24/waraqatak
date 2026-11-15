import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/catalog_events.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../services/access/access_guard.dart';
import '../services/access/permission_registry.dart';
import '../services/product_service.dart';
import '../utils/error_utils.dart';
import '../utils/format_utils.dart';
import 'barcode_scanner_screen.dart';
import 'inventory_screen.dart';
import 'product_form_screen.dart';
import 'activation_screen.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_status_colors.dart';
import '../widgets/product_image_thumbnail.dart';
import '../widgets/pro_upgrade_sheet.dart';
import '../widgets/responsive.dart';
import 'bulk_pricing_screen.dart';
import 'csv_import_export_screen.dart';

class ProductsScreen extends StatefulWidget {
  final int refreshToken;
  const ProductsScreen({super.key, this.refreshToken = 0});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product>? _products;
  List<String> _categories = [];
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _typeFilter;
  String? _categoryFilter;
  String? _error;
  Timer? _debounceTimer;
  int _searchSession = 0;

  static final _priceFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    CatalogEvents.pricesChanged.addListener(_onCatalogChanged);
    _load();
  }

  void _onCatalogChanged() {
    if (mounted) _load();
  }

  @override
  void didUpdateWidget(covariant ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  @override
  void dispose() {
    CatalogEvents.pricesChanged.removeListener(_onCatalogChanged);
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _query = v.trim();
      _load();
    });
  }

  Future<void> _load() async {
    final currentSession = ++_searchSession;
    setState(() {
      _products = null;
      _error = null;
    });
    try {
      final categoriesFuture = DatabaseHelper.instance.getProductCategories();
      List<Product> products;
      if (_query.isNotEmpty) {
        products = await DatabaseHelper.instance.searchProducts(
          _query,
          category: _categoryFilter,
        );
        if (_typeFilter != null) {
          products = products.where((p) => p.type == _typeFilter).toList();
        }
      } else {
        products = await DatabaseHelper.instance.getAllProducts(
          type: _typeFilter,
          category: _categoryFilter,
        );
      }
      final categories = await categoriesFuture;
      if (!mounted || currentSession != _searchSession) return;
      setState(() {
        _products = products;
        _categories = categories;
      });
    } catch (e) {
      if (!mounted || currentSession != _searchSession) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _scanBarcode() async {
    final l10n = AppLocalizations.of(context);
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || barcode.trim().isEmpty || !mounted) return;

    final query = barcode.trim();
    final matched = await DatabaseHelper.instance.searchProducts(query);
    final exact =
        matched.where((p) => p.barcode == query).firstOrNull ??
        (matched.isNotEmpty ? matched.first : null);

    if (!mounted) return;
    if (exact != null) {
      _searchCtrl.text = exact.barcode ?? exact.name;
      _query = _searchCtrl.text;
      _load();
    } else {
      if (AccessGuard.can(PermissionRegistry.productsManage)) {
        AppSnackBar.show(
          context,
          '${l10n.barcodeNotFound}: $query',
          actionLabel: l10n.addProduct,
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductFormScreen(initialBarcode: query),
              ),
            ).then((_) => _load());
          },
        );
      } else {
        AppSnackBar.show(
          context,
          '${l10n.barcodeNotFound}: $query',
        );
      }
    }
  }

  Future<void> _handleDelete(Product product) async {
    if (!AccessGuard.can(PermissionRegistry.productsDelete)) return;
    final l10n = AppLocalizations.of(context);
    final referenced = await DatabaseHelper.instance.isProductReferenced(
      product.id!,
    );

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
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.deactivateProduct),
            ),
          ],
        ),
      );
      if (deactivate == true && mounted) {
        await ProductService.setActive(product.id!, active: false);
        if (!mounted) return;
        AppSnackBar.show(context, l10n.productDeactivated);
        _load();
      }
      return;
    }

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.confirmDelete,
      message: l10n.deleteProductMessage,
      confirmLabel: l10n.delete,
      isDestructive: true,
    );

    if (confirmed && mounted) {
      try {
        await ProductService.deleteProduct(product.id!);
        if (!mounted) return;
        AppSnackBar.show(
          context,
          l10n.operationSuccessful,
          severity: AppSnackBarSeverity.success,
        );
        _load();
      } on ProductInUseException {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          l10n.errProductInUse,
          severity: AppSnackBarSeverity.error,
        );
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          ErrorUtils.toFriendlyMessage(e, l10n),
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _toggleActive(Product product) async {
    if (!AccessGuard.can(PermissionRegistry.productsManage)) return;
    final l10n = AppLocalizations.of(context);
    await ProductService.setActive(product.id!, active: !product.isActive);
    if (!mounted) return;
    AppSnackBar.show(
      context,
      product.isActive ? l10n.productDeactivated : l10n.productActivated,
    );
    _load();
  }

  void _editProduct(Product product) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
  ).then((_) => _load());

  Future<void> _openInventory() async {
    final entitlement = await LicenseService.instance.checkEntitlement(
      force: true,
    );
    if (!mounted) return;
    if (!FeatureAccess.canAccess(Feature.inventory, entitlement)) {
      final result = await ProUpgradeSheet.show(
        context,
        feature: Feature.inventory,
      );
      if (result == true && mounted) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
        );
        if (!mounted) return;
        LicenseService.instance.invalidateCache();
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InventoryScreen()),
    );
    if (mounted) {
      _load();
    }
  }

  Future<void> _openBulkPricing() async {
    final entitlement = await LicenseService.instance.checkEntitlement(
      force: true,
    );
    if (!mounted) return;
    if (!FeatureAccess.canAccess(Feature.bulkPriceUpdate, entitlement)) {
      final result = await ProUpgradeSheet.show(
        context,
        feature: Feature.bulkPriceUpdate,
      );
      if (result == true && mounted) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
        );
        if (!mounted) return;
        LicenseService.instance.invalidateCache();
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BulkPricingScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _openCsv() async {
    final entitlement = await LicenseService.instance.checkEntitlement(
      force: true,
    );
    if (!mounted) return;
    if (!FeatureAccess.canAccess(Feature.csvImportExport, entitlement)) {
      final result = await ProUpgradeSheet.show(
        context,
        feature: Feature.csvImportExport,
      );
      if (result == true && mounted) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
        );
        if (!mounted) return;
        LicenseService.instance.invalidateCache();
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CsvImportExportScreen()),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = AccessGuard.can(PermissionRegistry.productsManage);
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: l10n.scanBarcode,
            onPressed: _scanBarcode,
          ),
          IconButton(
            icon: const Icon(Icons.warehouse_outlined),
            tooltip: l10n.inventory,
            onPressed: _openInventory,
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'bulk_pricing') _openBulkPricing();
              if (val == 'csv') _openCsv();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'bulk_pricing',
                child: Row(
                  children: [
                    const Icon(Icons.price_change_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.bulkPricingTitle),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    const Icon(Icons.import_export_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.csvImportExportTitle),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonLabel,
                          onPressed: () {
                            _debounceTimer?.cancel();
                            _searchCtrl.clear();
                            _query = '';
                            _load();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        tooltip: l10n.scanBarcode,
                        onPressed: _scanBarcode,
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onSearchChanged,
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
            if (_categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _categoryChip(l10n.allCategories, null),
                      ..._categories.map(
                        (cat) => Padding(
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: _categoryChip(cat, cat),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: _buildList(context, l10n, cs)),
          ],
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'fab_products',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              ).then((_) => _load()),
              icon: const Icon(Icons.add),
              label: Text(l10n.addProduct),
            )
          : null,
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

  Widget _categoryChip(String label, String? category) {
    final selected = _categoryFilter == category;
    return FilterChip(
      avatar: selected ? null : const Icon(Icons.label_outline, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() => _categoryFilter = category);
        _load();
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    if (_error != null) {
      return AppErrorState(
        message: ErrorUtils.toFriendlyMessage(_error!, l10n),
        onRetry: _load,
      );
    }
    if (_products == null) {
      return const AppLoadingView();
    }
    final products = _products!;
    if (products.isEmpty) {
      if (_query.isNotEmpty) {
        return AppEmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.noSearchResults,
          description: l10n.noMatchingProduct,
        );
      }
      final canManage = AccessGuard.can(PermissionRegistry.productsManage);
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: l10n.noProducts,
        actionLabel: canManage ? l10n.addProduct : null,
        onAction: canManage
            ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              ).then((_) => _load())
            : null,
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
    final canManage = AccessGuard.can(PermissionRegistry.productsManage);
    final canDelete = AccessGuard.can(PermissionRegistry.productsDelete);
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isService = product.isService;

    final stockOut = !isService && product.stockQuantity <= 0;
    final stockLow =
        !isService &&
        !stockOut &&
        product.minStock > 0 &&
        product.stockQuantity <= product.minStock;

    final stockColor = stockOut
        ? cs.error
        : stockLow
            ? AppStatusColors.fg(context, AppStatus.warning)
            : AppStatusColors.fg(context, AppStatus.success);

    return Opacity(
      opacity: product.isActive ? 1.0 : 0.6,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onEdit,
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
                    // Icon swatch / image thumbnail
                    ProductImageThumbnail(
                      imagePath: product.imagePath,
                      isService: isService,
                      size: 44,
                      heroTag: product.id != null
                          ? 'product_image_${product.id}'
                          : null,
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
                                _badge(l10n.inactive, cs.onSurfaceVariant),
                              ] else if (stockOut)
                                _badge(l10n.outOfStock, cs.error)
                              else if (stockLow)
                                _badge(
                                  l10n.lowStock,
                                  AppStatusColors.fg(
                                      context, AppStatus.warning),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            children: [
                              if (product.category != null &&
                                  product.category!.isNotEmpty)
                                _metaChip(
                                  Icons.category_outlined,
                                  product.category!,
                                  cs,
                                ),
                              if (product.code != null &&
                                  product.code!.isNotEmpty)
                                _metaChip(
                                  Icons.tag,
                                  '${l10n.sku}: ${product.code}',
                                  cs,
                                ),
                              if (product.barcode != null &&
                                  product.barcode!.isNotEmpty)
                                _metaChip(Icons.qr_code, product.barcode!, cs),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
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
                            leading: Icon(
                              canManage
                                  ? Icons.edit_outlined
                                  : Icons.visibility_outlined,
                            ),
                            title: Text(canManage ? l10n.edit : l10n.details),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (canManage)
                          PopupMenuItem(
                            value: 'toggle',
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                product.isActive
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              title: Text(
                                product.isActive
                                    ? l10n.deactivateProduct
                                    : l10n.activateProduct,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        if (canDelete)
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.delete_outline,
                                color: cs.error,
                              ),
                              title: Text(
                                l10n.delete,
                                style: TextStyle(color: cs.error),
                              ),
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
                        if (product.priceCurrency != null &&
                            product.referenceSalePrice != null)
                          Text(
                            '${priceFmt.format(product.referenceSalePrice)} ${product.priceCurrency}',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.outline,
                            ),
                          ),
                        Text(
                          l10n.unitPrice,
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
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
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 13,
                                  color: stockColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  FormatUtils.formatQuantity(
                                    product.stockQuantity,
                                    unit: product.unit,
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: stockColor,
                                  ),
                                ),
                                if (product.minStock > 0) ...[
                                  Text(
                                    ' / ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.outline,
                                    ),
                                  ),
                                  Text(
                                    FormatUtils.formatQuantity(
                                      product.minStock,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
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
                                backgroundColor: cs.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(stockColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.build_circle_outlined,
                              size: 13,
                              color: AppStatusColors.fg(
                                  context, AppStatus.info),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.servicesOnly,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppStatusColors.fg(
                                    context, AppStatus.info),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
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
    child: Text(
      label,
      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
    ),
  );

  Widget _metaChip(IconData icon, String label, ColorScheme cs) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: cs.outline),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
    ],
  );
}
