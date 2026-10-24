import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/database_diagnostic.dart';
import '../models/document_status.dart';
import 'backup_service.dart';
import 'database_diagnostic_service.dart';

/// Represents an actionable database issue evaluated for repair safety.
class RepairableIssue {
  final DiagnosticFinding finding;
  final String title;
  final String explanation;
  final DiagnosticSeverity severity;
  final DiagnosticCategory category;
  final int affectedCount;
  final List<int> affectedIds;
  final String plannedChange;
  final String recommendedAction;
  final bool isSafeAutoRepair;
  final bool isReversible;

  const RepairableIssue({
    required this.finding,
    required this.title,
    required this.explanation,
    required this.severity,
    required this.category,
    required this.affectedCount,
    required this.affectedIds,
    required this.plannedChange,
    required this.recommendedAction,
    required this.isSafeAutoRepair,
    this.isReversible = false,
  });

  bool get requiresManualReview => !isSafeAutoRepair;
}

/// Result of executing an individual or batch repair operation.
class RepairResult {
  final bool success;
  final int repairedCount;
  final String message;
  final String? error;
  final String? safetyBackupPath;
  final bool rolledBack;

  const RepairResult({
    required this.success,
    required this.repairedCount,
    required this.message,
    this.error,
    this.safetyBackupPath,
    this.rolledBack = false,
  });
}

/// Service that executes verified, transaction-protected repairs on detected
/// database discrepancies and provides diagnostic report exports.
class DatabaseRepairService {
  DatabaseRepairService._();

  @visibleForTesting
  static Future<String> Function()? safetyBackupOverride;

  /// Resolves the default app SQLite database.
  static Future<Database> resolveDatabase() => DatabaseHelper.instance.database;

  /// Categorizes all raw findings in [report] into structured, action-oriented [RepairableIssue]s.
  static List<RepairableIssue> categorizeReport(
    DatabaseDiagnosticReport report,
    AppLocalizations l10n,
  ) {
    return report.findings.map((f) => _mapFindingToIssue(f, l10n)).toList();
  }

  static RepairableIssue _mapFindingToIssue(
    DiagnosticFinding f,
    AppLocalizations l10n,
  ) {
    final count = f.affectedIds.length;

    switch (f.code) {
      // 1. Orphaned document items
      case 'orphaned_document_items':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'حذف بنود الفواتير اليتيمة التي حُذفت مستنداتها الأصلية لتنظيف قاعدة البيانات.'
              : 'Delete orphaned line items whose parent document no longer exists.',
          recommendedAction: l10n.isArabic
              ? 'إصلاح تلقائي آمن: لا ترتبط هذه البنود بأي مستند ساري.'
              : 'Safe auto-repair: these lines have no active parent document.',
          isSafeAutoRepair: true,
          isReversible: false,
        );

      // 2. Broken receipt references in payments
      case 'broken_receipt_reference_in_payments':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'تصفير معرف سند القبض المحذوف مع الحفاظ التام على سجل سداد الفاتورة.'
              : 'Clear non-existent receipt ID pointer while preserving valid payment allocation.',
          recommendedAction: l10n.isArabic
              ? 'إصلاح تلقائي آمن يزيل الإشارات المعطوبة ويمنع أخطاء المفاتيح الأجنبية.'
              : 'Safe auto-repair: eliminates invalid foreign keys while preserving payment ledger.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      // 3. Broken document references in stock movements
      case 'broken_document_reference_in_movements':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'فك الارتباط بالمستند المحذوف مع الإبقاء على حركة المخزون ورصيد البضاعة دون مساس.'
              : 'Unlink deleted document reference while keeping physical stock balance and history intact.',
          recommendedAction: l10n.isArabic
              ? 'إصلاح تلقائي آمن يحافظ على رصيد المخزون الفعلي ويزيل الخطأ العلائقي.'
              : 'Safe auto-repair: preserves physical stock and cleans broken relational link.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      // 4. Broken related document references
      case 'broken_related_document_in_documents':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'إلغاء الإشارة إلى المستند المرتبط المحذوف لمنع تعارض القيود.'
              : 'Clear reference to non-existent related document.',
          recommendedAction: l10n.isArabic
              ? 'إصلاح تلقائي آمن يزيل التعارض العلائقي.'
              : 'Safe auto-repair: cleans broken relation pointer.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      // 5. Orphaned stocktake items
      case 'orphaned_stocktake_items':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'حذف بنود الجرد غير المرتبطة بجلسة جرد سارية.'
              : 'Remove unlinked stocktake count items.',
          recommendedAction: l10n.isArabic
              ? 'إصلاح تلقائي آمن لتنظيف سجلات الجرد الملغاة.'
              : 'Safe auto-repair: clean unlinked stocktake rows.',
          isSafeAutoRepair: true,
          isReversible: false,
        );

