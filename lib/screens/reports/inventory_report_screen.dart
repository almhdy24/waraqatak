import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/product.dart';
import '../../services/business_reporting_service.dart';
import '../../services/inventory_costing_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../../utils/format_utils.dart';
import '../inventory_screen.dart';
import '../../widgets/app_snackbar.dart';
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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
      if (!mounted) return;
      setState(() {
        _categories = futures[0] as List<String>;
        _summary = futures[1] as InventoryReportSummary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    final l10n = AppLocalizations.of(context);
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null || _summary == null) return;

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
        PdfReportColumn(title: l10n.stockQuantity, flex: 1.2, align: pw.TextAlign.right),
        PdfReportColumn(title: l10n.minStock, flex: 1.2, align: pw.TextAlign.right),
        PdfReportColumn(title: l10n.shortageQuantity, flex: 1.2, align: pw.TextAlign.right),
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
        PdfReportColumn(title: l10n.stockQuantity, flex: 1.2, align: pw.TextAlign.right),
        PdfReportColumn(title: l10n.minStock, flex: 1.2, align: pw.TextAlign.right),
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
        PdfReportColumn(title: l10n.stockQuantity, flex: 1.2, align: pw.TextAlign.right),
        PdfReportColumn(title: l10n.averageCost, flex: 1.3, align: pw.TextAlign.right),
        PdfReportColumn(title: l10n.inventoryValuationAtCost, flex: 1.5, align: pw.TextAlign.right),
      ];
      rows = summary.items.map((i) {
        final valStr = i.valuationAtCost != null
            ? _numFmt.format(i.valuationAtCost)
            : l10n.costUnknown;
        final costStr = i.averageCost != null ? _numFmt.format(i.averageCost) : '—';
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
        warning = '${l10n.unresolvedCostProducts}: ${summary.unvaluedProductsCount} (${l10n.unvaluedStockQty}: ${FormatUtils.formatQuantity(summary.unvaluedQuantity)})';
      }
    } else {
      reportTitle = l10n.currentInventoryReport;
      columns = [
        PdfReportColumn(title: l10n.product, flex: 2.2),
        PdfReportColumn(title: l10n.category, flex: 1.4),
        PdfReportColumn(title: l10n.stockQuantity, flex: 1.2, align: pw.TextAlign.right),
        PdfReportColumn(title: l10n.averageCost, flex: 1.2, align: pw.TextAlign.right),
        PdfReportColumn(title: l10n.inventoryValuationAtCost, flex: 1.4, align: pw.TextAlign.right),
      ];
      rows = summary.items.map((i) {
        final valStr = i.valuationAtCost != null
            ? _numFmt.format(i.valuationAtCost)
            : (i.stockQuantity > 0 ? l10n.costUnknown : '—');
        final costStr = i.averageCost != null ? _numFmt.format(i.averageCost) : '—';
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
        warning = '${l10n.unresolvedCostProducts}: ${summary.unvaluedProductsCount} (${l10n.unvaluedStockQty}: ${FormatUtils.formatQuantity(summary.unvaluedQuantity)})';
      }
    }

    final data = PdfReportData(
      title: reportTitle,
      subtitle: _selectedCategory != null ? _selectedCategory! : l10n.allCategories,
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
        '${l10n.operationFailed}: $e',
        severity: AppSnackBarSeverity.error,
      );
    }
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
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              final val = double.tryParse(costController.text.trim());
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
    final summary = await InventoryCostingService.instance.getLegacyCostSummary();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.legacyCostSummaryTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _auditRow(l10n.costKnown, '${summary.knownMovements}', Colors.green),
            _auditRow(l10n.costReconstructed, '${summary.reconstructedMovements}', Colors.blue),
            _auditRow(l10n.costUnknown, '${summary.unknownMovements}', Colors.orange),
            const Divider(height: 24),
            _auditRow(l10n.valuedStockCount, '${summary.knownProducts}', Colors.teal),
            _auditRow(l10n.unresolvedCostProducts, '${summary.unknownProducts}', Colors.amber.shade800),
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
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
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

    return Scaffold(
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
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.printOrShareReport,
            onPressed: summary != null && summary.items.isNotEmpty ? _exportPdf : null,
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: l10n.legacyCostSummaryTitle,
            onPressed: _showLegacyAuditDialog,
          ),
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
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Status Selector Tabs
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.searchProductsHint,
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          filled: true,
                          fillColor: cs.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          _searchQuery = val;
                          _load();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Category Dropdown
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedCategory,
                          isExpanded: true,
                          hint: Text(l10n.allCategories, style: const TextStyle(fontSize: 12)),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(l10n.allCategories, style: const TextStyle(fontSize: 12)),
                            ),
                            ..._categories.map((c) => DropdownMenuItem<String?>(
                                  value: c,
                                  child: Text(c,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                )),
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
                      Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      l10n.unresolvedCostProducts,
                      '$unvaluedCount',
                      unvaluedCount > 0 ? Colors.amber.shade800 : Colors.grey,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Row(
                  children: [
                    _chip(l10n.trackedProducts, '$total', Colors.blue),
                    const SizedBox(width: 8),
                    _chip(l10n.lowStock, '$lowStock', Colors.orange),
                    const SizedBox(width: 8),
                    _chip(l10n.outOfStock, '$outOfStock', Theme.of(context).colorScheme.error),
                  ],
                ),
              ),
            ],

            Expanded(child: _buildList(context, l10n)),
          ],
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
            Text(label,
                style: TextStyle(fontSize: 10, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(l10n.operationFailed),
          const SizedBox(height: 10),
          FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
        ]),
      );
    }
    final items = _summary?.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _selectedStatus == 'low_stock'
                  ? l10n.noReplenishmentNeeded
                  : l10n.noReportData,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ]),
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
                ? Colors.orange
                : Colors.green;
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
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (p.category != null && p.category!.isNotEmpty)
                            Text(
                              p.category!,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          FormatUtils.formatQuantity(p.stockQuantity, unit: p.unit),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isOut ? Theme.of(context).colorScheme.error : null,
                          ),
                        ),
                        if (isLow) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.shortageQuantity}: ${FormatUtils.formatQuantity(item.shortageQuantity, unit: p.unit)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
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
                            : (p.stockQuantity > 0 ? '${l10n.costStatus}: ${l10n.costUnknown}' : ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasCost ? Colors.teal.shade700 : Colors.orange,
                          fontWeight: hasCost ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (statusLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.reconcileCost,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
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
        );
      },
    );
  }
}
