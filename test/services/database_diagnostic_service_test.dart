import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/database_diagnostic.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/database_diagnostic_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseExecutor rawDb;
  late Business testBusiness;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('diagnostic_service_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'مؤسسة الفحص والتشخيص',
        ownerName: 'فاحص',
        phone: '0123456789',
        address: 'الخرطوم',
        taxRate: 0,
      ),
    );
    testBusiness = (await db.getFirstBusiness())!;
    rawDb = await db.database;
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test(
    '1. Diagnostics does NOT mutate or change any database records (strict read-only)',
    () async {
      final tables = [
        'businesses',
        'contacts',
        'products',
        'documents',
        'document_items',
        'document_payments',
        'stock_movements',
        'stocktake_sessions',
        'stocktake_items',
        'audit_log',
      ];

      // Snapshot counts and table rows before diagnostics
      final preCounts = <String, int>{};
      final preSnapshots = <String, List<Map<String, dynamic>>>{};
      for (final table in tables) {
        final rows = await rawDb.query(table);
        preCounts[table] = rows.length;
        preSnapshots[table] = rows;
      }

      // Run full diagnostics
      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      expect(report.totalChecksRun, greaterThanOrEqualTo(20));

      // Verify all table row counts and contents are completely identical
      for (final table in tables) {
        final postRows = await rawDb.query(table);
        expect(
          postRows.length,
          preCounts[table],
          reason: 'Table $table count changed after diagnostics',
        );
        expect(
          postRows,
          preSnapshots[table],
          reason: 'Table $table data mutated after diagnostics',
        );
      }
    },
  );

  test(
    '2. Clean database with valid documents and stock produces zero findings',
    () async {
      // Create a product with normal opening stock
      final pid = await ProductService.createProduct(
        name: 'منتج سليم 1',
        salePrice: 100,
        purchasePrice: 60,
        stockQuantity: 50,
      );

      // Create a normal invoice with issued status and costed items
      final invId = await DocumentService.createDocument(
        type: 'invoice',
        business: testBusiness,
        items: [
          DocumentItemInput(
            description: 'منتج سليم 1',
            quantity: 5,
            price: 100,
            productId: pid,
          ),
        ],
        paid: 200,
        paymentMethod: 'cash',
      );

      expect(invId, greaterThan(0));

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      expect(
        report.errorCount,
        0,
        reason: 'Clean records should not produce errors',
      );
      expect(
        report.warningCount,
        0,
        reason: 'Clean records should not produce warnings',
      );
    },
  );

  test('3. Detects orphaned records and broken foreign key references', () async {
    await rawDb.execute('PRAGMA foreign_keys = OFF');
    late int orphanedItemId;
    late int brokenProductItemId;
    late int orphanedPaymentId;
    late int brokenReceiptPaymentId;
    late int orphanedMovementId;
    late int brokenDocMovementId;
    late int brokenRelatedDocId;

    try {
      // 3.1 Insert orphaned document_item referencing non-existent document ID 99999
      orphanedItemId = await rawDb.insert('document_items', {
        'document_id': 99999,
        'description': 'بند يتيم',
        'quantity': 1.0,
        'price': 50.0,
        'total': 50.0,
        'taxable': 0,
      });

      // 3.2 Insert broken product reference in document_item
      final validDocId =
          (await rawDb.query(
                'documents',
                columns: ['id'],
                limit: 1,
              )).first['id']
              as int;
      brokenProductItemId = await rawDb.insert('document_items', {
        'document_id': validDocId,
        'product_id': 88888, // Non-existent product
        'description': 'منتج غير موجود',
        'quantity': 1.0,
        'price': 20.0,
        'total': 20.0,
        'taxable': 0,
      });

      // 3.3 Insert orphaned document_payment
      orphanedPaymentId = await rawDb.insert('document_payments', {
        'document_id': 99999,
        'amount': 100.0,
        'date': DateTime.now().toIso8601String(),
      });

      // 3.4 Insert broken receipt reference in payment
      brokenReceiptPaymentId = await rawDb.insert('document_payments', {
        'document_id': validDocId,
        'receipt_document_id': 77777, // Non-existent receipt
        'amount': 50.0,
        'date': DateTime.now().toIso8601String(),
      });

      // 3.5 Insert orphaned stock_movement
      orphanedMovementId = await rawDb.insert('stock_movements', {
        'product_id': 66666, // Non-existent product
        'type': StockMovement.typeOpening,
        'quantity': 10.0,
        'date': DateTime.now().toIso8601String(),
      });

      // 3.6 Insert broken reference document in stock_movement
      final validProdId =
          (await rawDb.query('products', columns: ['id'], limit: 1)).first['id']
              as int;
      brokenDocMovementId = await rawDb.insert('stock_movements', {
        'product_id': validProdId,
        'reference_document_id': 55555, // Non-existent document
        'type': StockMovement.typeSale,
        'quantity': -1.0,
        'date': DateTime.now().toIso8601String(),
      });

      // 3.7 Insert broken related_document_id in documents
      brokenRelatedDocId = await rawDb.insert('documents', {
        'type': 'payment_receipt',
        'document_number': 'REC-BROKEN-01',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 50.0,
        'total': 50.0,
        'paid': 50.0,
        'remaining': 0.0,
        'related_document_id': 44444, // Non-existent parent document
        'status': 'issued',
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final codes = report.findings.map((f) => f.code).toSet();

      expect(codes, contains('orphaned_document_items'));
      expect(codes, contains('broken_product_reference_in_items'));
      expect(codes, contains('orphaned_document_payments'));
      expect(codes, contains('broken_receipt_reference_in_payments'));
      expect(codes, contains('orphaned_stock_movements'));
      expect(codes, contains('broken_document_reference_in_movements'));
      expect(codes, contains('broken_related_document_in_documents'));
    } finally {
      await rawDb.delete(
        'document_items',
        where: 'id IN (?, ?)',
        whereArgs: [orphanedItemId, brokenProductItemId],
      );
      await rawDb.delete(
        'document_payments',
        where: 'id IN (?, ?)',
        whereArgs: [orphanedPaymentId, brokenReceiptPaymentId],
      );
      await rawDb.delete(
        'stock_movements',
        where: 'id IN (?, ?)',
        whereArgs: [orphanedMovementId, brokenDocMovementId],
      );
      await rawDb.delete(
        'documents',
        where: 'id = ?',
        whereArgs: [brokenRelatedDocId],
      );
      await rawDb.execute('PRAGMA foreign_keys = ON');
    }
  });

  test('4. Detects document balance and total mismatches', () async {
    late int badTotalDocId;
    late int badRemainingDocId;
    late int overpaidDocId;

    try {
      // Inconsistent document where total != subtotal - discount + tax
      badTotalDocId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-BAD-TOTAL',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 1000.0,
        'discount': 100.0,
        'tax_amount': 50.0,
        'total': 1200.0, // Expected: 950.0
        'paid': 0.0,
        'remaining': 1200.0,
        'status': 'issued',
      });

      // Document where remaining != total - paid
      badRemainingDocId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-BAD-REMAINING',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 500.0,
        'total': 500.0,
        'paid': 200.0,
        'remaining': 100.0, // Expected: 300.0
        'status': 'partially_paid',
      });

      // Document where paid > total (overpaid)
      overpaidDocId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-OVERPAID',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 300.0,
        'total': 300.0,
        'paid': 400.0,
        'remaining': 0.0,
        'status': 'paid',
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final codes = report.findings.map((f) => f.code).toSet();

      expect(codes, contains('document_total_calculation_mismatch'));
      expect(codes, contains('document_remaining_calculation_mismatch'));
      expect(codes, contains('document_overpaid'));
    } finally {
      await rawDb.delete(
        'documents',
        where: 'id IN (?, ?, ?)',
        whereArgs: [badTotalDocId, badRemainingDocId, overpaidDocId],
      );
    }
  });

  test('5. Detects document status inconsistencies', () async {
    late int paidIncompleteId;
    late int unpaidWithMoneyId;
    late int partialZeroId;

    try {
      // 5.1 Status = paid, but paid < total
      paidIncompleteId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-STATUS-1',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 500.0,
        'total': 500.0,
        'paid': 200.0,
        'remaining': 300.0,
        'status': 'paid',
      });

      // 5.2 Status = unpaid, but paid > 0
      unpaidWithMoneyId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-STATUS-2',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 500.0,
        'total': 500.0,
        'paid': 200.0,
        'remaining': 300.0,
        'status': 'unpaid',
      });

      // 5.3 Status = partially_paid, but paid == 0
      partialZeroId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-STATUS-3',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 500.0,
        'total': 500.0,
        'paid': 0.0,
        'remaining': 500.0,
        'status': 'partially_paid',
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final codes = report.findings.map((f) => f.code).toSet();

      expect(codes, contains('document_status_paid_incomplete'));
      expect(codes, contains('document_status_unpaid_with_payments'));
      expect(codes, contains('document_status_partial_invalid'));
    } finally {
      await rawDb.delete(
        'documents',
        where: 'id IN (?, ?, ?)',
        whereArgs: [paidIncompleteId, unpaidWithMoneyId, partialZeroId],
      );
    }
  });

  test(
    '6. Detects payment integrity mismatches and missing receipt records',
    () async {
      late int doc1Id;
      late int pmt1Id;
      late int receiptId;

      try {
        // 6.1 Payment records exceed document.paid
        doc1Id = await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-PMT-1',
          'date': DateTime.now().toIso8601String(),
          'subtotal': 500.0,
          'total': 500.0,
          'paid': 200.0,
          'remaining': 300.0,
          'status': 'partially_paid',
        });
        pmt1Id = await rawDb.insert('document_payments', {
          'document_id': doc1Id,
          'amount': 300.0, // Exceeds doc.paid (200.0)
          'date': DateTime.now().toIso8601String(),
        });

        // 6.2 Active linked receipt document without a document_payments row
        receiptId = await rawDb.insert('documents', {
          'type': 'payment_receipt',
          'document_number': 'REC-ACTIVE-01',
          'date': DateTime.now().toIso8601String(),
          'subtotal': 100.0,
          'total': 100.0,
          'paid': 100.0,
          'remaining': 0.0,
          'related_document_id': doc1Id,
          'status': 'issued',
        });

        final report = await DatabaseDiagnosticService.runDiagnostics(
          db: rawDb,
        );
        final codes = report.findings.map((f) => f.code).toSet();

        expect(codes, contains('payment_records_exceed_document_paid'));
        expect(codes, contains('active_receipt_missing_payment_record'));
      } finally {
        await rawDb.delete(
          'document_payments',
          where: 'id = ?',
          whereArgs: [pmt1Id],
        );
        await rawDb.delete(
          'documents',
          where: 'id IN (?, ?)',
          whereArgs: [doc1Id, receiptId],
        );
      }
    },
  );

  test(
    '7. Detects stock movement ledger discrepancies and missing opening stock',
    () async {
      late int prodDiscrepantId;
      late int mvtId;
      late int prodNoMovementsId;

      try {
        // 7.1 Product stock quantity does not match algebraic sum of movements
        prodDiscrepantId = await rawDb.insert('products', {
          'name': 'منتج به فارق مخزني',
          'type': 'product',
          'stock_quantity': 25.0,
        });
        mvtId = await rawDb.insert('stock_movements', {
          'product_id': prodDiscrepantId,
          'type': StockMovement.typeOpening,
          'quantity': 20.0, // 20 != 25
          'date': DateTime.now().toIso8601String(),
        });

        // 7.2 Product with stock on hand but ZERO stock movements
        prodNoMovementsId = await rawDb.insert('products', {
          'name': 'منتج قديم بدون حركات',
          'type': 'product',
          'stock_quantity': 15.0,
        });

        final report = await DatabaseDiagnosticService.runDiagnostics(
          db: rawDb,
        );
        final codes = report.findings.map((f) => f.code).toSet();

        expect(codes, contains('stock_movement_ledger_mismatch'));
        expect(codes, contains('missing_opening_stock'));
      } finally {
        await rawDb.delete(
          'stock_movements',
          where: 'id = ?',
          whereArgs: [mvtId],
        );
        await rawDb.delete(
          'products',
          where: 'id IN (?, ?)',
          whereArgs: [prodDiscrepantId, prodNoMovementsId],
        );
      }
    },
  );

  test('8. Detects negative stock balances and suspicious values', () async {
    late int negProdId;
    try {
      negProdId = await rawDb.insert('products', {
        'name': 'منتج برصيد سالب',
        'type': 'product',
        'stock_quantity': -10.0,
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final codes = report.findings.map((f) => f.code).toSet();

      expect(codes, contains('negative_stock_quantity'));
    } finally {
      await rawDb.delete('products', where: 'id = ?', whereArgs: [negProdId]);
    }
  });

  test('9. Detects inventory costing inconsistencies', () async {
    late int prodNullCostId;
    late int prodNegCostId;
    late int prodUnknownCostId;
    late int mvtKnownNullId;
    late int mvtMismatchId;
    late int invId;
    late int uncostedItemId;

    try {
      // 9.1 Product with cost_status = 'known' but average_cost IS NULL
      prodNullCostId = await rawDb.insert('products', {
        'name': 'منتج تكلفة معلومة خالية',
        'type': 'product',
        'stock_quantity': 10.0,
        'cost_status': StockMovement.costStatusKnown,
        'average_cost': null,
      });

      // 9.2 Product with negative average cost
      prodNegCostId = await rawDb.insert('products', {
        'name': 'منتج تكلفة سالبة',
        'type': 'product',
        'stock_quantity': 5.0,
        'average_cost': -20.0,
      });

      // 9.3 Product with stock on hand but unknown cost
      prodUnknownCostId = await rawDb.insert('products', {
        'name': 'بضاعة مجهولة التكلفة',
        'type': 'product',
        'stock_quantity': 8.0,
        'cost_status': StockMovement.costStatusUnknown,
        'average_cost': null,
      });

      // 9.4 Stock movement with cost_status = 'known' but unit_cost IS NULL
      mvtKnownNullId = await rawDb.insert('stock_movements', {
        'product_id': prodNullCostId,
        'type': StockMovement.typeOpening,
        'quantity': 10.0,
        'cost_status': StockMovement.costStatusKnown,
        'unit_cost': null,
        'date': DateTime.now().toIso8601String(),
      });

      // 9.5 Stock movement total_cost mismatch (total_cost != qty * unit_cost)
      mvtMismatchId = await rawDb.insert('stock_movements', {
        'product_id': prodNullCostId,
        'type': StockMovement.typePurchase,
        'quantity': 4.0,
        'unit_cost': 25.0,
        'total_cost': 150.0, // Expected: 100.0
        'cost_status': StockMovement.costStatusKnown,
        'date': DateTime.now().toIso8601String(),
      });

      // 9.6 Issued sales invoice item without cost for stocked product
      invId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-UNCOSTED',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 200.0,
        'total': 200.0,
        'paid': 200.0,
        'remaining': 0.0,
        'status': 'paid',
      });
      uncostedItemId = await rawDb.insert('document_items', {
        'document_id': invId,
        'product_id': prodNullCostId,
        'description': 'بند مباع بدون تكلفة',
        'quantity': 2.0,
        'price': 100.0,
        'total': 200.0,
        'taxable': 0,
        'unit_cost': null,
        'total_cost': null,
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final codes = report.findings.map((f) => f.code).toSet();

      expect(codes, contains('product_cost_status_known_missing_cost'));
      expect(codes, contains('product_negative_average_cost'));
      expect(codes, contains('product_held_stock_unknown_cost'));
      expect(codes, contains('movement_known_status_missing_cost'));
      expect(codes, contains('movement_total_cost_mismatch'));
      expect(codes, contains('issued_sale_item_missing_cost'));
    } finally {
      await rawDb.delete(
        'document_items',
        where: 'id = ?',
        whereArgs: [uncostedItemId],
      );
      await rawDb.delete('documents', where: 'id = ?', whereArgs: [invId]);
      await rawDb.delete(
        'stock_movements',
        where: 'id IN (?, ?)',
        whereArgs: [mvtKnownNullId, mvtMismatchId],
      );
      await rawDb.delete(
        'products',
        where: 'id IN (?, ?, ?)',
        whereArgs: [prodNullCostId, prodNegCostId, prodUnknownCostId],
      );
    }
  });

  test('10. Detects duplicate active document numbers', () async {
    late int docAId;
    late int docBId;

    try {
      docAId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-DUP-99',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 100.0,
        'total': 100.0,
        'paid': 0.0,
        'remaining': 100.0,
        'status': 'issued',
      });

      docBId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-DUP-99', // Duplicate number!
        'date': DateTime.now().toIso8601String(),
        'subtotal': 100.0,
        'total': 100.0,
        'paid': 0.0,
        'remaining': 100.0,
        'status': 'issued',
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final dupFinding = report.findings.firstWhere(
        (f) => f.code == 'duplicate_document_number',
      );

      expect(dupFinding.affectedIds, containsAll([docAId, docBId]));
      expect(dupFinding.requiresManualReview, isTrue);
    } finally {
      await rawDb.delete(
        'documents',
        where: 'id IN (?, ?)',
        whereArgs: [docAId, docBId],
      );
    }
  });

  test(
    '11. Legacy invoices without payment rows do NOT produce false-positive errors',
    () async {
      late int legacyInvId;
      late int standaloneReceiptId;
      late int quotationId;

      try {
        // A legacy invoice from an older backup where upfront payment was stored directly
        // in documents.paid and documents.remaining, without a corresponding document_payments row.
        legacyInvId = await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-LEGACY-001',
          'date': DateTime.now().toIso8601String(),
          'subtotal': 1000.0,
          'total': 1000.0,
          'paid': 400.0,
          'remaining': 600.0,
          'status': 'partially_paid',
        });

        // Standalone receipt document (related_document_id == null)
        standaloneReceiptId = await rawDb.insert('documents', {
          'type': 'payment_receipt',
          'document_number': 'REC-STANDALONE-001',
          'date': DateTime.now().toIso8601String(),
          'subtotal': 250.0,
          'total': 250.0,
          'paid': 250.0,
          'remaining': 0.0,
          'related_document_id': null,
          'status': 'issued',
        });

        // Valid quotation document (paid == 0, remaining == 0, no stock movements)
        quotationId = await rawDb.insert('documents', {
          'type': 'quotation',
          'document_number': 'QUO-001',
          'date': DateTime.now().toIso8601String(),
          'subtotal': 800.0,
          'total': 800.0,
          'paid': 0.0,
          'remaining': 0.0,
          'status': 'issued',
        });

        final report = await DatabaseDiagnosticService.runDiagnostics(
          db: rawDb,
        );

        // Verify none of these legitimate legacy/supported documents triggered false-positive errors
        final affectedDocumentErrorIds = report.findings
            .where(
              (f) =>
                  f.entityType == 'documents' &&
                  f.severity == DiagnosticSeverity.error,
            )
            .expand((f) => f.affectedIds)
            .toSet();

        expect(affectedDocumentErrorIds, isNot(contains(legacyInvId)));
        expect(affectedDocumentErrorIds, isNot(contains(standaloneReceiptId)));
        expect(affectedDocumentErrorIds, isNot(contains(quotationId)));
      } finally {
        await rawDb.delete(
          'documents',
          where: 'id IN (?, ?, ?)',
          whereArgs: [legacyInvId, standaloneReceiptId, quotationId],
        );
      }
    },
  );
}
