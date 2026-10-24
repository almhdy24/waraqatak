import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/widgets.dart' as pw;
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/date_range_filter.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../services/business_reporting_service.dart';
import '../services/pdf/pdf_report_builder.dart';
import '../services/pdf_service.dart';
import '../utils/format_utils.dart';
import '../widgets/responsive.dart';
import 'document_detail_screen.dart';
import 'reports/report_date_filter.dart';

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

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = await Future.wait([
        DatabaseHelper.instance.getAllProducts(type: 'product'),
        BusinessReportingService.instance.getStockMovementsReport(
          productId: _selectedProduct?.id,
          type: _selectedType,
          from: _range.from,
          to: _range.to,
          limit: 300,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _allProducts = futures[0] as List<Product>;
        _reportSummary = futures[1] as StockMovementReportSummary;
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
    if (business == null || _reportSummary == null) return;

    final columns = [
      PdfReportColumn(title: l10n.date, flex: 1.4),
      PdfReportColumn(title: l10n.product, flex: 2.2),
      PdfReportColumn(title: l10n.type, flex: 1.2),
      PdfReportColumn(title: l10n.quantity, flex: 1.2, align: pw.TextAlign.right),
      if (_selectedProduct != null)
        PdfReportColumn(title: l10n.balanceAfter, flex: 1.2, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.averageCost, flex: 1.2, align: pw.TextAlign.right),
    ];

    final rows = _reportSummary!.items.map((item) {
      final m = item.movement;
      final sign = m.quantity > 0 ? '+' : (m.quantity < 0 ? '-' : '');
      final costStr = m.unitCost != null
          ? _numFmt.format(m.unitCost)
          : (m.costStatus == StockMovement.costStatusUnknown ? '—' : l10n.costReconstructed);

      return [
        _dateFmt.format(m.date),
        m.productName ?? '—',
        _typeLabel(m.type, l10n),
        '$sign${FormatUtils.formatQuantity(m.quantity.abs())}',
        if (_selectedProduct != null)
          item.balanceAfter != null ? FormatUtils.formatQuantity(item.balanceAfter!) : '—',
        costStr,
      ];
    }).toList();

    final data = PdfReportData(
      title: l10n.stockMovementsReport,
      subtitle: _selectedProduct != null ? _selectedProduct!.name : l10n.allProducts,
      dateRange: _range.label(l10n),
      warningNotice: _reportSummary!.unvaluedMovementsCount > 0
          ? l10n.unknownCostNotice
          : null,
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.totalStockIn,
          value: '+${FormatUtils.formatQuantity(_reportSummary!.totalInQuantity)}',
        ),
        PdfReportSummaryCard(
          label: l10n.totalStockOut,
          value: '-${FormatUtils.formatQuantity(_reportSummary!.totalOutQuantity)}',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.operationFailed}: $e')),
      );
    }
  }

  String _typeLabel(String type, AppLocalizations l10n) => switch (type) {
        StockMovement.typeOpening => l10n.openingStock,
        StockMovement.typePurchase => l10n.purchase,
        StockMovement.typeSale => l10n.invoice,
        StockMovement.typeAdjustment => l10n.stockAdjustment,
        StockMovement.typeCancellation => l10n.cancelledCount,
        _ => type,
      };

  Color _typeColor(String type, ColorScheme cs) => switch (type) {
        StockMovement.typeOpening => Colors.blue,
        StockMovement.typePurchase => Colors.teal,
        StockMovement.typeSale => Colors.indigo,
        StockMovement.typeAdjustment => Colors.amber.shade800,
        StockMovement.typeCancellation => cs.error,
        _ => Colors.grey,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stockMovementsReport),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.printOrShareReport,
            onPressed: _reportSummary != null && _reportSummary!.items.isNotEmpty
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
                setState(() => _range = r);
                _load();
              },
            ),

            // Product Filter Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedProduct?.id,
                          isExpanded: true,
                          hint: Text(l10n.allProducts, style: const TextStyle(fontSize: 13)),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(l10n.allProducts, style: const TextStyle(fontSize: 13)),
                            ),
                            ..._allProducts.map((p) => DropdownMenuItem<int?>(
                                  value: p.id,
                                  child: Text(p.name,
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (id) {
                            setState(() {
                              _selectedProduct =
                                  id == null ? null : _allProducts.where((p) => p.id == id).firstOrNull;
                            });
                            _load();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
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
                  _typeChip(l10n.invoice, StockMovement.typeSale),
                  const SizedBox(width: 6),
                  _typeChip(l10n.stockAdjustment, StockMovement.typeAdjustment),
                  const SizedBox(width: 6),
                  _typeChip(l10n.openingStock, StockMovement.typeOpening),
                  const SizedBox(width: 6),
                  _typeChip(l10n.cancelledCount, StockMovement.typeCancellation),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Summary Bar
            if (_reportSummary != null && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_downward, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.totalStockIn,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    '+${FormatUtils.formatQuantity(_reportSummary!.totalInQuantity)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
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
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_upward, size: 16, color: Colors.red),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.totalStockOut,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    '-${FormatUtils.formatQuantity(_reportSummary!.totalOutQuantity)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),

            // Movements List
            Expanded(
              child: _buildBody(context, l10n, cs),
            ),
          ],
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
        setState(() => _selectedType = type);
        _load();
      },
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n, ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
    final items = _reportSummary?.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(l10n.noMovements,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 40),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final m = item.movement;
          final isIn = m.quantity > 0;
          final color = isIn ? Colors.green : (m.quantity < 0 ? Colors.red : Colors.grey);
          final typeBadgeColor = _typeColor(m.type, cs);
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
                      child: Icon(_typeIcon(m.type), color: typeBadgeColor, size: 20),
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
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
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
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          if (m.notes != null && m.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              m.notes!,
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
                                            m.referenceDocumentNumber!.isNotEmpty
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
                                    color: Colors.blueGrey.shade700,
                                  ),
                                ),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    '${FormatUtils.formatQuantity(item.balanceBefore!)} → ${FormatUtils.formatQuantity(item.balanceAfter!)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blueGrey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Cost info
                          if (m.unitCost != null &&
                              m.costStatus == StockMovement.costStatusKnown) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.averageCost}: ${_numFmt.format(m.unitCost)} | ${l10n.totalCost}: ${_numFmt.format(m.totalCost)}',
                              style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                            ),
                          ] else if (m.costStatus == StockMovement.costStatusReconstructed) ...[
                            const SizedBox(height: 4),
                            Text(
                              l10n.costReconstructed,
                              style: const TextStyle(fontSize: 10, color: Colors.blue),
                            ),
                          ] else if (m.costStatus == StockMovement.costStatusUnknown &&
                              m.type != StockMovement.typeOpening) ...[
                            const SizedBox(height: 4),
                            Text(
                              l10n.costUnknown,
                              style: const TextStyle(fontSize: 10, color: Colors.orange),
                            ),
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
      'receipt' => l10n.paymentReceipt,
      _ => l10n.documents,
    };
  }
}
