import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../models/entitlement.dart';
import '../../services/business_reporting_service.dart';
import '../../services/csv_service.dart';
import '../../services/feature_access.dart';
import '../../services/license_service.dart';
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
import '../../widgets/pro_upgrade_sheet.dart';
import '../../widgets/report_export_menu.dart';
import '../../widgets/responsive.dart';

class AgingReportScreen extends StatefulWidget {
  const AgingReportScreen({super.key});

  @override
  State<AgingReportScreen> createState() => _AgingReportScreenState();
}

class _AgingReportScreenState extends State<AgingReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AgingReportData? _receivables;
  AgingReportData? _payables;
  Business? _business;
  EntitlementState? _entitlement;
  bool _loading = true;
  String? _error;
  int _querySeq = 0;

  static final _numFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    LicenseService.instance
        .checkEntitlement(force: false)
        .then((e) {
          if (mounted) setState(() => _entitlement = e);
        })
        .catchError((_) {});
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
      final results = await Future.wait([
        BusinessReportingService.instance.getAgingReport(
          documentType: 'invoice',
        ),
        BusinessReportingService.instance.getAgingReport(
          documentType: 'purchase',
        ),
        DatabaseHelper.instance.getFirstBusiness(),
      ]);
      if (!mounted || seq != _querySeq) return;
      setState(() {
        _receivables = results[0] as AgingReportData;
        _payables = results[1] as AgingReportData;
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

  bool get _hasPro =>
      FeatureAccess.canAccess(Feature.advancedReports, _entitlement);

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
    AgingReportData data,
    bool isReceivables,
  ) {
    final title = isReceivables ? l10n.receivablesAging : l10n.payablesAging;
    final summaryCards = [
      PdfReportSummaryCard(
        label: l10n.agingBucket0To30,
        value: '${_numFmt.format(data.overall.current0To30)} $baseCurrency',
      ),
      PdfReportSummaryCard(
        label: l10n.agingBucket31To60,
        value: '${_numFmt.format(data.overall.days31To60)} $baseCurrency',
      ),
      PdfReportSummaryCard(
        label: l10n.agingBucket61To90,
        value: '${_numFmt.format(data.overall.days61To90)} $baseCurrency',
      ),
      PdfReportSummaryCard(
        label: l10n.agingBucket90Plus,
        value: '${_numFmt.format(data.overall.days90Plus)} $baseCurrency',
      ),
      PdfReportSummaryCard(
        label: l10n.totalRemainingDebt,
        value: '${_numFmt.format(data.overall.total)} $baseCurrency',
      ),
    ];

    final columns = [
      PdfReportColumn(
        title: isReceivables ? l10n.customer : l10n.supplier,
        flex: 2.5,
      ),
      PdfReportColumn(
        title: l10n.agingBucket0To30,
        flex: 1.5,
        align: pw.TextAlign.right,
      ),
      PdfReportColumn(
        title: l10n.agingBucket31To60,
        flex: 1.5,
        align: pw.TextAlign.right,
      ),
      PdfReportColumn(
        title: l10n.agingBucket61To90,
        flex: 1.5,
        align: pw.TextAlign.right,
      ),
      PdfReportColumn(
        title: l10n.agingBucket90Plus,
        flex: 1.5,
        align: pw.TextAlign.right,
      ),
      PdfReportColumn(
        title: l10n.totalRemainingDebt,
        flex: 1.8,
        align: pw.TextAlign.right,
      ),
    ];

    final rows = data.contactItems.map((item) {
      return [
        item.contactName,
        _numFmt.format(item.buckets.current0To30),
        _numFmt.format(item.buckets.days31To60),
        _numFmt.format(item.buckets.days61To90),
        _numFmt.format(item.buckets.days90Plus),
        _numFmt.format(item.buckets.total),
      ];
    }).toList();

    return PdfReportData(
      title: title,
      dateRange: DateFormat('dd/MM/yyyy').format(data.asOfDate),
      summaryCards: summaryCards,
      columns: columns,
      rows: rows,
    );
  }

  Future<void> _exportPdf(
    AppLocalizations l10n,
    String baseCurrency, {
    required PdfPageFormat pageFormat,
    required bool isShare,
  }) async {
    final isReceivables = _tabController.index == 0;
    final data = isReceivables ? _receivables : _payables;
    if (data == null) return;

    try {
      final pdfData = _buildPdfData(l10n, baseCurrency, data, isReceivables);
      final biz = _effectiveBusiness(baseCurrency);
      final fileName =
          '${isReceivables ? "receivables" : "payables"}_aging_${DateFormat('yyyyMMdd').format(data.asOfDate)}.pdf';

      if (isShare) {
        await PdfService.shareReportPdf(
          business: biz,
          l10n: l10n,
          data: pdfData,
          fileName: fileName,
          pageFormat: pageFormat,
        );
      } else {
        await PdfService.printOrShareReportPdf(
          business: biz,
          l10n: l10n,
          data: pdfData,
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

  Future<void> _exportCsv(AppLocalizations l10n, String baseCurrency) async {
    final isReceivables = _tabController.index == 0;
    final data = isReceivables ? _receivables : _payables;
    if (data == null) return;

    final headers = [
      isReceivables ? l10n.customer : l10n.supplier,
      l10n.phone,
      l10n.agingBucket0To30,
      l10n.agingBucket31To60,
      l10n.agingBucket61To90,
      l10n.agingBucket90Plus,
      l10n.totalRemainingDebt,
      l10n.currency,
    ];

    final rows = data.contactItems.map((item) {
      return [
        item.contactName,
        item.phone ?? '',
        _numFmt.format(item.buckets.current0To30),
        _numFmt.format(item.buckets.days31To60),
        _numFmt.format(item.buckets.days61To90),
        _numFmt.format(item.buckets.days90Plus),
        _numFmt.format(item.buckets.total),
        baseCurrency,
      ];
    }).toList();

    try {
      final bytes = CsvService.instance.exportReportToCsv(
        headers: headers,
        rows: rows,
      );
      final fileName =
          '${isReceivables ? "receivables" : "payables"}_aging_${DateFormat('yyyyMMdd').format(data.asOfDate)}.csv';
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

  Future<void> _shareText(AppLocalizations l10n, String baseCurrency) async {
    final isReceivables = _tabController.index == 0;
    final data = isReceivables ? _receivables : _payables;
    if (data == null) return;

    final buffer = StringBuffer();
    buffer.writeln(
      '📊 *${isReceivables ? l10n.receivablesAging : l10n.payablesAging}*',
    );
    buffer.writeln('📅 ${DateFormat('dd/MM/yyyy').format(data.asOfDate)}');
    buffer.writeln('───────────────');
    buffer.writeln(
      '• ${l10n.totalRemainingDebt}: ${_numFmt.format(data.overall.total)} $baseCurrency',
    );
    buffer.writeln(
      '• ${l10n.agingBucket0To30}: ${_numFmt.format(data.overall.current0To30)} $baseCurrency',
    );
    buffer.writeln(
      '• ${l10n.agingBucket31To60}: ${_numFmt.format(data.overall.days31To60)} $baseCurrency',
    );
    buffer.writeln(
      '• ${l10n.agingBucket61To90}: ${_numFmt.format(data.overall.days61To90)} $baseCurrency',
    );
    buffer.writeln(
      '• ${l10n.agingBucket90Plus}: ${_numFmt.format(data.overall.days90Plus)} $baseCurrency',
    );

    await PdfService.shareText(text: buffer.toString());
  }

  Future<void> _sendReminder(
    AppLocalizations l10n,
    ContactAgingItem item,
    String baseCurrency,
  ) async {
    final text =
        'السلام عليكم ${item.contactName}،\n'
        'نود تذكيركم بأن لديكم رصيد مستحق بقيمة ${_numFmt.format(item.buckets.total)} $baseCurrency طرفنا.\n'
        'نرجو التكرم بترتيب السداد في أقرب وقت.\n'
        'شكراً لتعاملكم معنا.';
    await PdfService.shareText(text: text);
  }

  void _openExportMenu(
    BuildContext context,
    AppLocalizations l10n,
    String baseCurrency,
  ) {
    ReportExportMenu.show(
      context: context,
      title: l10n.agingReport,
      onPrintPdf: () => _exportPdf(
        l10n,
        baseCurrency,
        pageFormat: PdfPageFormat.a4,
        isShare: false,
      ),
      onSharePdf: () => _exportPdf(
        l10n,
        baseCurrency,
        pageFormat: PdfPageFormat.a4,
        isShare: true,
      ),
      onExportCsv: () => _exportCsv(l10n, baseCurrency),
      onShareWhatsApp: () => _shareText(l10n, baseCurrency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final baseCurrency = _business?.currencyCode ?? 'SDG';

    return ScreenAccessGate(
      screenType: AgingReportScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.agingReport),
          actions: [
            if (!_loading &&
                _receivables != null &&
                ReportExportMenu.canExport())
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.exportOptions,
                onPressed: () => _openExportMenu(context, l10n, baseCurrency),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.receivablesAging),
              Tab(text: l10n.payablesAging),
            ],
          ),
        ),
        body: ResponsiveCenter(
          child: _loading
              ? const AppLoadingView()
              : _error != null
              ? AppErrorState(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTab(
                      l10n,
                      _receivables,
                      baseCurrency,
                      isReceivables: true,
                    ),
                    _buildTab(
                      l10n,
                      _payables,
                      baseCurrency,
                      isReceivables: false,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTab(
    AppLocalizations l10n,
    AgingReportData? data,
    String baseCurrency, {
    required bool isReceivables,
  }) {
    if (data == null || data.overall.total <= 0.001) {
      return AppEmptyState(
        icon: Icons.check_circle_outline,
        title: l10n.noReportData,
      );
    }

    final theme = Theme.of(context);
    final hasPro = _hasPro;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Total metric card
          AppMetricCard(
            title: l10n.totalRemainingDebt,
            value: '${_numFmt.format(data.overall.total)} $baseCurrency',
            icon: isReceivables
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: isReceivables
                ? AppStatusColors.fg(context, AppStatus.warning)
                : AppStatusColors.fg(context, AppStatus.danger),
          ),

          if (data.hasLegacyForeignCurrency) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
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
          ],

          const SizedBox(height: 12),

          // 4 Buckets Breakdown Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final itemWidth = isNarrow
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: AppMetricCard(
                      title: l10n.agingBucket0To30,
                      value:
                          '${_numFmt.format(data.overall.current0To30)} $baseCurrency',
                      icon: Icons.hourglass_top_rounded,
                      color: AppStatusColors.fg(context, AppStatus.success),
                      compact: true,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: AppMetricCard(
                      title: l10n.agingBucket31To60,
                      value:
                          '${_numFmt.format(data.overall.days31To60)} $baseCurrency',
                      icon: Icons.hourglass_bottom_rounded,
                      color: AppStatusColors.fg(context, AppStatus.info),
                      compact: true,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: AppMetricCard(
                      title: l10n.agingBucket61To90,
                      value:
                          '${_numFmt.format(data.overall.days61To90)} $baseCurrency',
                      icon: Icons.warning_amber_rounded,
                      color: AppStatusColors.fg(context, AppStatus.warning),
                      compact: true,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: AppMetricCard(
                      title: l10n.agingBucket90Plus,
                      value:
                          '${_numFmt.format(data.overall.days90Plus)} $baseCurrency',
                      icon: Icons.alarm_on_rounded,
                      color: AppStatusColors.fg(context, AppStatus.danger),
                      compact: true,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Pro gated section: Detailed breakdown per party
          if (!hasPro) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const ProBadge(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.proDetailedAgingTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await ProUpgradeSheet.show(
                          context,
                          feature: Feature.advancedReports,
                        );
                        if (result == true && mounted) {
                          final fresh = await LicenseService.instance
                              .checkEntitlement(force: true);
                          if (mounted) setState(() => _entitlement = fresh);
                        }
                      },
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: Text(l10n.proFeatureTitle),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isReceivables ? l10n.customers : l10n.suppliers,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final item in data.contactItems)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.cardRadius,
                  ),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.contactName.isEmpty
                                      ? l10n.unspecified
                                      : item.contactName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (item.phone != null &&
                                    item.phone!.isNotEmpty)
                                  Text(
                                    item.phone!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_numFmt.format(item.buckets.total)} $baseCurrency',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                '${item.openDocumentCount} ${l10n.openInvoices}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (isReceivables &&
                              item.phone != null &&
                              item.phone!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send_rounded, size: 20),
                              tooltip: l10n.sendPaymentReminder,
                              color: theme.colorScheme.primary,
                              onPressed: () =>
                                  _sendReminder(l10n, item, baseCurrency),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Mini bucket indicator pills
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.buckets.current0To30 > 0)
                            _bucketPill(
                              l10n.agingBucket0To30,
                              item.buckets.current0To30,
                              baseCurrency,
                              AppStatus.success,
                            ),
                          if (item.buckets.days31To60 > 0)
                            _bucketPill(
                              l10n.agingBucket31To60,
                              item.buckets.days31To60,
                              baseCurrency,
                              AppStatus.info,
                            ),
                          if (item.buckets.days61To90 > 0)
                            _bucketPill(
                              l10n.agingBucket61To90,
                              item.buckets.days61To90,
                              baseCurrency,
                              AppStatus.warning,
                            ),
                          if (item.buckets.days90Plus > 0)
                            _bucketPill(
                              l10n.agingBucket90Plus,
                              item.buckets.days90Plus,
                              baseCurrency,
                              AppStatus.danger,
                            ),
                        ],
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

  Widget _bucketPill(
    String label,
    double amount,
    String baseCurrency,
    AppStatus status,
  ) {
    final fg = AppStatusColors.fg(context, status);
    final bg = AppStatusColors.bg(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${_numFmt.format(amount)} $baseCurrency',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
