import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../services/business_reporting_service.dart';
import '../../services/csv_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../../utils/format_utils.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/app_design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_loading_view.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_status_colors.dart';
import '../../widgets/report_export_menu.dart';
import '../../widgets/responsive.dart';
import '../stock_movements_screen.dart';

/// Dedicated Low Stock Report screen for replenishment and inventory monitoring.
/// Does NOT display item cost or valuation, permitting access to staff with [PermissionRegistry.productsView].
class LowStockReportScreen extends StatefulWidget {
  final String initialStatus;
  const LowStockReportScreen({super.key, this.initialStatus = 'low_stock'});

  @override
  State<LowStockReportScreen> createState() => _LowStockReportScreenState();
}

class _LowStockReportScreenState extends State<LowStockReportScreen> {
  late String _selectedStatus;
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _querySeq = 0;
  String? _searchQuery;

  bool _loading = true;
  String? _error;
  List<String> _categories = [];
  InventoryReportSummary? _summary;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
    _load();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = val.trim());
      _load();
    });
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
    final reportTitle = _selectedStatus == 'out_of_stock'
        ? l10n.outOfStockReport
        : l10n.lowStockReport;

    final columns = [
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

    final rows = summary.items.map((i) {
      return [
        i.product.name,
        i.product.category ?? '—',
        FormatUtils.formatQuantity(i.stockQuantity, unit: i.product.unit),
        FormatUtils.formatQuantity(i.minStock, unit: i.product.unit),
        FormatUtils.formatQuantity(i.shortageQuantity, unit: i.product.unit),
      ];
    }).toList();

    return PdfReportData(
      title: reportTitle,
      subtitle: _selectedCategory ?? l10n.allCategories,
      dateRange: DateFormat('dd/MM/yyyy').format(DateTime.now()),
      columns: columns,
      rows: rows,
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.lowStock,
          value: '${summary.lowStockCount}',
        ),
        PdfReportSummaryCard(
          label: l10n.outOfStock,
          value: '${summary.outOfStockCount}',
        ),
      ],
    );
  }

  void _openExportMenu(BuildContext context, AppLocalizations l10n) {
    final summary = _summary;
    if (summary == null || summary.items.isEmpty) return;

    ReportExportMenu.show(
      context: context,
      title: l10n.lowStockReport,
      onPrintPdf: () async {
        final business = await DatabaseHelper.instance.getFirstBusiness();
        if (business == null) return;
        final pdfData = _buildPdfData(l10n);
        await PdfService.printOrShareReportPdf(
          business: business,
          l10n: l10n,
          data: pdfData,
        );
      },
      onSharePdf: () async {
        final business = await DatabaseHelper.instance.getFirstBusiness();
        if (business == null) return;
        final pdfData = _buildPdfData(l10n);
        await PdfService.shareReportPdf(
          business: business,
          l10n: l10n,
          data: pdfData,
        );
      },
      onShareWhatsApp: () async {
        final buffer = StringBuffer();
        buffer.writeln('*${l10n.lowStockReport}*');
        buffer.writeln('${l10n.total}: ${summary.items.length}');
        buffer.writeln('--------------------');
        for (final item in summary.items.take(30)) {
          final unit = item.product.unit ?? '';
          buffer.writeln(
            '• ${item.product.name}: ${l10n.stockQuantity} ${item.stockQuantity} $unit '
            '(${l10n.minStock}: ${item.minStock}, ${l10n.shortageQuantity}: ${item.shortageQuantity})',
          );
        }
        if (summary.items.length > 30) {
          buffer.writeln('... +${summary.items.length - 30}');
        }
        await PdfService.shareText(text: buffer.toString());
      },
      onExportCsv: () async {
        final headers = [
          l10n.product,
          l10n.category,
          l10n.stockQuantity,
          l10n.minStock,
          l10n.shortageQuantity,
          l10n.unit,
        ];
        final rows = summary.items.map((i) {
          return [
            i.product.name,
            i.product.category ?? '',
            i.stockQuantity,
            i.minStock,
            i.shortageQuantity,
            i.product.unit ?? '',
          ];
        }).toList();

        try {
          final bytes = CsvService.instance.exportReportToCsv(
            headers: headers,
            rows: rows,
          );
          await PdfService.shareCsv(
            bytes: bytes,
            fileName:
                'low_stock_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
          );
        } catch (e) {
          if (context.mounted) {
            AppSnackBar.show(
              context,
              '${l10n.operationFailed}: $e',
              severity: AppSnackBarSeverity.error,
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = _summary;
    final lowStock = summary?.lowStockCount ?? 0;
    final outOfStock = summary?.outOfStockCount ?? 0;

    return ScreenAccessGate(
      screenType: LowStockReportScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedStatus == 'out_of_stock'
                ? l10n.outOfStockReport
                : l10n.lowStockReport,
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: l10n.printOrShareReport,
              onPressed: summary != null && summary.items.isNotEmpty
                  ? () => _openExportMenu(context, l10n)
                  : null,
            ),
          ],
        ),
        body: ResponsiveCenter(
          child: Column(
            children: [
              // Status selector chips: Low Stock vs Out of Stock
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  children: [
                    _statusChip(l10n.lowStock, 'low_stock'),
                    const SizedBox(width: 8),
                    _statusChip(l10n.outOfStock, 'out_of_stock'),
                  ],
                ),
              ),

              // Search bar and category dropdown
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: l10n.searchProductsHint,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignTokens.smallRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String?>(
                      value: _selectedCategory,
                      hint: Text(l10n.allCategories),
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.allCategories),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c,
                            child: Text(c),
                          ),
                        ),
                      ],
                      onChanged: (cat) {
                        setState(() => _selectedCategory = cat);
                        _load();
                      },
                    ),
                  ],
                ),
              ),

              // Summary KPI chips
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    _kpiChip(
                      l10n.lowStock,
                      '$lowStock',
                      AppStatusColors.fg(context, AppStatus.warning),
                    ),
                    const SizedBox(width: 8),
                    _kpiChip(
                      l10n.outOfStock,
                      '$outOfStock',
                      Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
              ),

              Expanded(child: _buildBody(context, l10n)),
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

  Widget _kpiChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDesignTokens.smallRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loading) return const AppLoadingView();
    if (_error != null) {
      return AppErrorState(
        title: l10n.operationFailed,
        message: _error!,
        onRetry: _load,
      );
    }
    final items = _summary?.items ?? [];
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 350,
            child: AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: l10n.noReplenishmentNeeded,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: items.length,
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemBuilder: (ctx, i) {
          final item = items[i];
          final p = item.product;
          final isOut = item.isOutOfStock;
          final statusColor = isOut
              ? Theme.of(context).colorScheme.error
              : AppStatusColors.fg(context, AppStatus.warning);
          final statusLabel = isOut ? l10n.outOfStock : l10n.lowStock;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.smallRadius),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDesignTokens.smallRadius),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockMovementsScreen(initialProduct: p),
                ),
              ).then((_) => _load()),
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
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
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
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (p.category != null && p.category!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          p.category!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l10n.stockQuantity}: ${FormatUtils.formatQuantity(item.stockQuantity, unit: p.unit)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${l10n.minStock}: ${FormatUtils.formatQuantity(item.minStock, unit: p.unit)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${l10n.shortageQuantity}: ${FormatUtils.formatQuantity(item.shortageQuantity, unit: p.unit)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.error,
                            ),
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
}
