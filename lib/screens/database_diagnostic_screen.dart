import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../localization/app_localizations.dart';
import '../models/database_diagnostic.dart';
import '../services/database_diagnostic_service.dart';
import '../utils/error_utils.dart';
import '../widgets/responsive.dart';

/// Read-only diagnostic preview screen presenting data integrity and accounting checks.
///
/// This screen performs strictly read-only SELECT queries via [DatabaseDiagnosticService]
/// and never mutates, repairs, or deletes business data.
class DatabaseDiagnosticScreen extends StatefulWidget {
  final DatabaseExecutor? db;

  const DatabaseDiagnosticScreen({super.key, this.db});

  @override
  State<DatabaseDiagnosticScreen> createState() =>
      _DatabaseDiagnosticScreenState();
}

class _DatabaseDiagnosticScreenState extends State<DatabaseDiagnosticScreen> {
  DatabaseDiagnosticReport? _report;
  bool _loading = false;
  bool _isScanning = false;
  Object? _error;
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
      setState(() {
        _report = report;
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

  List<DiagnosticFinding> _getFilteredFindings() {
    if (_report == null) return const [];
    if (_selectedCategory == null) return _report!.findings;
    return _report!.findings
        .where((f) => f.category == _selectedCategory)
        .toList();
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
        title: Text(l10n.databaseDiagnosticsTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.diagnosticsRefresh,
            onPressed: (_loading || _isScanning) ? null : _runDiagnostics,
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
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.diagnosticsScanning,
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
    final filteredFindings = _getFilteredFindings();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Summary Cards
        _buildSummaryCards(report, l10n, theme, cs),
        const SizedBox(height: 12),

        // Execution info row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.diagnosticsTotalChecks}: ${report.totalChecksRun}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${l10n.diagnosticsLastScan}: ${_dateTimeFmt.format(report.executedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Category Filter Chips
        _buildCategoryFilters(report, l10n, theme, cs),
        const SizedBox(height: 12),

        // Findings List
        if (filteredFindings.isEmpty)
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
          ...filteredFindings.map(
            (finding) => _buildFindingCard(finding, l10n, theme, cs),
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
    // Collect categories that actually have findings
    final availableCategories = report.findings.map((f) => f.category).toSet();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text(
              '${l10n.diagnosticsCategoryAll} (${report.findings.length})',
            ),
            selected: _selectedCategory == null,
            onSelected: (selected) {
              if (selected) setState(() => _selectedCategory = null);
            },
          ),
          ...availableCategories.map((cat) {
            final count = report.findings
                .where((f) => f.category == cat)
                .length;
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

  Widget _buildFindingCard(
    DiagnosticFinding finding,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final color = _severityColor(finding.severity, cs);
    final icon = _severityIcon(finding.severity);

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
          finding.title,
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
                  _categoryLabel(finding.category, l10n),
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
                  '${finding.affectedIds.length} ${finding.entityType}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Manual review badge if required
              if (finding.requiresManualReview)
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
              finding.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
          if (finding.affectedIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${l10n.diagnosticsAffectedIds} (${finding.affectedIds.length}):',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _buildAffectedIdsWrap(finding, l10n, theme, cs),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAffectedIdsWrap(
    DiagnosticFinding finding,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    const int maxVisibleIds = 20;
    final totalIds = finding.affectedIds.length;
    final visibleIds = finding.affectedIds.take(maxVisibleIds).toList();
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
