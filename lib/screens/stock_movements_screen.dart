import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/widgets.dart' as pw;
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/date_range_filter.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../services/access/access_guard.dart';
import '../services/access/permission_registry.dart';
import '../services/business_reporting_service.dart';
import '../services/pdf/pdf_report_builder.dart';
import '../services/pdf_service.dart';
import '../utils/error_utils.dart';
import '../utils/format_utils.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_status_colors.dart';
import '../widgets/responsive.dart';
import '../widgets/access/screen_access_gate.dart';
import 'document_detail_screen.dart';
import 'inventory_screen.dart';
import 'reports/report_date_filter.dart';

class _ProductPickerResult {
  final Product? product;
  const _ProductPickerResult(this.product);
}

class StockMovementsScreen extends StatefulWidget {
  final Product? initialProduct;
  const StockMovementsScreen({super.key, this.initialProduct});

  @override
  State<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  DateRangeFilter _range = DateRangeFilter.thisMonth();
  StockMovementReportSummary? _reportSummary;
  List<Product> _allProducts = [];
  Product? _selectedProduct;
  String _selectedType = 'all';
  String? _error;
  bool _loading = true;
  int _currentLimit = 300;
  int _querySeq = 0;

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    _load(reloadProducts: true);
  }

  Future<void> _load({
    bool reloadProducts = false,
    bool showSpinner = true,
  }) async {
    final seq = ++_querySeq;
    setState(() {
      if (showSpinner) _loading = true;
      _error = null;
    });
    try {
      if (reloadProducts || _allProducts.isEmpty) {
        final products = await DatabaseHelper.instance.getAllProducts(
          type: 'product',
        );
        if (seq != _querySeq || !mounted) return;
        _allProducts = products;
        if (_selectedProduct != null &&
            !_allProducts.any((p) => p.id == _selectedProduct!.id)) {
          _selectedProduct = null;
        }
      }

      final summary = await BusinessReportingService.instance
          .getStockMovementsReport(
            productId: _selectedProduct?.id,
            type: _selectedType,
            from: _range.from,
            to: _range.to,
            limit: _currentLimit,
          );
      if (seq != _querySeq || !mounted) return;
      setState(() {
        _reportSummary = summary;
        _loading = false;
      });
    } catch (e) {
      if (seq != _querySeq || !mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openProductPicker(AppLocalizations l10n) async {
    if (_allProducts.isEmpty) {
      await _load(reloadProducts: true);
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<_ProductPickerResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = query.trim().isEmpty
                ? _allProducts
                : _allProducts.where((p) {
                    final q = query.trim().toLowerCase();
                    return p.name.toLowerCase().contains(q) ||
                        (p.code?.toLowerCase().contains(q) ?? false) ||
                        (p.barcode?.toLowerCase().contains(q) ?? false);
                  }).toList();

            final cs = Theme.of(ctx).colorScheme;
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: l10n.searchProductsHint,
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: cs.surfaceContainerLow,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) => setModalState(() => query = val),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.apps, color: cs.primary),
                      title: Text(
                        l10n.allProducts,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      selected: _selectedProduct == null,
                      onTap: () =>
                          Navigator.pop(ctx, const _ProductPickerResult(null)),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noSearchResults,
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final p = filtered[i];
                                final isSelected = p.id == _selectedProduct?.id;
                                final subtitleParts = [p.code, p.barcode]
                                    .where((s) => s != null && s.isNotEmpty)
                                    .join(' · ');
                                return ListTile(
                                  title: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: subtitleParts.isNotEmpty
                                      ? Text(
                                          subtitleParts,
                                          style: const TextStyle(fontSize: 11),
                                        )
                                      : null,
                                  selected: isSelected,
                                  onTap: () => Navigator.pop(
                                    ctx,
                                    _ProductPickerResult(p),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedProduct = result.product;
        _currentLimit = 300;
      });
      _load();
    }
  }

  Future<void> _exportPdf() async {
    final l10n = AppLocalizations.of(context);
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null || _reportSummary == null) return;

    final canViewCost = AccessGuard.can(PermissionRegistry.stockViewCost);
    final columns = [
      PdfReportColumn(title: l10n.date, flex: 1.4),
      PdfReportColumn(title: l10n.product, flex: 2.2),
      PdfReportColumn(title: l10n.type, flex: 1.2),
      PdfReportColumn(
        title: l10n.quantity,
        flex: 1.2,
        align: pw.TextAlign.right,
      ),
      if (_selectedProduct != null)
        PdfReportColumn(
          title: l10n.balanceAfter,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
      if (canViewCost)
        PdfReportColumn(
          title: l10n.averageCost,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
    ];

    final rows = _reportSummary!.items.map((item) {
      final m = item.movement;
      final sign = m.quantity > 0 ? '+' : (m.quantity < 0 ? '-' : '');
      final costStr = m.unitCost != null
          ? _numFmt.format(m.unitCost)
          : (m.costStatus == StockMovement.costStatusUnknown
                ? '—'
                : l10n.costReconstructed);

      return [
        _dateFmt.format(m.date),
        m.productName ?? '—',
        _typeLabel(m.type, l10n),
        '$sign${FormatUtils.formatQuantity(m.quantity.abs())}',
        if (_selectedProduct != null)
          item.balanceAfter != null
              ? FormatUtils.formatQuantity(item.balanceAfter!)
              : '—',
        if (canViewCost) costStr,
      ];
    }).toList();

    String subtitle = _selectedProduct != null
        ? _selectedProduct!.name
        : l10n.allProducts;
    if (_reportSummary!.items.length >= _currentLimit) {
      subtitle +=
          ' (${l10n.showingMovementsLimit(_reportSummary!.items.length)})';
    }

    final data = PdfReportData(
      title: l10n.stockMovementsReport,
      subtitle: subtitle,
      dateRange: _range.label(l10n),
      warningNotice: _reportSummary!.unvaluedMovementsCount > 0
          ? l10n.unknownCostNotice
          : null,
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.totalStockIn,
          value:
              '+${FormatUtils.formatQuantity(_reportSummary!.totalInQuantity)}',
        ),
        PdfReportSummaryCard(
          label: l10n.totalStockOut,
          value:
              '-${FormatUtils.formatQuantity(_reportSummary!.totalOutQuantity)}',
        ),
      ],
      columns: columns,
      rows: rows,
    );

    try {
      await PdfService.printOrShareReportPdf(
        business: business,
        l10n: l10n,
        data: data,
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

  String _typeLabel(String type, AppLocalizations l10n) => switch (type) {
    StockMovement.typeOpening => l10n.openingStock,
    StockMovement.typePurchase => l10n.purchase,
    StockMovement.typeSale => l10n.salesPeriod,
    StockMovement.typeAdjustment => l10n.stockAdjustment,
    StockMovement.typeCancellation => l10n.documentCancellation,
    _ => type,
  };

  Color _typeColor(BuildContext context, String type, ColorScheme cs) =>
      switch (type) {
        StockMovement.typeOpening => AppStatusColors.fg(
          context,
          AppStatus.info,
        ),
        StockMovement.typePurchase => cs.tertiary,
        StockMovement.typeSale => cs.primary,
        StockMovement.typeAdjustment => AppStatusColors.fg(
          context,
          AppStatus.warning,
        ),
        StockMovement.typeCancellation => cs.error,
        _ => cs.onSurfaceVariant,
      };

  IconData _typeIcon(String type) => switch (type) {
    StockMovement.typeOpening => Icons.flag_outlined,
    StockMovement.typePurchase => Icons.shopping_cart_outlined,
    StockMovement.typeSale => Icons.receipt_long_outlined,
    StockMovement.typeAdjustment => Icons.tune,
    StockMovement.typeCancellation => Icons.cancel_outlined,
    _ => Icons.swap_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return ScreenAccessGate(
      screenType: StockMovementsScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.stockMovementsReport),
          centerTitle: true,
          actions: [
            if (_selectedProduct != null)
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: l10n.stockAdjustment,
                onPressed: () async {
                  final changed = await InventoryScreen.showAdjustDialog(
                    context,
                    _selectedProduct!,
                  );
                  if (changed) _load();
                },
              ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: l10n.printOrShareReport,
              onPressed:
                  _reportSummary != null && _reportSummary!.items.isNotEmpty
                  ? _exportPdf
                  : null,
            ),
          ],
        ),
        body: ResponsiveCenter(
          child: Column(
            children: [
              // Date Filter
              ReportDateFilter(
                range: _range,
                onChanged: (r) {
                  setState(() {
                    _range = r;
                    _currentLimit = 300;
                  });
                  _load();
                },
              ),

              // Searchable Product Filter Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openProductPicker(l10n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedProduct?.name ?? l10n.allProducts,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedProduct != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _selectedProduct != null
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedProduct != null)
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _selectedProduct = null;
                                _currentLimit = 300;
                              });
                              _load();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.arrow_drop_down,
                            color: cs.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Type Filter Chips
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _typeChip(l10n.all, 'all'),
                    const SizedBox(width: 6),
                    _typeChip(l10n.purchase, StockMovement.typePurchase),
                    const SizedBox(width: 6),
                    _typeChip(l10n.salesPeriod, StockMovement.typeSale),
                    const SizedBox(width: 6),
                    _typeChip(
                      l10n.stockAdjustment,
                      StockMovement.typeAdjustment,
                    ),
                    const SizedBox(width: 6),
                    _typeChip(l10n.openingStock, StockMovement.typeOpening),
                    const SizedBox(width: 6),
                    _typeChip(
                      l10n.documentCancellation,
                      StockMovement.typeCancellation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Summary Bar
              if (_reportSummary != null && !_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Builder(
                    builder: (context) {
                      final successColor = AppDesignTokens.semanticSuccess(
                        context,
                      );
                      final dangerColor = AppDesignTokens.semanticDanger(
                        context,
                      );
                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: successColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: successColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_downward,
                                    size: 16,
                                    color: successColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.totalStockIn,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          '+${FormatUtils.formatQuantity(_reportSummary!.totalInQuantity)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: successColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: dangerColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: dangerColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_upward,
                                    size: 16,
                                    color: dangerColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.totalStockOut,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          '-${FormatUtils.formatQuantity(_reportSummary!.totalOutQuantity)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: dangerColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 4),

              // Movements List
              Expanded(child: _buildBody(context, l10n, cs)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String label, String type) {
    final selected = _selectedType == type;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() {
          _selectedType = type;
          _currentLimit = 300;
        });
        _load();
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    if (_loading) {
      return const AppLoadingView();
    }
    if (_error != null) {
      return AppErrorState(
        message: ErrorUtils.toFriendlyMessage(_error!, l10n),
        onRetry: _load,
      );
    }
    final items = _reportSummary?.items ?? [];
    if (items.isEmpty) {
      return AppEmptyState(
        icon: Icons.history_outlined,
        title: l10n.noMovements,
      );
    }

    final isAtLimit = items.length >= _currentLimit;
    final totalCount = items.length + (isAtLimit ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => _load(reloadProducts: true, showSpinner: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 40),
        itemCount: totalCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == items.length && isAtLimit) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.showingMovementsLimit(_currentLimit),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() => _currentLimit += 300);
                      _load(showSpinner: false);
                    },
                    child: Text(l10n.loadMore),
                  ),
                ],
              ),
            );
          }

          final item = items[i];
          final m = item.movement;
          final isIn = m.quantity > 0;
          final color = isIn
              ? AppDesignTokens.semanticSuccess(context)
              : (m.quantity < 0
                    ? AppDesignTokens.semanticDanger(context)
                    : cs.onSurfaceVariant);
          final typeBadgeColor = _typeColor(context, m.type, cs);
          final sign = isIn ? '+' : (m.quantity < 0 ? '-' : '');

          return Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: m.referenceDocumentId != null
                  ? () => _openDocument(context, m.referenceDocumentId!)
                  : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: typeBadgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _typeIcon(m.type),
                        color: typeBadgeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.productName ?? '—',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: typeBadgeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _typeLabel(m.type, l10n),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: typeBadgeColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dateFmt.format(m.date),
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (m.notes != null &&
                              m.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              m.notes!,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (m.referenceDocumentId != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.link, size: 12, color: cs.primary),
                                const SizedBox(width: 4),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    m.referenceDocumentNumber != null &&
                                            m
                                                .referenceDocumentNumber!
                                                .isNotEmpty
                                        ? '${_docTypeLabel(m.referenceDocumentType, l10n)}: ${m.referenceDocumentNumber}'
                                        : '#${m.referenceDocumentId}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Running balance (when filtering by product)
                          if (item.isBalanceReliable &&
                              item.balanceBefore != null &&
                              item.balanceAfter != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${l10n.balanceBefore}: ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    '${FormatUtils.formatQuantity(item.balanceBefore!)} → ${FormatUtils.formatQuantity(item.balanceAfter!)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Cost info
                          if (AccessGuard.can(
                            PermissionRegistry.stockViewCost,
                          )) ...[
                            if (m.unitCost != null &&
                                m.costStatus ==
                                    StockMovement.costStatusKnown) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.averageCost}: ${_numFmt.format(m.unitCost)} | ${l10n.totalCost}: ${_numFmt.format(m.totalCost)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.tertiary,
                                ),
                              ),
                            ] else if (m.costStatus ==
                                StockMovement.costStatusReconstructed) ...[
                              const SizedBox(height: 4),
                              Text(
                                l10n.costReconstructed,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppStatusColors.fg(
                                    context,
                                    AppStatus.info,
                                  ),
                                ),
                              ),
                            ] else if (m.costStatus ==
                                    StockMovement.costStatusUnknown &&
                                m.type != StockMovement.typeOpening) ...[
                              const SizedBox(height: 4),
                              Text(
                                l10n.costUnknown,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppStatusColors.fg(
                                    context,
                                    AppStatus.warning,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Quantity
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$sign${FormatUtils.formatQuantity(m.quantity.abs(), unit: m.productUnit)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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

  String _docTypeLabel(String? type, AppLocalizations l10n) {
    return switch (type) {
      'invoice' => l10n.invoice,
      'purchase' => l10n.purchase,
      'quotation' => l10n.quotation,
      'receipt' || 'payment_receipt' => l10n.paymentReceipt,
      'expense_voucher' => l10n.expenseVoucher,
      _ => l10n.documents,
    };
  }
}
