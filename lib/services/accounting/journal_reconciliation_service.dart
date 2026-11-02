import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../models/currency.dart';
import '../../models/database_diagnostic.dart';
import '../../utils/money_utils.dart';
import 'journal_backfill_service.dart';
import 'ledger.dart';
import 'ledger_service.dart';

/// Authoritative continuous reconciliation engine for double-entry books (D7).
///
/// Implements 8 strict read-only financial integrity and reconciliation checks.
/// Usable by tests and directly integrated into [DatabaseDiagnosticService].
/// Findings are strictly read-only and require manual review (never auto-fixed).
class JournalReconciliationService {
  JournalReconciliationService._();

  /// Runs all 8 reconciliation checks and returns any identified discrepancies.
  static Future<List<DiagnosticFinding>> runReconciliation({
    DatabaseExecutor? executor,
    AppLocalizations? l10n,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final findings = <DiagnosticFinding>[];

    // Check if journal tables exist and have recorded data
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = 'journal_entries'",
    );
    if (tables.isEmpty) return findings;

    final countRes = await db.rawQuery(
      "SELECT (SELECT COUNT(*) FROM journal_entries) + (SELECT COUNT(*) FROM journal_lines) as c",
    );
    final count = (countRes.first['c'] as num?)?.toInt() ?? 0;
    if (count == 0) return findings;

    // Fetch base currency
    final bRows = await db.query('businesses', limit: 1);
    final business = bRows.isNotEmpty ? Business.fromMap(bRows.first) : null;
    final base = business?.currencyCode ?? 'SDG';
    final decimalDigits = Currency.decimalDigitsForCode(base);

    // 1. Journal balanced per entry and overall
    await _checkJournalBalance(db, findings, l10n);

    // 2. Per source document: journal effect equals what document snapshot implies
    await _checkDocumentJournalEffects(db, findings, decimalDigits, l10n);

    // 3. Account 1140 equals inventory valued from movements
    await _checkInventoryValuation1140(db, findings, base, decimalDigits, l10n);

    // 4. Account 1130 equals sum of remaining on issued sales
    await _checkReceivables1130(db, findings, base, decimalDigits, l10n);

    // 5. Account 2110 equals purchases remaining
    await _checkPayables2110(db, findings, base, decimalDigits, l10n);

    // 6. Products stock quantity equals sum of movements
    await _checkPhysicalStockVsMovements(db, findings, l10n);

    // 7. Orphan journal rows
    await _checkOrphanJournalRows(db, findings, l10n);

    // 8. Parity status vs the derived ledger
    await _checkParityVsDerived(db, findings, base, l10n);

    return findings;
  }

  /// 1. Verifies that every journal entry balances individually in minor units,
  /// and that the entire journal is balanced in aggregate.
  static Future<void> _checkJournalBalance(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
    AppLocalizations? l10n,
  ) async {
    final unbalancedEntries = await db.rawQuery('''
      SELECT entry_id, SUM(debit_minor) as dr, SUM(credit_minor) as cr
      FROM journal_lines
      GROUP BY entry_id
      HAVING dr != cr
    ''');

    if (unbalancedEntries.isNotEmpty) {
      final affectedIds = unbalancedEntries.map((r) => (r['entry_id'] as num).toInt()).toList();
      findings.add(DiagnosticFinding(
        code: 'unbalanced_journal_entry',
        category: DiagnosticCategory.accountingReconciliation,
        severity: DiagnosticSeverity.error,
        entityType: 'journal_entries',
        affectedIds: affectedIds,
        title: l10n != null ? 'قيود يومية غير متوازنة' : 'Unbalanced Journal Entries',
        explanation: l10n != null
            ? 'يوجد ${affectedIds.length} قيد يومية لا يتساوى فيه المدين مع الدائن بالوحدات الصغرى.'
            : '${affectedIds.length} journal entries do not balance in minor units (Debits != Credits).',
        requiresManualReview: true,
        metadata: {'unbalanced_count': affectedIds.length},
      ));
    }

    final overall = await db.rawQuery('''
      SELECT COALESCE(SUM(debit_minor), 0) as dr, COALESCE(SUM(credit_minor), 0) as cr
      FROM journal_lines
    ''');
    if (overall.isNotEmpty) {
      final totalDr = (overall.first['dr'] as num).toInt();
      final totalCr = (overall.first['cr'] as num).toInt();
      if (totalDr != totalCr) {
        findings.add(DiagnosticFinding(
          code: 'unbalanced_overall_journal',
          category: DiagnosticCategory.accountingReconciliation,
          severity: DiagnosticSeverity.error,
          entityType: 'journal_lines',
          affectedIds: const [],
          title: l10n != null ? 'دفتر اليومية العام غير متوازن' : 'Grand Journal Unbalanced',
          explanation: l10n != null
              ? 'إجمالي المدين ($totalDr) لا يساوي إجمالي الدائن ($totalCr) عبر كامل دفتر اليومية.'
              : 'Grand total debits ($totalDr) does not equal grand total credits ($totalCr).',
          requiresManualReview: true,
          metadata: {'total_dr': totalDr, 'total_cr': totalCr},
        ));
      }
    }
  }