      // 6. Document remaining mismatch
      case 'document_remaining_calculation_mismatch':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'إعادة احتساب وتحديث الرصيد المتبقي بناءً على الإجمالي والمدفوع: (المتبقي = الإجمالي - المدفوع).'
              : 'Recalculate and update remaining balance: remaining = total - paid.',
          recommendedAction: l10n.isArabic
              ? 'إصلاح تلقائي حتمي يصحح الانحراف الحسابي وفق المعادلة المحاسبية المعتمدة.'
              : 'Safe auto-repair: deterministic arithmetic update to enforce accounting balance.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      // 7. Status mismatches with payments
      case 'document_status_paid_incomplete':
      case 'document_status_unpaid_with_payments':
      case 'document_status_partial_invalid':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'مزامنة حالة المستند تلقائياً مع حجم السداد الفعلي (مدفوع بالكامل، مدفوع جزئياً، أو صادر).'
              : 'Synchronize document status with actual verified payment totals.',
          recommendedAction: l10n.isArabic
              ? 'إصلاح تلقائي حتمي يعتمد على المبالغ النقدية الفعلية المسجلة.'
              : 'Safe auto-repair: sets status deterministically based on paid amounts.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      // 8. Movement total cost mismatch
      case 'movement_total_cost_mismatch':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'إعادة احتساب إجمالي التكلفة وفق حاصل ضرب الكمية في تكلفة الوحدة المقيدة.'
              : 'Recompute movement total cost as abs(quantity) * unit cost.',
          recommendedAction: l10n.isArabic
              ? 'إصلاح تلقائي حسابي بحت.'
              : 'Safe auto-repair: pure arithmetic recalculation.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      // -------------------------------------------------------------
      // ISSUES REQUIRING MANUAL REVIEW (NEVER AUTO-REPAIRED)
      // -------------------------------------------------------------

