import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../models/date_range_filter.dart';
import '../../models/payment_method.dart';
import '../../services/access/access_guard.dart';
import '../../services/access/permission_registry.dart';
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
import 'report_date_filter.dart';
import 'reports_date_scope.dart';

class DailyClosingReportScreen extends StatefulWidget {
  const DailyClosingReportScreen({super.key});

  @override
  State<DailyClosingReportScreen> createState() =>
      _DailyClosingReportScreenState();
}

class _DailyClosingReportScreenState extends State<DailyClosingReportScreen> {
  DateRangeFilter _range = ReportsDateNotifier.instance.range;
  DailyClosingSummary? _summary;
  Business? _business;
  Map<String, PaymentMethod> _methodsMap = {};
  bool _loading = true;
  String? _error;
  int _querySeq = 0;

  final TextEditingController _openingCashController = TextEditingController(
    text: '',
  );
  final TextEditingController _actualCashController = TextEditingController(
    text: '',
  );

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _openingCashController.dispose();
    _actualCashController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_querySeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        BusinessReportingService.instance.getDailyClosingSummary(
          from: _range.from,
          to: _range.to,
        ),
        DatabaseHelper.instance.getPaymentMethods(),
        DatabaseHelper.instance.getFirstBusiness(),
      ]);
      if (!mounted || seq != _querySeq) return;
      setState(() {
        _summary = results[0] as DailyClosingSummary;
        _methodsMap = {
          for (final m in (results[1] as List<PaymentMethod>)) m.key: m,
        };
        _business = results[2] as Business?;
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

  String _methodLabel(String key, AppLocalizations l10n) {
    final pm = _methodsMap[key];
    if (pm != null) {
      return l10n.isArabic ? pm.labelAr : pm.labelEn;
    }
    return key;
  }

  double _parseCashInput(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '');
    return double.tryParse(text) ?? 0.0;
  }

  Business _effectiveBusiness(String baseCurrency) {
    return _business ??
        Business(
          name: 'Waraqatak',
          ownerName: '',
          phone: '',
          address: '',
          currencyCode: baseCurrency,
        );
  }

  PdfReportData _buildPdfData(
    AppLocalizations l10n,
    String baseCurrency,
    DailyClosingSummary s,
    bool hasFinancials,
  ) {
    final opening = _parseCashInput(_openingCashController);
    final actual = _parseCashInput(_actualCashController);
    final cashIn = s.collectionsByMethod['cash'] ?? 0.0;
    final cashOut = hasFinancials
        ? (s.disbursementsByMethod['cash'] ?? 0.0)
        : 0.0;
    final expected = opening + cashIn - cashOut;
    final variance = actual - expected;

    final summaryCards = [
      PdfReportSummaryCard(
        label: l10n.netSalesTitle,
        value: '${_numFmt.format(s.netSales)} $baseCurrency',
      ),
      PdfReportSummaryCard(
        label: l10n.receivedPayments,
        value: '${_numFmt.format(s.totalCollected)} $baseCurrency',
      ),
      if (hasFinancials)
        PdfReportSummaryCard(
          label: l10n.totalOutflows,
          value: '${_numFmt.format(s.totalDisbursed)} $baseCurrency',
        ),
      PdfReportSummaryCard(
        label: l10n.expectedCash,
        value: '${_numFmt.format(expected)} $baseCurrency',
      ),
    ];

    final rows = <List<String>>[
      [l10n.grossSalesTitle, '${_numFmt.format(s.grossSales)} $baseCurrency'],
      [l10n.discount, '${_numFmt.format(s.totalDiscounts)} $baseCurrency'],
      [l10n.netSalesTitle, '${_numFmt.format(s.netSales)} $baseCurrency'],
      [l10n.invoicesCount, '${s.invoiceCount}'],
      [l10n.cancelledInvoicesCount, '${s.cancelledInvoiceCount}'],
      [l10n.creditSalesTitle, '${_numFmt.format(s.creditSales)} $baseCurrency'],
      [
        l10n.customerDebtsCollected,
        '${_numFmt.format(s.customerDebtCollected)} $baseCurrency',
      ],
      [
        l10n.receivedPayments,
        '${_numFmt.format(s.totalCollected)} $baseCurrency',
      ],
      for (final entry in s.collectionsByMethod.entries)
        [
          '  ${_methodLabel(entry.key, l10n)}',
          '${_numFmt.format(entry.value)} $baseCurrency',
        ],
      if (hasFinancials) ...[
        [
          l10n.totalOutflows,
          '${_numFmt.format(s.totalDisbursed)} $baseCurrency',
        ],
        [
          l10n.madePayments,
          '${_numFmt.format(s.supplierPayments)} $baseCurrency',
        ],
        [
          l10n.expenseVoucher,
          '${_numFmt.format(s.expenseVouchers)} $baseCurrency',
        ],
        for (final entry in s.disbursementsByMethod.entries)
          [
            '  ${_methodLabel(entry.key, l10n)}',
            '${_numFmt.format(entry.value)} $baseCurrency',
          ],
      ],
      [l10n.openingCash, '${_numFmt.format(opening)} $baseCurrency'],
      [l10n.expectedCash, '${_numFmt.format(expected)} $baseCurrency'],
      if (_actualCashController.text.trim().isNotEmpty) ...[
        [l10n.actualCash, '${_numFmt.format(actual)} $baseCurrency'],
        [l10n.cashVariance, '${_numFmt.format(variance)} $baseCurrency'],
      ],
    ];

    return PdfReportData(
      title: l10n.dailyClosingReport,
      dateRange: _range.label(l10n),
      summaryCards: summaryCards,
      columns: [
        PdfReportColumn(title: l10n.item, flex: 3),
        PdfReportColumn(title: l10n.amount, flex: 2, align: pw.TextAlign.right),
      ],
      rows: rows,
    );
  }

  Future<void> _exportPdf(
    AppLocalizations l10n,
    String baseCurrency,
    DailyClosingSummary s,
    bool hasFinancials, {
    required PdfPageFormat pageFormat,
    required bool isShare,
  }) async {
    try {
      final data = _buildPdfData(l10n, baseCurrency, s, hasFinancials);
      final biz = _effectiveBusiness(baseCurrency);
      final fileName =
          'daily_closing_${DateFormat('yyyyMMdd').format(s.from)}.pdf';
      if (isShare) {
        await PdfService.shareReportPdf(
          business: biz,
          l10n: l10n,
          data: data,
          fileName: fileName,
          pageFormat: pageFormat,
        );
      } else {
        await PdfService.printOrShareReportPdf(
          business: biz,
          l10n: l10n,
          data: data,
          pageFormat: pageFormat,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          l10n.operationFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _shareText(
    AppLocalizations l10n,
    String baseCurrency,
    DailyClosingSummary s,
    bool hasFinancials,
  ) async {
    final opening = _parseCashInput(_openingCashController);
    final actual = _parseCashInput(_actualCashController);
    final cashIn = s.collectionsByMethod['cash'] ?? 0.0;
    final cashOut = hasFinancials
        ? (s.disbursementsByMethod['cash'] ?? 0.0)
        : 0.0;
    final expected = opening + cashIn - cashOut;

    final buffer = StringBuffer();
    buffer.writeln('📋 *${l10n.dailyClosingReport}*');
    buffer.writeln('📅 ${_range.label(l10n)}');
    buffer.writeln('───────────────');
    buffer.writeln(
      '• ${l10n.netSalesTitle}: ${_numFmt.format(s.netSales)} $baseCurrency (${s.invoiceCount} ${l10n.featureInvoices})',
    );
    buffer.writeln(
      '• ${l10n.creditSalesTitle}: ${_numFmt.format(s.creditSales)} $baseCurrency',
    );
    buffer.writeln(
      '• ${l10n.receivedPayments}: ${_numFmt.format(s.totalCollected)} $baseCurrency',
    );
    for (final e in s.collectionsByMethod.entries) {
      buffer.writeln(
        '   - ${_methodLabel(e.key, l10n)}: ${_numFmt.format(e.value)} $baseCurrency',
      );
    }
    if (hasFinancials) {
      buffer.writeln('───────────────');
      buffer.writeln(
        '• ${l10n.totalOutflows}: ${_numFmt.format(s.totalDisbursed)} $baseCurrency',
      );
    }
    buffer.writeln('───────────────');
    buffer.writeln(
      '💵 ${l10n.expectedCash}: ${_numFmt.format(expected)} $baseCurrency',
    );
    if (_actualCashController.text.trim().isNotEmpty) {
      final variance = actual - expected;
      buffer.writeln(
        '💵 ${l10n.actualCash}: ${_numFmt.format(actual)} $baseCurrency',
      );
      buffer.writeln(
        '⚖️ ${l10n.cashVariance}: ${_numFmt.format(variance)} $baseCurrency',
      );
    }
    await PdfService.shareText(text: buffer.toString());
  }

  Future<void> _exportCsv(
    AppLocalizations l10n,
    String baseCurrency,
    DailyClosingSummary s,
    bool hasFinancials,
  ) async {
    final opening = _parseCashInput(_openingCashController);
    final actual = _parseCashInput(_actualCashController);
    final cashIn = s.collectionsByMethod['cash'] ?? 0.0;
    final cashOut = hasFinancials
        ? (s.disbursementsByMethod['cash'] ?? 0.0)
        : 0.0;
    final expected = opening + cashIn - cashOut;
    final variance = actual - expected;

    final headers = [l10n.item, l10n.amount, l10n.currency];
    final rows = <List<String>>[
      [l10n.grossSalesTitle, _numFmt.format(s.grossSales), baseCurrency],
      [l10n.discount, _numFmt.format(s.totalDiscounts), baseCurrency],
      [l10n.netSalesTitle, _numFmt.format(s.netSales), baseCurrency],
      [l10n.invoicesCount, '${s.invoiceCount}', ''],
      [l10n.cancelledInvoicesCount, '${s.cancelledInvoiceCount}', ''],
      [l10n.creditSalesTitle, _numFmt.format(s.creditSales), baseCurrency],
      [
        l10n.customerDebtsCollected,
        _numFmt.format(s.customerDebtCollected),
        baseCurrency,
      ],
      [l10n.receivedPayments, _numFmt.format(s.totalCollected), baseCurrency],
      for (final entry in s.collectionsByMethod.entries)
        [
          _methodLabel(entry.key, l10n),
          _numFmt.format(entry.value),
          baseCurrency,
        ],
      if (hasFinancials) ...[
        [l10n.totalOutflows, _numFmt.format(s.totalDisbursed), baseCurrency],
        [l10n.madePayments, _numFmt.format(s.supplierPayments), baseCurrency],
        [l10n.expenseVoucher, _numFmt.format(s.expenseVouchers), baseCurrency],
        for (final entry in s.disbursementsByMethod.entries)
          [
            _methodLabel(entry.key, l10n),
            _numFmt.format(entry.value),
            baseCurrency,
          ],
      ],
      [l10n.openingCash, _numFmt.format(opening), baseCurrency],
      [l10n.expectedCash, _numFmt.format(expected), baseCurrency],
      if (_actualCashController.text.trim().isNotEmpty) ...[
        [l10n.actualCash, _numFmt.format(actual), baseCurrency],
        [l10n.cashVariance, _numFmt.format(variance), baseCurrency],
      ],
    ];

    try {
      final bytes = CsvService.instance.exportReportToCsv(
        headers: headers,
        rows: rows,
      );
      final fileName =
          'daily_closing_${DateFormat('yyyyMMdd').format(s.from)}.csv';
      await PdfService.shareCsv(bytes: bytes, fileName: fileName);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          l10n.operationFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  void _openExportMenu(
    BuildContext context,
    AppLocalizations l10n,
    String baseCurrency,
    DailyClosingSummary s,
    bool hasFinancials,
  ) {
    ReportExportMenu.show(
      context: context,
      title: l10n.dailyClosingReport,
      onPrintPdf: () => _exportPdf(
        l10n,
        baseCurrency,
        s,
        hasFinancials,
        pageFormat: PdfPageFormat.a4,
        isShare: false,
      ),
      onSharePdf: () => _exportPdf(
        l10n,
        baseCurrency,
        s,
        hasFinancials,
        pageFormat: PdfPageFormat.a4,
        isShare: true,
      ),
      onExportCsv: () => _exportCsv(l10n, baseCurrency, s, hasFinancials),
      onShareWhatsApp: () => _shareText(l10n, baseCurrency, s, hasFinancials),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final baseCurrency = _business?.currencyCode ?? 'SDG';
    final hasFinancials = AccessGuard.can(
      PermissionRegistry.reportsViewFinancials,
    );

    return ScreenAccessGate(
      screenType: DailyClosingReportScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.dailyClosingReport),
          actions: [
            if (_summary != null && !_loading && ReportExportMenu.canExport())
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.exportOptions,
                onPressed: () => _openExportMenu(
                  context,
                  l10n,
                  baseCurrency,
                  _summary!,
                  hasFinancials,
                ),
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
              if (_summary?.hasLegacyForeignCurrency == true)
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
              Expanded(
                child: _buildBody(l10n, theme, baseCurrency, hasFinancials),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    ThemeData theme,
    String baseCurrency,
    bool hasFinancials,
  ) {
    if (_loading) {
      return const AppLoadingView();
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    final s = _summary;
    if (s == null) {
      return AppEmptyState(
        title: l10n.noReportData,
        icon: Icons.point_of_sale_outlined,
      );
    }

    final opening = _parseCashInput(_openingCashController);
    final actual = _parseCashInput(_actualCashController);
    final cashIn = s.collectionsByMethod['cash'] ?? 0.0;
    final cashOut = hasFinancials
        ? (s.disbursementsByMethod['cash'] ?? 0.0)
        : 0.0;
    final expected = opening + cashIn - cashOut;
    final hasActual = _actualCashController.text.trim().isNotEmpty;
    final variance = actual - expected;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Metric cards row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: isNarrow
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 8) / 2,
                    child: AppMetricCard(
                      title: l10n.netSalesTitle,
                      value: '${_numFmt.format(s.netSales)} $baseCurrency',
                      icon: Icons.trending_up,
                      color: AppStatusColors.fg(context, AppStatus.success),
                      compact: true,
                    ),
                  ),
                  SizedBox(
                    width: isNarrow
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 8) / 2,
                    child: AppMetricCard(
                      title: l10n.receivedPayments,
                      value:
                          '${_numFmt.format(s.totalCollected)} $baseCurrency',
                      icon: Icons.payments_outlined,
                      color: AppStatusColors.fg(context, AppStatus.info),
                      compact: true,
                    ),
                  ),
                  if (hasFinancials)
                    SizedBox(
                      width: isNarrow
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 8) / 2,
                      child: AppMetricCard(
                        title: l10n.totalOutflows,
                        value:
                            '${_numFmt.format(s.totalDisbursed)} $baseCurrency',
                        icon: Icons.money_off_outlined,
                        color: AppStatusColors.fg(context, AppStatus.danger),
                        compact: true,
                      ),
                    ),
                  SizedBox(
                    width: isNarrow
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 8) / 2,
                    child: AppMetricCard(
                      title: l10n.expectedCash,
                      value: '${_numFmt.format(expected)} $baseCurrency',
                      icon: Icons.account_balance_wallet_outlined,
                      color: theme.colorScheme.primary,
                      compact: true,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Cash Drawer Reconciliation Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.cashDrawerReconciliation,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _openingCashController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.openingCash,
                            hintText: '0',
                            suffixText: baseCurrency,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _actualCashController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.actualCash,
                            hintText: '0',
                            suffixText: baseCurrency,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow(
                    l10n.openingCash,
                    '${_numFmt.format(opening)} $baseCurrency',
                    theme,
                  ),
                  _buildSummaryRow(
                    '+ ${l10n.cash} (${l10n.receivedPayments})',
                    '${_numFmt.format(cashIn)} $baseCurrency',
                    theme,
                    color: AppStatusColors.fg(context, AppStatus.success),
                  ),
                  if (hasFinancials)
                    _buildSummaryRow(
                      '- ${l10n.cash} (${l10n.totalOutflows})',
                      '${_numFmt.format(cashOut)} $baseCurrency',
                      theme,
                      color: AppStatusColors.fg(context, AppStatus.danger),
                    ),
                  const Divider(height: 16),
                  _buildSummaryRow(
                    '= ${l10n.expectedCash}',
                    '${_numFmt.format(expected)} $baseCurrency',
                    theme,
                    isBold: true,
                  ),
                  if (hasActual) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (variance == 0
                                    ? AppStatusColors.fg(
                                        context,
                                        AppStatus.success,
                                      )
                                    : variance > 0
                                    ? AppStatusColors.fg(
                                        context,
                                        AppStatus.info,
                                      )
                                    : AppStatusColors.fg(
                                        context,
                                        AppStatus.danger,
                                      ))
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            variance == 0
                                ? Icons.check_circle_outline
                                : variance > 0
                                ? Icons.add_circle_outline
                                : Icons.warning_amber_rounded,
                            size: 18,
                            color: variance == 0
                                ? AppStatusColors.fg(context, AppStatus.success)
                                : variance > 0
                                ? AppStatusColors.fg(context, AppStatus.info)
                                : AppStatusColors.fg(context, AppStatus.danger),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              variance == 0
                                  ? l10n.cashVarianceBalanced
                                  : variance > 0
                                  ? l10n.cashVarianceSurplus
                                  : l10n.cashVarianceDeficit,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: variance == 0
                                    ? AppStatusColors.fg(
                                        context,
                                        AppStatus.success,
                                      )
                                    : variance > 0
                                    ? AppStatusColors.fg(
                                        context,
                                        AppStatus.info,
                                      )
                                    : AppStatusColors.fg(
                                        context,
                                        AppStatus.danger,
                                      ),
                              ),
                            ),
                          ),
                          Text(
                            '${variance >= 0 ? '+' : ''}${_numFmt.format(variance)} $baseCurrency',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: variance == 0
                                  ? AppStatusColors.fg(
                                      context,
                                      AppStatus.success,
                                    )
                                  : variance > 0
                                  ? AppStatusColors.fg(context, AppStatus.info)
                                  : AppStatusColors.fg(
                                      context,
                                      AppStatus.danger,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sales Section Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.salesReport,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    l10n.grossSalesTitle,
                    '${_numFmt.format(s.grossSales)} $baseCurrency',
                    theme,
                  ),
                  _buildSummaryRow(
                    l10n.discount,
                    '-${_numFmt.format(s.totalDiscounts)} $baseCurrency',
                    theme,
                    color: AppStatusColors.fg(context, AppStatus.danger),
                  ),
                  _buildSummaryRow(
                    l10n.netSalesTitle,
                    '${_numFmt.format(s.netSales)} $baseCurrency',
                    theme,
                    isBold: true,
                  ),
                  const Divider(height: 16),
                  _buildSummaryRow(
                    l10n.invoicesCount,
                    '${s.invoiceCount}',
                    theme,
                  ),
                  _buildSummaryRow(
                    l10n.cancelledInvoicesCount,
                    '${s.cancelledInvoiceCount}',
                    theme,
                  ),
                  _buildSummaryRow(
                    l10n.creditSalesTitle,
                    '${_numFmt.format(s.creditSales)} $baseCurrency',
                    theme,
                    color: theme.colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Collections Breakdown Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.collectionsByMethodTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${_numFmt.format(s.totalCollected)} $baseCurrency',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppStatusColors.fg(context, AppStatus.success),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (s.customerDebtCollected > 0)
                    _buildSummaryRow(
                      l10n.customerDebtsCollected,
                      '${_numFmt.format(s.customerDebtCollected)} $baseCurrency',
                      theme,
                    ),
                  for (final e in s.collectionsByMethod.entries)
                    _buildSummaryRow(
                      _methodLabel(e.key, l10n),
                      '${_numFmt.format(e.value)} $baseCurrency',
                      theme,
                    ),
                ],
              ),
            ),
          ),

          if (hasFinancials && s.totalDisbursed > 0) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.disbursementsByMethodTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${_numFmt.format(s.totalDisbursed)} $baseCurrency',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppStatusColors.fg(
                              context,
                              AppStatus.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (s.supplierPayments > 0)
                      _buildSummaryRow(
                        l10n.madePayments,
                        '${_numFmt.format(s.supplierPayments)} $baseCurrency',
                        theme,
                      ),
                    if (s.expenseVouchers > 0)
                      _buildSummaryRow(
                        l10n.expenseVoucher,
                        '${_numFmt.format(s.expenseVouchers)} $baseCurrency',
                        theme,
                      ),
                    for (final e in s.disbursementsByMethod.entries)
                      _buildSummaryRow(
                        _methodLabel(e.key, l10n),
                        '${_numFmt.format(e.value)} $baseCurrency',
                        theme,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    ThemeData theme, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
