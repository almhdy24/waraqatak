import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../models/currency.dart';
import '../../models/date_range_filter.dart';
import '../../services/business_reporting_service.dart';
import '../../services/csv_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
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
import '../document_detail_screen.dart';
import 'report_date_filter.dart';
import 'reports_date_scope.dart';

class TaxDiscountReportScreen extends StatefulWidget {
  const TaxDiscountReportScreen({super.key});

  @override
  State<TaxDiscountReportScreen> createState() =>
      _TaxDiscountReportScreenState();
}

class _TaxDiscountReportScreenState extends State<TaxDiscountReportScreen> {
  DateRangeFilter _range = ReportsDateNotifier.instance.range;
  TaxDiscountSummary? _summary;
  Business? _business;
  String? _error;
  bool _loading = true;

  static final _numFmt = NumberFormat('#,##0.##');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        BusinessReportingService.instance.getTaxDiscountSummary(
          from: _range.from,
          to: _range.to,
        ),
        DatabaseHelper.instance.getFirstBusiness(),
      ]);

      if (!mounted) return;
      setState(() {
        _summary = results[0] as TaxDiscountSummary;
        _business = results[1] as Business?;
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

  PdfReportData _buildPdfData(AppLocalizations l10n, Business business) {
    final s = _summary!;
    final sym = Currency.symbolForCode(s.currencyCode);

    final columns = [
      PdfReportColumn(title: l10n.documentNumber, flex: 2.0),
      PdfReportColumn(title: l10n.date, flex: 1.5),
      PdfReportColumn(title: l10n.type, flex: 1.2),
      PdfReportColumn(title: l10n.tax, flex: 1.5, align: pw.TextAlign.right),
      PdfReportColumn(
        title: l10n.discount,
        flex: 1.5,
        align: pw.TextAlign.right,
      ),
      PdfReportColumn(title: l10n.total, flex: 1.8, align: pw.TextAlign.right),
    ];

    final rows = s.documents.map((d) {
      final isInvoice = d.type == 'invoice';
      return [
        d.documentNumber,
        _dateFmt.format(d.date),
        isInvoice ? l10n.invoice : l10n.purchase,
        '${_numFmt.format(d.taxAmount)} $sym',
        '${_numFmt.format(d.discount)} $sym',
        '${_numFmt.format(d.total)} $sym',
      ];
    }).toList();

    return PdfReportData(
      title: l10n.taxDiscountReport,
      dateRange: _range.label(l10n),
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.taxCollected,
          value: '${_numFmt.format(s.salesTaxCollected)} $sym',
        ),
        PdfReportSummaryCard(
          label: l10n.taxPaid,
          value: '${_numFmt.format(s.purchaseTaxPaid)} $sym',
        ),
        PdfReportSummaryCard(
          label: l10n.netTax,
          value: '${_numFmt.format(s.netTax)} $sym',
        ),
        PdfReportSummaryCard(
          label: l10n.discountsGiven,
          value: '${_numFmt.format(s.salesDiscountsGiven)} $sym',
        ),
        PdfReportSummaryCard(
          label: l10n.discountsReceived,
          value: '${_numFmt.format(s.purchaseDiscountsReceived)} $sym',
        ),
        PdfReportSummaryCard(
          label: l10n.netDiscounts,
          value: '${_numFmt.format(s.netDiscounts)} $sym',
        ),
      ],
      columns: columns,
      rows: rows,
    );
  }

  Future<void> _exportPdf({
    required bool isShare,
    PdfPageFormat? pageFormat,
  }) async {
    final l10n = AppLocalizations.of(context);
    final business = _business;
    if (business == null || _summary == null) return;
    final data = _buildPdfData(l10n, business);

    try {
      if (isShare) {
        await PdfService.shareReportPdf(
          business: business,
          l10n: l10n,
          data: data,
          pageFormat: pageFormat,
        );
      } else {
        await PdfService.printOrShareReportPdf(
          business: business,
          l10n: l10n,
          data: data,
          pageFormat: pageFormat,
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
    final s = _summary;
    if (s == null) return;
    final sym = Currency.symbolForCode(s.currencyCode);
    final text =
        '${l10n.taxDiscountReport} (${_range.label(l10n)})\n'
        '------------------------\n'
        '${l10n.taxCollected}: ${_numFmt.format(s.salesTaxCollected)} $sym\n'
        '${l10n.taxPaid}: ${_numFmt.format(s.purchaseTaxPaid)} $sym\n'
        '${l10n.netTax}: ${_numFmt.format(s.netTax)} $sym\n'
        '------------------------\n'
        '${l10n.discountsGiven}: ${_numFmt.format(s.salesDiscountsGiven)} $sym\n'
        '${l10n.discountsReceived}: ${_numFmt.format(s.purchaseDiscountsReceived)} $sym\n'
        '${l10n.netDiscounts}: ${_numFmt.format(s.netDiscounts)} $sym';
    await PdfService.shareText(text: text);
  }

  Future<void> _exportCsv(AppLocalizations l10n) async {
    final s = _summary;
    if (s == null) return;
    final headers = [
      l10n.documentNumber,
      l10n.date,
      l10n.type,
      l10n.tax,
      l10n.discount,
      l10n.total,
    ];
    final csvRows = s.documents.map((d) {
      final isInvoice = d.type == 'invoice';
      return [
        d.documentNumber,
        _dateFmt.format(d.date),
        isInvoice ? l10n.invoice : l10n.purchase,
        d.taxAmount,
        d.discount,
        d.total,
      ];
    }).toList();

    try {
      final bytes = CsvService.instance.exportReportToCsv(
        headers: headers,
        rows: csvRows,
      );
      await PdfService.shareCsv(
        bytes: bytes,
        fileName:
            'tax_discount_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
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
      title: l10n.taxDiscountReport,
      onPrintPdf: () => _exportPdf(isShare: false),
      onSharePdf: () => _exportPdf(isShare: true),
      onShareWhatsApp: () => _shareWhatsApp(l10n),
      onExportCsv: () => _exportCsv(l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sym = Currency.symbolForCode(_summary?.currencyCode ?? 'SDG');

    return ScreenAccessGate(
      screenType: TaxDiscountReportScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.taxDiscountReport),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: l10n.exportOptions,
              onPressed: _summary != null
                  ? () => _openExportMenu(context, l10n)
                  : null,
            ),
          ],
        ),
        body: ResponsiveCenter(
          child: Column(
            children: [
              ReportDateFilter(
                range: _range,
                onChanged: (r) {
                  setState(() => _range = r);
                  ReportsDateScope.update(context, r);
                  _load();
                },
              ),
              if (_loading)
                const Expanded(child: AppLoadingView())
              else if (_error != null)
                Expanded(
                  child: AppErrorState(message: _error!, onRetry: _load),
                )
              else if (_summary != null)
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        // Tax Section Header
                        Text(
                          l10n.tax,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: AppMetricCard(
                                title: l10n.taxCollected,
                                value:
                                    '${_numFmt.format(_summary!.salesTaxCollected)} $sym',
                                icon: Icons.receipt_long_outlined,
                                color: AppStatusColors.fg(
                                  context,
                                  AppStatus.success,
                                ),
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppMetricCard(
                                title: l10n.taxPaid,
                                value:
                                    '${_numFmt.format(_summary!.purchaseTaxPaid)} $sym',
                                icon: Icons.shopping_bag_outlined,
                                color: AppStatusColors.fg(
                                  context,
                                  AppStatus.warning,
                                ),
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AppMetricCard(
                          title: l10n.netTax,
                          value: '${_numFmt.format(_summary!.netTax)} $sym',
                          icon: Icons.account_balance_outlined,
                          color: _summary!.netTax >= 0
                              ? AppStatusColors.fg(context, AppStatus.success)
                              : Theme.of(context).colorScheme.error,
                          compact: true,
                        ),
                        const SizedBox(height: 16),

                        // Discount Section Header
                        Text(
                          l10n.discount,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: AppMetricCard(
                                title: l10n.discountsGiven,
                                value:
                                    '${_numFmt.format(_summary!.salesDiscountsGiven)} $sym',
                                icon: Icons.discount_outlined,
                                color: Theme.of(context).colorScheme.error,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppMetricCard(
                                title: l10n.discountsReceived,
                                value:
                                    '${_numFmt.format(_summary!.purchaseDiscountsReceived)} $sym',
                                icon: Icons.loyalty_outlined,
                                color: AppStatusColors.fg(
                                  context,
                                  AppStatus.success,
                                ),
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AppMetricCard(
                          title: l10n.netDiscounts,
                          value:
                              '${_numFmt.format(_summary!.netDiscounts)} $sym',
                          icon: Icons.price_check_outlined,
                          color: _summary!.netDiscounts >= 0
                              ? AppStatusColors.fg(context, AppStatus.success)
                              : Theme.of(context).colorScheme.error,
                          compact: true,
                        ),
                        const SizedBox(height: 20),

                        // Transactions with Tax or Discount
                        Row(
                          children: [
                            Text(
                              l10n.documents,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '(${_summary!.documents.length})',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_summary!.documents.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: l10n.noReportData,
                              description: l10n.noDataForPeriod,
                            ),
                          )
                        else
                          ..._summary!.documents.map((doc) {
                            final isInvoice = doc.type == 'invoice';
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDesignTokens.cardRadius,
                                ),
                                side: BorderSide(color: cs.outlineVariant),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isInvoice
                                      ? AppStatusColors.bg(
                                          context,
                                          AppStatus.success,
                                        )
                                      : AppStatusColors.bg(
                                          context,
                                          AppStatus.warning,
                                        ),
                                  child: Icon(
                                    isInvoice
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    size: 16,
                                    color: isInvoice
                                        ? AppStatusColors.fg(
                                            context,
                                            AppStatus.success,
                                          )
                                        : AppStatusColors.fg(
                                            context,
                                            AppStatus.warning,
                                          ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        doc.documentNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_numFmt.format(doc.total)} $sym',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      _dateFmt.format(doc.date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (doc.taxAmount > 0)
                                      Text(
                                        '${l10n.tax}: ${_numFmt.format(doc.taxAmount)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    if (doc.taxAmount > 0 && doc.discount > 0)
                                      const Text(
                                        ' · ',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    if (doc.discount > 0)
                                      Text(
                                        '${l10n.discount}: ${_numFmt.format(doc.discount)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DocumentDetailScreen(
                                      documentId: doc.id!,
                                    ),
                                  ),
                                ).then((_) => _load()),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
