import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../localization/app_localizations.dart';
import '../models/database_diagnostic.dart';
import '../services/database_diagnostic_service.dart';
import '../services/database_repair_service.dart';
import '../utils/error_utils.dart';
import '../widgets/responsive.dart';

/// Advanced repair and diagnostic screen presenting data integrity checks and
/// executing safe, transaction-protected database repairs.
class DatabaseDiagnosticScreen extends StatefulWidget {
  final DatabaseExecutor? db;

  const DatabaseDiagnosticScreen({super.key, this.db});

  @override
  State<DatabaseDiagnosticScreen> createState() =>
      _DatabaseDiagnosticScreenState();
}

enum _RepairTabFilter { all, safe, review }

class _DatabaseDiagnosticScreenState extends State<DatabaseDiagnosticScreen> {
  DatabaseDiagnosticReport? _report;
  List<RepairableIssue> _issues = [];
  bool _loading = false;
  bool _isScanning = false;
  bool _isRepairing = false;
  Object? _error;
  _RepairTabFilter _currentTab = _RepairTabFilter.all;
  DiagnosticCategory? _selectedCategory;

  static final _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    if (_isScanning) return; // Prevent concurrent scans
    _isScanning = true;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await DatabaseDiagnosticService.runDiagnostics(
        db: widget.db,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final issues = DatabaseRepairService.categorizeReport(report, l10n);
      setState(() {
        _report = report;
        _issues = issues;
        _loading = false;
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _isScanning = false;
      });
    }
  }

  List<RepairableIssue> _getFilteredIssues() {
    var filtered = _issues;

    // Filter by Tab
    switch (_currentTab) {
      case _RepairTabFilter.all:
        break;
      case _RepairTabFilter.safe:
        filtered = filtered.where((i) => i.isSafeAutoRepair).toList();
        break;
      case _RepairTabFilter.review:
        filtered = filtered.where((i) => i.requiresManualReview).toList();
        break;
    }

    // Filter by Category
    if (_selectedCategory != null) {
      filtered =
          filtered.where((i) => i.category == _selectedCategory).toList();
    }

    return filtered;
  }

  Future<void> _exportReport() async {
    final report = _report;
    if (report == null) return;
    final l10n = AppLocalizations.of(context);
    final text = DatabaseRepairService.exportReportText(report, _issues, l10n);

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.repairReportCopied)));
  }

  Future<void> _fixSingleIssue(RepairableIssue issue) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Show preview confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.build_circle_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.repairFixPreviewTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                issue.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.repairPlannedChange}:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(issue.plannedChange, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${l10n.repairRecordsCount}: ${issue.affectedCount}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.repairConfirmFixAllBody,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.repairActionFix),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRepairing = true);

    try {
      final db = widget.db ?? await DatabaseRepairService.resolveDatabase();
      final result = await DatabaseRepairService.repairIssue(
        db: db,
        issue: issue,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.repairSuccess}${result.safetyBackupPath != null ? "\n${l10n.repairSafetyBackupCreated}${result.safetyBackupPath}" : ""}',
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }

      await _runDiagnostics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRepairing = false);
    }
  }

  Future<void> _fixAllSafeIssues() async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final safeIssues = _issues.where((i) => i.isSafeAutoRepair).toList();
    if (safeIssues.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_fix_high, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.repairConfirmFixAllTitle)),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.repairConfirmFixAllBody),
            const SizedBox(height: 12),
            Text(
              '${l10n.diagnosticsCleanDesc} (${safeIssues.length} ${l10n.repairSafeBadge})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () => Navigator.pop(ctx, true),
            label: Text(l10n.repairActionFixAll),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRepairing = true);

    try {
      final db = widget.db ?? await DatabaseRepairService.resolveDatabase();
      final result = await DatabaseRepairService.repairAllSafe(
        db: db,
        issues: safeIssues,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.repairSuccess} (${result.repairedCount})${result.safetyBackupPath != null ? "\n${l10n.repairSafetyBackupCreated}${result.safetyBackupPath}" : ""}',
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }

      await _runDiagnostics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRepairing = false);
    }
  }

  void _showManualReviewGuidance(RepairableIssue issue) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: Icon(
                    Icons.rate_review_outlined,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.repairReviewDialogTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              issue.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              issue.explanation,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.repairReviewGuidance,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    issue.recommendedAction,
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.diagnosticsAffectedIds} (${issue.affectedCount}):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: issue.affectedIds
                      .map(
                        (id) => Chip(
                          label: Text('#$id'),
                          padding: EdgeInsets.zero,
                          labelStyle: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(DiagnosticCategory cat, AppLocalizations l10n) {
    return switch (cat) {
      DiagnosticCategory.orphanedRecord => l10n.diagnosticsCategoryOrphaned,
      DiagnosticCategory.stockDiscrepancy => l10n.diagnosticsCategoryStock,
      DiagnosticCategory.missingOpeningStock =>
        l10n.diagnosticsCategoryMissingOpeningStock,
      DiagnosticCategory.negativeStock => l10n.diagnosticsCategoryNegativeStock,
      DiagnosticCategory.inventoryCosting => l10n.diagnosticsCategoryCosting,
      DiagnosticCategory.documentBalanceMismatch =>
        l10n.diagnosticsCategoryBalances,
      DiagnosticCategory.documentStatusMismatch =>
        l10n.diagnosticsCategoryStatuses,
      DiagnosticCategory.paymentMismatch => l10n.diagnosticsCategoryPayments,
      DiagnosticCategory.duplicateDocumentNumber =>
        l10n.diagnosticsCategoryDuplicates,
    };
  }

  Color _severityColor(DiagnosticSeverity severity, ColorScheme cs) {
    return switch (severity) {
      DiagnosticSeverity.error => cs.error,
      DiagnosticSeverity.warning => Colors.amber.shade800,
      DiagnosticSeverity.info => cs.primary,
    };
  }

  IconData _severityIcon(DiagnosticSeverity severity) {
    return switch (severity) {
      DiagnosticSeverity.error => Icons.error_outline,
      DiagnosticSeverity.warning => Icons.warning_amber_rounded,
      DiagnosticSeverity.info => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.repairSystemTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.repairActionExport,
            onPressed: (_loading || _report == null) ? null : _exportReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.diagnosticsRefresh,
            onPressed: (_loading || _isScanning || _isRepairing)
                ? null
                : _runDiagnostics,
          ),
        ],
      ),
      body: ResponsiveCenter(child: _buildBody(context, l10n, theme, cs)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    if (_loading || _isRepairing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _isRepairing ? l10n.repairExecuting : l10n.diagnosticsScanning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.report_problem_outlined, size: 56, color: cs.error),
              const SizedBox(height: 16),
              Text(
                l10n.diagnosticsExecutionFailed,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                ErrorUtils.getFriendlyErrorMessage(_error!, l10n: l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
                onPressed: _runDiagnostics,
              ),
            ],
          ),
        ),
      );
    }

    final report = _report;
    if (report == null) {
      return const SizedBox.shrink();
    }

    if (report.isClean) {
      return _buildCleanState(context, report, l10n, theme, cs);
    }

    return _buildReportView(context, report, l10n, theme, cs);
  }

  Widget _buildCleanState(
    BuildContext context,
    DatabaseDiagnosticReport report,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 72,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.diagnosticsCleanTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diagnosticsCleanDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 20,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.diagnosticsTotalChecks}: ${report.totalChecksRun}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.diagnosticsLastScan}: ${_dateTimeFmt.format(report.executedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(l10n.diagnosticsRefresh),
              onPressed: _runDiagnostics,
            ),
            const SizedBox(height: 24),
            _buildDisclaimer(l10n, theme, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildReportView(
    BuildContext context,
    DatabaseDiagnosticReport report,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final filteredIssues = _getFilteredIssues();
    final safeIssues = _issues.where((i) => i.isSafeAutoRepair).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Summary Cards
        _buildSummaryCards(report, l10n, theme, cs),
        const SizedBox(height: 12),

        // Action banner: Fix All Safe Issues
        if (safeIssues.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primary,
                  child: Icon(Icons.auto_fix_high, color: cs.onPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.repairActionFixAll,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${safeIssues.length} ${l10n.repairSafeBadge}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _isRepairing ? null : _fixAllSafeIssues,
                  child: Text(l10n.repairActionFix),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Segmented Control Tabs (All, Safe, Review)
        SegmentedButton<_RepairTabFilter>(
          segments: [
            ButtonSegment(
              value: _RepairTabFilter.all,
              label: Text('${l10n.repairTabAll} (${_issues.length})'),
            ),
            ButtonSegment(
              value: _RepairTabFilter.safe,
              label: Text('${l10n.repairTabAuto} (${safeIssues.length})'),
            ),
            ButtonSegment(
              value: _RepairTabFilter.review,
              label: Text(
                '${l10n.repairTabReview} (${_issues.length - safeIssues.length})',
              ),
            ),
          ],
          selected: {_currentTab},
          onSelectionChanged: (selected) {
            setState(() => _currentTab = selected.first);
          },
        ),
        const SizedBox(height: 12),

        // Category Filter Chips
        _buildCategoryFilters(report, l10n, theme, cs),
        const SizedBox(height: 12),

        // Issues List
        if (filteredIssues.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36.0),
            child: Center(
              child: Text(
                l10n.diagnosticsNoFindingsForFilter,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...filteredIssues.map(
            (issue) => _buildIssueCard(issue, l10n, theme, cs),
          ),

        const SizedBox(height: 16),
        _buildDisclaimer(l10n, theme, cs),
      ],
    );
  }

  Widget _buildSummaryCards(
    DatabaseDiagnosticReport report,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: l10n.diagnosticsSummaryErrors,
            count: report.errorCount,
            color: cs.error,
            icon: Icons.error_outline,
            theme: theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            title: l10n.diagnosticsSummaryWarnings,
            count: report.warningCount,
            color: Colors.amber.shade800,
            icon: Icons.warning_amber_rounded,
            theme: theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            title: l10n.diagnosticsSummaryInfo,
            count: report.infoCount,
            color: cs.primary,
            icon: Icons.info_outline,
            theme: theme,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: count > 0 ? color.withValues(alpha: 0.4) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(
    DatabaseDiagnosticReport report,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final availableCategories = report.findings.map((f) => f.category).toSet();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text(
              '${l10n.diagnosticsCategoryAll} (${_issues.length})',
            ),
            selected: _selectedCategory == null,
            onSelected: (selected) {
              if (selected) setState(() => _selectedCategory = null);
            },
          ),
          ...availableCategories.map((cat) {
            final count =
                _issues.where((i) => i.category == cat).length;
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsetsDirectional.only(start: 6.0),
              child: FilterChip(
                label: Text('${_categoryLabel(cat, l10n)} ($count)'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = selected ? cat : null;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildIssueCard(
    RepairableIssue issue,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final color = _severityColor(issue.severity, cs);
    final icon = _severityIcon(issue.severity);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(icon, color: color, size: 24),
        title: Text(
          issue.finding.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              // Category tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _categoryLabel(issue.category, l10n),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              // Affected count tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${issue.affectedCount} ${issue.finding.entityType}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Safe badge or Manual review badge
              if (issue.isSafeAutoRepair)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 12,
                        color: Colors.green.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.repairSafeBadge,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.amber.shade800.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 12,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.diagnosticsManualReviewRequired,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        children: [
          const Divider(height: 16),
          // Explanation
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              issue.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Planned Change Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      issue.isSafeAutoRepair
                          ? Icons.build_outlined
                          : Icons.info_outline,
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.repairPlannedChange,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  issue.plannedChange,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (issue.affectedIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${l10n.diagnosticsAffectedIds} (${issue.affectedIds.length}):',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _buildAffectedIdsWrap(issue, l10n, theme, cs),
            ),
          ],
          const SizedBox(height: 14),
          // Action button (Fix or Review)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: issue.isSafeAutoRepair
                ? FilledButton.icon(
                    icon: const Icon(Icons.build_outlined, size: 18),
                    label: Text(l10n.repairActionFix),
                    onPressed: _isRepairing ? null : () => _fixSingleIssue(issue),
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: Text(l10n.repairActionReview),
                    onPressed: () => _showManualReviewGuidance(issue),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAffectedIdsWrap(
    RepairableIssue issue,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    const int maxVisibleIds = 20;
    final totalIds = issue.affectedIds.length;
    final visibleIds = issue.affectedIds.take(maxVisibleIds).toList();
    final remainingCount = totalIds - maxVisibleIds;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...visibleIds.map(
          (id) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#$id',
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$remainingCount ${l10n.diagnosticsMoreIds}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDisclaimer(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.diagnosticsDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
