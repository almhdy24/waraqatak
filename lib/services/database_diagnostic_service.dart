import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/database_diagnostic.dart';
import '../models/document_status.dart';
import '../models/stock_movement.dart';

/// Read-only diagnostic service that inspects existing Waraqatak SQLite databases
/// for data integrity, accounting, inventory, and relational inconsistencies.
///
/// Principles:
/// - Strictly read-only: executes only SELECT queries.
/// - Never mutates, inserts, deletes, or migrates database records.
/// - Never invents financial amounts, costs, or inventory quantities.
/// - Distinguishes confirmed corruption from suspicious conditions requiring manual review.
/// - Excludes valid legacy representations (e.g. legacy invoices with unlinked upfront payments).
class DatabaseDiagnosticService {
  DatabaseDiagnosticService._();

  static const double _moneyEpsilon = 0.05;
  static const double _balanceEpsilon = 0.01;
  static const double _qtyEpsilon = 0.001;

  /// Runs all available diagnostic checks on the database.
  /// If [db] is not provided, uses [DatabaseHelper.instance.database].
  static Future<DatabaseDiagnosticReport> runDiagnostics({
    DatabaseExecutor? db,
  }) async {
    final executor = db ?? await DatabaseHelper.instance.database;
    final findings = <DiagnosticFinding>[];
    int checksRun = 0;

    // 1. Orphaned records & broken foreign-key relationships
    checksRun += await _checkOrphanedRecords(executor, findings);

    // 2. Document calculations & balances
    checksRun += await _checkDocumentBalances(executor, findings);

    // 3. Document status consistency
    checksRun += await _checkDocumentStatuses(executor, findings);

    // 4. Payment reconciliation & receipts
    checksRun += await _checkPaymentIntegrity(executor, findings);

    // 5. Stock quantities & movement reconciliation
    checksRun += await _checkStockReconciliation(executor, findings);

    // 6. Suspicious stock balances
    checksRun += await _checkStockBalances(executor, findings);

    // 7. Inventory costing consistency
    checksRun += await _checkInventoryCosting(executor, findings);

    // 8. Duplicate document numbers
    checksRun += await _checkDuplicateDocumentNumbers(executor, findings);

    return DatabaseDiagnosticReport(
      executedAt: DateTime.now(),
      totalChecksRun: checksRun,
      findings: findings,
    );
  }

  // =========================================================================
  // 1. ORPHANED RECORDS & BROKEN FOREIGN KEYS
  // =========================================================================

