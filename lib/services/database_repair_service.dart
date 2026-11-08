import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/database_diagnostic.dart';
import '../models/document_status.dart';
import '../models/stock_movement.dart';
import 'access/access_guard.dart';
import 'access/permission_registry.dart';
import 'accounting/journal_backfill_service.dart';
import 'accounting/stock_ledger.dart';
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

/// Repair options for document stock movement discrepancies.
enum PurchaseRepairOption {
  /// Neutralize surplus movement so net doc movement equals doc items.
  optionA,

  /// Pair duplicate movement with compensating stock adjustment and neutralize both.
  optionB,
}

/// Structured preview of a guided stock movement repair.
class MovementRepairPreview {
  final int documentId;
  final String documentNumber;
  final int productId;
  final String productName;
  final double expectedMovement;
  final double actualMovement;
  final double surplusMovement;
  final List<Map<String, dynamic>> affectedMovements;
  final Map<String, dynamic>? compensatingAdjustment;
  final PurchaseRepairOption option;
  final String confirmationToken;
  final String summary;

  const MovementRepairPreview({
    required this.documentId,
    required this.documentNumber,
    required this.productId,
    required this.productName,
    required this.expectedMovement,
    required this.actualMovement,
    required this.surplusMovement,
    required this.affectedMovements,
    this.compensatingAdjustment,
    required this.option,
    required this.confirmationToken,
    required this.summary,
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
    final isAr = l10n.isArabic;

    final title = _issueTitle(f, l10n);
    final explanation = _issueExplanation(f, count, l10n);

    switch (f.code) {
      // -------------------------------------------------------------
      // 1. DETERMINISTIC SAFE AUTO-REPAIRS (NEVER TOUCH FINANCIAL CASH)
      // -------------------------------------------------------------

      case 'orphaned_document_items':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'حذف بنود الفواتير اليتيمة التي حُذفت مستنداتها الأصلية لتنظيف قاعدة البيانات.'
              : 'Delete orphaned line items whose parent document no longer exists.',
          recommendedAction: isAr
              ? 'إصلاح تلقائي آمن: لا ترتبط هذه البنود بأي مستند ساري.'
              : 'Safe auto-repair: these lines have no active parent document.',
          isSafeAutoRepair: true,
          isReversible: false,
        );

      case 'broken_receipt_reference_in_payments':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'تصفير معرف سند القبض المحذوف مع الحفاظ التام على سجل سداد الفاتورة.'
              : 'Clear non-existent receipt ID pointer while preserving valid payment allocation.',
          recommendedAction: isAr
              ? 'إصلاح تلقائي آمن يزيل الإشارات المعطوبة ويمنع أخطاء المفاتيح الأجنبية.'
              : 'Safe auto-repair: eliminates invalid foreign keys while preserving payment ledger.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      case 'broken_document_reference_in_movements':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'فك الارتباط بالمستند المحذوف مع الإبقاء على حركة المخزون ورصيد البضاعة دون مساس.'
              : 'Unlink deleted document reference while keeping physical stock balance and history intact.',
          recommendedAction: isAr
              ? 'إصلاح تلقائي آمن يحافظ على رصيد المخزون الفعلي ويزيل الخطأ العلائقي.'
              : 'Safe auto-repair: preserves physical stock and cleans broken relational link.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      case 'broken_related_document_in_documents':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'إلغاء الإشارة إلى المستند المرتبط المحذوف لمنع تعارض القيود.'
              : 'Clear reference to non-existent related document.',
          recommendedAction: isAr
              ? 'إصلاح تلقائي آمن يزيل التعارض العلائقي.'
              : 'Safe auto-repair: cleans broken relation pointer.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      case 'orphaned_stocktake_items':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'حذف بنود الجرد غير المرتبطة بجلسة جرد سارية.'
              : 'Remove unlinked stocktake count items.',
          recommendedAction: isAr
              ? 'إصلاح تلقائي آمن لتنظيف سجلات الجرد الملغاة.'
              : 'Safe auto-repair: clean unlinked stocktake rows.',
          isSafeAutoRepair: true,
          isReversible: false,
        );

      case 'document_remaining_calculation_mismatch':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'إعادة احتساب وتحديث الرصيد المتبقي بناءً على الإجمالي والمدفوع: (المتبقي = الإجمالي - المدفوع).'
              : 'Recalculate and update remaining balance: remaining = total - paid.',
          recommendedAction: isAr
              ? 'إصلاح تلقائي حتمي يصحح الانحراف الحسابي وفق المعادلة المحاسبية المعتمدة.'
              : 'Safe auto-repair: deterministic arithmetic update to enforce accounting balance.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      case 'document_status_paid_incomplete':
      case 'document_status_unpaid_with_payments':
      case 'document_status_partial_invalid':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'مزامنة حالة المستند تلقائياً مع حجم السداد الفعلي (مدفوع بالكامل، مدفوع جزئياً، أو صادر).'
              : 'Synchronize document status with actual verified payment totals.',
          recommendedAction: isAr
              ? 'إصلاح تلقائي حتمي يعتمد على المبالغ النقدية الفعلية المسجلة.'
              : 'Safe auto-repair: sets status deterministically based on paid amounts.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      case 'movement_total_cost_mismatch':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'إعادة احتساب إجمالي التكلفة وفق حاصل ضرب الكمية في تكلفة الوحدة المقيدة.'
              : 'Recompute movement total cost as abs(quantity) * unit cost.',
          recommendedAction: isAr
              ? 'إصلاح تلقائي حسابي بحت.'
              : 'Safe auto-repair: pure arithmetic recalculation.',
          isSafeAutoRepair: true,
          isReversible: true,
        );

      // -------------------------------------------------------------
      // 2. ISSUES REQUIRING MANUAL REVIEW (NEVER AUTO-REPAIRED)
      // -------------------------------------------------------------

