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

  group('DatabaseRepairService - Arabic Localization & Accounting Terminology', () {
    test('every DiagnosticCategory maps to clear professional Arabic terminology', () {
      final categories = DiagnosticCategory.values;
      for (final cat in categories) {
        final labelAr = DatabaseRepairService.categoryLabel(cat, l10nAr);
        expect(labelAr, isNotEmpty);
        expect(labelAr, isNot(contains(cat.name))); // Never exposes raw enum name!
      }

      // Check specific accounting terminology requirements:
      expect(DatabaseRepairService.categoryLabel(DiagnosticCategory.paymentMismatch, l10nAr),
          contains('اختلاف بين المبلغ المسدد وسجل المدفوعات'));
      expect(DatabaseRepairService.categoryLabel(DiagnosticCategory.stockDiscrepancy, l10nAr),
          contains('اختلاف رصيد المخزون عن سجل حركة الأصناف'));
      expect(DatabaseRepairService.categoryLabel(DiagnosticCategory.negativeStock, l10nAr),
          contains('رصيد مخزون سالب'));
    });

    test('all 32 diagnostic finding codes produce tailored Arabic titles, explanations, and actions', () {
      const all32Codes = [
        'orphaned_document_items',
        'broken_product_reference_in_items',
        'orphaned_document_payments',
        'broken_receipt_reference_in_payments',
        'orphaned_stock_movements',
        'broken_document_reference_in_movements',
        'broken_related_document_in_documents',
        'orphaned_stocktake_items',
        'document_total_calculation_mismatch',
        'document_items_sum_mismatch',
        'document_remaining_calculation_mismatch',
        'document_overpaid',
        'document_status_paid_incomplete',
        'document_status_unpaid_with_payments',
        'document_status_partial_invalid',
        'payment_records_exceed_document_paid',
        'payment_records_less_than_document_paid',
        'active_receipt_missing_payment_record',
        'cancelled_document_payment_mismatch',
        'stock_movement_ledger_mismatch',
        'missing_opening_stock',
        'negative_stock_quantity',
        'suspicious_nan_or_infinite_stock',
        'legacy_schema_costing_unsupported',
        'product_cost_status_known_missing_cost',
        'product_negative_average_cost',
        'product_held_stock_unknown_cost',
        'movement_known_status_missing_cost',
        'movement_total_cost_mismatch',
        'movement_negative_unit_cost',
        'issued_sale_item_missing_cost',
        'duplicate_document_number',
      ];

      final findings = all32Codes.map((code) => DiagnosticFinding(
        code: code,
        title: 'English title for $code',
        explanation: 'English explanation for $code',
        severity: DiagnosticSeverity.warning,
        category: DiagnosticCategory.orphanedRecord,
        affectedIds: [100],
        entityType: 'document_items',
        requiresManualReview: false,
      )).toList();

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: findings,
        totalChecksRun: 32,
      );

      final issuesAr = DatabaseRepairService.categorizeReport(report, l10nAr);
      expect(issuesAr.length, equals(32));

      for (final issue in issuesAr) {
        expect(issue.title, isNotEmpty);
        expect(issue.explanation, isNotEmpty);
        expect(issue.plannedChange, isNotEmpty);
        expect(issue.recommendedAction, isNotEmpty);

        // Assert no raw English titles leaked in Arabic report:
        expect(issue.title, isNot(startsWith('English title')));
        expect(issue.explanation, isNot(startsWith('English explanation')));

        // Assert Arabic characters present:
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(issue.title), isTrue);
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(issue.explanation), isTrue);
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(issue.plannedChange), isTrue);
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(issue.recommendedAction), isTrue);
      }
    });

    test('exported Arabic report contains zero raw English labels, enums, or table names', () {
      final findings = [
        const DiagnosticFinding(
          code: 'payment_records_less_than_document_paid',
          title: 'Payment records less than document paid',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.paymentMismatch,
          affectedIds: [5, 6],
          explanation: 'Payment rows do not match document paid',
          entityType: 'document_payments',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'stock_movement_ledger_mismatch',
          title: 'Stock movement ledger mismatch',
          severity: DiagnosticSeverity.warning,
          category: DiagnosticCategory.stockDiscrepancy,
          affectedIds: [12, 13, 14],
          explanation: 'Stock quantity differs from movements sum',
          entityType: 'stock_movements',
          requiresManualReview: true,
        ),
      ];

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime(2026, 10, 24, 15, 30, 0),
        findings: findings,
        totalChecksRun: 32,
      );

      final issuesAr = DatabaseRepairService.categorizeReport(report, l10nAr);
      final reportText = DatabaseRepairService.exportReportText(report, issuesAr, l10nAr);

      // 1. Verify Arabic headers and sections
      expect(reportText, contains('تقرير فحص وإصلاح قاعدة البيانات — ورقتك'));
      expect(reportText, contains('تاريخ ووقت الفحص: 2026-10-24 15:30:00'));
      expect(reportText, contains('إجمالي الفحوصات المنفذة: 32'));
      expect(reportText, contains('عدد المشكلات المكتشفة: 2'));
      expect(reportText, contains('أخطاء تكامل البيانات: 1'));
      expect(reportText, contains('تنبيهات التدقيق المحاسبي: 1'));

      // 2. Verify Arabic issue detail labels
      expect(reportText, contains('المشكلة #1: [خطأ تكامل]'));
      expect(reportText, contains('التصنيف: اختلاف بين المبلغ المسدد وسجل المدفوعات'));
      expect(reportText, contains('السجلات المتأثرة: 2 من سجلات المدفوعات'));
      expect(reportText, contains('قابل للإصلاح التلقائي: يتطلب مراجعة يدوية'));
      expect(reportText, contains('الإجراء المخطط:'));
      expect(reportText, contains('الإجراء الموصى به:'));
      expect(reportText, contains('المعرفات المتأثرة: #5, #6'));

      expect(reportText, contains('المشكلة #2: [تنبيه تدقيق]'));
      expect(reportText, contains('التصنيف: اختلاف رصيد المخزون عن سجل حركة الأصناف'));
      expect(reportText, contains('السجلات المتأثرة: 3 من حركات المخزون'));
      expect(reportText, contains('المعرفات المتأثرة: #12, #13, #14'));

      // 3. Verify no raw enum names, table names, or English labels
      expect(reportText, isNot(contains('paymentMismatch')));
      expect(reportText, isNot(contains('stockDiscrepancy')));
      expect(reportText, isNot(contains('document_payments')));
      expect(reportText, isNot(contains('stock_movements')));
      expect(reportText, isNot(contains('Auto-repair safe:')));
      expect(reportText, isNot(contains('Category:')));
      expect(reportText, isNot(contains('Affected records:')));
      expect(reportText, isNot(contains('Explanation:')));
    });

    test('entity types are converted to user-friendly Arabic without exposing raw tables', () {
      expect(l10nAr.diagnosticEntityType('document_items'), equals('بنود المستندات'));
      expect(l10nAr.diagnosticEntityType('products'), equals('أصناف المخزون'));
      expect(l10nAr.diagnosticEntityType('stock_movements'), equals('حركات المخزون'));
      expect(l10nAr.diagnosticEntityType('documents'), equals('مستندات'));
      expect(l10nAr.diagnosticEntityType('document_payments'), equals('سجلات المدفوعات'));
      expect(l10nAr.diagnosticEntityType('stocktake_items'), equals('بنود الجرد'));
      expect(l10nAr.diagnosticEntityType('stocktake_sessions'), equals('جلسات الجرد'));
    });
  });

  group('DatabaseRepairService - Accounting Safety & Payment Invariants', () {
    test('1. Legacy upfront payments without payment rows are protected from automatic repair', () async {
      // Legacy document where upfront payment was stored directly on document without rows in document_payments
      const legacyFinding = DiagnosticFinding(
        code: 'payment_records_less_than_document_paid',
        title: 'Payment records sum is less than document paid balance',
        severity: DiagnosticSeverity.warning,
        category: DiagnosticCategory.paymentMismatch,
        affectedIds: [1001],
        explanation: 'Legacy invoice with upfront paid amount but no individual payment rows',
        entityType: 'documents',
        requiresManualReview: true,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [legacyFinding],
        totalChecksRun: 32,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nAr);
      final issue = issues.first;

      expect(issue.isSafeAutoRepair, isFalse);
      expect(issue.requiresManualReview, isTrue);
      expect(issue.plannedChange, contains('لا يتم حذف أو تعديل أي مدفوعات نقدية'));
      expect(issue.recommendedAction, contains('يتطلب مراجعة محاسبية يدوية'));

      // Execution attempt must be rejected
      final result = await DatabaseRepairService.repairIssue(
        db: FakeDatabaseExecutor(),
        issue: issue,
        createSafetyBackup: false,
        l10n: l10nAr,
      );

      expect(result.success, isFalse);
      expect(result.repairedCount, equals(0));
      expect(result.error, equals('Manual review required'));
      expect(result.message, contains('هذه المشكلة تتطلب مراجعة يدوية ولا يمكن إصلاحها تلقائياً'));
    });

    test('2. Complete and consistent payment rows produce zero unsafe repair issues', () {
      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: const [],
        totalChecksRun: 32,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      expect(issues, isEmpty);

      final reportText = DatabaseRepairService.exportReportText(report, issues, l10nEn);
      expect(reportText, contains('Database is completely clean with zero integrity issues.'));
    });

    test('3. Partial payments with payment records exceeding document paid strictly require manual review', () async {
      // payment_records_exceed_document_paid must never auto-recalculate document.paid
      const excessFinding = DiagnosticFinding(
        code: 'payment_records_exceed_document_paid',
        title: 'Payment records sum exceeds document paid amount',
        severity: DiagnosticSeverity.error,
        category: DiagnosticCategory.paymentMismatch,
        affectedIds: [2001],
        explanation: 'Payment rows sum exceeds document paid balance',
        entityType: 'documents',
        requiresManualReview: true,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [excessFinding],
        totalChecksRun: 32,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nAr);
      final issue = issues.first;

      expect(issue.isSafeAutoRepair, isFalse);
      expect(issue.requiresManualReview, isTrue);

      final result = await DatabaseRepairService.repairIssue(
        db: FakeDatabaseExecutor(),
        issue: issue,
        createSafetyBackup: false,
        l10n: l10nAr,
      );

      expect(result.success, isFalse);
      expect(result.repairedCount, equals(0));
      expect(result.error, equals('Manual review required'));
    });

    test('4. Missing payment records for active receipt require manual review', () async {
      const missingReceiptRowFinding = DiagnosticFinding(
        code: 'active_receipt_missing_payment_record',
        title: 'Active linked receipt/voucher missing payment record',
        severity: DiagnosticSeverity.warning,
        category: DiagnosticCategory.paymentMismatch,
        affectedIds: [3001],
        explanation: 'Active receipt has no row in document_payments',
        entityType: 'documents',
        requiresManualReview: true,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [missingReceiptRowFinding],
        totalChecksRun: 32,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nEn);
      final issue = issues.first;

      expect(issue.isSafeAutoRepair, isFalse);
      expect(issue.requiresManualReview, isTrue);

      final result = await DatabaseRepairService.repairIssue(
        db: FakeDatabaseExecutor(),
        issue: issue,
        createSafetyBackup: false,
        l10n: l10nEn,
      );

      expect(result.success, isFalse);
      expect(result.repairedCount, equals(0));
      expect(result.error, equals('Manual review required'));
    });

    test('5. Cancelled document payment mismatches and reversals are preserved for audit trail', () async {
      const cancelledMismatchFinding = DiagnosticFinding(
        code: 'cancelled_document_payment_mismatch',
        title: 'Payment discrepancy in cancelled document',
        severity: DiagnosticSeverity.warning,
        category: DiagnosticCategory.paymentMismatch,
        affectedIds: [4001],
        explanation: 'Cancelled document has remaining payment rows pending customer refund confirmation',
        entityType: 'documents',
        requiresManualReview: true,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [cancelledMismatchFinding],
        totalChecksRun: 32,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nAr);
      final issue = issues.first;

      expect(issue.isSafeAutoRepair, isFalse);
      expect(issue.requiresManualReview, isTrue);
      expect(issue.plannedChange, contains('لا يتم حذف المدفوعات المسجلة تلقائياً'));

      final result = await DatabaseRepairService.repairIssue(
        db: FakeDatabaseExecutor(),
        issue: issue,
        createSafetyBackup: false,
        l10n: l10nAr,
      );

      expect(result.success, isFalse);
      expect(result.error, equals('Manual review required'));
    });

    test('6. Failed repair triggers complete transaction rollback and reports rolledBack = true', () async {
      const safeFinding = DiagnosticFinding(
        code: 'orphaned_document_items',
        title: 'Orphaned document items',
        severity: DiagnosticSeverity.error,
        category: DiagnosticCategory.orphanedRecord,
        affectedIds: [5001],
        explanation: 'Items with no parent document',
        entityType: 'document_items',
        requiresManualReview: false,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [safeFinding],
        totalChecksRun: 32,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nAr);
      final issue = issues.first;
      expect(issue.isSafeAutoRepair, isTrue);

      final failingDb = MockRollbackDatabase();

      final result = await DatabaseRepairService.repairIssue(
        db: failingDb,
        issue: issue,
        createSafetyBackup: false,
        l10n: l10nAr,
      );

      expect(result.success, isFalse);
      expect(result.repairedCount, equals(0));
      expect(result.rolledBack, isTrue);
      expect(failingDb.rollbackOccurred, isTrue);
      expect(result.message, contains('فشل الإصلاح أثناء المعاملة. تم التراجع عن جميع التغييرات'));
    });

    test('7. Batch repairAllSafe strictly excludes all payment mismatch issues and preserves payment records', () async {
      final mixedFindings = [
        const DiagnosticFinding(
          code: 'payment_records_less_than_document_paid',
          title: 'Payment records less than paid',
          severity: DiagnosticSeverity.warning,
          category: DiagnosticCategory.paymentMismatch,
          affectedIds: [6001],
          explanation: 'Payment records less than paid',
          entityType: 'documents',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'payment_records_exceed_document_paid',
          title: 'Payment records exceed paid',
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.paymentMismatch,
          affectedIds: [6002],
          explanation: 'Payment records exceed paid',
          entityType: 'documents',
          requiresManualReview: true,
        ),
        const DiagnosticFinding(
          code: 'active_receipt_missing_payment_record',
          title: 'Active receipt missing payment record',
          severity: DiagnosticSeverity.warning,
          category: DiagnosticCategory.paymentMismatch,
          affectedIds: [6003],
          explanation: 'Active receipt missing payment record',
          entityType: 'documents',
          requiresManualReview: true,
        ),
      ];

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: mixedFindings,
        totalChecksRun: 32,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nAr);

      // Verify that NONE of the payment mismatch issues are marked as safe auto-repair
      final safeCount = issues.where((i) => i.isSafeAutoRepair).length;
      expect(safeCount, equals(0));

      final batchResult = await DatabaseRepairService.repairAllSafe(
        db: FakeDatabaseExecutor(),
        issues: issues,
        createSafetyBackup: false,
        l10n: l10nAr,
      );

      expect(batchResult.success, isTrue);
      expect(batchResult.repairedCount, equals(0));
      expect(batchResult.message, contains('لا توجد مشكلات آمنة قابلة للإصلاح التلقائي'));
    });

    test('8. Accurate remaining balance calculation mismatch is strictly arithmetic and does not mutate payments', () {
      const remainingFinding = DiagnosticFinding(
        code: 'document_remaining_calculation_mismatch',
        title: 'Document remaining balance mismatch',
        severity: DiagnosticSeverity.error,
        category: DiagnosticCategory.documentBalanceMismatch,
        affectedIds: [7001],
        explanation: 'Remaining balance does not match total - paid',
        entityType: 'documents',
        requiresManualReview: false,
      );

      final report = DatabaseDiagnosticReport(
        executedAt: DateTime.now(),
        findings: [remainingFinding],
        totalChecksRun: 32,
      );

      final issues = DatabaseRepairService.categorizeReport(report, l10nAr);
      final issue = issues.first;

      // This is an arithmetic repair on the document table itself, leaving paid and payments untouched
      expect(issue.isSafeAutoRepair, isTrue);
      expect(issue.category, equals(DiagnosticCategory.documentBalanceMismatch));
      expect(issue.plannedChange, contains('إعادة احتساب وتحديث الرصيد المتبقي بناءً على الإجمالي والمدفوع'));
    });
  });
}

// Mock database to verify transaction rollback on failure
class MockRollbackDatabase implements Database {
  bool rollbackOccurred = false;

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    try {
      final mockTxn = MockFailingTransaction();
      return await action(mockTxn);
    } catch (e) {
      rollbackOccurred = true;
      rethrow;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFailingTransaction implements Transaction {
  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    throw Exception('Simulated database failure during repair execution');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Dummy DatabaseExecutor to test non-DB branch guards
class FakeDatabaseExecutor implements DatabaseExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
