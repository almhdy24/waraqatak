import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/database_diagnostic.dart';
import 'package:warqatek/services/database_repair_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10nEn = AppLocalizations('en');
  final l10nAr = AppLocalizations('ar');

  group('DatabaseRepairService - Categorization & Safety Guarantees', () {
    test('categorizes verified deterministic issues as isSafeAutoRepair = true', () {
      final safeFindings = [
        const DiagnosticFinding(
          code: 'orphaned_document_items',
          title: 'Orphaned items',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.orphanedRecord,
          affectedIds: [1, 2],
          explanation: 'Items with missing doc',
          entityType: 'items',
          requiresManualReview: false,
        ),
        const DiagnosticFinding(
          code: 'broken_receipt_reference_in_payments',
          title: 'Broken receipt pointer',
          severity: DiagnosticSeverity.warning,
          category: DiagnosticCategory.orphanedRecord,
          affectedIds: [10],
          explanation: 'Receipt missing',
          entityType: 'payments',
          requiresManualReview: false,
        ),
        const DiagnosticFinding(
          code: 'broken_document_reference_in_movements',
          title: 'Broken document pointer',
          severity: DiagnosticSeverity.warning,
          category: DiagnosticCategory.orphanedRecord,
          affectedIds: [20],
          explanation: 'Doc missing',
          entityType: 'movements',
          requiresManualReview: false,
        ),
        const DiagnosticFinding(
          code: 'broken_related_document_in_documents',
          title: 'Broken related doc pointer',
          severity: DiagnosticSeverity.warning,
          category: DiagnosticCategory.orphanedRecord,
          affectedIds: [30],
          explanation: 'Related doc missing',
          entityType: 'documents',
          requiresManualReview: false,
        ),
        const DiagnosticFinding(
          code: 'orphaned_stocktake_items',
          title: 'Orphaned stocktake item',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.orphanedRecord,
          affectedIds: [40],
          explanation: 'Session missing',
          entityType: 'stocktake_items',
          requiresManualReview: false,
        ),
        const DiagnosticFinding(
          code: 'document_remaining_calculation_mismatch',
          title: 'Remaining mismatch',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.documentBalanceMismatch,
          affectedIds: [100],
          explanation: 'remaining != total - paid',
          entityType: 'documents',
          requiresManualReview: false,
        ),
        const DiagnosticFinding(
          code: 'document_status_paid_incomplete',
          title: 'Status paid incomplete',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.documentStatusMismatch,
          affectedIds: [101],
          explanation: 'status = paid but remaining > 0',
          entityType: 'documents',
          requiresManualReview: false,
        ),
        const DiagnosticFinding(
          code: 'movement_total_cost_mismatch',
          title: 'Movement total cost mismatch',
          severity: DiagnosticSeverity.warning,
          category: DiagnosticCategory.inventoryCosting,
          affectedIds: [301],
          explanation: 'total_cost != quantity * unit_cost',
          entityType: 'stock_movements',
          requiresManualReview: false,
        ),
      ];

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: safeFindings,
        totalChecksRun: 15,
      );

      final issuesEn = DatabaseRepairService.categorizeReport(report, l10nEn);
      expect(issuesEn.length, equals(safeFindings.length));
      for (final issue in issuesEn) {
        expect(issue.isSafeAutoRepair, isTrue,
            reason: '${issue.finding.code} should be safe to auto-repair');
        expect(issue.requiresManualReview, isFalse);
        expect(issue.plannedChange.isNotEmpty, isTrue);
        expect(issue.recommendedAction.isNotEmpty, isTrue);
      }

      final issuesAr = DatabaseRepairService.categorizeReport(report, l10nAr);
      expect(issuesAr.length, equals(safeFindings.length));
      for (final issue in issuesAr) {
        expect(issue.isSafeAutoRepair, isTrue);
      }
    });

    test('categorizes accounting and costing discrepancies strictly as requiresManualReview', () {
      final manualFindings = [
        const DiagnosticFinding(
          code: 'active_receipt_missing_payment_record',
          title: 'Receipt missing payment',
          severity: DiagnosticSeverity.warning,
          category: DiagnosticCategory.paymentMismatch,
          affectedIds: [102],
          explanation: 'Active receipt has no payment row',
          entityType: 'documents',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'stock_movement_ledger_mismatch',
          title: 'Stock mismatch',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.stockDiscrepancy,
          affectedIds: [201],
          explanation: 'Product quantity != sum of movements',
          entityType: 'products',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'product_negative_average_cost',
          title: 'Negative average cost',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.inventoryCosting,
          affectedIds: [401],
          explanation: 'average_cost < 0',
          entityType: 'products',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'movement_negative_unit_cost',
          title: 'Negative unit cost',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.inventoryCosting,
          affectedIds: [402],
          explanation: 'unit_cost < 0',
          entityType: 'stock_movements',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'document_items_sum_mismatch',
          title: 'Items sum mismatch',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.documentBalanceMismatch,
          affectedIds: [501],
          explanation: 'Sum of items != document subtotal',
          entityType: 'documents',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'document_overpaid',
          title: 'Document overpaid',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.documentBalanceMismatch,
          affectedIds: [502],
          explanation: 'Paid amount > total',
          entityType: 'documents',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'payment_records_exceed_document_paid',
          title: 'Payment records exceed paid',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.paymentMismatch,
          affectedIds: [503],
          explanation: 'Sum of payment records > document.paid',
          entityType: 'documents',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'negative_stock_quantity',
          title: 'Negative physical stock',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.negativeStock,
          affectedIds: [504],
          explanation: 'Stock quantity < 0',
          entityType: 'products',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'duplicate_document_number',
          title: 'Duplicate document number',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.duplicateDocumentNumber,
          affectedIds: [505, 506],
          explanation: 'Duplicate document numbers found',
          entityType: 'documents',
          requiresManualReview: true,
        ),
      ];

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: manualFindings,
        totalChecksRun: 15,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      expect(issues.length, equals(manualFindings.length));
      for (final issue in issues) {
        expect(issue.isSafeAutoRepair, isFalse,
            reason: '${issue.finding.code} MUST NOT be auto-repaired');
        expect(issue.requiresManualReview, isTrue);
        expect(issue.recommendedAction.isNotEmpty, isTrue);
      }
    });

    test('rejects repair execution for active_receipt_missing_payment_record', () async {
      final finding = const DiagnosticFinding(
        code: 'active_receipt_missing_payment_record',
        title: 'Receipt missing payment',
        severity: DiagnosticSeverity.warning,
        category: DiagnosticCategory.paymentMismatch,
        affectedIds: [77],
        explanation: 'Active receipt has no payment row',
        entityType: 'documents',
        requiresManualReview: true,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [finding],
        totalChecksRun: 1,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      final result = await DatabaseRepairService.repairIssue(
        db: FakeDatabaseExecutor(),
        issue: issues.first,
        createSafetyBackup: false,
      );

      expect(result.success, isFalse);
      expect(result.repairedCount, equals(0));
      expect(result.error, contains('Manual review required'));
    });

    test('rejects repair execution for stock_movement_ledger_mismatch', () async {
      final finding = const DiagnosticFinding(
        code: 'stock_movement_ledger_mismatch',
        title: 'Stock movement ledger mismatch',
        severity: DiagnosticSeverity.error,
        category: DiagnosticCategory.stockDiscrepancy,
        affectedIds: [88],
        explanation: 'Stock quantity != sum of movements',
        entityType: 'products',
        requiresManualReview: true,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [finding],
        totalChecksRun: 1,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      final result = await DatabaseRepairService.repairIssue(
        db: FakeDatabaseExecutor(),
        issue: issues.first,
        createSafetyBackup: false,
      );

      expect(result.success, isFalse);
      expect(result.repairedCount, equals(0));
      expect(result.error, contains('Manual review required'));
    });

    test('rejects repair execution for product_negative_average_cost', () async {
      final finding = const DiagnosticFinding(
        code: 'product_negative_average_cost',
        title: 'Negative average cost',
        severity: DiagnosticSeverity.error,
        category: DiagnosticCategory.inventoryCosting,
        affectedIds: [99],
        explanation: 'average_cost < 0',
        entityType: 'products',
        requiresManualReview: true,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [finding],
        totalChecksRun: 1,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      final result = await DatabaseRepairService.repairIssue(
        db: FakeDatabaseExecutor(),
        issue: issues.first,
        createSafetyBackup: false,
      );

      expect(result.success, isFalse);
      expect(result.repairedCount, equals(0));
      expect(result.error, contains('Manual review required'));
    });

    test('rejects repair execution for movement_negative_unit_cost', () async {
      final finding = const DiagnosticFinding(
        code: 'movement_negative_unit_cost',
        title: 'Negative unit cost',
        severity: DiagnosticSeverity.error,
        category: DiagnosticCategory.inventoryCosting,
        affectedIds: [601],
        explanation: 'unit_cost < 0',
        entityType: 'stock_movements',
        requiresManualReview: true,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [finding],
        totalChecksRun: 1,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      final result = await DatabaseRepairService.repairIssue(
        db: FakeDatabaseExecutor(),
        issue: issues.first,
        createSafetyBackup: false,
      );

      expect(result.success, isFalse);
      expect(result.repairedCount, equals(0));
      expect(result.error, contains('Manual review required'));
    });

    test('fails safely if safety backup creation throws an error', () async {
      final safeFinding = const DiagnosticFinding(
        code: 'orphaned_document_items',
        title: 'Orphaned items',
        severity: DiagnosticSeverity.error,
        category: DiagnosticCategory.orphanedRecord,
        affectedIds: [1, 2],
        explanation: 'Items with missing doc',
        entityType: 'items',
        requiresManualReview: false,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [safeFinding],
        totalChecksRun: 1,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      final issue = issues.first;

      DatabaseRepairService.safetyBackupOverride = () async {
        throw Exception('Storage full: could not create safety backup');
      };

      try {
        final result = await DatabaseRepairService.repairIssue(
          db: FakeDatabaseExecutor(),
          issue: issue,
          createSafetyBackup: true,
        );

        expect(result.success, isFalse);
        expect(result.message, contains('safety backup'));
        expect(result.error, contains('Storage full'));
      } finally {
        DatabaseRepairService.safetyBackupOverride = null;
      }
    });

    test('repairAllSafe ignores manual review issues and repairs only safe ones', () async {
      final findings = [
        const DiagnosticFinding(
          code: 'orphaned_document_items',
          title: 'Orphaned items',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.orphanedRecord,
          affectedIds: [1],
          explanation: 'Items with missing doc',
          entityType: 'items',
          requiresManualReview: false,
        ),
        const DiagnosticFinding(
          code: 'stock_movement_ledger_mismatch',
          title: 'Stock mismatch',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.stockDiscrepancy,
          affectedIds: [2],
          explanation: 'Stock quantity mismatch',
          entityType: 'products',
          requiresManualReview: true,
        ),
      ];

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: findings,
        totalChecksRun: 2,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      final safeIssues = issues.where((i) => i.isSafeAutoRepair).toList();
      expect(safeIssues.length, equals(1));
      expect(safeIssues.first.finding.code, equals('orphaned_document_items'));
    });
  });

  group('DatabaseRepairService - Report Export', () {
    test('generates formatted privacy-safe report for clean database', () {
      final report = DatabaseDiagnosticReport(
        executedAt: DateTime(2026, 10, 24, 12, 0, 0),
        findings: const [],
        totalChecksRun: 25,
      );

      final textEn = DatabaseRepairService.exportReportText(report, const [], l10nEn);
      expect(textEn, contains('Waraqatak Database Diagnostic & Health Report'));
      expect(textEn, contains('Total checks executed: 25'));
      expect(textEn, contains('Discrepancies found: 0'));
      expect(textEn, contains('Database is completely clean'));

      final textAr = DatabaseRepairService.exportReportText(report, const [], l10nAr);
      expect(textAr, contains('تقرير فحص وإصلاح قاعدة البيانات — ورقتك'));
      expect(textAr, contains('قاعدة البيانات سليمة تماماً'));
    });

    test('generates detailed structured findings report with recommendations', () {
      final findings = [
        const DiagnosticFinding(
          code: 'broken_receipt_reference_in_payments',
          title: 'Broken Receipt Link',
          severity: DiagnosticSeverity.warning,
          category: DiagnosticCategory.orphanedRecord,
          affectedIds: [12, 34],
          explanation: 'Receipt pointer is invalid',
          entityType: 'payments',
          requiresManualReview: false,
        ),
        const DiagnosticFinding(
          code: 'document_items_sum_mismatch',
          title: 'Invoice Item Sum Mismatch',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.documentBalanceMismatch,
          affectedIds: [88],
          explanation: 'Line sum does not match header subtotal',
          entityType: 'documents',
          requiresManualReview: true,
        ),
      ];

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime(2026, 10, 24, 12, 0, 0),
        findings: findings,
        totalChecksRun: 25,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      final text = DatabaseRepairService.exportReportText(report, issues, l10nEn);

      expect(text, contains('Discrepancies found: 2'));
      expect(text, contains('Issue #1: [WARNING]'));
      expect(text, contains('Auto-repair safe: YES'));
      expect(text, contains('Issue #2: [ERROR]'));
      expect(text, contains('Auto-repair safe: NO'));
      expect(text, contains('Planned action:'));
      expect(text, contains('Recommended next step:'));
    });
  });
}

// Dummy DatabaseExecutor to test non-DB branch guards
class FakeDatabaseExecutor implements DatabaseExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