      case 'active_receipt_missing_payment_record':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'لا يوجد تعديل تلقائي. يتطلب فحص علاقة سند القبض بالفاتورة والقيود المحاسبية يدوياً لمنع ازدواجية السداد.'
              : 'No automatic modification. Payment-to-document relationship and accounting entries must be reviewed manually before repair.',
          recommendedAction: l10n.isArabic
              ? 'راجع سند القبض والفاتورة المرتبطة وتحقق من حالة سداد العميل في كشف الحساب.'
              : 'Review the receipt and parent invoice, and verify customer payment status in their account statement.',
          isSafeAutoRepair: false,
        );

      case 'stock_movement_ledger_mismatch':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'لا يتم تعديل رصيد المخزون الفعلي تلقائياً بالاعتماد على سجل الحركات فقط.'
              : 'Physical stock will not be automatically overwritten based solely on movement history.',
          recommendedAction: l10n.isArabic
              ? 'قم بإجراء جلسة جرد فعلي (Stocktake) للتحقق من الكميات الموجودة في المستودع وتحديث الرصيد.'
              : 'Perform a physical stocktake in Inventory to establish the actual counted stock before adjusting balances.',
          isSafeAutoRepair: false,
        );

      case 'product_negative_average_cost':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'لا يتم تعديل أو حذف التكلفة السالبة تلقائياً للحفاظ على سلامة سجل التكاليف وتدقيق الأرباح.'
              : 'Negative cost will not be automatically cleared or nullified to preserve costing history and auditability.',
          recommendedAction: l10n.isArabic
              ? 'راجع حركات الشراء وتعديلات التكلفة لهذا المنتج وصحح حركة الإدخال المسببة للتكلفة السالبة.'
              : 'Inspect purchase movements and cost adjustments for this product to correct the source transaction causing negative cost.',
          isSafeAutoRepair: false,
        );

      case 'movement_negative_unit_cost':
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'لا يوجد تعديل تلقائي لتكلفة الوحدة السالبة. يتطلب مراجعة مستند الشراء أو قيد التسوية يدوياً.'
              : 'No automatic modification of negative unit cost. Source purchase or adjustment transaction must be reviewed manually.',
          recommendedAction: l10n.isArabic
              ? 'راجع حركة المخزون ومستند الشراء الأصلي لتصحيح تكلفة الوحدة يدوياً.'
              : 'Inspect the movement and source document to correct the unit cost manually.',
          isSafeAutoRepair: false,
        );
      // -------------------------------------------------------------

      case 'document_items_sum_mismatch':
        return RepairableIssue(
          finding: f,
          title: l10n.isArabic
              ? 'عدم تطابق مجموع بنود الفاتورة مع الإجمالي'
              : 'Invoice Items Sum Mismatch',
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'لا يوجد تعديل تلقائي. التعديل التلقائي قد يغير وثائق رسمية أو ضريبية.'
              : 'No automatic modification. Modifying totals automatically could alter official documents.',
          recommendedAction: l10n.isArabic
              ? 'افتح الفاتورة المعنية وراجع بنودها وأسعارها وخصوماتها يدوياً.'
              : 'Open the affected document in the editor and manually reconcile line items.',
          isSafeAutoRepair: false,
        );

      case 'document_overpaid':
        return RepairableIssue(
          finding: f,
          title: l10n.isArabic
              ? 'مبالغ مدفوعة تتجاوز إجمالي المستند'
              : 'Overpaid Document',
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'لا يوجد تعديل تلقائي للمبالغ المالية الفائضة.'
              : 'No automatic modification of financial cash surplus.',
          recommendedAction: l10n.isArabic
              ? 'راجع سندات القبض المرتبطة أو حرر سند استرداد نقدي للعميل.'
              : 'Review payment receipts linked to this document and issue a refund if appropriate.',
          isSafeAutoRepair: false,
        );

      case 'payment_records_less_than_document_paid':
      case 'payment_records_exceed_document_paid':
        return RepairableIssue(
          finding: f,
          title: l10n.isArabic
              ? 'فارق بين سجل المدفوعات والمبلغ المسدد'
              : 'Payment Record Discrepancy',
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'لا يتم حذف أو تعديل أي مدفوعات نقدية تلقائياً.'
              : 'No automatic alteration of payment records.',
          recommendedAction: l10n.isArabic
              ? 'راجع كشف حساب العميل والمدفوعات المقيدة مع المحاسب.'
              : 'Reconcile customer statement and payment rows manually.',
          isSafeAutoRepair: false,
        );

      case 'negative_stock_quantity':
        return RepairableIssue(
          finding: f,
          title: l10n.isArabic
              ? 'رصيد مخزون سالب للبضاعة'
              : 'Negative Physical Stock Balance',
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'لا يمكن تخمين الكميات الحقيقية للبضاعة برمجياً.'
              : 'Cannot programmatically guess physical inventory count.',
          recommendedAction: l10n.isArabic
              ? 'قم بإجراء جلسة جرد مخزني (Stocktake) لإثبات الكمية الفعلية على الرفوف.'
              : 'Perform a physical stocktake in Inventory to establish the actual counted stock.',
          isSafeAutoRepair: false,
        );

      case 'duplicate_document_number':
        return RepairableIssue(
          finding: f,
          title: l10n.isArabic
              ? 'تكرار في أرقام المستندات'
              : 'Duplicate Document Numbers',
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'لا يتم تغيير أرقام الفواتير الصادرة للعملاء تلقائياً.'
              : 'No automatic renaming of issued customer document numbers.',
          recommendedAction: l10n.isArabic
              ? 'راجع المستندات المكررة في شاشة المستندات وقم بتعديل الرقم للمسودة أو المستند المعني.'
              : 'Inspect duplicate documents and manually update numbers to maintain unique audit sequence.',
          isSafeAutoRepair: false,
        );

      default:
        return RepairableIssue(
          finding: f,
          title: f.title,
          explanation: f.explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: l10n.isArabic
              ? 'يتطلب فحصاً محاسبياً يدوياً.'
              : 'Requires manual accounting inspection.',
          recommendedAction: l10n.isArabic
              ? 'راجع السجلات ذات المعرفات المتأثرة للتحقق من صحتها.'
              : 'Review affected record IDs to determine appropriate business action.',
          isSafeAutoRepair: false,
        );
    }
  }

  /// Executes a single repair for [issue] inside a transaction with transactional verification.
  static Future<RepairResult> repairIssue({
    required DatabaseExecutor db,
    required RepairableIssue issue,
    bool createSafetyBackup = true,
  }) async {
    if (!issue.isSafeAutoRepair) {
      return const RepairResult(
        success: false,
        repairedCount: 0,
        message: 'This issue requires manual review and cannot be safely repaired automatically.',
        error: 'Manual review required',
      );
    }

    String? safetyBackupPath;
    if (createSafetyBackup) {
      try {
        safetyBackupPath = safetyBackupOverride != null
            ? await safetyBackupOverride!()
            : await BackupService.createSafetyBackup();
      } catch (e) {
        return RepairResult(
          success: false,
          repairedCount: 0,
          message: 'Failed to create pre-repair safety backup. Repair aborted to prevent data loss.',
          error: e.toString(),
        );
      }
    }

    final database = db is Database ? db : await DatabaseHelper.instance.database;

    try {
      int repairedCount = 0;
      await database.transaction((txn) async {
        repairedCount = await _executeSpecificRepair(txn, issue);

        // Transaction-scoped post-repair verification
        final reportAfter = await DatabaseDiagnosticService.runDiagnostics(db: txn);
        final remainingFinding = reportAfter.findings
            .where((f) => f.code == issue.finding.code)
            .firstOrNull;
        final remainingCount = remainingFinding?.affectedIds.length ?? 0;

        if (remainingCount > 0 && remainingCount >= issue.affectedCount) {
          throw StateError(
            'Post-repair verification failed for ${issue.finding.code}: $remainingCount discrepancies remain.',
          );
        }
      });

      return RepairResult(
        success: true,
        repairedCount: repairedCount,
        message: 'Repair executed and verified successfully.',
        safetyBackupPath: safetyBackupPath,
      );
    } catch (e) {
      return RepairResult(
        success: false,
        repairedCount: 0,
        message: 'Repair failed during transaction. All changes were rolled back.',
        error: e.toString(),
        safetyBackupPath: safetyBackupPath,
        rolledBack: true,
      );
    }
  }

  /// Batch repairs all safe auto-repairable issues in [issues] inside a single transaction.
  static Future<RepairResult> repairAllSafe({
    required DatabaseExecutor db,
    required List<RepairableIssue> issues,
    bool createSafetyBackup = true,
  }) async {
    final safeIssues = issues.where((i) => i.isSafeAutoRepair).toList();
    if (safeIssues.isEmpty) {
      return const RepairResult(
        success: true,
        repairedCount: 0,
        message: 'No safe auto-repairable issues found.',
      );
    }

    String? safetyBackupPath;
    if (createSafetyBackup) {
      try {
        safetyBackupPath = safetyBackupOverride != null
            ? await safetyBackupOverride!()
            : await BackupService.createSafetyBackup();
      } catch (e) {
        return RepairResult(
          success: false,
          repairedCount: 0,
          message: 'Failed to create safety backup. Batch repair aborted.',
          error: e.toString(),
        );
      }
    }

    final database = db is Database ? db : await DatabaseHelper.instance.database;

    try {
      int totalRepaired = 0;
      await database.transaction((txn) async {
        for (final issue in safeIssues) {
          totalRepaired += await _executeSpecificRepair(txn, issue);
        }

        // Transaction-scoped post-repair verification for all safe issues
        final reportAfter = await DatabaseDiagnosticService.runDiagnostics(db: txn);
        for (final issue in safeIssues) {
          final remainingFinding = reportAfter.findings
              .where((f) => f.code == issue.finding.code)
              .firstOrNull;
          final remainingCount = remainingFinding?.affectedIds.length ?? 0;

          if (remainingCount > 0 && remainingCount >= issue.affectedCount) {
            throw StateError(
              'Batch repair verification failed for ${issue.finding.code}: $remainingCount discrepancies remain.',
            );
          }
        }
      });

      return RepairResult(
        success: true,
        repairedCount: totalRepaired,
        message: 'All safe issues were repaired and verified successfully.',
        safetyBackupPath: safetyBackupPath,
      );
    } catch (e) {
      return RepairResult(
        success: false,
        repairedCount: 0,
        message: 'Batch repair failed during transaction. All operations were rolled back.',
        error: e.toString(),
        safetyBackupPath: safetyBackupPath,
        rolledBack: true,
      );
    }
  }

  static Future<int> _executeSpecificRepair(
    Transaction txn,
    RepairableIssue issue,
  ) async {
    final ids = issue.affectedIds;
    if (ids.isEmpty) return 0;
    final inList = ids.join(',');

    switch (issue.finding.code) {
      case 'orphaned_document_items':
        return await txn.rawDelete(
          'DELETE FROM document_items WHERE id IN ($inList)',
        );

      case 'broken_receipt_reference_in_payments':
        return await txn.rawUpdate(
          'UPDATE document_payments SET receipt_document_id = NULL WHERE id IN ($inList)',
        );

      case 'broken_document_reference_in_movements':
        return await txn.rawUpdate(
          'UPDATE stock_movements SET reference_document_id = NULL WHERE id IN ($inList)',
        );

      case 'broken_related_document_in_documents':
        return await txn.rawUpdate(
          'UPDATE documents SET related_document_id = NULL WHERE id IN ($inList)',
        );

      case 'orphaned_stocktake_items':
        return await txn.rawDelete(
          'DELETE FROM stocktake_items WHERE id IN ($inList)',
        );

      case 'document_remaining_calculation_mismatch':
        return await txn.rawUpdate('''
          UPDATE documents
          SET remaining = CASE
            WHEN total - paid < 0 THEN 0.0
            ELSE ROUND(total - paid, 2)
          END
          WHERE id IN ($inList)
        ''');

      case 'document_status_paid_incomplete':
      case 'document_status_unpaid_with_payments':
      case 'document_status_partial_invalid':
        int updated = 0;
        final rows = await txn.rawQuery(
          'SELECT id, total, paid, status FROM documents WHERE id IN ($inList)',
        );
        for (final r in rows) {
          final id = r['id'] as int;
          final total = (r['total'] as num).toDouble();
          final paid = (r['paid'] as num).toDouble();
          final correctStatus = DocumentStatus.fromPayment(paid, total);
          await txn.update(
            'documents',
            {'status': correctStatus},
            where: 'id = ?',
            whereArgs: [id],
          );
          updated++;
        }
        return updated;

      case 'movement_total_cost_mismatch':
        return await txn.rawUpdate('''
          UPDATE stock_movements
          SET total_cost = ROUND(ABS(quantity) * unit_cost, 2)
          WHERE id IN ($inList) AND unit_cost IS NOT NULL AND unit_cost >= 0
        ''');

      default:
        throw UnsupportedError(
          'Automatic repair not permitted for finding: ${issue.finding.code}. Manual review required.',
        );
    }
  }

  /// Generates a clean, privacy-respecting export of the diagnostic report.
  static String exportReportText(
    DatabaseDiagnosticReport report,
    List<RepairableIssue> issues,
    AppLocalizations l10n,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('==============================================');
    buffer.writeln(l10n.isArabic ? 'تقرير فحص وإصلاح قاعدة البيانات — ورقتك' : 'Waraqatak Database Diagnostic & Health Report');
    buffer.writeln('==============================================');
    buffer.writeln('Generated: ${report.executedAt.toIso8601String()}');
    buffer.writeln('Total checks executed: ${report.totalChecksRun}');
    buffer.writeln('Discrepancies found: ${report.findings.length}');
    buffer.writeln('  - Integrity Errors: ${report.errorCount}');
    buffer.writeln('  - Audit Warnings: ${report.warningCount}');
    buffer.writeln('  - Information: ${report.infoCount}');
    buffer.writeln('----------------------------------------------\n');

    if (issues.isEmpty) {
      buffer.writeln(l10n.isArabic ? 'قاعدة البيانات سليمة تماماً ولا توجد مشكلات.' : 'Database is completely clean with zero integrity issues.');
    } else {
      for (var i = 0; i < issues.length; i++) {
        final issue = issues[i];
        buffer.writeln('Issue #${i + 1}: [${issue.severity.name.toUpperCase()}] ${issue.title}');
        buffer.writeln('Category: ${issue.category.name}');
        buffer.writeln('Affected records: ${issue.affectedCount}');
        buffer.writeln('Explanation: ${issue.explanation}');
        buffer.writeln('Auto-repair safe: ${issue.isSafeAutoRepair ? "YES" : "NO"}');
        buffer.writeln('Planned action: ${issue.plannedChange}');
        buffer.writeln('Recommended next step: ${issue.recommendedAction}');
        buffer.writeln('----------------------------------------------');
      }
    }

    return buffer.toString();
  }
}