  /// 2. Verifies that the net journal posting effect of each issued document matches its document total.
  static Future<void> _checkDocumentJournalEffects(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
    int decimalDigits,
    AppLocalizations? l10n,
  ) async {
    final docs = await db.rawQuery('''
      SELECT id, document_number, type, total, currency_code
      FROM documents
      WHERE type IN ('invoice', 'purchase')
        AND status NOT IN ('draft', 'cancelled')
    ''');

    final discrepantDocIds = <int>[];
    for (final doc in docs) {
      final docId = (doc['id'] as num).toInt();
      final docTotal = (doc['total'] as num).toDouble();
      final expectedMinor = MoneyUtils.toMinorUnits(docTotal, decimalDigits);

      final lines = await db.rawQuery('''
        SELECT l.account_code, l.debit_minor, l.credit_minor
        FROM journal_lines l
        JOIN journal_entries e ON l.entry_id = e.id
        WHERE e.source_id = ? 
          AND e.source_type = ?
          AND e.reverses_entry_id IS NULL
          AND e.id NOT IN (
            SELECT reverses_entry_id FROM journal_entries WHERE reverses_entry_id IS NOT NULL
          )
      ''', [docId, doc['type']]);

      if (lines.isEmpty) continue; // Unposted or foreign currency document

      int journalDocTotalMinor = 0;
      final docType = doc['type'] as String;
      if (docType == 'invoice') {
        // Sales revenue (4100) + VAT output (2120) net credits
        for (final l in lines) {
          final code = l['account_code'] as String;
          if (code == Accounts.salesRevenue.code || code == Accounts.vatOutput.code) {
            journalDocTotalMinor += ((l['credit_minor'] as num).toInt() - (l['debit_minor'] as num).toInt());
          }
        }
      } else {
        // Purchases: Inventory (1140) + operating expenses (6100) + input VAT (1150) net debits
        for (final l in lines) {
          final code = l['account_code'] as String;
          if (code == Accounts.inventory.code ||
              code == Accounts.operatingExpenses.code ||
              code == Accounts.vatInput.code) {
            journalDocTotalMinor += ((l['debit_minor'] as num).toInt() - (l['credit_minor'] as num).toInt());
          }
        }
      }

      if (journalDocTotalMinor != expectedMinor && journalDocTotalMinor > 0) {
        discrepantDocIds.add(docId);
      }
    }

    if (discrepantDocIds.isNotEmpty) {
      findings.add(DiagnosticFinding(
        code: 'document_journal_effect_mismatch',
        category: DiagnosticCategory.accountingReconciliation,
        severity: DiagnosticSeverity.error,
        entityType: 'documents',
        affectedIds: discrepantDocIds,
        title: l10n != null ? 'عدم تطابق أثر القيود مع المستند' : 'Document Journal Effect Mismatch',
        explanation: l10n != null
            ? 'يوجد ${discrepantDocIds.length} مستند لا يتطابق إجمالي قيوده المسجلة في اليومية مع إجمالي المستند.'
            : '${discrepantDocIds.length} documents have a recorded journal posting effect different from document totals.',
        requiresManualReview: true,
        metadata: {'discrepant_count': discrepantDocIds.length},
      ));
    }
  }

