import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/product.dart';
import '../../services/business_reporting_service.dart';
import '../../services/csv_service.dart';
import '../../services/inventory_costing_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../../utils/format_utils.dart';
import '../../utils/number_input.dart';
import '../../widgets/amount_field.dart';
import '../inventory_screen.dart';
import '../stock_movements_screen.dart';
import '../../services/feature_access.dart';
import '../../services/license_service.dart';
import '../../widgets/pro_upgrade_sheet.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/report_export_menu.dart';
import '../../widgets/app_status_colors.dart';
import '../../widgets/responsive.dart';

class InventoryReportScreen extends StatefulWidget {
  final String initialFilter;
  const InventoryReportScreen({super.key, this.initialFilter = 'all'});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> {
  InventoryReportSummary? _summary;
  List<String> _categories = [];
  late String _selectedStatus;
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _querySeq = 0;
  String? _error;
  bool _loading = true;

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialFilter;
    _load();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_querySeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = await Future.wait([
        DatabaseHelper.instance.getProductCategories(),
        BusinessReportingService.instance.getInventoryReport(
          category: _selectedCategory,
          stockStatus: _selectedStatus,
          searchQuery: _searchQuery,
        ),
      ]);
      if (!mounted || seq != _querySeq) return;
      setState(() {
        _categories = futures[0] as List<String>;
        _summary = futures[1] as InventoryReportSummary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _querySeq) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  PdfReportData _buildPdfData(AppLocalizations l10n) {
    final summary = _summary!;
    String reportTitle;
    List<PdfReportColumn> columns;
    List<List<String>> rows;
    List<String>? totalsRow;
    String? warning;

    if (_selectedStatus == 'low_stock') {
      reportTitle = l10n.lowStockReport;
      columns = [
        PdfReportColumn(title: l10n.product, flex: 2.2),
        PdfReportColumn(title: l10n.category, flex: 1.5),
        PdfReportColumn(
          title: l10n.stockQuantity,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.minStock,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.shortageQuantity,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
      ];
      rows = summary.items.map((i) {
        return [
          i.product.name,
          i.product.category ?? '—',
          FormatUtils.formatQuantity(i.stockQuantity, unit: i.product.unit),
          FormatUtils.formatQuantity(i.minStock, unit: i.product.unit),
          FormatUtils.formatQuantity(i.shortageQuantity, unit: i.product.unit),
        ];
      }).toList();
    } else if (_selectedStatus == 'out_of_stock') {
      reportTitle = l10n.outOfStockReport;
      columns = [
        PdfReportColumn(title: l10n.product, flex: 2.5),
        PdfReportColumn(title: l10n.category, flex: 1.5),
        PdfReportColumn(
          title: l10n.stockQuantity,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.minStock,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
      ];
      rows = summary.items.map((i) {
        return [
          i.product.name,
          i.product.category ?? '—',
          FormatUtils.formatQuantity(i.stockQuantity, unit: i.product.unit),
          FormatUtils.formatQuantity(i.minStock, unit: i.product.unit),
        ];
      }).toList();
    } else if (_selectedStatus == 'valuation') {
      reportTitle = l10n.inventoryValuationReport;
      columns = [
        PdfReportColumn(title: l10n.product, flex: 2.5),
        PdfReportColumn(title: l10n.category, flex: 1.5),
        PdfReportColumn(
          title: l10n.stockQuantity,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.averageCost,
          flex: 1.3,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.inventoryValuationAtCost,
          flex: 1.5,
          align: pw.TextAlign.right,
        ),
      ];
      rows = summary.items.map((i) {
        final valStr = i.valuationAtCost != null
            ? _numFmt.format(i.valuationAtCost)
            : l10n.costUnknown;
        final costStr = i.averageCost != null
            ? _numFmt.format(i.averageCost)
            : '—';
        return [
          i.product.name,
          i.product.category ?? '—',
          FormatUtils.formatQuantity(i.stockQuantity, unit: i.product.unit),
          costStr,
          valStr,
        ];
      }).toList();
      totalsRow = [
        l10n.total,
        '',
        '',
        '',
        _numFmt.format(summary.totalValuationAtCost),
      ];
      if (summary.unvaluedProductsCount > 0) {
        warning =
            '${l10n.unresolvedCostProducts}: ${summary.unvaluedProductsCount} (${l10n.unvaluedStockQty}: ${FormatUtils.formatQuantity(summary.unvaluedQuantity)})';
      }
    } else {
      reportTitle = l10n.currentInventoryReport;
      columns = [
        PdfReportColumn(title: l10n.product, flex: 2.2),
        PdfReportColumn(title: l10n.category, flex: 1.4),
        PdfReportColumn(
          title: l10n.stockQuantity,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.averageCost,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.inventoryValuationAtCost,
          flex: 1.4,
          align: pw.TextAlign.right,
        ),
      ];
      rows = summary.items.map((i) {
        final valStr = i.valuationAtCost != null
            ? _numFmt.format(i.valuationAtCost)
            : (i.stockQuantity > 0 ? l10n.costUnknown : '—');
        final costStr = i.averageCost != null
            ? _numFmt.format(i.averageCost)
            : '—';
        return [
          i.product.name,
          i.product.category ?? '—',
          FormatUtils.formatQuantity(i.stockQuantity, unit: i.product.unit),
          costStr,
          valStr,
        ];
      }).toList();
      totalsRow = [
        l10n.total,
        '',
        '',
        '',
        _numFmt.format(summary.totalValuationAtCost),
      ];
      if (summary.unvaluedProductsCount > 0) {
        warning =
            '${l10n.unresolvedCostProducts}: ${summary.unvaluedProductsCount} (${l10n.unvaluedStockQty}: ${FormatUtils.formatQuantity(summary.unvaluedQuantity)})';
      }
    }

    return PdfReportData(
      title: reportTitle,
      subtitle: _selectedCategory != null
          ? _selectedCategory!
          : l10n.allCategories,
      dateRange: DateFormat('dd/MM/yyyy').format(DateTime.now()),
      warningNotice: warning,
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.inventoryValuationAtCost,
          value: _numFmt.format(summary.totalValuationAtCost),
        ),
        PdfReportSummaryCard(
          label: l10n.lowStock,
          value: '${summary.lowStockCount}',
        ),
        PdfReportSummaryCard(
          label: l10n.outOfStock,
          value: '${summary.outOfStockCount}',
        ),
      ],
      columns: columns,
      rows: rows,
      totalsRow: totalsRow,
    );
  }

  Future<void> _exportPdf({required bool isShare}) async {
    final l10n = AppLocalizations.of(context);
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null || _summary == null) return;
    final data = _buildPdfData(l10n);

    try {
      if (isShare) {
        await PdfService.shareReportPdf(
          business: business,
          l10n: l10n,
          data: data,
        );
      } else {
        await PdfService.printOrShareReportPdf(
          business: business,
          l10n: l10n,
          data: data,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        '${l10n.operationFailed}: $e',
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  Future<void> _shareWhatsApp(AppLocalizations l10n) async {
    final summary = _summary;
    if (summary == null) return;
    final text =
        '${l10n.inventoryReport}\n'
        '${l10n.inventoryValuationAtCost}: ${_numFmt.format(summary.totalValuationAtCost)}\n'
        '${l10n.lowStock}: ${summary.lowStockCount}\n'
        '${l10n.outOfStock}: ${summary.outOfStockCount}';
    await PdfService.shareText(text: text);
  }

  Future<void> _exportCsv(AppLocalizations l10n) async {
    final summary = _summary;
    if (summary == null) return;
    final headers = [
      l10n.product,
      l10n.category,
      l10n.stockQuantity,
      l10n.unit,
      l10n.purchasePrice,
      l10n.sellingPrice,
    ];
    final csvRows = summary.items
        .map(
          (i) => [
            i.product.name,
            i.product.category ?? '',
            i.stockQuantity,
            i.product.unit ?? '',
            i.isCostKnown
                ? (i.averageCost ?? i.product.purchasePrice)
                : i.product.purchasePrice,
            i.product.salePrice,
          ],
        )
        .toList();

    try {
      final bytes = CsvService.instance.exportReportToCsv(
        headers: headers,
        rows: csvRows,
      );
      await PdfService.shareCsv(
        bytes: bytes,
        fileName:
            'inventory_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          '${l10n.operationFailed}: $e',
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  void _openExportMenu(BuildContext context, AppLocalizations l10n) {
    ReportExportMenu.show(
      context: context,
      title: l10n.inventoryReport,
      onPrintPdf: () => _exportPdf(isShare: false),
      onSharePdf: () => _exportPdf(isShare: true),
      onShareWhatsApp: () => _shareWhatsApp(l10n),
      onExportCsv: () => _exportCsv(l10n),
    );
  }

  void _showReconciliationDialog(Product p) {
    final l10n = AppLocalizations.of(context);
    final costController = TextEditingController(
      text: p.purchasePrice > 0 ? '${p.purchasePrice}' : '',
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.reconcileCost}: ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.currentStock}: ${FormatUtils.formatQuantity(p.stockQuantity, unit: p.unit)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            AmountField(
              controller: costController,
              maxDecimals: 4,
              showMultipliers: true,
              decoration: InputDecoration(
                labelText: l10n.enterCostBasis,
                hintText: l10n.costBasisHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: l10n.costReconciliationReason,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final val = NumberInput.parse(costController.text.trim());
              if (val == null || val <= 0) return;
              Navigator.pop(ctx);
              try {
                await DatabaseHelper.instance.reconcileProductCost(
                  productId: p.id!,
                  newUnitCost: val,
                  notes: reasonController.text.trim().isNotEmpty
                      ? reasonController.text.trim()
                      : null,
                );
                if (mounted) {
                  AppSnackBar.show(
                    context,
                    l10n.costReconciliationSuccess,
                    severity: AppSnackBarSeverity.success,
                  );
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.show(
                    context,
                    e.toString(),
                    severity: AppSnackBarSeverity.error,
                  );
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showLegacyAuditDialog() async {
    final l10n = AppLocalizations.of(context);
    final summary = await InventoryCostingService.instance
        .getLegacyCostSummary();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.legacyCostSummaryTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _auditRow(
              l10n.costKnown,
              '${summary.knownMovements}',
              AppStatusColors.fg(ctx, AppStatus.success),
            ),
            _auditRow(
              l10n.costReconstructed,
              '${summary.reconstructedMovements}',
              AppStatusColors.fg(ctx, AppStatus.info),
            ),
            _auditRow(
              l10n.costUnknown,
              '${summary.unknownMovements}',
              AppStatusColors.fg(ctx, AppStatus.warning),
            ),
            const Divider(height: 24),
            _auditRow(
              l10n.valuedStockCount,
              '${summary.knownProducts}',
              AppStatusColors.fg(ctx, AppStatus.success),
            ),
            _auditRow(
              l10n.unresolvedCostProducts,
              '${summary.unknownProducts}',
              AppStatusColors.fg(ctx, AppStatus.warning),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _auditRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final summary = _summary;

    final totalValuation = summary?.totalValuationAtCost ?? 0.0;
    final unvaluedCount = summary?.unvaluedProductsCount ?? 0;
    final lowStock = summary?.lowStockCount ?? 0;
    final outOfStock = summary?.outOfStockCount ?? 0;
    final total = summary?.trackedProductsCount ?? 0;

    return ScreenAccessGate(
      screenType: InventoryReportScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedStatus == 'low_stock'
                ? l10n.lowStockReport
                : (_selectedStatus == 'out_of_stock'
                      ? l10n.outOfStockReport
                      : (_selectedStatus == 'valuation'
                            ? l10n.inventoryValuationReport
                            : l10n.inventoryReport)),
          ),
          centerTitle: true,
          actions: [
            if (ReportExportMenu.canExport())
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: l10n.printOrShareReport,
                onPressed: summary != null && summary.items.isNotEmpty
                    ? () => _openExportMenu(context, l10n)
                    : null,
              ),
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: l10n.legacyCostSummaryTitle,
              onPressed: _showLegacyAuditDialog,
            ),
            IconButton(
              icon: const Icon(Icons.warehouse_outlined),
              tooltip: l10n.inventory,
              onPressed: () async {
                final entitlement = await LicenseService.instance
                    .checkEntitlement(force: true);
                if (!context.mounted) return;
                if (!FeatureAccess.canAccess(Feature.inventory, entitlement)) {
                  final activated = await ProUpgradeSheet.show(
                    context,
                    feature: Feature.inventory,
                  );
                  if (!activated || !context.mounted) return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                ).then((_) => _load());
              },
            ),
          ],
        ),
        body: ResponsiveCenter(
          child: Column(
            children: [
              // Status Selector Tabs
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  children: [
                    _statusChip(l10n.all, 'all'),
                    const SizedBox(width: 6),
                    _statusChip(l10n.lowStock, 'low_stock'),
                    const SizedBox(width: 6),
                    _statusChip(l10n.outOfStock, 'out_of_stock'),
                    const SizedBox(width: 6),
                    _statusChip(l10n.inventoryValuationReport, 'valuation'),
                  ],
                ),
              ),

              // Search Bar & Category Filter
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Row(
                  children: [
                    // Search TextField
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: l10n.searchProductsHint,
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              _searchQuery = val;
                              _load();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Category Dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedCategory,
                            isExpanded: true,
                            hint: Text(
                              l10n.allCategories,
                              style: const TextStyle(fontSize: 12),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  l10n.allCategories,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              ..._categories.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedCategory = val);
                              _load();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Valuation & Stock Status Summary Chips
              if (summary != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                  child: Row(
                    children: [
                      _chip(
                        l10n.inventoryValuationAtCost,
                        _numFmt.format(totalValuation),
                        AppStatusColors.fg(context, AppStatus.success),
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        l10n.unresolvedCostProducts,
                        '$unvaluedCount',
                        unvaluedCount > 0
                            ? AppStatusColors.fg(context, AppStatus.warning)
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Row(
                    children: [
                      _chip(
                        l10n.trackedProducts,
                        '$total',
                        AppStatusColors.fg(context, AppStatus.info),
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        l10n.lowStock,
                        '$lowStock',
                        AppStatusColors.fg(context, AppStatus.warning),
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        l10n.outOfStock,
                        '$outOfStock',
                        Theme.of(context).colorScheme.error,
                      ),
                    ],
                  ),
                ),
              ],

              Expanded(child: _buildList(context, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, String status) {
    final selected = _selectedStatus == status;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() => _selectedStatus = status);
        _load();
      },
    );
  }

  Widget _chip(String label, String value, Color color) {
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
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.operationFailed),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    final items = _summary?.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warehouse_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                _selectedStatus == 'low_stock'
                    ? l10n.noReplenishmentNeeded
                    : l10n.noReportData,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final p = item.product;
        final isOut = item.isOutOfStock;
        final isLow = item.isLowStock;
        final statusColor = isOut
            ? Theme.of(context).colorScheme.error
            : isLow
            ? AppStatusColors.fg(context, AppStatus.warning)
            : AppStatusColors.fg(context, AppStatus.success);
        final statusLabel = isOut
            ? l10n.outOfStock
            : isLow
            ? l10n.lowStock
            : '';

        final hasCost = item.isCostKnown && item.averageCost != null;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StockMovementsScreen(initialProduct: p),
              ),
            ).then((_) => _load()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (p.category != null && p.category!.isNotEmpty)
                              Text(
                                p.category!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            FormatUtils.formatQuantity(
                              p.stockQuantity,
                              unit: p.unit,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isOut
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                          if (isLow) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${l10n.shortageQuantity}: ${FormatUtils.formatQuantity(item.shortageQuantity, unit: p.unit)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppStatusColors.fg(
                                  context,
                                  AppStatus.warning,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasCost
                              ? '${l10n.averageCost}: ${_numFmt.format(p.averageCost)} | ${l10n.inventoryValuationAtCost}: ${_numFmt.format(item.valuationAtCost)}'
                              : (p.stockQuantity > 0
                                    ? '${l10n.costStatus}: ${l10n.costUnknown}'
                                    : ''),
                          style: TextStyle(
                            fontSize: 11,
                            color: hasCost
                                ? AppStatusColors.fg(context, AppStatus.success)
                                : AppStatusColors.fg(
                                    context,
                                    AppStatus.warning,
                                  ),
                            fontWeight: hasCost
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (statusLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!hasCost && p.stockQuantity > 0) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showReconciliationDialog(p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppStatusColors.bg(
                                context,
                                AppStatus.info,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.reconcileCost,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppStatusColors.fg(
                                  context,
                                  AppStatus.info,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
