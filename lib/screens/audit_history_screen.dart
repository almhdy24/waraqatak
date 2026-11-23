import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/date_range_filter.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../services/csv_service.dart';
import '../services/pdf/pdf_report_builder.dart';
import '../services/pdf_service.dart';
import '../utils/error_utils.dart';
import '../widgets/app_status_colors.dart';
import '../widgets/access/screen_access_gate.dart';
import '../widgets/pro_upgrade_sheet.dart';
import '../widgets/report_export_menu.dart';
import '../widgets/responsive.dart';
import 'document_detail_screen.dart';
import 'reports/report_date_filter.dart';
import 'reports/reports_date_scope.dart';

class AuditHistoryScreen extends StatefulWidget {
  const AuditHistoryScreen({super.key});

  @override
  State<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends State<AuditHistoryScreen> {
  DateRangeFilter _range = ReportsDateNotifier.instance.range;
  String _selectedAction = 'all';
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  int _querySeq = 0;

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _checkEntitlementAndLoad();
  }

  Future<void> _checkEntitlementAndLoad() async {
    final entitlement = await LicenseService.instance.checkEntitlement(
      force: true,
    );
    if (!FeatureAccess.canAccess(Feature.inventoryAudit, entitlement)) {
      if (mounted) {
        final activated = await ProUpgradeSheet.show(
          context,
          feature: Feature.inventoryAudit,
        );
        if (activated && mounted) {
          final updated = await LicenseService.instance.checkEntitlement(
            force: true,
          );
          if (FeatureAccess.canAccess(Feature.inventoryAudit, updated)) {
            await _load();
            return;
          }
        }
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    final seq = ++_querySeq;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final events = await DatabaseHelper.instance.getAuditEvents(
        action: _selectedAction == 'all' ? null : _selectedAction,
        from: _range.from,
        to: _range.to,
        limit: 200,
      );
      if (!mounted || seq != _querySeq) return;

      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _querySeq) return;
      setState(() {
        _error = ErrorUtils.getFriendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  PdfReportData _buildPdfData(AppLocalizations l10n) {
    final columns = [
      PdfReportColumn(title: l10n.date, flex: 1.8),
      PdfReportColumn(title: l10n.eventType, flex: 1.6),
      PdfReportColumn(title: l10n.details, flex: 3.0),
    ];

    final rows = _events.map((e) {
      final ts = DateTime.tryParse(e['timestamp'] as String? ?? '');
      final dateStr = ts != null
          ? _dateFmt.format(ts)
          : (e['timestamp']?.toString() ?? '—');
      final action = e['action'] as String? ?? '—';
      final details = e['details'] as String? ?? '—';
      return <String>[dateStr, _formatActionLabel(action, l10n), details];
    }).toList();

    return PdfReportData(
      title: l10n.auditHistoryTitle,
      dateRange: _range.label(l10n),
      summaryCards: [
        PdfReportSummaryCard(label: l10n.allEvents, value: '${_events.length}'),
      ],
      columns: columns,
      rows: rows,
    );
  }

  Future<void> _exportPdf({required bool isShare}) async {
    final l10n = AppLocalizations.of(context);
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null || _events.isEmpty) return;
    final data = _buildPdfData(l10n);

    try {
      if (isShare) {
        await PdfService.shareReportPdf(
          data: data,
          business: business,
          l10n: l10n,
        );
      } else {
        await PdfService.printOrShareReportPdf(
          data: data,
          business: business,
          l10n: l10n,
        );
      }
    } catch (_) {}
  }

  Future<void> _shareWhatsApp(AppLocalizations l10n) async {
    final text =
        '${l10n.auditHistoryTitle} · ${_range.label(l10n)}\n'
        '${l10n.allEvents}: ${_events.length}';
    await PdfService.shareText(text: text);
  }

  Future<void> _exportCsv(AppLocalizations l10n) async {
    final headers = [l10n.date, l10n.eventType, l10n.entityLabel, l10n.details];
    final csvRows = _events.map((e) {
      final ts = DateTime.tryParse(e['timestamp'] as String? ?? '');
      final action = e['action'] as String? ?? '';
      return [
        ts ?? (e['timestamp'] ?? ''),
        _formatActionLabel(action, l10n),
        e['entity_type'] ?? '',
        e['details'] ?? '',
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
            'audit_history_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } catch (_) {}
  }

  void _openExportMenu(BuildContext context, AppLocalizations l10n) {
    ReportExportMenu.show(
      context: context,
      title: l10n.auditHistoryTitle,
      onPrintPdf: () => _exportPdf(isShare: false),
      onSharePdf: () => _exportPdf(isShare: true),
      onShareWhatsApp: () => _shareWhatsApp(l10n),
      onExportCsv: () => _exportCsv(l10n),
    );
  }

  String _formatActionLabel(String action, AppLocalizations l10n) {
    switch (action) {
      case 'stocktake_started':
        return l10n.eventStocktakeStarted;
      case 'stocktake_finalized':
        return l10n.eventStocktakeFinalized;
      case 'stocktake_cancelled':
        return l10n.eventStocktakeCancelled;
      case 'bulk_pricing':
        return l10n.eventBulkPricing;
      case 'csv_import':
        return l10n.eventCsvImport;
      case 'cost_reconciled':
        return l10n.eventCostReconciled;
      case 'stock_adjusted':
        return l10n.eventStockAdjustment;
      default:
        return action;
    }
  }

  IconData _getActionIcon(String action) {
    if (action.startsWith('stocktake')) return Icons.fact_check_outlined;
    if (action.startsWith('bulk_pricing')) return Icons.price_change_outlined;
    if (action.startsWith('csv_import')) return Icons.import_export_outlined;
    if (action.startsWith('cost')) return Icons.account_balance_wallet_outlined;
    return Icons.history_edu_outlined;
  }

  Color _getActionColor(BuildContext context, String action, ColorScheme cs) {
    if (action.contains('finalized')) {
      return AppStatusColors.fg(context, AppStatus.success);
    }
    if (action.contains('cancelled')) return cs.error;
    if (action.startsWith('bulk_pricing')) {
      return AppStatusColors.fg(context, AppStatus.info);
    }
    if (action.startsWith('csv_import')) return cs.tertiary;
    return AppStatusColors.fg(context, AppStatus.warning);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return ScreenAccessGate(
      screenType: AuditHistoryScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.auditHistoryTitle),
          actions: [
            if (ReportExportMenu.canExport())
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: l10n.printOrShareReport,
                onPressed: _events.isNotEmpty
                    ? () => _openExportMenu(context, l10n)
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
                onChanged: (newRange) {
                  ReportsDateScope.update(context, newRange);
                  setState(() => _range = newRange);
                  _load();
                },
              ),

              // Event Type Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    _chip('all', l10n.allEvents),
                    const SizedBox(width: 6),
                    _chip('stocktake_finalized', l10n.eventStocktake),
                    const SizedBox(width: 6),
                    _chip('bulk_pricing', l10n.eventBulkPricing),
                    const SizedBox(width: 6),
                    _chip('csv_import', l10n.eventCsvImport),
                    const SizedBox(width: 6),
                    _chip('cost_reconciled', l10n.eventCostReconciled),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Events List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : _events.isEmpty
                    ? Center(child: Text(l10n.noDataForPeriod))
                    : ListView.separated(
                        itemCount: _events.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final e = _events[idx];
                          final action = e['action'] as String? ?? '';
                          final details = e['details'] as String? ?? '—';
                          final ts = DateTime.tryParse(
                            e['timestamp'] as String? ?? '',
                          );
                          final dateStr = ts != null
                              ? _dateFmt.format(ts)
                              : (e['timestamp'] ?? '—');
                          final color = _getActionColor(context, action, cs);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.12),
                              child: Icon(
                                _getActionIcon(action),
                                color: color,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _formatActionLabel(action, l10n),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  details,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(_formatActionLabel(action, l10n)),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${l10n.date}: $dateStr',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${l10n.actionTypeLabel}: $action',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (e['entity_type'] != null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                '${l10n.entityLabel}: ${e['entity_type']} ',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (e['entity_id'] != null)
                                                Directionality(
                                                  textDirection:
                                                      TextDirection.ltr,
                                                  child: Text(
                                                    '(#${e['entity_id']})',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Text(
                                          '${l10n.detailsLabel}:',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SelectableText(
                                          details,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    if (e['entity_type'] == 'document' &&
                                        e['entity_id'] != null)
                                      FilledButton.tonal(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _openDocument(
                                            context,
                                            e['entity_id'] as int,
                                          );
                                        },
                                        child: Text(l10n.viewDocument),
                                      ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(l10n.close),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String actionKey, String label) {
    final selected = _selectedAction == actionKey;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedAction = actionKey);
        _load();
      },
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
}