  /// 3. Verifies that account 1140 (Inventory) matches the net movement valuation.
  static Future<void> _checkInventoryValuation1140(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
    String baseCurrency,
    int decimalDigits,
    AppLocalizations? l10n,
  ) async {
    final jRes = await db.rawQuery('''
      SELECT COALESCE(SUM(debit_minor) - SUM(credit_minor), 0) as bal
      FROM journal_lines
      WHERE account_code = ?
    ''', [Accounts.inventory.code]);
    final journalBalMinor = jRes.isNotEmpty ? (jRes.first['bal'] as num).toInt() : 0;

    // Derived reference book valuation
    final book = await LedgerService.buildDerived(
      currencyCode: baseCurrency,
      executor: db,
    );
    final derivedTB = AccountingReports.trialBalance(book.entries);
    final derivedBal = derivedTB.rows
        .firstWhere(
          (r) => r.account.code == Accounts.inventory.code,
          orElse: () => AccountBalance(Accounts.inventory, 0, 0),
        )
        .balance;
    final derivedBalMinor = MoneyUtils.toMinorUnits(derivedBal, decimalDigits);

    if (journalBalMinor != derivedBalMinor) {
      findings.add(DiagnosticFinding(
        code: 'inventory_account_valuation_mismatch',
        category: DiagnosticCategory.accountingReconciliation,
        severity: DiagnosticSeverity.warning,
        entityType: 'accounts',
        affectedIds: const [],
        title: l10n != null ? 'عدم تطابق تقييم حساب المخزون 1140' : 'Inventory Account 1140 Valuation Mismatch',
        explanation: l10n != null
            ? 'رصيد حساب المخزون في دفتر اليومية ($journalBalMinor) لا يطابق تقييم حركات المخزون ($derivedBalMinor).'
            : 'Inventory account 1140 balance ($journalBalMinor minor) does not match stock movements valuation ($derivedBalMinor minor).',
        requiresManualReview: true,
        metadata: {'journal_minor': journalBalMinor, 'derived_minor': derivedBalMinor},
      ));
    }
  }

