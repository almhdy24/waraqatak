import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/date_range_filter.dart';
import '../../services/business_reporting_service.dart';
import '../../services/feature_access.dart';
import '../../services/license_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../../utils/format_utils.dart';
import '../../widgets/app_status_colors.dart';
import '../../widgets/pro_upgrade_sheet.dart';
import '../../widgets/responsive.dart';
import 'report_date_filter.dart';

class AdvancedInventoryAnalyticsScreen extends StatefulWidget {
  const AdvancedInventoryAnalyticsScreen({super.key});

  @override
  State<AdvancedInventoryAnalyticsScreen> createState() =>
      _AdvancedInventoryAnalyticsScreenState();
}

class _AdvancedInventoryAnalyticsScreenState
    extends State<AdvancedInventoryAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  DateRangeFilter _range = DateRangeFilter.thisMonth();
  AdvancedInventoryMetrics? _metrics;
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkEntitlementAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkEntitlementAndLoad() async {
    final entitlement = await LicenseService.instance.checkEntitlement(force: true);
    if (!FeatureAccess.canAccess(Feature.advancedReports, entitlement)) {
      if (mounted) {
        await ProUpgradeSheet.show(context, feature: Feature.advancedReports);
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final catRows = await db.rawQuery(
        "SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != '' ORDER BY category ASC",
      );
      _categories = catRows.map((r) => r['category'] as String).toList();

      final metrics = await BusinessReportingService.instance
          .getAdvancedInventoryMetrics(
        from: _range.from,
        to: _range.to,
        category: _selectedCategory,
      );

      setState(() {
        _metrics = metrics;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_metrics == null) return;
    final l10n = AppLocalizations.of(context);
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null) return;

    final columns = [
      PdfReportColumn(title: l10n.product, flex: 2.2),
      PdfReportColumn(title: l10n.category, flex: 1.4),
      PdfReportColumn(title: l10n.stock, flex: 1.2, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.salesVelocity, flex: 1.4, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.estimatedDaysRemaining, flex: 1.4, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.reorderRecommendations, flex: 1.4, align: pw.TextAlign.right),
    ];

    final rows = _metrics!.velocityItems.map((item) {
      return <String>[
        item.product.name,
        item.product.category ?? '—',
        FormatUtils.formatQuantity(item.stockQuantity),
        item.salesVelocity.toStringAsFixed(2),
        item.estimatedDaysRemaining != null ? '~${item.estimatedDaysRemaining}' : '—',
        item.reorderSuggestion > 0 ? FormatUtils.formatQuantity(item.reorderSuggestion) : '—',
      ];
    }).toList();

    final data = PdfReportData(
      title: l10n.advancedInventoryAnalytics,
      dateRange: _range.label(l10n),
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.inventoryTurnover,
          value: _metrics!.inventoryTurnoverRatio.toStringAsFixed(2),
        ),
        PdfReportSummaryCard(
          label: l10n.tiedUpCapital,
          value: _numFmt.format(_metrics!.totalTiedUpCapitalInSlowMoving),
        ),
        PdfReportSummaryCard(
          label: l10n.reorderRecommendations,
          value: '${_metrics!.reorderCount}',
        ),
        PdfReportSummaryCard(
          label: l10n.negativeMarginAlert,
          value: '${_metrics!.negativeMarginCount}',
        ),
      ],
      columns: columns,
      rows: rows,
    );

    await PdfService.printOrShareReportPdf(data: data, business: business, l10n: l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.advancedInventoryAnalytics),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.printOrShareReport,
            onPressed: _metrics != null ? _exportPdf : null,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.salesVelocity),
            Tab(text: '${l10n.slowMovingStock} (${_metrics?.slowMovingCount ?? 0})'),
            Tab(text: '${l10n.negativeMarginAlert} (${_metrics?.negativeMarginCount ?? 0})'),
            Tab(text: l10n.categoryValuationShare),
          ],
        ),
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Date Filter
            ReportDateFilter(
              range: _range,
              onChanged: (newRange) {
                setState(() => _range = newRange);
                _load();
              },
            ),

            // Category Filter
            if (_categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(l10n.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<String?>(
                      value: _selectedCategory,
                      hint: Text(l10n.allCategories, style: const TextStyle(fontSize: 12)),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.allCategories, style: const TextStyle(fontSize: 12))),
                        ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCategory = val);
                        _load();
                      },
                    ),
                  ],
                ),
              ),

            // Key Metrics Summary Cards
            if (_metrics != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    _chip(l10n.inventoryTurnover, _metrics!.inventoryTurnoverRatio.toStringAsFixed(2), AppStatusColors.fg(context, AppStatus.info)),
                    const SizedBox(width: 8),
                    _chip(l10n.tiedUpCapital, _numFmt.format(_metrics!.totalTiedUpCapitalInSlowMoving), AppStatusColors.fg(context, AppStatus.warning)),
                    const SizedBox(width: 8),
                    _chip(l10n.reorderRecommendations, '${_metrics!.reorderCount}', AppStatusColors.fg(context, AppStatus.success)),
                    const SizedBox(width: 8),
                    _chip(l10n.negativeMarginAlert, '${_metrics!.negativeMarginCount}',
                        _metrics!.negativeMarginCount > 0 ? cs.error : cs.onSurfaceVariant),
                  ],
                ),
              ),
            ],

            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // 1. Sales Velocity & Reorder Suggestions
                            _buildVelocityTab(l10n, cs),

                            // 2. Slow-Moving Stock
                            _buildSlowMovingTab(l10n, cs),

                            // 3. Negative Margins
                            _buildNegativeMarginTab(l10n, cs),

                            // 4. Category Valuation Share
                            _buildCategoryShareTab(l10n, cs),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildVelocityTab(AppLocalizations l10n, ColorScheme cs) {
    final items = _metrics?.velocityItems ?? [];
    if (items.isEmpty) return Center(child: Text(l10n.noMatchingProduct));

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final it = items[idx];
        return ListTile(
          title: Text(it.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(
            '${l10n.stock}: ${FormatUtils.formatQuantity(it.stockQuantity)} • '
            '${l10n.salesVelocity}: ${it.salesVelocity.toStringAsFixed(2)}${l10n.perDaySuffix} • '
            '${l10n.estimatedDaysRemaining}: ${it.estimatedDaysRemaining != null ? l10n.daysRemainingCount(it.estimatedDaysRemaining!) : "—"}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: it.reorderSuggestion > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppStatusColors.bg(ctx, AppStatus.warning),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.reorderSuggestionTag(FormatUtils.formatQuantity(it.reorderSuggestion)),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppStatusColors.fg(ctx, AppStatus.warning)),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildSlowMovingTab(AppLocalizations l10n, ColorScheme cs) {
    final items = _metrics?.slowMovingItems ?? [];
    if (items.isEmpty) return Center(child: Text(l10n.noMatchingProduct));

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final it = items[idx];
        return ListTile(
          leading: Icon(Icons.hourglass_bottom_rounded, color: AppStatusColors.fg(ctx, AppStatus.warning)),
          title: Text(it.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(
            '${l10n.stock}: ${FormatUtils.formatQuantity(it.stockQuantity)} ${it.product.unit ?? ""} • '
            '${l10n.category}: ${it.product.category ?? "—"}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: it.valuation != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_numFmt.format(it.valuation),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppStatusColors.fg(ctx, AppStatus.warning))),
                    Text(l10n.tiedUpCapital, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _buildNegativeMarginTab(AppLocalizations l10n, ColorScheme cs) {
    final items = _metrics?.negativeMarginItems ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: AppStatusColors.fg(context, AppStatus.success)),
              const SizedBox(height: 8),
              Text(
                l10n.noProductsBelowCost,
                style: TextStyle(fontSize: 13, color: AppStatusColors.fg(context, AppStatus.success)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final p = items[idx];
        final avgCost = p.averageCost ?? 0.0;
        final loss = avgCost - p.salePrice;

        return ListTile(
          leading: Icon(Icons.warning_rounded, color: cs.error),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(
            '${l10n.sellingPrice}: ${_numFmt.format(p.salePrice)} | ${l10n.averageCost}: ${_numFmt.format(avgCost)}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text(
            l10n.lossAmount(_numFmt.format(loss)),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: cs.error),
          ),
        );
      },
    );
  }

  Widget _buildCategoryShareTab(AppLocalizations l10n, ColorScheme cs) {
    final items = _metrics?.categoryValuations ?? [];
    if (items.isEmpty) return Center(child: Text(l10n.noMatchingProduct));

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final cat = items[idx];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text(
              '${cat.sharePercentage.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
            ),
          ),
          title: Text(cat.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(
            '${cat.productCount} ${l10n.product}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text(
            _numFmt.format(cat.valuationAtCost),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        );
      },
    );
  }
}
