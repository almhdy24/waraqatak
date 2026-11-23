import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/currency.dart';
import '../../services/csv_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../customer_detail_screen.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/app_design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_loading_view.dart';
import '../../widgets/app_metric_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_status_colors.dart';
import '../../widgets/report_export_menu.dart';
import '../../widgets/responsive.dart';

class SupplierReportScreen extends StatefulWidget {
  const SupplierReportScreen({super.key});

  static List<String> buildPdfRow(Map<String, dynamic> r, NumberFormat numFmt) {
    return [
      r['name'] as String? ?? '—',
      r['phone'] as String? ?? '—',
      numFmt.format(((r['total_amount'] ?? r['total'] ?? 0) as num).toDouble()),
      numFmt.format(((r['total_paid'] ?? r['paid'] ?? 0) as num).toDouble()),
      numFmt.format(((r['outstanding'] ?? 0) as num).toDouble()),
    ];
  }

  static List<String> buildTotalsRow({
    required double totalAmount,
    required double totalPaid,
    required double totalPayable,
    required String totalLabel,
    required NumberFormat numFmt,
  }) {
    return [
      totalLabel,
      '',
      numFmt.format(totalAmount),
      numFmt.format(totalPaid),
      numFmt.format(totalPayable),
    ];
  }

  @override
  State<SupplierReportScreen> createState() => _SupplierReportScreenState();
}