  /// 4. Verifies that account 1130 (Receivables) matches the sum of remaining on issued sales.
  static Future<void> _checkReceivables1130(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
    String baseCurrency,
    int decimalDigits,
    AppLocalizations? l10n,
  ) async {
    final jRes = await db.rawQuery('''
      SELECT COALESCE(SUM(debit_minor) - SUM(credit_minor), 0) as bal
      FROM journal_lines
      WHERE account_code = ?
    ''', [Accounts.receivables.code]);
    final journalBalMinor = jRes.isNotEmpty ? (jRes.first['bal'] as num).toInt() : 0;

    final docRes = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining), 0) as remaining_sum
      FROM documents
      WHERE type = 'invoice'
        AND status NOT IN ('draft', 'cancelled')
        AND currency_code = ?
    ''', [baseCurrency]);
    final remainingSum = docRes.isNotEmpty ? (docRes.first['remaining_sum'] as num).toDouble() : 0.0;
    final expectedMinor = MoneyUtils.toMinorUnits(remainingSum, decimalDigits);

    if (journalBalMinor != expectedMinor) {
      findings.add(DiagnosticFinding(
        code: 'receivables_ledger_mismatch',
        category: DiagnosticCategory.accountingReconciliation,
        severity: DiagnosticSeverity.warning,
        entityType: 'accounts',
        affectedIds: const [],
        title: l10n != null ? 'عدم تطابق حساب الذمم المدينة 1130' : 'Receivables 1130 Reconciliation Discrepancy',
        explanation: l10n != null
            ? 'رصيد حساب الذمم المدينة ($journalBalMinor) لا يطابق مجموع المتبقي على الفواتير الصادرة ($expectedMinor).'
            : 'Receivables 1130 balance ($journalBalMinor minor) does not match sum of remaining on unpaid invoices ($expectedMinor minor).',
        requiresManualReview: true,
        metadata: {'journal_minor': journalBalMinor, 'expected_minor': expectedMinor},
      ));
    }
  }

  /// 5. Verifies that account 2110 (Payables) matches the sum of remaining on issued purchases.
  static Future<void> _checkPayables2110(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
    String baseCurrency,
    int decimalDigits,
    AppLocalizations? l10n,
  ) async {
    final jRes = await db.rawQuery('''
      SELECT COALESCE(SUM(credit_minor) - SUM(debit_minor), 0) as bal
      FROM journal_lines
      WHERE account_code = ?
    ''', [Accounts.payables.code]);
    final journalBalMinor = jRes.isNotEmpty ? (jRes.first['bal'] as num).toInt() : 0;

    final docRes = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining), 0) as remaining_sum
      FROM documents
      WHERE type = 'purchase'
        AND status NOT IN ('draft', 'cancelled')
        AND currency_code = ?
    ''', [baseCurrency]);
    final remainingSum = docRes.isNotEmpty ? (docRes.first['remaining_sum'] as num).toDouble() : 0.0;
    final expectedMinor = MoneyUtils.toMinorUnits(remainingSum, decimalDigits);

    if (journalBalMinor != expectedMinor) {
      findings.add(DiagnosticFinding(
        code: 'payables_ledger_mismatch',
        category: DiagnosticCategory.accountingReconciliation,
        severity: DiagnosticSeverity.warning,
        entityType: 'accounts',
        affectedIds: const [],
        title: l10n != null ? 'عدم تطابق حساب الذمم الدائنة 2110' : 'Payables 2110 Reconciliation Discrepancy',
        explanation: l10n != null
            ? 'رصيد حساب الذمم الدائنة ($journalBalMinor) لا يطابق مجموع المتبقي للموردين في المشتريات ($expectedMinor).'
            : 'Payables 2110 balance ($journalBalMinor minor) does not match sum of remaining on unpaid purchases ($expectedMinor minor).',
        requiresManualReview: true,
        metadata: {'journal_minor': journalBalMinor, 'expected_minor': expectedMinor},
      ));
    }
  }

  /// 6. Verifies that products.stock_quantity equals the cumulative sum of stock movements.
  static Future<void> _checkPhysicalStockVsMovements(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
    AppLocalizations? l10n,
  ) async {
    final rows = await db.rawQuery('''
      SELECT p.id, p.name, p.stock_quantity, COALESCE(SUM(m.quantity), 0) as movement_sum
      FROM products p
      LEFT JOIN stock_movements m ON p.id = m.product_id
      WHERE p.type = 'product'
      GROUP BY p.id
      HAVING ABS(p.stock_quantity - movement_sum) > 0.0001
    ''');

    if (rows.isNotEmpty) {
      final affectedIds = rows.map((r) => (r['id'] as num).toInt()).toList();
      findings.add(DiagnosticFinding(
        code: 'product_stock_movement_discrepancy',
        category: DiagnosticCategory.accountingReconciliation,
        severity: DiagnosticSeverity.error,
        entityType: 'products',
        affectedIds: affectedIds,
        title: l10n != null ? 'فارق بين رصيد المخزون وسجل الحركات' : 'Stock Quantity vs Movement Ledger Discrepancy',
        explanation: l10n != null
            ? 'يوجد ${affectedIds.length} منتج لا يتطابق رصيده الفعلي مع مجموع حركات المخزون المسجلة.'
            : '${affectedIds.length} products have a stock quantity differing from the sum of recorded stock movements.',
        requiresManualReview: true,
        metadata: {'discrepant_count': affectedIds.length},
      ));
    }
  }

  /// 7. Verifies that no orphaned journal lines or entries exist.
  static Future<void> _checkOrphanJournalRows(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
    AppLocalizations? l10n,
  ) async {
    final orphanLines = await db.rawQuery('''
      SELECT l.id
      FROM journal_lines l
      LEFT JOIN journal_entries e ON l.entry_id = e.id
      WHERE e.id IS NULL
    ''');

    if (orphanLines.isNotEmpty) {
      final lineIds = orphanLines.map((r) => (r['id'] as num).toInt()).toList();
      findings.add(DiagnosticFinding(
        code: 'orphaned_journal_lines',
        category: DiagnosticCategory.accountingReconciliation,
        severity: DiagnosticSeverity.error,
        entityType: 'journal_lines',
        affectedIds: lineIds,
        title: l10n != null ? 'أسطر قيود معلقة بدون قيد رئيسي' : 'Orphaned Journal Lines',
        explanation: l10n != null
            ? 'يوجد ${lineIds.length} سطر قيد محاسبي لا يرتبط بأي قيد يومية رئيسي صالح.'
            : '${lineIds.length} journal lines exist without a corresponding parent journal entry.',
        requiresManualReview: true,
        metadata: {'orphan_count': lineIds.length},
      ));
    }
  }

  /// 8. Verifies 100% parity against the derived reference ledger.
  static Future<void> _checkParityVsDerived(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
    String baseCurrency,
    AppLocalizations? l10n,
  ) async {
    try {
      await JournalBackfillService.verifyParity(executor: db, currencyCode: baseCurrency);
    } catch (e) {
      findings.add(DiagnosticFinding(
        code: 'journal_derived_parity_mismatch',
        category: DiagnosticCategory.accountingReconciliation,
        severity: DiagnosticSeverity.error,
        entityType: 'journal_entries',
        affectedIds: const [],
        title: l10n != null ? 'عدم تطابق بين اليومية والدفتر المشتق' : 'Journal Parity Mismatch vs Derived Ledger',
        explanation: l10n != null
            ? 'فشل اختبار المطابقة بين دفتر اليومية والدفتر المشتق: $e'
            : 'Parity check failed between persisted journal and reference derived ledger: $e',
        requiresManualReview: true,
        metadata: {'error': e.toString()},
      ));
    }
  }
}