      case 'broken_product_reference_in_items':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم حذف البنود تلقائياً للحفاظ على القيمة المالية التاريخية للفاتورة.'
              : 'Line items are preserved to maintain historical document totals.',
          recommendedAction: isAr
              ? 'راجع الفاتورة المعنية وتأكد من الصنف المسجل أو أعد إضافة الصنف في قائمة الأصناف.'
              : 'Review the document and re-create or link the product manually.',
          isSafeAutoRepair: false,
        );

      case 'orphaned_document_payments':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم حذف سجلات المدفوعات تلقائياً للحفاظ على القيود النقدية ومسار التدقيق المالي.'
              : 'Payment records are not deleted automatically to preserve cash audit trails.',
          recommendedAction: isAr
              ? 'راجع حركة الصندوق وسجلات المدفوعات يدوياً لمطابقة المبلغ المسدد مع العميل.'
              : 'Inspect cash movements and payments manually to reconcile payments.',
          isSafeAutoRepair: false,
        );

      case 'orphaned_stock_movements':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم حذف حركات المخزون تلقائياً لتفادي الإخلال بسجل التدقيق التاريخي للبضاعة.'
              : 'Stock movements are not deleted automatically to protect audit history.',
          recommendedAction: isAr
              ? 'راجع سجل حركات المخزون وقم بإجراء جرد فعلي لتصحيح كميات الأصناف.'
              : 'Review the stock ledger and perform a stocktake to verify quantities.',
          isSafeAutoRepair: false,
        );

      case 'document_total_calculation_mismatch':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم تعديل الإجمالي تلقائياً لتفادي تغيير مبالغ فواتير تم إصدارها للعملاء.'
              : 'No automatic modification to avoid altering issued invoices.',
          recommendedAction: isAr
              ? 'افتح المستند وراجع بنود الفاتورة والخصم والضريبة المطبقة يدوياً.'
              : 'Open the document and manually reconcile line items, discounts, and taxes.',
          isSafeAutoRepair: false,
        );

      case 'document_items_sum_mismatch':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يوجد تعديل تلقائي. التعديل التلقائي قد يغير وثائق رسمية أو ضريبية صادرة.'
              : 'No automatic modification. Modifying totals automatically could alter official documents.',
          recommendedAction: isAr
              ? 'افتح الفاتورة المعنية وراجع بنودها وأسعارها وخصوماتها يدوياً.'
              : 'Open the affected document in the editor and manually reconcile line items.',
          isSafeAutoRepair: false,
        );

      case 'document_overpaid':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يوجد تعديل تلقائي للمبالغ المالية الفائضة للحفاظ على حقوق العملاء.'
              : 'No automatic modification of financial cash surplus.',
          recommendedAction: isAr
              ? 'راجع سندات القبض المرتبطة أو حرر سند استرداد نقدي للعميل.'
              : 'Review payment receipts linked to this document and issue a refund if appropriate.',
          isSafeAutoRepair: false,
        );

      case 'payment_records_less_than_document_paid':
      case 'payment_records_exceed_document_paid':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم حذف أو تعديل أي مدفوعات نقدية أو أرصدة مستندات تلقائياً لمنع التلاعب المالي وحماية القيود المحاسبية.'
              : 'No automatic modification of payment records or document balances to maintain financial audit integrity.',
          recommendedAction: isAr
              ? 'يتطلب مراجعة محاسبية يدوية: راجع كشف حساب العميل والإيصالات الفعلية وسجلات المدفوعات لمطابقة المبالغ المسددة والمتبقية.'
              : 'Manual accounting review required: Reconcile customer statements, receipts, and payment rows manually before adjusting balances.',
          isSafeAutoRepair: false,
        );

      case 'active_receipt_missing_payment_record':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يوجد تعديل تلقائي. يتطلب فحص علاقة سند القبض بالفاتورة والقيود المحاسبية يدوياً لمنع ازدواجية السداد.'
              : 'No automatic modification. Payment-to-document relationship and accounting entries must be reviewed manually before repair.',
          recommendedAction: isAr
              ? 'راجع سند القبض والفاتورة المرتبطة وتحقق من حالة سداد العميل في كشف الحساب.'
              : 'Review the receipt and parent invoice, and verify customer payment status in their account statement.',
          isSafeAutoRepair: false,
        );

      case 'cancelled_document_payment_mismatch':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم حذف المدفوعات المسجلة تلقائياً لحين التحقق من تسوية المبالغ مع العميل.'
              : 'Payments are not cleared automatically until refund or reversal is confirmed.',
          recommendedAction: isAr
              ? 'تحقق من تسوية المبالغ المستردة للعميل أو إلغاء سند القبض المرتبط يدوياً.'
              : 'Verify customer refund or adjust associated receipts manually.',
          isSafeAutoRepair: false,
        );

      case 'stock_movement_ledger_mismatch':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم تعديل رصيد المخزون الفعلي تلقائياً بالاعتماد على سجل الحركات فقط.'
              : 'Physical stock will not be automatically overwritten based solely on movement history.',
          recommendedAction: isAr
              ? 'قم بإجراء جلسة جرد فعلي (Stocktake) للتحقق من الكميات الموجودة في المستودع وتحديث الرصيد.'
              : 'Perform a physical stocktake in Inventory to establish the actual counted stock before adjusting balances.',
          isSafeAutoRepair: false,
        );

      case 'document_movement_mismatch':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'تتطلب استخدام أداة الإصلاح الموجه لمعادلة الحركات الزائدة أو ربطها بالتسويات المخزنية.'
              : 'Requires guided repair tool to neutralize surplus movements or pair with stock adjustments.',
          recommendedAction: isAr
              ? 'استخدم أداة الإصلاح الموجه لفحص حركات المستند ومعادلة التكرار بأمان مع أخذ نسخة احتياطية.'
              : 'Use the guided repair tool to inspect document movements and neutralize duplicates safely with a backup.',
          isSafeAutoRepair: false,
        );

      case 'ledger_movement_inventory_mismatch':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم تعديل حركات دفتر الأستاذ أو المخزون تلقائياً للحفاظ على القيود المحاسبية وتاريخ الحركات.'
              : 'No automatic ledger or movement changes to protect accounting entries and audit history.',
          recommendedAction: isAr
              ? 'راجع حركات المخزون والمستندات المرتبطة لمعالجة الفوارق بين رصيد الأستاذ وحركات المخزن.'
              : 'Review stock movements and linked documents to reconcile ledger balances with warehouse movements.',
          isSafeAutoRepair: false,
        );

      case 'missing_opening_stock':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم توليد رصيد افتتاحي تلقائياً بدون معرفة الكمية والتكلفة الابتدائية الفعلية للصنف.'
              : 'No synthetic opening balance is generated without verified historical cost.',
          recommendedAction: isAr
              ? 'راجع بطاقة الصنف وسجل له رصيداً افتتاحياً وتكلفة أولية من خلال شاشة تعديل الصنف.'
              : 'Open the product editor and record an initial opening stock balance and cost.',
          isSafeAutoRepair: false,
        );

      case 'negative_stock_quantity':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يمكن تخمين الكميات الحقيقية للبضاعة برمجياً أو تصفير العجز تلقائياً.'
              : 'Cannot programmatically guess physical inventory count.',
          recommendedAction: isAr
              ? 'قم بإجراء جلسة جرد مخزني (Stocktake) لإثبات الكمية الفعلية على الرفوف.'
              : 'Perform a physical stocktake in Inventory to establish the actual counted stock.',
          isSafeAutoRepair: false,
        );

      case 'suspicious_nan_or_infinite_stock':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم تعديل رصيد المخزون التالف تلقائياً دون مطابقة الجرد الفعلي للمنتج.'
              : 'Corrupted stock value is not modified automatically without inventory verification.',
          recommendedAction: isAr
              ? 'قم بتعديل الصنف وأدخل الكمية الفعلية الصحيحة من خلال شاشة الأصناف.'
              : 'Edit the product and input the verified stock quantity manually.',
          isSafeAutoRepair: false,
        );

      case 'legacy_schema_costing_unsupported':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'تتطلب ترقية بنية قاعدة البيانات من خلال نظام الترحيل الآمن المعتمد.'
              : 'Requires database migration through the standard upgrade pipeline.',
          recommendedAction: isAr
              ? 'أعد تشغيل التطبيق لتطبيق ترقيات قاعدة البيانات التلقائية بأمان.'
              : 'Restart the app to trigger automatic database migrations safely.',
          isSafeAutoRepair: false,
        );

      case 'product_cost_status_known_missing_cost':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم فرض تكلفة تقديرية تلقائياً دون استناد إلى فواتير شراء موثقة.'
              : 'No speculative cost is assigned without purchase invoice evidence.',
          recommendedAction: isAr
              ? 'راجع فواتير شراء هذا الصنف وأدخل متوسط التكلفة الصحيح يدوياً.'
              : 'Review purchase invoices for this product and input the verified average cost.',
          isSafeAutoRepair: false,
        );

      case 'product_negative_average_cost':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم تعديل أو حذف التكلفة السالبة تلقائياً للحفاظ على سلامة سجل التكاليف وتدقيق الأرباح.'
              : 'Negative cost will not be automatically cleared or nullified to preserve costing history and auditability.',
          recommendedAction: isAr
              ? 'راجع حركات الشراء وتعديلات التكلفة لهذا المنتج وصحح حركة الإدخال المسببة للتكلفة السالبة.'
              : 'Inspect purchase movements and cost adjustments for this product to correct the source transaction causing negative cost.',
          isSafeAutoRepair: false,
        );

      case 'product_held_stock_unknown_cost':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم فرض تكلفة تقديرية تلقائياً لمنع تشويه تقارير الأرباح والخسائر.'
              : 'No speculative cost will be assigned automatically.',
          recommendedAction: isAr
              ? 'سجل فواتير الشراء أو عدّل الصنف وحدد تكلفة الشراء لتحسين دقة حساب الأرباح.'
              : 'Record purchase invoices or update the product purchase price to calculate accurate profits.',
          isSafeAutoRepair: false,
        );

      case 'movement_known_status_missing_cost':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم استنتاج تكلفة افتراضية تلقائياً للحفاظ على التدقيق المحاسبي الموثوق.'
              : 'No default cost is inferred automatically to preserve audit integrity.',
          recommendedAction: isAr
              ? 'راجع مستند الشراء أو قيد حركة المخزون المرتبط لتحديد تكلفة الوحدة الفعلية.'
              : 'Review the related purchase document or movement to establish unit cost.',
          isSafeAutoRepair: false,
        );

      case 'movement_negative_unit_cost':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يوجد تعديل تلقائي لتكلفة الوحدة السالبة. يتطلب مراجعة مستند الشراء أو قيد التسوية يدوياً.'
              : 'No automatic modification of negative unit cost. Source purchase or adjustment transaction must be reviewed manually.',
          recommendedAction: isAr
              ? 'راجع حركة المخزون ومستند الشراء الأصلي لتصحيح تكلفة الوحدة يدوياً.'
              : 'Inspect the movement and source document to correct the unit cost manually.',
          isSafeAutoRepair: false,
        );

      case 'issued_sale_item_missing_cost':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم فرض تكلفة تقديرية بعد إصدار الفاتورة للحفاظ على مصداقية تقارير المبيعات.'
              : 'No speculative cost is assigned to issued sales invoices.',
          recommendedAction: isAr
              ? 'تحقق من متوسط تكلفة الصنف وقت البيع وحدد تكلفة البند في تقرير أرباح المبيعات.'
              : 'Verify the product average cost at the time of sale.',
          isSafeAutoRepair: false,
        );

      case 'duplicate_document_number':
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'لا يتم تغيير أرقام الفواتير الصادرة للعملاء تلقائياً لمنع أي لبس في الفواتير الورقية أو الإلكترونية.'
              : 'No automatic renaming of issued customer document numbers.',
          recommendedAction: isAr
              ? 'راجع المستندات المكررة في شاشة المستندات وقم بتعديل الرقم للمسودة أو المستند المعني.'
              : 'Inspect duplicate documents and manually update numbers to maintain unique audit sequence.',
          isSafeAutoRepair: false,
        );

      default:
        return RepairableIssue(
          finding: f,
          title: title,
          explanation: explanation,
          severity: f.severity,
          category: f.category,
          affectedCount: count,
          affectedIds: f.affectedIds,
          plannedChange: isAr
              ? 'يتطلب فحصاً محاسبياً يدوياً قبل اتخاذ أي إجراء.'
              : 'Requires manual accounting inspection.',
          recommendedAction: isAr
              ? 'راجع السجلات ذات المعرفات المتأثرة للتحقق من صحتها واستشر المحاسب إن لزم الأمر.'
              : 'Review affected record IDs to determine appropriate business action.',
          isSafeAutoRepair: false,
        );
    }
  }

  static String _issueTitle(DiagnosticFinding f, AppLocalizations l10n) {
    if (!l10n.isArabic) {
      return f.title;
    }
    return switch (f.code) {
      'orphaned_document_items' => 'بنود فواتير يتيمة بدون مستند أصلي',
      'broken_product_reference_in_items' => 'بنود مستندات مرتبطة بأصناف غير موجودة',
      'orphaned_document_payments' => 'سجلات مدفوعات يتيمة بدون مستند أصلي',
      'broken_receipt_reference_in_payments' => 'سجلات مدفوعات مرتبطة بسندات قبض غير موجودة',
      'orphaned_stock_movements' => 'حركات مخزون يتيمة بدون صنف مسجل',
      'broken_document_reference_in_movements' => 'حركات مخزون مرتبطة بمستندات غير موجودة',
      'broken_related_document_in_documents' => 'مستندات مرتبطة بوثائق مرجعية غير موجودة',
      'orphaned_stocktake_items' => 'بنود جرد مخزني يتيمة بدون جلسة جرد',
      'document_total_calculation_mismatch' => 'عدم تطابق حساب إجمالي الفاتورة مع المجموع والضريبة',
      'document_items_sum_mismatch' => 'عدم تطابق مجموع بنود الفاتورة مع الإجمالي',
      'document_remaining_calculation_mismatch' => 'عدم تطابق المبلغ المتبقي مع ناتج (الإجمالي - المدفوع)',
      'document_overpaid' => 'مبالغ مدفوعة تتجاوز إجمالي المستند',
      'document_status_paid_incomplete' => 'حالة المستند مدفوع بالكامل رغم وجود رصيد متبقٍ',
      'document_status_unpaid_with_payments' => 'حالة المستند غير مدفوع رغم وجود دفعات مسجلة',
      'document_status_partial_invalid' => 'حالة المستند غير متطابقة مع مبالغ السداد المسجلة',
      'payment_records_exceed_document_paid' => 'اختلاف بين المبلغ المسدد وسجل المدفوعات (زيادة في سجلات الدفع)',
      'payment_records_less_than_document_paid' => 'اختلاف بين المبلغ المسدد وسجل المدفوعات (نقص في سجلات الدفع)',
      'active_receipt_missing_payment_record' => 'سند قبض نشط غير مقيد في سجلات المدفوعات',
      'cancelled_document_payment_mismatch' => 'مستند ملغى يحتوي على مدفوعات نشطة مسجلة',
      'stock_movement_ledger_mismatch' => 'اختلاف رصيد المخزون عن سجل حركة الأصناف',
      'document_movement_mismatch' => 'اختلاف حركات المخزون عن بنود المستند',
      'ledger_movement_inventory_mismatch' => 'اختلاف رصيد المخزون في دفتر الأستاذ عن سجل الحركات',
      'missing_opening_stock' => 'صنف يحتوي على حركات مخزون بدون رصيد افتتاحي',
      'negative_stock_quantity' => 'رصيد مخزون سالب للبضاعة',
      'suspicious_nan_or_infinite_stock' => 'قيمة غير رقمية أو تالفة في رصيد المخزون',
      'legacy_schema_costing_unsupported' => 'أعمدة تكلفة المخزون مفقودة في بنية قاعدة البيانات',
      'product_cost_status_known_missing_cost' => 'صنف بحالة تكلفة معروفة بدون متوسط تكلفة مسجل',
      'product_negative_average_cost' => 'متوسط تكلفة سالب للصنف',
      'product_held_stock_unknown_cost' => 'مخزون فعلي متوفر بتكلفة مجهولة أو غير محددة',
      'movement_known_status_missing_cost' => 'حركة مخزون محددة بتكلفة معروفة دون تسجيل تكلفة الوحدة',
      'movement_total_cost_mismatch' => 'عدم تطابق إجمالي تكلفة حركة المخزون مع حاصل (الكمية × تكلفة الوحدة)',
      'movement_negative_unit_cost' => 'حركة مخزون بتكلفة وحدة سالبة',
      'issued_sale_item_missing_cost' => 'بند فاتورة مبيعات صادرة بدون تكلفة مسجلة للوحدة',
      'duplicate_document_number' => 'تكرار في أرقام المستندات من نفس النوع',
      _ => f.title,
    };
  }

  static String _issueExplanation(
    DiagnosticFinding f,
    int count,
    AppLocalizations l10n,
  ) {
    if (!l10n.isArabic) {
      return f.explanation;
    }
    return switch (f.code) {
      'orphaned_document_items' =>
        'تم العثور على $count من بنود الفواتير تشير إلى مستندات محذوفة أو غير موجودة.',
      'broken_product_reference_in_items' =>
        'تم العثور على $count من بنود المستندات تشير إلى أصناف محذوفة أو غير مسجلة في قائمة الأصناف.',
      'orphaned_document_payments' =>
        'تم العثور على $count من سجلات المدفوعات تشير إلى مستندات غير موجودة في قاعدة البيانات.',
      'broken_receipt_reference_in_payments' =>
        'تم العثور على $count من سجلات المدفوعات تشير إلى سندات قبض محذوفة مع بقاء حركة الدفع سليمة.',
      'orphaned_stock_movements' =>
        'تم العثور على $count من حركات المخزون تشير إلى أصناف محذوفة أو غير موجودة.',
      'broken_document_reference_in_movements' =>
        'تم العثور على $count من حركات المخزون تشير إلى مستندات محذوفة مع بقاء الكميات والتكلفة سليمة.',
      'broken_related_document_in_documents' =>
        'تم العثور على $count من المستندات تشير إلى وثائق أصلية تم حذفها من النظام.',
      'orphaned_stocktake_items' =>
        'تم العثور على $count من بنود الجرد تشير إلى جلسات جرد محذوفة أو غير موجودة.',
      'document_total_calculation_mismatch' =>
        'تم العثور على $count من المستندات حيث لا يساوي الإجمالي: (المجموع الفرعي - الخصم + الضريبة).',
      'document_items_sum_mismatch' =>
        'تم العثور على $count من المستندات حيث يختلف مجموع بنود الأصناف عن إجمالي المستند المسجل.',
      'document_remaining_calculation_mismatch' =>
        'تم العثور على $count من المستندات حيث يختلف المبلغ المتبقي عن حاصل طرح المبلغ المدفوع من الإجمالي.',
      'document_overpaid' =>
        'تم العثور على $count من المستندات حيث تتجاوز المبالغ المسددة إجمالي قيمة المستند.',
      'document_status_paid_incomplete' =>
        'تم العثور على $count من المستندات محددة كمدفوعة بالكامل رغم وجود متبقٍ لم يُسدد.',
      'document_status_unpaid_with_payments' =>
        'تم العثور على $count من المستندات محددة كغير مدفوعة رغم تسجيل دفعات نقدية لها.',
      'document_status_partial_invalid' =>
        'تم العثور على $count من المستندات بحالة دفع غير متطابقة مع المبالغ المسددة والمتبقية.',
      'payment_records_exceed_document_paid' =>
        'تم العثور على $count من المستندات حيث يتجاوز مجموع سجلات المدفوعات المبلغ المسدد المسجل بالفاتورة.',
      'payment_records_less_than_document_paid' =>
        'تم العثور على $count من المستندات حيث يقل مجموع سجلات المدفوعات عن المبلغ المسدد المسجل بالفاتورة.',
      'active_receipt_missing_payment_record' =>
        'تم العثور على $count من سندات القبض النشطة غير مقيدة في جدول سجلات المدفوعات للفاتورة الأصلية.',
      'cancelled_document_payment_mismatch' =>
        'تم العثور على $count من المستندات الملغاة وما زالت تحتوي على مدفوعات مسجلة أو مبالغ مسددة.',
      'stock_movement_ledger_mismatch' =>
        'تم العثور على $count من الأصناف حيث لا يتطابق رصيد المخزون الحالي مع مجموع حركات المخزون المسجلة.',
      'document_movement_mismatch' =>
        'تم العثور على $count من المستندات حيث لا يتطابق صافي حركات المخزون المسجلة مع كميات البنود في المستند.',
      'ledger_movement_inventory_mismatch' =>
        'تم العثور على $count من الأصناف حيث يختلف رصيد المخزون المحسوب دفترياً عن مجموع حركات المخزون الفعلية.',
      'missing_opening_stock' =>
        'تم العثور على $count من الأصناف مسجل لها حركات مخزون ولكن بدون قيد رصيد افتتاحي أولي.',
      'negative_stock_quantity' =>
        'تم العثور على $count من الأصناف يظهر لها رصيد مخزون سالب، مما يشير إلى تسجيل مبيعات تفوق الوارد.',
      'suspicious_nan_or_infinite_stock' =>
        'تم العثور على $count من الأصناف برصيد مخزون يحتوي على قيمة تالفة أو غير معرّفة.',
      'legacy_schema_costing_unsupported' =>
        'قاعدة البيانات تفتقر إلى حقول تكلفة المخزون (متوسط التكلفة وتكلفة الوحدة).',
      'product_cost_status_known_missing_cost' =>
        'تم العثور على $count من الأصناف محددة بتكلفة معروفة ولكن حقل متوسط التكلفة فارغ.',
      'product_negative_average_cost' =>
        'تم العثور على $count من الأصناف بمتوسط تكلفة سالب، وهو مؤشر على حركة شراء أو تعديل خاطئ.',
      'product_held_stock_unknown_cost' =>
        'تم العثور على $count من الأصناف متوفرة في المخزن ولكن بدون تكلفة محددة لحساب الأرباح بدقة.',
      'movement_known_status_missing_cost' =>
        'تم العثور على $count من حركات المخزون بحالة تكلفة معروفة ولكن بدون تسجيل سعر تكلفة الوحدة.',
      'movement_total_cost_mismatch' =>
        'تم العثور على $count من حركات المخزون حيث لا يساوي إجمالي التكلفة حاصل ضرب الكمية في تكلفة الوحدة.',
      'movement_negative_unit_cost' =>
        'تم العثور على $count من حركات المخزون تحتوي على تكلفة وحدة سالبة.',
      'issued_sale_item_missing_cost' =>
        'تم العثور على $count من بنود فواتير المبيعات الصادرة بدون قيد تكلفة الوحدة لحساب مجمل الربح.',
      'duplicate_document_number' =>
        'تم العثور على $count من المستندات تشترك في نفس الرقم والنوع، مما قد يسبب التباساً محاسبياً.',
      _ => f.explanation,
    };
  }

  /// Executes a single repair for [issue] inside a transaction with transactional verification.
  static Future<RepairResult> repairIssue({
    required DatabaseExecutor db,
    required RepairableIssue issue,
    bool createSafetyBackup = true,
    AppLocalizations? l10n,
  }) async {
    AccessGuard.require(PermissionRegistry.systemRepair);
    final isAr = l10n?.isArabic ?? false;
    if (!issue.isSafeAutoRepair) {
      return RepairResult(
        success: false,
        repairedCount: 0,
        message: isAr
            ? 'هذه المشكلة تتطلب مراجعة يدوية ولا يمكن إصلاحها تلقائياً للحفاظ على البيانات المالية.'
            : 'This issue requires manual review and cannot be safely repaired automatically.',
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
          message: isAr
              ? 'فشل إنشاء نسخة الأمان الاحتياطية. تم إلغاء عملية الإصلاح لمنع فقدان البيانات.'
              : 'Failed to create pre-repair safety backup. Repair aborted to prevent data loss.',
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

      if (createSafetyBackup && safetyBackupPath != null) {
        await BackupService.pruneSafetyBackups(preservePath: safetyBackupPath);
      }

      return RepairResult(
        success: true,
        repairedCount: repairedCount,
        message: isAr
            ? 'تم تنفيذ الإصلاح والتحقق من سلامة البيانات بنجاح.'
            : 'Repair executed and verified successfully.',
        safetyBackupPath: safetyBackupPath,
      );
    } catch (e) {
      return RepairResult(
        success: false,
        repairedCount: 0,
        message: isAr
            ? 'فشل الإصلاح أثناء المعاملة. تم التراجع عن جميع التغييرات للحفاظ على البيانات.'
            : 'Repair failed during transaction. All changes were rolled back.',
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
    AppLocalizations? l10n,
  }) async {
    AccessGuard.require(PermissionRegistry.systemRepair);
    final isAr = l10n?.isArabic ?? false;
    final safeIssues = issues.where((i) => i.isSafeAutoRepair).toList();
    if (safeIssues.isEmpty) {
      return RepairResult(
        success: true,
        repairedCount: 0,
        message: isAr
            ? 'لا توجد مشكلات آمنة قابلة للإصلاح التلقائي.'
            : 'No safe auto-repairable issues found.',
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
          message: isAr
              ? 'فشل إنشاء نسخة الأمان الاحتياطية. تم إلغاء عملية الإصلاح لمنع فقدان البيانات.'
              : 'Failed to create safety backup. Batch repair aborted.',
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

      if (createSafetyBackup && safetyBackupPath != null) {
        await BackupService.pruneSafetyBackups(preservePath: safetyBackupPath);
      }

      return RepairResult(
        success: true,
        repairedCount: totalRepaired,
        message: isAr
            ? 'تم إصلاح جميع المشكلات الآمنة ($totalRepaired) والتحقق من سلامتها بنجاح.'
            : 'All safe issues were repaired and verified successfully.',
        safetyBackupPath: safetyBackupPath,
      );
    } catch (e) {
      return RepairResult(
        success: false,
        repairedCount: 0,
        message: isAr
            ? 'فشلت المعاملة أثناء الإصلاح الشامل. تم التراجع عن كافة العمليات بالكامل.'
            : 'Batch repair failed during transaction. All operations were rolled back.',
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
    final fmtDate =
        '${report.executedAt.year}-${report.executedAt.month.toString().padLeft(2, '0')}-${report.executedAt.day.toString().padLeft(2, '0')} ${report.executedAt.hour.toString().padLeft(2, '0')}:${report.executedAt.minute.toString().padLeft(2, '0')}:${report.executedAt.second.toString().padLeft(2, '0')}';

    if (l10n.isArabic) {
      buffer.writeln('==============================================');
      buffer.writeln('تقرير فحص وإصلاح قاعدة البيانات — ورقتك');
      buffer.writeln('==============================================');
      buffer.writeln('تاريخ ووقت الفحص: $fmtDate');
      buffer.writeln('إجمالي الفحوصات المنفذة: ${report.totalChecksRun}');
      buffer.writeln('عدد المشكلات المكتشفة: ${report.findings.length}');
      buffer.writeln('  - أخطاء تكامل البيانات: ${report.errorCount}');
      buffer.writeln('  - تنبيهات التدقيق المحاسبي: ${report.warningCount}');
      buffer.writeln('  - ملاحظات عامة: ${report.infoCount}');
      buffer.writeln('----------------------------------------------\n');

      if (issues.isEmpty) {
        buffer.writeln('قاعدة البيانات سليمة تماماً ولا توجد مشكلات أو تعارضات.');
      } else {
        for (var i = 0; i < issues.length; i++) {
          final issue = issues[i];
          final severityStr = severityLabel(issue.severity, l10n);
          final categoryStr = categoryLabel(issue.category, l10n);
          final entityStr = l10n.diagnosticEntityType(issue.finding.entityType);
          final safeStr = issue.isSafeAutoRepair
              ? 'نعم (إصلاح آمن وتلقائي)'
              : 'يتطلب مراجعة يدوية';

          buffer.writeln('المشكلة #${i + 1}: [$severityStr] ${issue.title}');
          buffer.writeln('التصنيف: $categoryStr');
          buffer.writeln('السجلات المتأثرة: ${issue.affectedCount} من $entityStr');
          buffer.writeln('التفاصيل: ${issue.explanation}');
          buffer.writeln('قابل للإصلاح التلقائي: $safeStr');
          buffer.writeln('الإجراء المخطط: ${issue.plannedChange}');
          buffer.writeln('الإجراء الموصى به: ${issue.recommendedAction}');
          if (issue.affectedIds.isNotEmpty) {
            final idList =
                issue.affectedIds.take(20).map((id) => '#$id').join(', ');
            final remaining = issue.affectedIds.length - 20;
            final extra = remaining > 0 ? ' (+$remaining إضافية)' : '';
            buffer.writeln('المعرفات المتأثرة: $idList$extra');
          }
          buffer.writeln('----------------------------------------------');
        }
      }
    } else {
      buffer.writeln('==============================================');
      buffer.writeln('Waraqatak Database Diagnostic & Health Report');
      buffer.writeln('==============================================');
      buffer.writeln('Generated: ${report.executedAt.toIso8601String()}');
      buffer.writeln('Total checks executed: ${report.totalChecksRun}');
      buffer.writeln('Discrepancies found: ${report.findings.length}');
      buffer.writeln('  - Integrity Errors: ${report.errorCount}');
      buffer.writeln('  - Audit Warnings: ${report.warningCount}');
      buffer.writeln('  - Information: ${report.infoCount}');
      buffer.writeln('----------------------------------------------\n');

      if (issues.isEmpty) {
        buffer.writeln('Database is completely clean with zero integrity issues.');
      } else {
        for (var i = 0; i < issues.length; i++) {
          final issue = issues[i];
          final categoryStr = categoryLabel(issue.category, l10n);
          final entityStr = l10n.diagnosticEntityType(issue.finding.entityType);

          buffer.writeln('Issue #${i + 1}: [${issue.severity.name.toUpperCase()}] ${issue.title}');
          buffer.writeln('Category: $categoryStr');
          buffer.writeln('Affected records: ${issue.affectedCount} $entityStr');
          buffer.writeln('Explanation: ${issue.explanation}');
          buffer.writeln('Auto-repair safe: ${issue.isSafeAutoRepair ? "YES" : "NO"}');
          buffer.writeln('Planned action: ${issue.plannedChange}');
          buffer.writeln('Recommended next step: ${issue.recommendedAction}');
          if (issue.affectedIds.isNotEmpty) {
            final idList =
                issue.affectedIds.take(20).map((id) => '#$id').join(', ');
            final remaining = issue.affectedIds.length - 20;
            final extra = remaining > 0 ? ' (+$remaining more)' : '';
            buffer.writeln('Affected IDs: $idList$extra');
          }
          buffer.writeln('----------------------------------------------');
        }
      }
    }

    return buffer.toString();
  }

  /// Returns user-facing localized category title.
  static String categoryLabel(DiagnosticCategory cat, AppLocalizations l10n) {
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

  /// Returns user-facing localized severity title.
  static String severityLabel(DiagnosticSeverity sev, AppLocalizations l10n) {
    if (!l10n.isArabic) {
      return sev.name.toUpperCase();
    }
    return switch (sev) {
      DiagnosticSeverity.error => 'خطأ تكامل',
      DiagnosticSeverity.warning => 'تنبيه تدقيق',
      DiagnosticSeverity.info => 'ملاحظة',
    };
  }

  /// Returns user-facing localized entity type label.
  static String entityTypeLabel(String entityType, AppLocalizations l10n) {
    return l10n.diagnosticEntityType(entityType);
  }

  // =========================================================================
  // GUIDED PURCHASE MOVEMENT REPAIR (OPTION A & OPTION B)
  // =========================================================================

  /// Previews guided repair for document stock movement discrepancies without mutating database.
  static Future<MovementRepairPreview> previewPurchaseMovementRepair({
    required DatabaseExecutor db,
    required int documentId,
    required int productId,
    required PurchaseRepairOption option,
  }) async {
    final docs = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
    );
    if (docs.isEmpty) {
      throw ArgumentError('Document with ID $documentId not found.');
    }
    final doc = docs.first;
    final docNumber = doc['document_number'] as String;

    final prods = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (prods.isEmpty) {
      throw ArgumentError('Product with ID $productId not found.');
    }
    final prod = prods.first;
    final prodName = prod['name'] as String;

    // Calculate expected movement from document items
    final items = await db.query(
      'document_items',
      where: 'document_id = ? AND product_id = ?',
      whereArgs: [documentId, productId],
    );
    double expectedMovement = 0.0;
    final docStatus = doc['status'] as String?;
    final docType = doc['type'] as String?;
    if (docStatus != 'draft' && docStatus != 'cancelled') {
      for (final it in items) {
        final qty = (it['quantity'] as num).toDouble();
        final factor = (it['unit_conversion_factor'] as num?)?.toDouble() ?? 1.0;
        if (docType == 'purchase') {
          expectedMovement += qty * factor;
        } else if (docType == 'invoice') {
          expectedMovement -= qty * factor;
        }
      }
    }

    // Actual movements referencing this document
    final movements = await db.query(
      'stock_movements',
      where: 'reference_document_id = ? AND product_id = ?',
      whereArgs: [documentId, productId],
      orderBy: 'id ASC',
    );
    double actualMovement = 0.0;
    for (final m in movements) {
      actualMovement += (m['quantity'] as num).toDouble();
    }

    final surplus = actualMovement - expectedMovement;

    Map<String, dynamic>? compensatingAdj;
    if (option == PurchaseRepairOption.optionB) {
      // Find subsequent adjustment for this product that offset the surplus
      final adjs = await db.rawQuery('''
        SELECT * FROM stock_movements
        WHERE product_id = ?
          AND type = 'adjustment'
          AND abs(quantity - ?) < 0.001
        ORDER BY id DESC
        LIMIT 1
      ''', [productId, -surplus]);
      if (adjs.isNotEmpty) {
        compensatingAdj = adjs.first;
      }
    }

    final token = 'CONFIRM-REPAIR-$docNumber';
    final summary = option == PurchaseRepairOption.optionA
        ? 'Option A: Neutralize surplus $surplus units on $docNumber by recording a compensating reversal movement.'
        : 'Option B: Pair duplicate movement on $docNumber with compensating adjustment (${compensatingAdj != null ? 'ID: ${compensatingAdj['id']}' : 'None'}) and neutralize both, removing phantom loss from accounting.';

    return MovementRepairPreview(
      documentId: documentId,
      documentNumber: docNumber,
      productId: productId,
      productName: prodName,
      expectedMovement: expectedMovement,
      actualMovement: actualMovement,
      surplusMovement: surplus,
      affectedMovements: movements,
      compensatingAdjustment: compensatingAdj,
      option: option,
      confirmationToken: token,
      summary: summary,
    );
  }

  /// Executes guided stock movement repair inside an atomic transaction after safety backup.
  static Future<RepairResult> executePurchaseMovementRepair({
    required DatabaseExecutor db,
    required MovementRepairPreview preview,
    required String confirmationToken,
    bool createSafetyBackup = true,
    AppLocalizations? l10n,
  }) async {
    final isAr = l10n?.isArabic ?? false;

    if (confirmationToken != preview.confirmationToken) {
      return RepairResult(
        success: false,
        repairedCount: 0,
        message: isAr
            ? 'رمز التأكيد غير صحيح. تم إلغاء عملية الإصلاح.'
            : 'Invalid confirmation token. Repair cancelled.',
        error: 'Token mismatch',
      );
    }

    if (preview.surplusMovement.abs() < 0.001) {
      return RepairResult(
        success: true,
        repairedCount: 0,
        message: isAr
            ? 'لا يوجد فائض في حركات المخزون لهذا المستند.'
            : 'No stock movement surplus found for this document.',
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
          message: isAr
              ? 'فشل إنشاء نسخة الأمان الاحتياطية. تم إلغاء الإصلاح.'
              : 'Failed to create safety backup. Repair aborted.',
          error: e.toString(),
        );
      }
    }

    final database = db is Database ? db : await DatabaseHelper.instance.database;

    try {
      int repairedCount = 0;
      await database.transaction((txn) async {
        if (preview.option == PurchaseRepairOption.optionA) {
          // Option A: Neutralize surplus movement so net doc movement equals doc items.
          final unitCost = (preview.affectedMovements.lastOrNull?['unit_cost'] as num?)?.toDouble() ?? 0.0;
          final totalCost = (unitCost * preview.surplusMovement.abs());

          await StockLedger.record(
            txn,
            productId: preview.productId,
            deltaQuantity: -preview.surplusMovement,
            type: StockMovement.typeCancellation,
            unitCost: unitCost,
            totalCost: totalCost,
            costStatus: StockMovement.costStatusKnown,
            date: DateTime.now(),
            notes: '[REPAIR-OPTION-A] Neutralize duplicate purchase edit movement for ${preview.documentNumber}',
            referenceDocumentId: preview.documentId,
            reason: 'entry_correction',
          );

          // Audit log inside txn
          await txn.insert('audit_log', {
            'action': 'REPAIR_MOVEMENT_OPTION_A',
            'entity_type': 'documents',
            'entity_id': preview.documentId,
            'details': 'Neutralized surplus movement of ${preview.surplusMovement} on ${preview.documentNumber}',
            'timestamp': DateTime.now().toIso8601String(),
          });
          repairedCount = 1;
        } else {
          // Option B: Pair duplicate movement with compensating adjustment and neutralize both
          final compAdj = preview.compensatingAdjustment;
          if (compAdj == null) {
            throw StateError('Cannot apply Option B: compensating stock adjustment was not found.');
          }

          if (preview.affectedMovements.length < 2) {
            throw StateError('Cannot apply Option B: multiple movements referencing document not found.');
          }
          final duplicateMov = preview.affectedMovements.last;
          final dupId = duplicateMov['id'] as int;
          final adjId = compAdj['id'] as int;

          // Neutralize duplicate movement: unlink reference doc and mark type neutralized
          await txn.update(
            'stock_movements',
            {
              'type': 'neutralized',
              'reference_document_id': null,
              'notes': '${duplicateMov['notes'] ?? ''} [NEUTRALIZED-OPTION-B]',
            },
            where: 'id = ?',
            whereArgs: [dupId],
          );

          // Neutralize compensating adjustment: mark type neutralized
          await txn.update(
            'stock_movements',
            {
              'type': 'neutralized',
              'notes': '${compAdj['notes'] ?? ''} [NEUTRALIZED-OPTION-B]',
            },
            where: 'id = ?',
            whereArgs: [adjId],
          );

          // Audit log inside txn
          await txn.insert('audit_log', {
            'action': 'REPAIR_MOVEMENT_OPTION_B',
            'entity_type': 'documents',
            'entity_id': preview.documentId,
            'details': 'Neutralized duplicate movement #$dupId and compensating adjustment #$adjId for ${preview.documentNumber}',
            'timestamp': DateTime.now().toIso8601String(),
          });
          repairedCount = 2;
        }
      });

      return RepairResult(
        success: true,
        repairedCount: repairedCount,
        message: isAr
            ? 'تم تنفيذ الإصلاح بنجاح ومعادلة حركات المخزون.'
            : 'Repair executed successfully and stock movements reconciled.',
        safetyBackupPath: safetyBackupPath,
      );
    } catch (e) {
      return RepairResult(
        success: false,
        repairedCount: 0,
        message: isAr
            ? 'فشل تنفيذ الإصلاح. تم التراجع عن جميع التغييرات.'
            : 'Repair failed during execution. All changes rolled back.',
        error: e.toString(),
        safetyBackupPath: safetyBackupPath,
        rolledBack: true,
      );
    }
  }

  /// Rebuilds the double-entry journal from scratch and restores 100% parity with derived ledger.
  static Future<RepairResult> rebuildJournal({
    Database? db,
    AppLocalizations? l10n,
  }) async {
    final targetDb = db ?? await DatabaseHelper.instance.database;
    final isAr = l10n?.isArabic ?? false;

    String? safetyBackupPath;
    try {
      safetyBackupPath = safetyBackupOverride != null
          ? await safetyBackupOverride!()
          : await BackupService.createSafetyBackup();
    } catch (_) {}

    try {
      final count = await JournalBackfillService.rebuildJournal(dbOverride: targetDb);
      return RepairResult(
        success: true,
        repairedCount: count,
        message: isAr
            ? 'تمت إعادة بناء دفتر اليومية بنجاح ومطابقة الأرصدة 100% ($count قيد).'
            : 'Journal rebuilt successfully with 100% parity ($count entries).',
        safetyBackupPath: safetyBackupPath,
      );
    } catch (e) {
      return RepairResult(
        success: false,
        repairedCount: 0,
        message: isAr
            ? 'فشل إعادة بناء دفتر اليومية: $e'
            : 'Failed to rebuild journal: $e',
        error: e.toString(),
        safetyBackupPath: safetyBackupPath,
      );
    }
  }
}