class _SupplierReportScreenState extends State<SupplierReportScreen> {
  List<Map<String, dynamic>>? _allRows;
  List<Map<String, dynamic>>? _filteredRows;
  bool _hasLegacyForeign = false;
  String? _error;
  String _currencySymbol = '';

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _querySeq = 0;
  bool _sortByName = false;

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_querySeq;
    setState(() {
      _allRows = null;
      _filteredRows = null;
      _error = null;
    });
    try {
      final business = await DatabaseHelper.instance.getFirstBusiness();
      final currency = business?.currencyCode ?? 'SDG';
      final symbol = Currency.symbolForCode(currency);

      final results = await Future.wait([
        DatabaseHelper.instance.getContactBalances(
          'supplier',
          'purchase',
          currencyCode: currency,
        ),
        DatabaseHelper.instance.getContactBalances('supplier', 'purchase'),
      ]);

      if (!mounted || seq != _querySeq) return;

      final rows = results[0];
      final allUnfiltered = results[1];
      final hasForeign = allUnfiltered.any((r) {
        final c = (r['currency_code'] as String?)?.trim();
        return c != null && c.isNotEmpty && c != currency;
      });

      setState(() {
        _currencySymbol = symbol;
        _allRows = rows;
        _hasLegacyForeign = hasForeign;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted || seq != _querySeq) return;
      setState(() => _error = e.toString());
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _applyFilter());
      }
    });
  }

  void _applyFilter() {
    if (_allRows == null) return;
    final query = _searchController.text.trim().toLowerCase();
    var list = _allRows!;
    if (query.isNotEmpty) {
      list = list.where((r) {
        final name = (r['name'] as String? ?? '').toLowerCase();
        final phone = (r['phone'] as String? ?? '').toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    }
    if (_sortByName) {
      list = List.of(list)
        ..sort(
          (a, b) => (a['name'] as String? ?? '').compareTo(
            b['name'] as String? ?? '',
          ),
        );
    } else {
      list = List.of(list)
        ..sort(
          (a, b) => ((b['outstanding'] ?? 0) as num).compareTo(
            (a['outstanding'] ?? 0) as num,
          ),
        );
    }
    _filteredRows = list;
  }

  PdfReportData _buildPdfData(AppLocalizations l10n) {
    final rows = _filteredRows ?? _allRows ?? [];
    final totalAmount = rows.fold(
      0.0,
      (s, r) => s + ((r['total_amount'] ?? r['total'] ?? 0) as num).toDouble(),
    );
    final totalPaid = rows.fold(
      0.0,
      (s, r) => s + ((r['total_paid'] ?? r['paid'] ?? 0) as num).toDouble(),
    );
    final totalPayable = rows.fold(
      0.0,
      (s, r) => s + ((r['outstanding'] ?? 0) as num).toDouble(),
    );

    final columns = [
      PdfReportColumn(title: l10n.supplier, flex: 2.2),
      PdfReportColumn(title: l10n.phone, flex: 1.5),
      PdfReportColumn(title: l10n.total, flex: 1.3, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.paid, flex: 1.3, align: pw.TextAlign.right),
      PdfReportColumn(
        title: l10n.remaining,
        flex: 1.3,
        align: pw.TextAlign.right,
      ),
    ];

    final pdfRows = rows
        .map((r) => SupplierReportScreen.buildPdfRow(r, _numFmt))
        .toList();

    return PdfReportData(
      title: l10n.supplierReport,
      dateRange: DateFormat('dd/MM/yyyy').format(DateTime.now()),
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.totalOutstanding,
          value: '${_numFmt.format(totalPayable)} $_currencySymbol',
        ),
      ],
      columns: columns,
      rows: pdfRows,
      totalsRow: SupplierReportScreen.buildTotalsRow(
        totalAmount: totalAmount,
        totalPaid: totalPaid,
        totalPayable: totalPayable,
        totalLabel: l10n.total,
        numFmt: _numFmt,
      ),
    );
  }

  Future<void> _exportPdf({required bool isShare}) async {
    final l10n = AppLocalizations.of(context);
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null || _filteredRows == null) return;
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

  Future<void> _shareWhatsApp(
    AppLocalizations l10n,
    double totalPayable,
  ) async {
    final text =
        '${l10n.supplierReport}\n'
        '${l10n.totalOutstanding}: ${_numFmt.format(totalPayable)} $_currencySymbol';
    await PdfService.shareText(text: text);
  }

  Future<void> _exportCsv(AppLocalizations l10n) async {
    final rows = _filteredRows ?? _allRows;
    if (rows == null) return;
    final headers = [
      l10n.supplier,
      l10n.phone,
      l10n.total,
      l10n.paid,
      l10n.remaining,
    ];
    final csvRows = rows
        .map(
          (r) => [
            r['name'] as String? ?? '',
            r['phone'] as String? ?? '',
            (r['total_amount'] ?? r['total'] ?? 0) as num,
            (r['total_paid'] ?? r['paid'] ?? 0) as num,
            (r['outstanding'] ?? 0) as num,
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
            'supplier_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
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

  void _openExportMenu(
    BuildContext context,
    AppLocalizations l10n,
    double totalPayable,
  ) {
    ReportExportMenu.show(
      context: context,
      title: l10n.supplierReport,
      onPrintPdf: () => _exportPdf(isShare: false),
      onSharePdf: () => _exportPdf(isShare: true),
      onShareWhatsApp: () => _shareWhatsApp(l10n, totalPayable),
      onExportCsv: () => _exportCsv(l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final totalPayable =
        _allRows?.fold(
          0.0,
          (s, r) => s + (r['outstanding'] as num).toDouble(),
        ) ??
        0.0;

    return ScreenAccessGate(
      screenType: SupplierReportScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.supplierReport),
          centerTitle: true,
          actions: [
            if (ReportExportMenu.canExport())
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.exportOptions,
                onPressed: _allRows != null && _allRows!.isNotEmpty
                    ? () => _openExportMenu(context, l10n, totalPayable)
                    : null,
              ),
          ],
        ),
        body: ResponsiveCenter(
          child: Column(
            children: [
              if (_allRows != null && _allRows!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: AppMetricCard(
                    title: l10n.totalOutstanding,
                    value: '${_numFmt.format(totalPayable)} $_currencySymbol',
                    icon: Icons.store_outlined,
                    color: AppStatusColors.fg(context, AppStatus.warning),
                    compact: true,
                  ),
                ),
                if (_hasLegacyForeign)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.legacyForeignDocumentsNotice,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Search & Sort Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: l10n.searchSupplier,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _applyFilter());
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _sortByName
                              ? Icons.sort_by_alpha
                              : Icons.format_list_numbered,
                          size: 20,
                        ),
                        tooltip: _sortByName
                            ? l10n.sortByName
                            : l10n.sortByRemaining,
                        onPressed: () {
                          setState(() {
                            _sortByName = !_sortByName;
                            _applyFilter();
                          });
                        },
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

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_allRows == null) return const AppLoadingView();
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    final cs = Theme.of(context).colorScheme;
    if (_allRows!.isEmpty) {
      return AppEmptyState(
        icon: Icons.store_outlined,
        title: l10n.noReportData,
      );
    }
    if (_filteredRows!.isEmpty) {
      return AppEmptyState(icon: Icons.search_off, title: l10n.noSearchResults);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _filteredRows!.length,
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemBuilder: (ctx, i) {
          final row = _filteredRows![i];
          final outstanding = (row['outstanding'] as num).toDouble();
          final total = (row['total_amount'] as num).toDouble();
          final docCount = row['doc_count'] as int;
          final hasDebt = outstanding > 0;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      row['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (hasDebt)
                    Text(
                      _numFmt.format(outstanding),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppStatusColors.fg(context, AppStatus.warning),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                '${l10n.purchaseCount}: $docCount · ${l10n.totalPurchasesAmt}: ${_numFmt.format(total)}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              trailing: hasDebt
                  ? null
                  : Icon(
                      Icons.check_circle_outline,
                      color: AppStatusColors.fg(context, AppStatus.success),
                      size: 18,
                    ),
              onTap: () async {
                final contactId = row['contact_id'] as int;
                final contact = await DatabaseHelper.instance.getContactById(
                  contactId,
                );
                if (contact == null || !ctx.mounted) return;
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailScreen(contact: contact),
                  ),
                ).then((_) => _load());
              },
            ),
          );
        },
      ),
    );
  }
}
