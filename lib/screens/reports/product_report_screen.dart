import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/date_range_filter.dart';
import '../../services/business_reporting_service.dart';
import '../../services/csv_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../../utils/format_utils.dart';
import '../stock_movements_screen.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_status_colors.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/report_export_menu.dart';
import '../../widgets/responsive.dart';
import 'report_date_filter.dart';
import 'reports_date_scope.dart';

class ProductReportScreen extends StatefulWidget {
  final int initialTab;
  const ProductReportScreen({super.key, this.initialTab = 0});

  @override
  State<ProductReportScreen> createState() => _ProductReportScreenState();
}

class _ProductReportScreenState extends State<ProductReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateRangeFilter _range = ReportsDateNotifier.instance.range;
  ProductPerformanceSummary? _summary;
  List<String> _categories = [];
  String? _selectedCategory;
  String _sortBy = 'revenue'; // 'revenue', 'quantity', 'profit'
  String? _error;
  bool _loading = true;
  int _querySeq = 0;

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_querySeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final business = await DatabaseHelper.instance.getFirstBusiness();
      final futures = await Future.wait([
        DatabaseHelper.instance.getProductCategories(),
        BusinessReportingService.instance.getProductPerformance(
          from: _range.from,
          to: _range.to,
          category: _selectedCategory,
          currencyCode: business?.currencyCode,
          sortBy: _sortBy,
        ),
      ]);
      if (!mounted || seq != _querySeq) return;
      setState(() {
        _categories = futures[0] as List<String>;
        _summary = futures[1] as ProductPerformanceSummary;
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
    final tabIndex = _tabController.index;

    String reportTitle;
    List<PdfReportColumn> columns;
    List<List<String>> rows;
    List<String>? totalsRow;
    String? warning;

    if (tabIndex == 0) {
      // Sales by Product
      reportTitle = l10n.salesByProduct;
      columns = [
        PdfReportColumn(title: l10n.product, flex: 2.2),
        PdfReportColumn(title: l10n.category, flex: 1.4),
        PdfReportColumn(
          title: l10n.salesQty,
          flex: 1.2,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.transactionCount,
          flex: 1.0,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.salesValue,
          flex: 1.5,
          align: pw.TextAlign.right,
        ),
      ];
      rows = summary.items.map((i) {
        return [
          i.productName,
          i.category ?? '—',
          FormatUtils.formatQuantity(i.salesQty, unit: i.unit),
          '${i.transactionCount}',
          _numFmt.format(i.salesRevenue),
        ];
      }).toList();
      totalsRow = [
        l10n.total,
        '',
        '',
        '',
        _numFmt.format(summary.totalSalesRevenue),
      ];
    } else if (tabIndex == 1) {
      // Profit by Product
      reportTitle = l10n.profitByProduct;
      columns = [
        PdfReportColumn(title: l10n.product, flex: 2.2),
        PdfReportColumn(
          title: l10n.salesValue,
          flex: 1.3,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(title: l10n.cogs, flex: 1.3, align: pw.TextAlign.right),
        PdfReportColumn(
          title: l10n.grossProfit,
          flex: 1.4,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.profitMargin,
          flex: 1.1,
          align: pw.TextAlign.right,
        ),
      ];
      rows = summary.items.map((i) {
        final marginStr = i.isCostReliable && i.salesRevenue > 0
            ? '${i.profitMargin.toStringAsFixed(1)}%'
            : '—';
        final profitStr = i.isCostReliable
            ? _numFmt.format(i.grossProfit)
            : '—';
        return [
          i.productName,
          _numFmt.format(i.salesRevenue),
          _numFmt.format(i.cogs),
          profitStr,
          marginStr,
        ];
      }).toList();
      totalsRow = [
        l10n.total,
        _numFmt.format(summary.totalSalesRevenue),
        _numFmt.format(summary.totalCogs),
        summary.hasIncompleteCosts
            ? '${_numFmt.format(summary.totalTrustedGrossProfit)}*'
            : _numFmt.format(summary.totalTrustedGrossProfit),
        '',
      ];
      warning = l10n.grossProfitNotice;
      if (summary.hasIncompleteCosts) {
        warning =
            '$warning\n${l10n.unknownCostNotice} ${l10n.unvaluedSalesNotice(summary.unvaluedSalesCount)}';
      }
      if (summary.hasMultipleCurrencies) {
        warning = '$warning\n${l10n.mixedCurrenciesNotice}';
      }
    } else {
      // Product Performance
      reportTitle = l10n.productPerformance;
      columns = [
        PdfReportColumn(title: l10n.product, flex: 2.0),
        PdfReportColumn(
          title: l10n.salesQty,
          flex: 1.1,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.salesValue,
          flex: 1.3,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.grossProfit,
          flex: 1.3,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.stockQuantity,
          flex: 1.1,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.inventoryValuationAtCost,
          flex: 1.3,
          align: pw.TextAlign.right,
        ),
      ];
      rows = summary.items.map((i) {
        final valStr = i.currentValuation != null
            ? _numFmt.format(i.currentValuation)
            : '—';
        final profitStr = i.isCostReliable
            ? _numFmt.format(i.grossProfit)
            : '—';
        return [
          i.productName,
          FormatUtils.formatQuantity(i.salesQty, unit: i.unit),
          _numFmt.format(i.salesRevenue),
          profitStr,
          FormatUtils.formatQuantity(i.currentStock, unit: i.unit),
          valStr,
        ];
      }).toList();
      totalsRow = [
        l10n.total,
        '',
        _numFmt.format(summary.totalSalesRevenue),
        summary.hasIncompleteCosts
            ? '${_numFmt.format(summary.totalTrustedGrossProfit)}*'
            : _numFmt.format(summary.totalTrustedGrossProfit),
        '',
        '',
      ];
      warning = l10n.grossProfitNotice;
      if (summary.hasIncompleteCosts) {
        warning = '$warning\n${l10n.unknownCostNotice}';
      }
      if (summary.hasMultipleCurrencies) {
        warning = '$warning\n${l10n.mixedCurrenciesNotice}';
      }
    }

    return PdfReportData(
      title: reportTitle,
      subtitle: _selectedCategory != null
          ? _selectedCategory!
          : l10n.allCategories,
      dateRange: _range.label(l10n),
      warningNotice: warning,
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.totalSales,
          value: _numFmt.format(summary.totalSalesRevenue),
        ),
        PdfReportSummaryCard(
          label: l10n.cogs,
          value: _numFmt.format(summary.totalCogs),
        ),
        PdfReportSummaryCard(
          label: l10n.grossProfit,
          value: summary.hasIncompleteCosts
              ? '${_numFmt.format(summary.totalTrustedGrossProfit)}*'
              : _numFmt.format(summary.totalTrustedGrossProfit),
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
        '${l10n.productReport} · ${_range.label(l10n)}\n'
        '${l10n.totalSales}: ${_numFmt.format(summary.totalSalesRevenue)}\n'
        '${l10n.grossProfit}: ${_numFmt.format(summary.totalTrustedGrossProfit)}';
    await PdfService.shareText(text: text);
  }

  Future<void> _exportCsv(AppLocalizations l10n) async {
    final summary = _summary;
    if (summary == null) return;
    final headers = [
      l10n.product,
      l10n.category,
      l10n.salesQty,
      l10n.salesValue,
      l10n.cogs,
      l10n.grossProfit,
      l10n.profitMargin,
    ];
    final csvRows = summary.items
        .map(
          (i) => [
            i.productName,
            i.category ?? '',
            i.salesQty,
            i.salesRevenue,
            i.cogs,
            i.isCostReliable ? i.grossProfit : '',
            i.isCostReliable && i.salesRevenue > 0 ? i.profitMargin : '',
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
            'product_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
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
      title: l10n.productReport,
      onPrintPdf: () => _exportPdf(isShare: false),
      onSharePdf: () => _exportPdf(isShare: true),
      onShareWhatsApp: () => _shareWhatsApp(l10n),
      onExportCsv: () => _exportCsv(l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final summary = _summary;

    final totalSalesValue = summary?.totalSalesRevenue ?? 0.0;
    final totalCogs = summary?.totalCogs ?? 0.0;
    final totalProfit = summary?.totalTrustedGrossProfit ?? 0.0;
    final hasUnknownCost = summary?.hasIncompleteCosts ?? false;

    return ScreenAccessGate(
      screenType: ProductReportScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.productReport),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: l10n.printOrShareReport,
              onPressed:
                  summary != null &&
                      summary.items.isNotEmpty &&
                      ReportExportMenu.canExport()
                  ? () => _openExportMenu(context, l10n)
                  : null,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.salesByProduct),
              Tab(text: l10n.profitByProduct),
              Tab(text: l10n.productPerformance),
            ],
          ),
        ),
        body: ResponsiveCenter(
          child: Column(
            children: [
              // Date Filter
              ReportDateFilter(
                range: _range,
                onChanged: (r) {
                  setState(() => _range = r);
                  ReportsDateScope.update(context, r);
                  _load();
                },
              ),

              // Category Filter & Sort Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Row(
                  children: [
                    // Category Dropdown
                    Expanded(
                      flex: 3,
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
                    const SizedBox(width: 8),

                    // Sort By Dropdown
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
                          child: DropdownButton<String>(
                            value: _sortBy,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                value: 'revenue',
                                child: Text(
                                  l10n.sortByRevenue,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'quantity',
                                child: Text(
                                  l10n.sortByQuantity,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'profit',
                                child: Text(
                                  l10n.sortByProfit,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _sortBy = val);
                                _load();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Chips
              if (summary != null && summary.items.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    children: [
                      _chip(
                        l10n.totalSales,
                        totalSalesValue,
                        AppStatusColors.fg(context, AppStatus.success),
                      ),
                      const SizedBox(width: 8),
                      _chip(l10n.cogs, totalCogs, cs.secondary),
                      const SizedBox(width: 8),
                      _chip(
                        l10n.grossProfit,
                        totalProfit,
                        AppStatusColors.fg(context, AppStatus.success),
                      ),
                    ],
                  ),
                ),
                if (hasUnknownCost)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 13,
                          color: AppStatusColors.fg(context, AppStatus.warning),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l10n.costIncomplete,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppStatusColors.fg(
                                context,
                                AppStatus.warning,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (summary.hasMultipleCurrencies)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 13,
                          color: AppStatusColors.fg(context, AppStatus.warning),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l10n.mixedCurrenciesNotice,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppStatusColors.fg(
                                context,
                                AppStatus.warning,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              // Active Tab Content List
              Expanded(child: _buildList(context, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, double value, Color color) {
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
            Text(label, style: TextStyle(fontSize: 10, color: color)),
            Text(
              _numFmt.format(value),
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
                Icons.inventory_2_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noDataForPeriod,
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

    final activeTab = _tabController.index;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: items.length,
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemBuilder: (ctx, i) {
          final item = items[i];

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
              onTap: () async {
                final p = await DatabaseHelper.instance.getProductById(
                  item.productId,
                );
                if (p != null && ctx.mounted) {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => StockMovementsScreen(initialProduct: p),
                    ),
                  ).then((_) => _load());
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                                item.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.category != null &&
                                  item.category!.isNotEmpty)
                                Text(
                                  item.category!,
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
                        if (item.salesQty > 0 && !item.isCostReliable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: AppStatusColors.bg(
                                context,
                                AppStatus.warning,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppStatusColors.border(
                                  context,
                                  AppStatus.warning,
                                ),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              l10n.costIncomplete,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppStatusColors.fg(
                                  context,
                                  AppStatus.warning,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          '${l10n.stockStatus}: ${FormatUtils.formatQuantity(item.currentStock, unit: item.unit)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Metrics based on active tab
                    if (activeTab == 0) ...[
                      // Sales by Product Tab
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _statCell(
                            l10n.salesQty,
                            FormatUtils.formatQuantity(
                              item.salesQty,
                              unit: item.unit,
                            ),
                            AppStatusColors.fg(context, AppStatus.success),
                          ),
                          _statCell(
                            l10n.salesValue,
                            _numFmt.format(item.salesRevenue),
                            AppStatusColors.fg(context, AppStatus.success),
                          ),
                          _statCell(
                            l10n.transactionCount,
                            '${item.transactionCount}',
                            AppStatusColors.fg(context, AppStatus.info),
                          ),
                        ],
                      ),
                    ] else if (activeTab == 1) ...[
                      // Profit by Product Tab
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _statCell(
                            l10n.salesValue,
                            _numFmt.format(item.salesRevenue),
                            AppStatusColors.fg(context, AppStatus.success),
                          ),
                          _statCell(
                            l10n.cogs,
                            _numFmt.format(item.cogs),
                            Theme.of(context).colorScheme.secondary,
                          ),
                          _statCell(
                            l10n.grossProfit,
                            item.isCostReliable
                                ? _numFmt.format(item.grossProfit)
                                : '—',
                            (item.isCostReliable && item.grossProfit >= 0)
                                ? AppStatusColors.fg(context, AppStatus.success)
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          _statCell(
                            l10n.profitMargin,
                            item.isCostReliable && item.salesRevenue > 0
                                ? '${item.profitMargin.toStringAsFixed(1)}%'
                                : '—',
                            AppStatusColors.fg(context, AppStatus.info),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Product Performance Tab
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _statCell(
                            l10n.salesQty,
                            FormatUtils.formatQuantity(
                              item.salesQty,
                              unit: item.unit,
                            ),
                            AppStatusColors.fg(context, AppStatus.success),
                          ),
                          _statCell(
                            l10n.salesValue,
                            _numFmt.format(item.salesRevenue),
                            AppStatusColors.fg(context, AppStatus.success),
                          ),
                          _statCell(
                            l10n.grossProfit,
                            item.isCostReliable
                                ? _numFmt.format(item.grossProfit)
                                : '—',
                            (item.isCostReliable && item.grossProfit >= 0)
                                ? AppStatusColors.fg(context, AppStatus.success)
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          if (item.currentValuation != null)
                            _statCell(
                              l10n.inventoryValuationAtCost,
                              _numFmt.format(item.currentValuation),
                              AppStatusColors.fg(context, AppStatus.success),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statCell(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
