import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/database_diagnostic.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/journal_reconciliation_service.dart';
import 'package:warqatek/services/database_diagnostic_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('journal_reconciliation_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    db = DatabaseHelper.instance;
  });

  tearDownAll(() async {
    await db.closeDatabase();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await db.closeDatabase();
    if (tempDir.existsSync()) {
      for (final f in tempDir.listSync()) {
        if (f is File) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }

    await db.insertBusiness(
      const Business(
        name: 'Reconciliation Test Co',
        ownerName: 'Auditor',
        phone: '0123456789',
        address: 'Khartoum',
        currencyCode: 'SDG',
        taxRate: 0.15,
        taxesEnabled: true,
        pricesIncludeTax: false,
      ),
    );
  });

  test('1. Clean database produces zero reconciliation findings', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'شاي فاخر',
        barcode: 'TEA-1',
        salePrice: 120.0,
        purchasePrice: 70.0,
        averageCost: 70.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 20.0,
      ),
    );

    // Create an invoice
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-REC-1',
      date: DateTime(2026, 3, 1),
      subtotal: 240.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 36.0,
      total: 276.0,
      paid: 276.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(inv, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'شاي فاخر',
        quantity: 2.0,
        price: 120.0,
        total: 240.0,
      ),
    ]);

    final findings = await JournalReconciliationService.runReconciliation();
    expect(findings, isEmpty, reason: 'Clean database must have 0 reconciliation discrepancies');
  });

  test('2. Unbalanced journal entries are flagged with requiresManualReview: true', () async {
    final rawDb = await db.database;

    // Create a dummy entry
    final entryId = await rawDb.insert('journal_entries', {
      'entry_no': 'JE-TEST-UNBALANCED',
      'effective_date': '2026-03-01',
      'posted_at': DateTime.now().toIso8601String(),
      'source_type': 'invoice',
      'source_id': 9999,
      'revision': 1,
      'origin': 'live',
    });

    // Deliberately insert unbalanced lines (Dr 1000 vs Cr 500)
    await rawDb.insert('journal_lines', {
      'entry_id': entryId,
      'account_code': '1110',
      'debit_minor': 1000,
      'credit_minor': 0,
    });
    await rawDb.insert('journal_lines', {
      'entry_id': entryId,
      'account_code': '4100',
      'debit_minor': 0,
      'credit_minor': 500,
    });

    final findings = await JournalReconciliationService.runReconciliation();
    final unbalancedFinding = findings.firstWhere(
      (f) => f.code == 'unbalanced_journal_entry',
    );

    expect(unbalancedFinding.category, equals(DiagnosticCategory.accountingReconciliation));
    expect(unbalancedFinding.severity, equals(DiagnosticSeverity.error));
    expect(unbalancedFinding.requiresManualReview, isTrue);
    expect(unbalancedFinding.affectedIds, contains(entryId));
  });

  test('3. Product stock discrepancy vs movement ledger is flagged', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'سكر كنانة',
        barcode: 'SUGAR-1',
        salePrice: 50.0,
        purchasePrice: 30.0,
        stockQuantity: 100.0, // stock_quantity = 100
      ),
    );

    // Deliberately corrupt stock quantity directly in products table
    final rawDb = await db.database;
    await rawDb.update(
      'products',
      {'stock_quantity': 42.0}, // movement sum is 0, stock is 42 -> discrepancy!
      where: 'id = ?',
      whereArgs: [pId],
    );

    final findings = await JournalReconciliationService.runReconciliation();
    final stockDiscrepancy = findings.firstWhere(
      (f) => f.code == 'product_stock_movement_discrepancy',
    );

    expect(stockDiscrepancy.category, equals(DiagnosticCategory.accountingReconciliation));
    expect(stockDiscrepancy.severity, equals(DiagnosticSeverity.error));
    expect(stockDiscrepancy.requiresManualReview, isTrue);
    expect(stockDiscrepancy.affectedIds, contains(pId));
  });

  test('4. Orphaned journal lines are detected and flagged', () async {
    final rawDb = await db.database;

    // Temporarily disable foreign keys to simulate corrupt orphaned records
    await rawDb.execute('PRAGMA foreign_keys = OFF');
    final orphanId = await rawDb.insert('journal_lines', {
      'entry_id': 999999,
      'account_code': '1110',
      'debit_minor': 5000,
      'credit_minor': 0,
    });
    await rawDb.execute('PRAGMA foreign_keys = ON');

    final findings = await JournalReconciliationService.runReconciliation();
    final orphanFinding = findings.firstWhere(
      (f) => f.code == 'orphaned_journal_lines',
    );

    expect(orphanFinding.category, equals(DiagnosticCategory.accountingReconciliation));
    expect(orphanFinding.severity, equals(DiagnosticSeverity.error));
    expect(orphanFinding.requiresManualReview, isTrue);
    expect(orphanFinding.affectedIds, contains(orphanId));
  });

  test('5. DatabaseDiagnosticService integrates reconciliation checks seamlessly', () async {
    final report = await DatabaseDiagnosticService.runDiagnostics();
    expect(report.totalChecksRun, greaterThanOrEqualTo(8));
  });
}
