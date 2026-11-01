import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/database_diagnostic.dart';
import '../models/product.dart';
import '../services/accounting/journal_backfill_service.dart';
import '../services/accounting/ledger_service.dart';
import '../services/database_diagnostic_service.dart';
import '../services/database_repair_service.dart';
import '../utils/error_utils.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';
import 'document_detail_screen.dart';
import 'product_form_screen.dart';
import 'stock_movements_screen.dart';
import 'stocktake/stocktake_screen.dart';

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
  ParityStatus? _parityStatus;

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
      final parity = await JournalBackfillService.checkParityStatus(
        executor: widget.db,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final issues = DatabaseRepairService.categorizeReport(report, l10n);
      setState(() {
        _report = report;
        _issues = issues;
        _parityStatus = parity;
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

    AppSnackBar.show(context, l10n.repairReportCopied);
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
        l10n: l10n,
      );

      if (!mounted) return;

      if (result.success) {
        AppSnackBar.show(
          context,
          '${l10n.repairSuccess}${result.safetyBackupPath != null ? "\n${l10n.repairSafetyBackupCreated}${result.safetyBackupPath}" : ""}',
          severity: AppSnackBarSeverity.success,
        );
      } else {
        AppSnackBar.show(
          context,
          result.message,
          severity: AppSnackBarSeverity.error,
        );
      }

      await _runDiagnostics();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
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
        l10n: l10n,
      );

      if (!mounted) return;

      if (result.success) {
        AppSnackBar.show(
          context,
          '${l10n.repairSuccess} (${result.repairedCount})${result.safetyBackupPath != null ? "\n${l10n.repairSafetyBackupCreated}${result.safetyBackupPath}" : ""}',
          severity: AppSnackBarSeverity.success,
        );
      } else {
        AppSnackBar.show(
          context,
          result.message,
          severity: AppSnackBarSeverity.error,
        );
      }

      await _runDiagnostics();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
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
                          label: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text('#$id'),
                          ),
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
            if (issue.finding.code == 'document_movement_mismatch' ||
                issue.finding.code == 'ledger_movement_inventory_mismatch') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('repairMovementActionButton'),
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(l10n.repairMovementAction),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openPurchaseMovementRepairPreview(issue);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openPurchaseMovementRepairPreview(RepairableIssue issue) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final db = await _resolveDb();

    // 1. Resolve documentId and productId
    int? docId;
    int? prodId;

    final mismatches = issue.finding.metadata?['mismatches'] as List?;
    if (mismatches != null && mismatches.isNotEmpty) {
      final first = mismatches.first as Map<String, dynamic>;
      docId = first['document_id'] as int?;
      prodId = first['product_id'] as int?;
    }

    if (docId == null || prodId == null) {
      if (issue.finding.code == 'document_movement_mismatch' &&
          issue.affectedIds.isNotEmpty) {
        docId = issue.affectedIds.first;
        final items = await db.query(
          'document_items',
          columns: ['product_id'],
          where: 'document_id = ? AND product_id IS NOT NULL',
          whereArgs: [docId],
          limit: 1,
        );
        if (items.isNotEmpty) {
          prodId = items.first['product_id'] as int?;
        }
      } else if (issue.finding.code == 'ledger_movement_inventory_mismatch' &&
          issue.affectedIds.isNotEmpty) {
        prodId = issue.affectedIds.first;
        final docs = await db.rawQuery('''
          SELECT di.document_id
          FROM document_items di
          JOIN documents d ON di.document_id = d.id
          WHERE di.product_id = ? AND d.type = 'purchase'
          ORDER BY d.id DESC LIMIT 1
        ''', [prodId]);
        if (docs.isNotEmpty) {
          docId = docs.first['document_id'] as int?;
        }
      }
    }

    if (docId == null || prodId == null) {
      if (mounted) {
        AppSnackBar.show(
          context,
          l10n.repairFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
      return;
    }

    // Default option is B (neutralize duplicate & adjustment, no P&L loss)
    var chosenOption = PurchaseRepairOption.optionB;

    MovementRepairPreview preview;
    try {
      preview = await DatabaseRepairService.previewPurchaseMovementRepair(
        db: db,
        documentId: docId,
        productId: prodId,
        option: chosenOption,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
          severity: AppSnackBarSeverity.error,
        );
      }
      return;
    }

    if (!mounted) return;

    // Show preview dialog with Option A and Option B selection
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.preview_outlined, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.repairMovementPreviewTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.documents}: #${preview.documentNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview.productName,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.repairExpectedMovement,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${preview.expectedMovement}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.repairActualMovement,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${preview.actualMovement}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.repairSurplusMovement,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${preview.surplusMovement}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.error,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      l10n.repairPlannedChange,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ignore: deprecated_member_use
                    RadioListTile<PurchaseRepairOption>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.repairOptionNeutralize,
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: PurchaseRepairOption.optionB,
                      // ignore: deprecated_member_use
                      groupValue: chosenOption,
                      // ignore: deprecated_member_use
                      onChanged: (val) async {
                        if (val == null) return;
                        final updated =
                            await DatabaseRepairService
                                .previewPurchaseMovementRepair(
                          db: db,
                          documentId: docId!,
                          productId: prodId!,
                          option: val,
                        );
                        setDialogState(() {
                          chosenOption = val;
                          preview = updated;
                        });
                      },
                    ),
                    // ignore: deprecated_member_use
                    RadioListTile<PurchaseRepairOption>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.repairOptionCompensate,
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: PurchaseRepairOption.optionA,
                      // ignore: deprecated_member_use
                      groupValue: chosenOption,
                      // ignore: deprecated_member_use
                      onChanged: (val) async {
                        if (val == null) return;
                        final updated =
                            await DatabaseRepairService
                                .previewPurchaseMovementRepair(
                          db: db,
                          documentId: docId!,
                          productId: prodId!,
                          option: val,
                        );
                        setDialogState(() {
                          chosenOption = val;
                          preview = updated;
                        });
                      },
                    ),
                    const Divider(height: 16),
                    Text(
                      '${l10n.repairAffectedMovementsCount} (${preview.affectedMovements.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...preview.affectedMovements.map(
                      (m) => Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ID #${m['id']} • ${m['type']}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              '${m['quantity']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('repairPreviewCancelButton'),
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(80, 48),
                  ),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  key: const Key('repairPreviewProceedButton'),
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 48),
                  ),
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldProceed != true || !mounted) return;

    // Show AppConfirmDialog for user confirmation
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.repairConfirmTitle,
      message: l10n.repairConfirmMovementBody,
      confirmLabel: l10n.confirm,
      cancelLabel: l10n.cancel,
    );

    if (!confirmed || !mounted) return;

    // Execute repair with confirmation token
    setState(() => _isRepairing = true);
    try {
      final result =
          await DatabaseRepairService.executePurchaseMovementRepair(
        db: db,
        preview: preview,
        confirmationToken: preview.confirmationToken,
        createSafetyBackup: true,
        l10n: l10n,
      );

      if (!mounted) return;

      if (result.success) {
        AppSnackBar.show(
          context,
          '${l10n.repairSuccess}${result.safetyBackupPath != null ? "\n${l10n.repairSafetyBackupCreated}${result.safetyBackupPath}" : ""}',
          severity: AppSnackBarSeverity.success,
        );
      } else {
        AppSnackBar.show(
          context,
          result.message,
          severity: AppSnackBarSeverity.error,
        );
      }

      await _runDiagnostics();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _isRepairing = false);
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
      DiagnosticCategory.accountingReconciliation =>
        l10n.accountingBooksSection,
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
        title: Text(l10n.databaseDiagnosticsTitle),
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
            const SizedBox(height: 16),
            _buildAccountingBooksCard(context, l10n, theme, cs),
            const SizedBox(height: 24),
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

        // Accounting Books Section
        _buildAccountingBooksCard(context, l10n, theme, cs),
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
          issue.title,
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
                  '${issue.affectedCount} ${l10n.diagnosticEntityType(issue.finding.entityType)}',
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

  String _docTypeLabel(String? type, AppLocalizations l10n) {
    return switch (type) {
      'invoice' => l10n.invoice,
      'purchase' => l10n.purchase,
      'quotation' => l10n.quotation,
      'payment_receipt' => l10n.paymentReceipt,
      'expense_voucher' => l10n.expenseVoucher,
      _ => l10n.documents,
    };
  }

  Future<DatabaseExecutor> _resolveDb() async {
    return widget.db ?? await DatabaseHelper.instance.database;
  }

  Future<void> _openSingleRecord(String entityType, int id) async {
    final l10n = AppLocalizations.of(context);
    final db = await _resolveDb();

    switch (entityType) {
      case 'documents':
        final rows = await db.rawQuery(
          'SELECT id, document_number, type FROM documents WHERE id = ?',
          [id],
        );
        if (!mounted) return;
        if (rows.isEmpty) {
          _showRecordNotFoundDialog(context, l10n, id, entityType);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(documentId: id),
          ),
        );
        if (mounted) _runDiagnostics();

      case 'products':
        final rows = await db.rawQuery(
          'SELECT * FROM products WHERE id = ?',
          [id],
        );
        if (!mounted) return;
        if (rows.isEmpty) {
          _showRecordNotFoundDialog(context, l10n, id, entityType);
          return;
        }
        final product = Product.fromMap(rows.first);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(product: product),
          ),
        );
        if (mounted) _runDiagnostics();

      case 'stock_movements':
        final rows = await db.rawQuery('''
          SELECT sm.id, sm.product_id, sm.reference_document_id
          FROM stock_movements sm
          WHERE sm.id = ?
        ''', [id]);
        if (!mounted) return;
        if (rows.isEmpty) {
          _showRecordNotFoundDialog(context, l10n, id, entityType);
          return;
        }
        final refDocId = rows.first['reference_document_id'] as int?;
        if (refDocId != null) {
          final docRows = await db.rawQuery(
            'SELECT id FROM documents WHERE id = ?',
            [refDocId],
          );
          if (docRows.isNotEmpty && mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentDetailScreen(documentId: refDocId),
              ),
            );
            if (mounted) _runDiagnostics();
            return;
          }
        }
        final prodId = rows.first['product_id'] as int?;
        if (prodId != null) {
          final prodRows = await db.rawQuery(
            'SELECT * FROM products WHERE id = ?',
            [prodId],
          );
          if (prodRows.isNotEmpty && mounted) {
            final product = Product.fromMap(prodRows.first);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StockMovementsScreen(initialProduct: product),
              ),
            );
            if (mounted) _runDiagnostics();
            return;
          }
        }
        if (mounted) {
          _showRecordNotFoundDialog(context, l10n, id, entityType);
        }

      case 'document_payments':
        final rows = await db.rawQuery('''
          SELECT dp.id, dp.document_id, dp.receipt_document_id
          FROM document_payments dp
          WHERE dp.id = ?
        ''', [id]);
        if (!mounted) return;
        if (rows.isEmpty) {
          _showRecordNotFoundDialog(context, l10n, id, entityType);
          return;
        }
        final receiptId = rows.first['receipt_document_id'] as int?;
        final docId = rows.first['document_id'] as int?;
        final targetId = receiptId ?? docId;
        if (targetId != null) {
          final docRows = await db.rawQuery(
            'SELECT id FROM documents WHERE id = ?',
            [targetId],
          );
          if (docRows.isNotEmpty && mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentDetailScreen(documentId: targetId),
              ),
            );
            if (mounted) _runDiagnostics();
            return;
          }
        }
        if (mounted) {
          _showRecordNotFoundDialog(context, l10n, id, entityType);
        }

      case 'document_items':
        final rows = await db.rawQuery(
          'SELECT id, document_id FROM document_items WHERE id = ?',
          [id],
        );
        if (!mounted) return;
        if (rows.isEmpty) {
          _showRecordNotFoundDialog(context, l10n, id, entityType);
          return;
        }
        final docId = rows.first['document_id'] as int?;
        if (docId != null) {
          final docRows = await db.rawQuery(
            'SELECT id FROM documents WHERE id = ?',
            [docId],
          );
          if (docRows.isNotEmpty && mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentDetailScreen(documentId: docId),
              ),
            );
            if (mounted) _runDiagnostics();
            return;
          }
        }
        if (mounted) {
          _showRecordNotFoundDialog(context, l10n, id, entityType, isOrphaned: true);
        }

      case 'stocktake_items':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StocktakeScreen()),
        );
        if (mounted) _runDiagnostics();

      default:
        _showRecordNotFoundDialog(context, l10n, id, entityType);
    }
  }

  void _showRecordNotFoundDialog(
    BuildContext context,
    AppLocalizations l10n,
    int id,
    String entityType, {
    bool isOrphaned = false,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline, color: Colors.orange, size: 36),
        title: Text(l10n.diagnosticsRecordUnavailable),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOrphaned
                  ? l10n.diagnosticsRecordOrphanedDesc
                  : l10n.diagnosticsRecordUnavailableDesc,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#$id (${l10n.diagnosticEntityType(entityType)})',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _showAffectedRecordsSheet(RepairableIssue issue) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entityType = issue.finding.entityType;
    final ids = issue.affectedIds;
    final db = await _resolveDb();

    final records = await _fetchRecordDetails(db, entityType, ids, l10n);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetCtx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.list_alt_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.diagnosticsAffectedRecordsTitle} (${ids.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: records.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (listCtx, idx) {
                  final rec = records[idx];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: rec.exists
                          ? cs.primaryContainer.withValues(alpha: 0.5)
                          : Colors.orange.withValues(alpha: 0.15),
                      child: Icon(
                        rec.icon,
                        color: rec.exists ? cs.primary : Colors.orange.shade800,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      rec.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: rec.subtitle != null
                        ? Text(
                            rec.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        : null,
                    trailing: Icon(
                      AppIcons.chevronForward(context),
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _openSingleRecord(entityType, rec.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_DiagnosticRecordDetails>> _fetchRecordDetails(
    DatabaseExecutor db,
    String entityType,
    List<int> ids,
    AppLocalizations l10n,
  ) async {
    final list = <_DiagnosticRecordDetails>[];
    if (ids.isEmpty) return list;
    final inList = ids.join(',');

    switch (entityType) {
      case 'documents':
        final rows = await db.rawQuery(
          'SELECT id, document_number, type, date, recipient_name, total FROM documents WHERE id IN ($inList)',
        );
        final rowMap = {for (final r in rows) r['id'] as int: r};
        for (final id in ids) {
          final r = rowMap[id];
          if (r != null) {
            final typeLabel = _docTypeLabel(r['type'] as String?, l10n);
            final docNum = r['document_number'] as String? ?? '#$id';
            final recipient = r['recipient_name'] as String?;
            final date = r['date'] as String?;
            final total = (r['total'] as num?)?.toDouble() ?? 0.0;
            final subParts = [
              if (recipient != null && recipient.isNotEmpty) recipient,
              if (date != null) date.split('T').first,
              total.toStringAsFixed(2),
            ];
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '$typeLabel: $docNum',
                subtitle: subParts.join(' • '),
                icon: Icons.description_outlined,
                exists: true,
              ),
            );
          } else {
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '#$id (${l10n.documentNotFoundDesc})',
                icon: Icons.broken_image_outlined,
                exists: false,
              ),
            );
          }
        }

      case 'products':
        final rows = await db.rawQuery(
          'SELECT id, name, sku, stock_quantity FROM products WHERE id IN ($inList)',
        );
        final rowMap = {for (final r in rows) r['id'] as int: r};
        for (final id in ids) {
          final r = rowMap[id];
          if (r != null) {
            final name = r['name'] as String;
            final qty = (r['stock_quantity'] as num?)?.toDouble() ?? 0.0;
            final sku = r['sku'] as String?;
            final sub = [
              if (sku != null && sku.isNotEmpty) 'SKU: $sku',
              '${l10n.stock}: $qty',
            ].join(' • ');
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '${l10n.product}: $name',
                subtitle: sub,
                icon: Icons.inventory_2_outlined,
                exists: true,
              ),
            );
          } else {
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '#$id (${l10n.diagnosticsRecordUnavailable})',
                icon: Icons.broken_image_outlined,
                exists: false,
              ),
            );
          }
        }

      case 'stock_movements':
        final rows = await db.rawQuery('''
          SELECT sm.id, sm.product_id, sm.quantity, sm.movement_type, sm.reference_document_id,
                 p.name AS product_name, d.document_number, d.type AS document_type
          FROM stock_movements sm
          LEFT JOIN products p ON sm.product_id = p.id
          LEFT JOIN documents d ON sm.reference_document_id = d.id
          WHERE sm.id IN ($inList)
        ''');
        final rowMap = {for (final r in rows) r['id'] as int: r};
        for (final id in ids) {
          final r = rowMap[id];
          if (r != null) {
            final pName = r['product_name'] as String? ?? '#${r['product_id']}';
            final qty = (r['quantity'] as num?)?.toDouble() ?? 0.0;
            final qtyStr = qty > 0 ? '+$qty' : '$qty';
            final docNum = r['document_number'] as String?;
            final docType = _docTypeLabel(r['document_type'] as String?, l10n);
            final sub = docNum != null ? '${l10n.relatedDocument}: $docType: $docNum' : null;
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '${l10n.stockMovement}: $pName ($qtyStr)',
                subtitle: sub,
                icon: Icons.swap_horiz_outlined,
                exists: true,
              ),
            );
          } else {
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '#$id',
                icon: Icons.broken_image_outlined,
                exists: false,
              ),
            );
          }
        }

      case 'document_payments':
        final rows = await db.rawQuery('''
          SELECT dp.id, dp.document_id, dp.amount, dp.payment_method, dp.date, dp.receipt_document_id,
                 d.document_number, d.type AS document_type
          FROM document_payments dp
          LEFT JOIN documents d ON dp.document_id = d.id
          WHERE dp.id IN ($inList)
        ''');
        final rowMap = {for (final r in rows) r['id'] as int: r};
        for (final id in ids) {
          final r = rowMap[id];
          if (r != null) {
            final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
            final method = r['payment_method'] as String? ?? '';
            final docNum = r['document_number'] as String?;
            final sub = docNum != null ? '${l10n.parentDocument}: $docNum' : null;
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '${l10n.paymentMethod}: $method (${amt.toStringAsFixed(2)})',
                subtitle: sub,
                icon: Icons.payments_outlined,
                exists: true,
              ),
            );
          } else {
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '#$id',
                icon: Icons.broken_image_outlined,
                exists: false,
              ),
            );
          }
        }

      case 'document_items':
        final rows = await db.rawQuery('''
          SELECT di.id, di.document_id, di.product_name, di.quantity, di.total,
                 d.document_number, d.type AS document_type
          FROM document_items di
          LEFT JOIN documents d ON di.document_id = d.id
          WHERE di.id IN ($inList)
        ''');
        final rowMap = {for (final r in rows) r['id'] as int: r};
        for (final id in ids) {
          final r = rowMap[id];
          if (r != null) {
            final pName = r['product_name'] as String? ?? '#$id';
            final docNum = r['document_number'] as String?;
            final sub = docNum != null
                ? '${l10n.relatedDocument}: $docNum'
                : '${l10n.diagnosticsCategoryOrphaned} (${l10n.diagnosticsRecordUnavailable})';
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '${l10n.item}: $pName',
                subtitle: sub,
                icon: docNum != null ? Icons.receipt_long_outlined : Icons.link_off_outlined,
                exists: docNum != null,
              ),
            );
          } else {
            list.add(
              _DiagnosticRecordDetails(
                id: id,
                title: '#$id',
                icon: Icons.broken_image_outlined,
                exists: false,
              ),
            );
          }
        }

      default:
        for (final id in ids) {
          list.add(
            _DiagnosticRecordDetails(
              id: id,
              title: '#$id',
              icon: Icons.circle_outlined,
              exists: true,
            ),
          );
        }
    }
    return list;
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
    final entityType = issue.finding.entityType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...visibleIds.map(
              (id) => Material(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => _openSingleRecord(entityType, id),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$id',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.open_in_new,
                          size: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (remainingCount > 0)
              Material(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => _showAffectedRecordsSheet(issue),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '+$remainingCount ${l10n.diagnosticsMoreIds}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (totalIds > 1) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.list_alt_rounded, size: 16),
            label: Text(
              '${l10n.diagnosticsViewAffectedRecords} ($totalIds)',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _showAffectedRecordsSheet(issue),
          ),
        ],
      ],
    );
  }

  Widget _buildAccountingBooksCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final parity = _parityStatus;
    final isParity = parity?.isParity ?? false;
    final reportsFromJournal = parity?.reportsFromJournal ?? false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  radius: 18,
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.accountingBooksSection,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        l10n.accountingBooksSectionDesc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isParity
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isParity
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: isParity ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isParity ? '100% OK' : 'Drift',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isParity ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Parity row
            Row(
              children: [
                Icon(
                  isParity
                      ? Icons.verified_outlined
                      : Icons.sync_problem_outlined,
                  size: 18,
                  color: isParity ? Colors.green : cs.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isParity
                        ? l10n.journalParityVerified
                        : l10n.journalParityMismatch,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isParity ? cs.onSurface : cs.error,
                    ),
                  ),
                ),
                Text(
                  '${parity?.entryCount ?? 0} entries',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (!isParity && parity?.mismatchReason != null) ...[
              const SizedBox(height: 6),
              Text(
                parity!.mismatchReason!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            const SizedBox(height: 12),
            // Report switch row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    reportsFromJournal
                        ? Icons.storage_rounded
                        : Icons.auto_awesome_motion_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.journalReportSource,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          reportsFromJournal
                              ? l10n.journalSourcePersisted
                              : l10n.journalSourceDerived,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: reportsFromJournal,
                    onChanged: (val) => _toggleJournalReports(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Backfill trigger button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history_edu_rounded, size: 18),
                label: Text(l10n.triggerJournalBackfill),
                onPressed: _triggerBackfill,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleJournalReports(bool enabled) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.switchJournalReportsTitle,
      message: l10n.switchJournalReportsConfirm,
      confirmLabel: l10n.confirm,
      isDestructive: false,
    );
    if (!confirmed) return;

    await LedgerService.setJournalReportsEnabled(enabled);
    await _runDiagnostics();
    if (!mounted) return;
    AppSnackBar.show(
      context,
      enabled ? l10n.journalSourcePersisted : l10n.journalSourceDerived,
      severity: AppSnackBarSeverity.success,
    );
  }

  Future<void> _triggerBackfill() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.triggerJournalBackfill,
      message: l10n.accountingNote,
      confirmLabel: l10n.confirm,
      isDestructive: false,
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final db = (widget.db is Database)
          ? (widget.db as Database)
          : await DatabaseHelper.instance.database;
      await JournalBackfillService.runBackfill(db);
      await _runDiagnostics();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        l10n.journalBackfillSuccess,
        severity: AppSnackBarSeverity.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.show(
        context,
        ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
        severity: AppSnackBarSeverity.error,
      );
    }
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

class _DiagnosticRecordDetails {
  final int id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool exists;

  const _DiagnosticRecordDetails({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.exists,
  });
}