  static Future<int> _checkOrphanedRecords(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
  ) async {
    int checks = 0;

    // 1.1 Orphaned document_items (document does not exist)
    checks++;
    final orphanedItems = await db.rawQuery('''
      SELECT di.id, di.document_id
      FROM document_items di
      LEFT JOIN documents d ON di.document_id = d.id
      WHERE d.id IS NULL
    ''');
    if (orphanedItems.isNotEmpty) {
      final ids = orphanedItems.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'orphaned_document_items',
          category: DiagnosticCategory.orphanedRecord,
          severity: DiagnosticSeverity.error,
          entityType: 'document_items',
          affectedIds: ids,
          title: 'Orphaned document items',
          explanation:
              'Found ${ids.length} line item(s) referencing non-existent document(s).',
          requiresManualReview: false,
          metadata: {
            'count': ids.length,
            'missing_document_ids': orphanedItems
                .map((r) => r['document_id'] as int)
                .toSet()
                .toList(),
          },
        ),
      );
    }

    // 1.2 Document items with broken product reference (product_id is set but product does not exist)
    checks++;
    final brokenProductItems = await db.rawQuery('''
      SELECT di.id, di.product_id
      FROM document_items di
      LEFT JOIN products p ON di.product_id = p.id
      WHERE di.product_id IS NOT NULL AND p.id IS NULL
    ''');
    if (brokenProductItems.isNotEmpty) {
      final ids = brokenProductItems.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'broken_product_reference_in_items',
          category: DiagnosticCategory.orphanedRecord,
          severity: DiagnosticSeverity.error,
          entityType: 'document_items',
          affectedIds: ids,
          title: 'Broken product references in document items',
          explanation:
              'Found ${ids.length} item(s) referencing deleted or non-existent product(s).',
          requiresManualReview: false,
          metadata: {
            'count': ids.length,
            'missing_product_ids': brokenProductItems
                .map((r) => r['product_id'] as int)
                .toSet()
                .toList(),
          },
        ),
      );
    }

    // 1.3 Orphaned document_payments (document does not exist)
    checks++;
    final orphanedPayments = await db.rawQuery('''
      SELECT dp.id, dp.document_id
      FROM document_payments dp
      LEFT JOIN documents d ON dp.document_id = d.id
      WHERE d.id IS NULL
    ''');
    if (orphanedPayments.isNotEmpty) {
      final ids = orphanedPayments.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'orphaned_document_payments',
          category: DiagnosticCategory.orphanedRecord,
          severity: DiagnosticSeverity.error,
          entityType: 'document_payments',
          affectedIds: ids,
          title: 'Orphaned payment records',
          explanation:
              'Found ${ids.length} payment record(s) referencing non-existent invoice/purchase document(s).',
          requiresManualReview: false,
          metadata: {
            'count': ids.length,
            'missing_document_ids': orphanedPayments
                .map((r) => r['document_id'] as int)
                .toSet()
                .toList(),
          },
        ),
      );
    }

    // 1.4 Payment records with broken receipt reference (receipt_document_id is set but does not exist)
    checks++;
    final brokenReceiptPayments = await db.rawQuery('''
      SELECT dp.id, dp.receipt_document_id
      FROM document_payments dp
      LEFT JOIN documents d ON dp.receipt_document_id = d.id
      WHERE dp.receipt_document_id IS NOT NULL AND d.id IS NULL
    ''');
    if (brokenReceiptPayments.isNotEmpty) {
      final ids = brokenReceiptPayments.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'broken_receipt_reference_in_payments',
          category: DiagnosticCategory.orphanedRecord,
          severity: DiagnosticSeverity.error,
          entityType: 'document_payments',
          affectedIds: ids,
          title: 'Broken receipt document references in payments',
          explanation:
              'Found ${ids.length} payment record(s) referencing deleted or non-existent receipt document(s).',
          requiresManualReview: false,
          metadata: {
            'count': ids.length,
            'missing_receipt_ids': brokenReceiptPayments
                .map((r) => r['receipt_document_id'] as int)
                .toSet()
                .toList(),
          },
        ),
      );
    }

    // 1.5 Orphaned stock_movements (product does not exist)
    checks++;
    final orphanedMovements = await db.rawQuery('''
      SELECT sm.id, sm.product_id
      FROM stock_movements sm
      LEFT JOIN products p ON sm.product_id = p.id
      WHERE p.id IS NULL
    ''');
    if (orphanedMovements.isNotEmpty) {
      final ids = orphanedMovements.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'orphaned_stock_movements',
          category: DiagnosticCategory.orphanedRecord,
          severity: DiagnosticSeverity.error,
          entityType: 'stock_movements',
          affectedIds: ids,
          title: 'Orphaned stock movements',
          explanation:
              'Found ${ids.length} stock movement(s) referencing non-existent product(s).',
          requiresManualReview: true,
          metadata: {
            'count': ids.length,
            'missing_product_ids': orphanedMovements
                .map((r) => r['product_id'] as int)
                .toSet()
                .toList(),
          },
        ),
      );
    }

    // 1.6 Stock movements with broken document reference (reference_document_id is set but does not exist)
    checks++;
    final brokenDocMovements = await db.rawQuery('''
      SELECT sm.id, sm.reference_document_id
      FROM stock_movements sm
      LEFT JOIN documents d ON sm.reference_document_id = d.id
      WHERE sm.reference_document_id IS NOT NULL AND d.id IS NULL
    ''');
    if (brokenDocMovements.isNotEmpty) {
      final ids = brokenDocMovements.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'broken_document_reference_in_movements',
          category: DiagnosticCategory.orphanedRecord,
          severity: DiagnosticSeverity.error,
          entityType: 'stock_movements',
          affectedIds: ids,
          title: 'Broken document references in stock movements',
          explanation:
              'Found ${ids.length} stock movement(s) referencing non-existent document(s).',
          requiresManualReview: false,
          metadata: {
            'count': ids.length,
            'missing_document_ids': brokenDocMovements
                .map((r) => r['reference_document_id'] as int)
                .toSet()
                .toList(),
          },
        ),
      );
    }

    // 1.7 Documents with broken related_document_id
    checks++;
    final brokenRelatedDocs = await db.rawQuery('''
      SELECT d.id, d.related_document_id
      FROM documents d
      LEFT JOIN documents target ON d.related_document_id = target.id
      WHERE d.related_document_id IS NOT NULL AND target.id IS NULL
    ''');
    if (brokenRelatedDocs.isNotEmpty) {
      final ids = brokenRelatedDocs.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'broken_related_document_in_documents',
          category: DiagnosticCategory.orphanedRecord,
          severity: DiagnosticSeverity.error,
          entityType: 'documents',
          affectedIds: ids,
          title: 'Broken parent/related document references',
          explanation:
              'Found ${ids.length} document(s) referencing deleted or non-existent related document(s).',
          requiresManualReview: false,
          metadata: {
            'count': ids.length,
            'missing_related_ids': brokenRelatedDocs
                .map((r) => r['related_document_id'] as int)
                .toSet()
                .toList(),
          },
        ),
      );
    }

    // 1.8 Orphaned stocktake items (if stocktake tables exist)
    final hasStocktake =
        Sqflite.firstIntValue(
          await db.rawQuery('''
      SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='stocktake_items'
    '''),
        ) ==
        1;

    if (hasStocktake) {
      checks++;
      final orphanedStocktakeItems = await db.rawQuery('''
        SELECT si.id, si.session_id
        FROM stocktake_items si
        LEFT JOIN stocktake_sessions ss ON si.session_id = ss.id
        WHERE ss.id IS NULL
      ''');
      if (orphanedStocktakeItems.isNotEmpty) {
        final ids = orphanedStocktakeItems.map((r) => r['id'] as int).toList();
        findings.add(
          DiagnosticFinding(
            code: 'orphaned_stocktake_items',
            category: DiagnosticCategory.orphanedRecord,
            severity: DiagnosticSeverity.error,
            entityType: 'stocktake_items',
            affectedIds: ids,
            title: 'Orphaned stocktake items',
            explanation:
                'Found ${ids.length} stocktake item(s) referencing non-existent stocktake session(s).',
            requiresManualReview: false,
          ),
        );
      }
    }

    return checks;
  }

  // =========================================================================
  // 2. DOCUMENT BALANCES & TOTALS
  // =========================================================================

  static Future<int> _checkDocumentBalances(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
  ) async {
    int checks = 0;

    // 2.1 Document total calculation discrepancy: total != subtotal - discount + tax_amount
    checks++;
    final docRows = await db.rawQuery('''
      SELECT id, document_number, subtotal, discount, tax_amount, total
      FROM documents
      WHERE status != '${DocumentStatus.cancelled}'
    ''');

    final calculationMismatches = <int>[];
    for (final row in docRows) {
      final subtotal = (row['subtotal'] as num?)?.toDouble() ?? 0.0;
      final discount = (row['discount'] as num?)?.toDouble() ?? 0.0;
      final taxAmount = (row['tax_amount'] as num?)?.toDouble() ?? 0.0;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;

      final expectedTotal = subtotal - discount + taxAmount;
      if ((total - expectedTotal).abs() > _moneyEpsilon) {
        calculationMismatches.add(row['id'] as int);
      }
    }

    if (calculationMismatches.isNotEmpty) {
      findings.add(
        DiagnosticFinding(
          code: 'document_total_calculation_mismatch',
          category: DiagnosticCategory.documentBalanceMismatch,
          severity: DiagnosticSeverity.error,
          entityType: 'documents',
          affectedIds: calculationMismatches,
          title: 'Document total calculation mismatch',
          explanation:
              'Found ${calculationMismatches.length} document(s) where total does not equal subtotal - discount + tax.',
          requiresManualReview: false,
        ),
      );
    }

    // 2.2 Document items sum vs document subtotal
    checks++;
    final itemSumMismatches = await db.rawQuery('''
      SELECT d.id, d.document_number, d.subtotal, SUM(di.total) AS items_sum
      FROM documents d
      JOIN document_items di ON d.id = di.document_id
      WHERE d.status != '${DocumentStatus.cancelled}'
      GROUP BY d.id
      HAVING abs(d.subtotal - items_sum) > $_moneyEpsilon
    ''');
    if (itemSumMismatches.isNotEmpty) {
      final ids = itemSumMismatches.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'document_items_sum_mismatch',
          category: DiagnosticCategory.documentBalanceMismatch,
          severity: DiagnosticSeverity.error,
          entityType: 'documents',
          affectedIds: ids,
          title: 'Document subtotal does not match line items',
          explanation:
              'Found ${ids.length} document(s) whose subtotal does not equal the sum of line items.',
          requiresManualReview: true,
        ),
      );
    }

    // 2.3 Document remaining calculation discrepancy: remaining != (total - paid).clamp(0, infinity)
    checks++;
    final remainingRows = await db.rawQuery('''
      SELECT id, document_number, total, paid, remaining
      FROM documents
      WHERE type IN ('invoice', 'purchase')
        AND status != '${DocumentStatus.cancelled}'
    ''');
    final remainingMismatches = <int>[];
    final overpaidDocs = <int>[];

    for (final row in remainingRows) {
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      final paid = (row['paid'] as num?)?.toDouble() ?? 0.0;
      final remaining = (row['remaining'] as num?)?.toDouble() ?? 0.0;

      final expectedRemaining = (total - paid).clamp(0.0, double.infinity);
      if ((remaining - expectedRemaining).abs() > _balanceEpsilon) {
        remainingMismatches.add(row['id'] as int);
      }
      if (paid > total + _balanceEpsilon) {
        overpaidDocs.add(row['id'] as int);
      }
    }

    if (remainingMismatches.isNotEmpty) {
      findings.add(
        DiagnosticFinding(
          code: 'document_remaining_calculation_mismatch',
          category: DiagnosticCategory.documentBalanceMismatch,
          severity: DiagnosticSeverity.error,
          entityType: 'documents',
          affectedIds: remainingMismatches,
          title: 'Document remaining balance mismatch',
          explanation:
              'Found ${remainingMismatches.length} document(s) where remaining != max(0, total - paid).',
          requiresManualReview: false,
        ),
      );
    }

    if (overpaidDocs.isNotEmpty) {
      findings.add(
        DiagnosticFinding(
          code: 'document_overpaid',
          category: DiagnosticCategory.documentBalanceMismatch,
          severity: DiagnosticSeverity.warning,
          entityType: 'documents',
          affectedIds: overpaidDocs,
          title: 'Document paid amount exceeds total',
          explanation:
              'Found ${overpaidDocs.length} document(s) where paid amount exceeds invoice/purchase total.',
          requiresManualReview: true,
        ),
      );
    }

    return checks;
  }

  // =========================================================================
  // 3. DOCUMENT STATUS CONSISTENCY
  // =========================================================================

  static Future<int> _checkDocumentStatuses(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
  ) async {
    int checks = 0;

    // 3.1 Document marked 'paid' but paid amount < total
    checks++;
    final paidIncomplete = await db.rawQuery('''
      SELECT id, document_number, total, paid
      FROM documents
      WHERE type IN ('invoice', 'purchase')
        AND status = '${DocumentStatus.paid}'
        AND paid < total - $_balanceEpsilon
    ''');
    if (paidIncomplete.isNotEmpty) {
      final ids = paidIncomplete.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'document_status_paid_incomplete',
          category: DiagnosticCategory.documentStatusMismatch,
          severity: DiagnosticSeverity.error,
          entityType: 'documents',
          affectedIds: ids,
          title: 'Document status marked paid but payment is incomplete',
          explanation:
              'Found ${ids.length} invoice/purchase document(s) with status="paid" but recorded paid amount is less than total.',
          requiresManualReview: false,
        ),
      );
    }

    // 3.2 Document marked 'unpaid' or 'issued' but paid > 0
    checks++;
    final unpaidWithPayments = await db.rawQuery('''
      SELECT id, document_number, total, paid
      FROM documents
      WHERE type IN ('invoice', 'purchase')
        AND status IN ('${DocumentStatus.issued}', 'unpaid')
        AND paid > $_balanceEpsilon
    ''');
    if (unpaidWithPayments.isNotEmpty) {
      final ids = unpaidWithPayments.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'document_status_unpaid_with_payments',
          category: DiagnosticCategory.documentStatusMismatch,
          severity: DiagnosticSeverity.error,
          entityType: 'documents',
          affectedIds: ids,
          title: 'Document status marked unpaid but has payments',
          explanation:
              'Found ${ids.length} invoice/purchase document(s) with status="unpaid"/"issued" despite having paid > 0.',
          requiresManualReview: false,
        ),
      );
    }

    // 3.3 Document marked 'partially_paid' but paid <= 0 or paid >= total
    checks++;
    final invalidPartial = await db.rawQuery('''
      SELECT id, document_number, total, paid
      FROM documents
      WHERE type IN ('invoice', 'purchase')
        AND status = '${DocumentStatus.partiallyPaid}'
        AND (paid <= $_balanceEpsilon OR paid >= total - $_balanceEpsilon)
    ''');
    if (invalidPartial.isNotEmpty) {
      final ids = invalidPartial.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'document_status_partial_invalid',
          category: DiagnosticCategory.documentStatusMismatch,
          severity: DiagnosticSeverity.error,
          entityType: 'documents',
          affectedIds: ids,
          title: 'Invalid partially paid document status',
          explanation:
              'Found ${ids.length} document(s) marked "partially_paid" that are either completely unpaid or fully paid.',
          requiresManualReview: false,
        ),
      );
    }

    // 3.4 Legacy foreign currency documents
    checks++;
    final hasBusinesses =
        Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='businesses'"),
        ) ==
        1;
    final hasDocuments =
        Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='documents'"),
        ) ==
        1;
    if (hasBusinesses && hasDocuments) {
      final docCols = await db.rawQuery("PRAGMA table_info('documents')");
      final hasDocCurrency = docCols.any((c) => c['name'] == 'currency_code');
      if (hasDocCurrency) {
        final bizRows = await db.rawQuery('SELECT currency_code FROM businesses LIMIT 1');
        final baseCurrency = (bizRows.isNotEmpty ? (bizRows.first['currency_code'] as String?)?.trim() : null) ?? 'SDG';
        final resolvedBase = baseCurrency.isNotEmpty ? baseCurrency : 'SDG';
        final foreignDocs = await db.rawQuery('''
          SELECT id, document_number, currency_code, total
          FROM documents
          WHERE currency_code IS NOT NULL
            AND TRIM(currency_code) != ''
            AND TRIM(currency_code) != ?
        ''', [resolvedBase]);
        if (foreignDocs.isNotEmpty) {
          final ids = foreignDocs.map((r) => r['id'] as int).toList();
          final foreignCurrencies = foreignDocs
              .map((r) => ((r['currency_code'] as String?) ?? '').trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList();
          findings.add(
            DiagnosticFinding(
              code: 'legacy_foreign_currency_documents',
              category: DiagnosticCategory.documentStatusMismatch,
              severity: DiagnosticSeverity.info,
              entityType: 'documents',
              affectedIds: ids,
              title: 'Legacy documents stored in non-base currencies',
              explanation:
                  'Found ${ids.length} document(s) recorded in foreign currencies ($foreignCurrencies) different from active business base currency ($resolvedBase). These records remain preserved as historical snapshots and are segregated from base-currency totals.',
              requiresManualReview: true,
              metadata: {
                'baseCurrency': resolvedBase,
                'foreignCurrencies': foreignCurrencies,
                'count': ids.length,
              },
            ),
          );
        }
      }
    }

    return checks;
  }

  // =========================================================================
  // 4. PAYMENT RECONCILIATION & RECEIPTS
  // =========================================================================

  static Future<int> _checkPaymentIntegrity(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
  ) async {
    int checks = 0;

    // 4.1 Sum of payment rows exceeds document paid amount (active documents)
    // (Note: Requires manual accounting review because payments may be duplicate, erroneously
    // entered, or unverified against bank receipts/statements).
    checks++;
    final paymentsExceedPaid = await db.rawQuery('''
      SELECT d.id, d.document_number, d.paid, SUM(dp.amount) AS payments_sum
      FROM documents d
      JOIN document_payments dp ON d.id = dp.document_id
      WHERE d.status != '${DocumentStatus.cancelled}'
      GROUP BY d.id
      HAVING payments_sum > d.paid + $_balanceEpsilon
    ''');
    if (paymentsExceedPaid.isNotEmpty) {
      final ids = paymentsExceedPaid.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'payment_records_exceed_document_paid',
          category: DiagnosticCategory.paymentMismatch,
          severity: DiagnosticSeverity.error,
          entityType: 'documents',
          affectedIds: ids,
          title: 'Payment records sum exceeds document paid amount',
          explanation:
              'Found ${ids.length} active document(s) where total of document_payments exceeds document.paid.',
          requiresManualReview: true,
        ),
      );
    }

    // 4.2 Sum of payment rows is non-zero but less than document paid amount (active documents)
    // (Note: Requires manual review because legacy invoices may have upfront payment recorded only on the document).
    checks++;
    final paymentsLessThanPaid = await db.rawQuery('''
      SELECT d.id, d.document_number, d.paid, SUM(dp.amount) AS payments_sum
      FROM documents d
      JOIN document_payments dp ON d.id = dp.document_id
      WHERE d.status != '${DocumentStatus.cancelled}'
      GROUP BY d.id
      HAVING payments_sum > 0 AND payments_sum < d.paid - $_balanceEpsilon
    ''');
    if (paymentsLessThanPaid.isNotEmpty) {
      final ids = paymentsLessThanPaid.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'payment_records_less_than_document_paid',
          category: DiagnosticCategory.paymentMismatch,
          severity: DiagnosticSeverity.warning,
          entityType: 'documents',
          affectedIds: ids,
          title: 'Payment records sum is less than document paid balance',
          explanation:
              'Found ${ids.length} active document(s) where document.paid exceeds recorded payment rows. May reflect legacy upfront payments or missing receipts.',
          requiresManualReview: true,
        ),
      );
    }

    // 4.3 Active linked receipt document without a corresponding payment row
    checks++;
    final activeReceiptMissingRow = await db.rawQuery('''
      SELECT r.id, r.document_number, r.type, r.total, r.related_document_id
      FROM documents r
      LEFT JOIN document_payments dp ON dp.receipt_document_id = r.id
      WHERE r.status != '${DocumentStatus.cancelled}'
        AND r.type IN ('payment_receipt', 'expense_voucher')
        AND r.related_document_id IS NOT NULL
        AND dp.id IS NULL
    ''');
    if (activeReceiptMissingRow.isNotEmpty) {
      final ids = activeReceiptMissingRow.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'active_receipt_missing_payment_record',
          category: DiagnosticCategory.paymentMismatch,
          severity: DiagnosticSeverity.warning,
          entityType: 'documents',
          affectedIds: ids,
          title: 'Active linked receipt/voucher missing payment record',
          explanation:
              'Found ${ids.length} active receipt/voucher document(s) that lack a corresponding row in document_payments.',
          requiresManualReview: true,
        ),
      );
    }

    // 4.4 Cancelled documents with unresolved payment discrepancy
    checks++;
    final cancelledPaymentMismatches = await db.rawQuery('''
      SELECT d.id, d.document_number, d.paid, SUM(dp.amount) AS payments_sum
      FROM documents d
      JOIN document_payments dp ON d.id = dp.document_id
      WHERE d.status = '${DocumentStatus.cancelled}'
      GROUP BY d.id
      HAVING abs(d.paid - payments_sum) > $_balanceEpsilon
    ''');
    if (cancelledPaymentMismatches.isNotEmpty) {
      final ids = cancelledPaymentMismatches
          .map((r) => r['id'] as int)
          .toList();
      findings.add(
        DiagnosticFinding(
          code: 'cancelled_document_payment_mismatch',
          category: DiagnosticCategory.paymentMismatch,
          severity: DiagnosticSeverity.warning,
          entityType: 'documents',
          affectedIds: ids,
          title: 'Payment discrepancy in cancelled document',
          explanation:
              'Found ${ids.length} cancelled document(s) with conflicting payment records where document_payments sum differs from document.paid.',
          requiresManualReview: true,
          metadata: {
            'discrepancies': cancelledPaymentMismatches
                .map(
                  (r) => {
                    'document_id': r['id'],
                    'document_number': r['document_number'],
                    'paid': r['paid'],
                    'payments_sum': r['payments_sum'],
                  },
                )
                .toList(),
          },
        ),
      );
    }

    return checks;
  }

  // =========================================================================
  // 5. STOCK QUANTITIES & MOVEMENT RECONCILIATION
  // =========================================================================

  static Future<int> _checkStockReconciliation(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
  ) async {
    int checks = 0;

    // 5.1 Stock quantity discrepancy between product balance and stock movements
    checks++;
    final stockDiscrepancies = await db.rawQuery('''
      SELECT p.id, p.name, p.stock_quantity, SUM(sm.quantity) AS movements_sum
      FROM products p
      JOIN stock_movements sm ON p.id = sm.product_id
      WHERE p.type = 'product'
      GROUP BY p.id
      HAVING abs(p.stock_quantity - movements_sum) > $_qtyEpsilon
    ''');
    if (stockDiscrepancies.isNotEmpty) {
      final ids = stockDiscrepancies.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'stock_movement_ledger_mismatch',
          category: DiagnosticCategory.stockDiscrepancy,
          severity: DiagnosticSeverity.error,
          entityType: 'products',
          affectedIds: ids,
          title: 'Product stock does not match movement history',
          explanation:
              'Found ${ids.length} product(s) where stock_quantity does not equal the algebraic sum of stock movements.',
          requiresManualReview: true,
        ),
      );
    }

    // 5.2 Stocked product with existing stock but zero stock movements (missing opening movement)
    checks++;
    final missingOpeningStock = await db.rawQuery('''
      SELECT p.id, p.name, p.stock_quantity
      FROM products p
      LEFT JOIN stock_movements sm ON p.id = sm.product_id
      WHERE p.type = 'product'
        AND p.stock_quantity > $_qtyEpsilon
        AND sm.id IS NULL
    ''');
    if (missingOpeningStock.isNotEmpty) {
      final ids = missingOpeningStock.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'missing_opening_stock',
          category: DiagnosticCategory.missingOpeningStock,
          severity: DiagnosticSeverity.warning,
          entityType: 'products',
          affectedIds: ids,
          title: 'Product with stock has no recorded stock movements',
          explanation:
              'Found ${ids.length} product(s) with stock_quantity > 0 but no stock movements recorded (legacy pre-movement record).',
          requiresManualReview: true,
        ),
      );
    }

    // 5.3 Document stock movements mismatch (expected vs actual net movements)
    checks++;
    final itemCols = await db.rawQuery("PRAGMA table_info('document_items')");
    final hasFactor = itemCols.any((c) => c['name'] == 'unit_conversion_factor');
    final factorExpr = hasFactor ? 'COALESCE(di.unit_conversion_factor, 1.0)' : '1.0';

    final expectedDocMovements = await db.rawQuery('''
      SELECT 
        d.id AS doc_id,
        d.document_number,
        d.type AS doc_type,
        d.status AS doc_status,
        di.product_id,
        SUM(
          CASE 
            WHEN d.status IN ('draft', 'cancelled') THEN 0.0
            WHEN d.type = 'purchase' THEN di.quantity * $factorExpr
            WHEN d.type = 'invoice' THEN -1.0 * di.quantity * $factorExpr
            ELSE 0.0
          END
        ) AS expected_movement
      FROM documents d
      JOIN document_items di ON d.id = di.document_id
      WHERE di.product_id IS NOT NULL AND d.type IN ('purchase', 'invoice')
      GROUP BY d.id, di.product_id
    ''');

    final actualDocMovements = await db.rawQuery('''
      SELECT 
        sm.reference_document_id AS doc_id,
        sm.product_id,
        SUM(sm.quantity) AS actual_movement
      FROM stock_movements sm
      WHERE sm.reference_document_id IS NOT NULL
      GROUP BY sm.reference_document_id, sm.product_id
    ''');

    final actualMap = <String, double>{};
    for (final row in actualDocMovements) {
      final docId = row['doc_id'] as int;
      final prodId = row['product_id'] as int;
      actualMap['${docId}_$prodId'] = (row['actual_movement'] as num).toDouble();
    }

    final docMismatchIds = <int>{};
    final mismatchedDetails = <Map<String, dynamic>>[];

    for (final row in expectedDocMovements) {
      final docId = row['doc_id'] as int;
      final docNum = row['document_number'] as String;
      final prodId = row['product_id'] as int;
      final expected = (row['expected_movement'] as num).toDouble();
      final actual = actualMap['${docId}_$prodId'] ?? 0.0;

      if ((expected - actual).abs() > _qtyEpsilon) {
        docMismatchIds.add(docId);
        mismatchedDetails.add({
          'document_id': docId,
          'document_number': docNum,
          'product_id': prodId,
          'expected_movement': expected,
          'actual_movement': actual,
        });
      }
    }

    if (docMismatchIds.isNotEmpty) {
      findings.add(
        DiagnosticFinding(
          code: 'document_movement_mismatch',
          category: DiagnosticCategory.stockDiscrepancy,
          severity: DiagnosticSeverity.error,
          entityType: 'documents',
          affectedIds: docMismatchIds.toList()..sort(),
          title: 'Document stock movements mismatch',
          explanation:
              'Found ${docMismatchIds.length} document(s) where net stock movements do not match document line item quantities.',
          requiresManualReview: true,
          metadata: {'mismatches': mismatchedDetails},
        ),
      );
    }

    // 5.4 Ledger-vs-movements inventory difference per product
    checks++;
    final ledgerQtyRows = await db.rawQuery('''
      SELECT p.id AS product_id,
        (
          COALESCE((
            SELECT SUM(di.quantity * $factorExpr)
            FROM documents d
            JOIN document_items di ON d.id = di.document_id
            WHERE di.product_id = p.id AND d.type = 'purchase' AND d.status NOT IN ('draft', 'cancelled')
          ), 0.0)
          -
          COALESCE((
            SELECT SUM(di.quantity * $factorExpr)
            FROM documents d
            JOIN document_items di ON d.id = di.document_id
            WHERE di.product_id = p.id AND d.type = 'invoice' AND d.status NOT IN ('draft', 'cancelled')
          ), 0.0)
          +
          COALESCE((
            SELECT SUM(sm.quantity)
            FROM stock_movements sm
            WHERE sm.product_id = p.id AND sm.type IN ('opening', 'adjustment', 'cancellation')
              AND sm.reference_document_id IS NULL
          ), 0.0)
        ) AS ledger_expected_qty,
        COALESCE((
          SELECT SUM(sm.quantity)
          FROM stock_movements sm
          WHERE sm.product_id = p.id
        ), 0.0) AS actual_movement_sum
      FROM products p
      WHERE p.type = 'product'
    ''');

    final ledgerMismatchIds = <int>[];
    final ledgerMismatchDetails = <Map<String, dynamic>>[];
    for (final row in ledgerQtyRows) {
      final prodId = row['product_id'] as int;
      final ledgerQty = (row['ledger_expected_qty'] as num).toDouble();
      final actualSum = (row['actual_movement_sum'] as num).toDouble();
      if ((ledgerQty - actualSum).abs() > _qtyEpsilon) {
        ledgerMismatchIds.add(prodId);
        ledgerMismatchDetails.add({
          'product_id': prodId,
          'ledger_quantity': ledgerQty,
          'movement_quantity': actualSum,
          'difference': (actualSum - ledgerQty),
        });
      }
    }

    if (ledgerMismatchIds.isNotEmpty) {
      findings.add(
        DiagnosticFinding(
          code: 'ledger_movement_inventory_mismatch',
          category: DiagnosticCategory.stockDiscrepancy,
          severity: DiagnosticSeverity.error,
          entityType: 'products',
          affectedIds: ledgerMismatchIds,
          title: 'Ledger and movement inventory discrepancy',
          explanation:
              'Found ${ledgerMismatchIds.length} product(s) where inventory derived by ledger events differs from the sum of stock movements.',
          requiresManualReview: true,
          metadata: {'mismatches': ledgerMismatchDetails},
        ),
      );
    }

    return checks;
  }

  // =========================================================================
  // 6. SUSPICIOUS STOCK BALANCES
  // =========================================================================

  static Future<int> _checkStockBalances(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
  ) async {
    int checks = 0;

    // 6.1 Negative stock balance
    checks++;
    final negativeStock = await db.rawQuery('''
      SELECT id, name, stock_quantity
      FROM products
      WHERE type = 'product' AND stock_quantity < -$_qtyEpsilon
    ''');
    if (negativeStock.isNotEmpty) {
      final ids = negativeStock.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'negative_stock_quantity',
          category: DiagnosticCategory.negativeStock,
          severity: DiagnosticSeverity.warning,
          entityType: 'products',
          affectedIds: ids,
          title: 'Negative stock balance',
          explanation:
              'Found ${ids.length} product(s) with negative stock quantity on hand, indicating overselling or missing purchase records.',
          requiresManualReview: true,
        ),
      );
    }

    // 6.2 NaN or Infinite stock balance
    checks++;
    final allProducts = await db.query(
      'products',
      columns: ['id', 'stock_quantity'],
      where: "type = 'product'",
    );
    final nanOrInfinite = <int>[];
    for (final p in allProducts) {
      final qty = (p['stock_quantity'] as num?)?.toDouble();
      if (qty != null && (qty.isNaN || qty.isInfinite)) {
        nanOrInfinite.add(p['id'] as int);
      }
    }
    if (nanOrInfinite.isNotEmpty) {
      findings.add(
        DiagnosticFinding(
          code: 'suspicious_nan_or_infinite_stock',
          category: DiagnosticCategory.negativeStock,
          severity: DiagnosticSeverity.error,
          entityType: 'products',
          affectedIds: nanOrInfinite,
          title: 'NaN or infinite stock quantity',
          explanation:
              'Found ${nanOrInfinite.length} product(s) with corrupted numeric stock_quantity (NaN or infinite).',
          requiresManualReview: false,
        ),
      );
    }

    return checks;
  }

  // =========================================================================
  // 7. INVENTORY COSTING CONSISTENCY
  // =========================================================================

  static Future<int> _checkInventoryCosting(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
  ) async {
    int checks = 0;

    // Check if costing columns exist (schema version >= 15)
    final productCols = await db.rawQuery("PRAGMA table_info('products')");
    final hasCostingColumns = productCols.any(
      (c) => c['name'] == 'cost_status',
    );
    if (!hasCostingColumns) {
      findings.add(
        const DiagnosticFinding(
          code: 'legacy_schema_costing_unsupported',
          category: DiagnosticCategory.inventoryCosting,
          severity: DiagnosticSeverity.info,
          entityType: 'database',
          affectedIds: [],
          title: 'Legacy database schema: costing diagnostics skipped',
          explanation:
              'Database schema predates version 15 (historical costing columns not present). Costing diagnostics require schema migration.',
          requiresManualReview: false,
        ),
      );
      return checks;
    }

    // 7.1 Product marked 'known' cost_status but average_cost is NULL
    checks++;
    final knownMissingCost = await db.rawQuery('''
      SELECT id, name, stock_quantity, cost_status
      FROM products
      WHERE type = 'product'
        AND cost_status = '${StockMovement.costStatusKnown}'
        AND average_cost IS NULL
    ''');
    if (knownMissingCost.isNotEmpty) {
      final ids = knownMissingCost.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'product_cost_status_known_missing_cost',
          category: DiagnosticCategory.inventoryCosting,
          severity: DiagnosticSeverity.error,
          entityType: 'products',
          affectedIds: ids,
          title: 'Product cost marked known but average cost is NULL',
          explanation:
              'Found ${ids.length} product(s) marked with cost_status="known" but average_cost is NULL.',
          requiresManualReview: false,
        ),
      );
    }

    // 7.2 Product with negative average cost
    checks++;
    final negativeAvgCost = await db.rawQuery('''
      SELECT id, name, stock_quantity, average_cost
      FROM products
      WHERE type = 'product'
        AND average_cost IS NOT NULL
        AND average_cost < 0
    ''');
    if (negativeAvgCost.isNotEmpty) {
      final ids = negativeAvgCost.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'product_negative_average_cost',
          category: DiagnosticCategory.inventoryCosting,
          severity: DiagnosticSeverity.error,
          entityType: 'products',
          affectedIds: ids,
          title: 'Negative average cost',
          explanation:
              'Found ${ids.length} product(s) with negative average cost.',
          requiresManualReview: false,
        ),
      );
    }

    // 7.3 Product with stock on hand but unknown cost
    checks++;
    final heldStockUnknownCost = await db.rawQuery('''
      SELECT id, name, stock_quantity, cost_status
      FROM products
      WHERE type = 'product'
        AND stock_quantity > $_qtyEpsilon
        AND (cost_status = '${StockMovement.costStatusUnknown}' OR average_cost IS NULL)
    ''');
    if (heldStockUnknownCost.isNotEmpty) {
      final ids = heldStockUnknownCost.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'product_held_stock_unknown_cost',
          category: DiagnosticCategory.inventoryCosting,
          severity: DiagnosticSeverity.info,
          entityType: 'products',
          affectedIds: ids,
          title: 'Inventory held with unknown cost basis',
          explanation:
              'Found ${ids.length} product(s) with physical stock on hand but unknown average cost basis.',
          requiresManualReview: true,
        ),
      );
    }

    // 7.4 Stock movement marked 'known' cost_status but unit_cost is NULL
    checks++;
    final movementKnownMissingCost = await db.rawQuery('''
      SELECT id, product_id, type, quantity, cost_status
      FROM stock_movements
      WHERE cost_status = '${StockMovement.costStatusKnown}'
        AND unit_cost IS NULL
    ''');
    if (movementKnownMissingCost.isNotEmpty) {
      final ids = movementKnownMissingCost.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'movement_known_status_missing_cost',
          category: DiagnosticCategory.inventoryCosting,
          severity: DiagnosticSeverity.error,
          entityType: 'stock_movements',
          affectedIds: ids,
          title: 'Stock movement marked known but unit cost is missing',
          explanation:
              'Found ${ids.length} stock movement(s) marked with cost_status="known" but unit_cost is NULL.',
          requiresManualReview: false,
        ),
      );
    }

    // 7.5 Stock movement total_cost mismatch: abs(total_cost) != abs(quantity) * unit_cost
    checks++;
    final movementCostMismatch = await db.rawQuery('''
      SELECT id, product_id, type, quantity, unit_cost, total_cost
      FROM stock_movements
      WHERE unit_cost IS NOT NULL
        AND total_cost IS NOT NULL
        AND (
          abs(abs(total_cost) - (abs(quantity) * unit_cost)) > $_moneyEpsilon
          OR (quantity > 0 AND total_cost < -$_moneyEpsilon)
        )
    ''');
    if (movementCostMismatch.isNotEmpty) {
      final ids = movementCostMismatch.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'movement_total_cost_mismatch',
          category: DiagnosticCategory.inventoryCosting,
          severity: DiagnosticSeverity.error,
          entityType: 'stock_movements',
          affectedIds: ids,
          title:
              'Stock movement total cost does not match quantity * unit_cost',
          explanation:
              'Found ${ids.length} stock movement(s) where total_cost does not match quantity * unit_cost.',
          requiresManualReview: true,
        ),
      );
    }

    // 7.6 Stock movement with negative unit cost
    checks++;
    final negativeUnitCost = await db.rawQuery('''
      SELECT id, product_id, type, quantity, unit_cost
      FROM stock_movements
      WHERE unit_cost IS NOT NULL
        AND unit_cost < -$_moneyEpsilon
    ''');
    if (negativeUnitCost.isNotEmpty) {
      final ids = negativeUnitCost.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'movement_negative_unit_cost',
          category: DiagnosticCategory.inventoryCosting,
          severity: DiagnosticSeverity.error,
          entityType: 'stock_movements',
          affectedIds: ids,
          title: 'Stock movement with negative unit cost',
          explanation:
              'Found ${ids.length} stock movement(s) with invalid negative unit cost.',
          requiresManualReview: true,
        ),
      );
    }

    // 7.6 Issued sales invoice line items missing cost for stocked products
    checks++;
    final uncostedSaleItems = await db.rawQuery('''
      SELECT di.id, di.document_id, di.product_id, di.description
      FROM document_items di
      JOIN documents d ON d.id = di.document_id
      JOIN products p ON p.id = di.product_id
      WHERE d.type = 'invoice'
        AND d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
        AND p.type = 'product'
        AND (di.unit_cost IS NULL OR di.total_cost IS NULL)
    ''');
    if (uncostedSaleItems.isNotEmpty) {
      final ids = uncostedSaleItems.map((r) => r['id'] as int).toList();
      findings.add(
        DiagnosticFinding(
          code: 'issued_sale_item_missing_cost',
          category: DiagnosticCategory.inventoryCosting,
          severity: DiagnosticSeverity.warning,
          entityType: 'document_items',
          affectedIds: ids,
          title: 'Issued invoice line items missing cost of sales',
          explanation:
              'Found ${ids.length} stocked item(s) on issued sales invoices with unrecorded cost basis.',
          requiresManualReview: true,
        ),
      );
    }

    return checks;
  }

  // =========================================================================
  // 8. DUPLICATE DOCUMENT NUMBERS
  // =========================================================================

  static Future<int> _checkDuplicateDocumentNumbers(
    DatabaseExecutor db,
    List<DiagnosticFinding> findings,
  ) async {
    int checks = 1;

    final duplicates = await db.rawQuery('''
      SELECT type, document_number, COUNT(*) AS cnt, GROUP_CONCAT(id) AS ids
      FROM documents
      WHERE status != '${DocumentStatus.cancelled}'
      GROUP BY type, document_number
      HAVING cnt > 1
    ''');

    if (duplicates.isNotEmpty) {
      final allAffectedIds = <int>[];
      final duplicateList = <Map<String, dynamic>>[];

      for (final row in duplicates) {
        final idStrs = (row['ids'] as String? ?? '').split(',');
        final ids = idStrs.map(int.tryParse).whereType<int>().toList();
        allAffectedIds.addAll(ids);
        duplicateList.add({
          'type': row['type'],
          'document_number': row['document_number'],
          'count': row['cnt'],
          'ids': ids,
        });
      }

      findings.add(
        DiagnosticFinding(
          code: 'duplicate_document_number',
          category: DiagnosticCategory.duplicateDocumentNumber,
          severity: DiagnosticSeverity.warning,
          entityType: 'documents',
          affectedIds: allAffectedIds,
          title: 'Duplicate active document numbers',
          explanation:
              'Found ${duplicates.length} document number(s) shared by multiple active documents of the same type.',
          requiresManualReview: true,
          metadata: {'duplicates': duplicateList},
        ),
      );
    }

    return checks;
  }
}
