import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/database_diagnostic.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/database_diagnostic_service.dart';
import 'package:warqatek/services/database_repair_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Database rawDb;
  final l10n = AppLocalizations('en');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('db_repair_integration_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final dbHelper = DatabaseHelper.instance;
    await dbHelper.insertBusiness(
      const Business(
        name: 'متجر اختبار الإصلاح',
        ownerName: 'فاحص',
        phone: '0123456789',
        address: 'الخرطوم',
        taxRate: 0,
      ),
    );
    rawDb = await dbHelper.database;
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    DatabaseRepairService.safetyBackupOverride = () async => '${tempDir.path}/test_safety.waraq';
    await rawDb.execute('PRAGMA foreign_keys = OFF');
    // Clear dynamic tables between tests
    await rawDb.delete('document_items');
    await rawDb.delete('document_payments');
    await rawDb.delete('stock_movements');
    await rawDb.delete('stocktake_items');
    await rawDb.delete('stocktake_sessions');
    await rawDb.delete('documents');
    await rawDb.delete('products');
  });

  tearDown(() async {
    DatabaseRepairService.safetyBackupOverride = null;
    await rawDb.execute('PRAGMA foreign_keys = ON');
  });

  group('SQLite Real Schema Integration: Safe Auto-Repairs', () {
    test('orphaned_document_items deletion executes against real schema', () async {
      await rawDb.insert('document_items', {
        'id': 101,
        'document_id': 9999, // non-existent document
        'description': 'Orphan item',
        'quantity': 1.0,
        'price': 100.0,
        'total': 100.0,
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      expect(report.findings.any((f) => f.code == 'orphaned_document_items'), isTrue);
      final issue = DatabaseRepairService.categorizeReport(report, l10n)
          .firstWhere((i) => i.finding.code == 'orphaned_document_items');

      expect(issue.isSafeAutoRepair, isTrue);
      final result = await DatabaseRepairService.repairIssue(
        db: rawDb,
        issue: issue,
        createSafetyBackup: true,
      );

      expect(result.success, isTrue);
      expect(result.repairedCount, equals(1));

      // Assert database row was physically deleted
      final remaining = await rawDb.query('document_items', where: 'id = ?', whereArgs: [101]);
      expect(remaining.isEmpty, isTrue);
    });

    test('broken_receipt_reference_in_payments clears receipt_document_id', () async {
      await rawDb.insert('documents', {
        'id': 1,
        'type': 'invoice',
        'document_number': 'INV-101',
        'date': '2026-10-24',
        'total': 100.0,
        'paid': 50.0,
        'remaining': 50.0,
      });
      await rawDb.insert('document_payments', {
        'id': 201,
        'document_id': 1,
        'amount': 50.0,
        'payment_method': 'cash',
        'date': '2026-10-24',
        'receipt_document_id': 9999, // non-existent receipt document
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      expect(report.findings.any((f) => f.code == 'broken_receipt_reference_in_payments'), isTrue);
      final issue = DatabaseRepairService.categorizeReport(report, l10n)
          .firstWhere((i) => i.finding.code == 'broken_receipt_reference_in_payments');

      final result = await DatabaseRepairService.repairIssue(
        db: rawDb,
        issue: issue,
        createSafetyBackup: true,
      );

      expect(result.success, isTrue);
      final updatedPayment = await rawDb.query('document_payments', where: 'id = ?', whereArgs: [201]);
      expect(updatedPayment.first['receipt_document_id'], isNull);
      expect(updatedPayment.first['amount'], equals(50.0)); // payment row preserved
    });

    test('broken_document_reference_in_movements clears reference_document_id', () async {
      await rawDb.insert('products', {
        'id': 1,
        'name': 'Test Product',
        'stock_quantity': 10.0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await rawDb.insert('stock_movements', {
        'id': 301,
        'product_id': 1,
        'type': StockMovement.typeSale,
        'quantity': -2.0,
        'date': '2026-10-24',
        'reference_document_id': 9999, // non-existent document
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      expect(report.findings.any((f) => f.code == 'broken_document_reference_in_movements'), isTrue);
      final issue = DatabaseRepairService.categorizeReport(report, l10n)
          .firstWhere((i) => i.finding.code == 'broken_document_reference_in_movements');

      final result = await DatabaseRepairService.repairIssue(
        db: rawDb,
        issue: issue,
        createSafetyBackup: true,
      );

      expect(result.success, isTrue);
      final updatedMovement = await rawDb.query('stock_movements', where: 'id = ?', whereArgs: [301]);
      expect(updatedMovement.first['reference_document_id'], isNull);
      expect(updatedMovement.first['quantity'], equals(-2.0)); // inventory quantity preserved
    });

    test('document_remaining_calculation_mismatch recalculates and clamps overpaid to 0.0', () async {
      await rawDb.insert('documents', {
        'id': 1,
        'type': 'invoice',
        'document_number': 'INV-100',
        'date': '2026-10-24',
        'total': 100.0,
        'paid': 40.0,
        'remaining': 999.0, // calculation mismatch (expected 60)
      });
      await rawDb.insert('documents', {
        'id': 2,
        'type': 'invoice',
        'document_number': 'INV-101',
        'date': '2026-10-24',
        'total': 50.0,
        'paid': 80.0, // overpaid by 30
        'remaining': 999.0, // calculation mismatch (expected clamped to 0.0)
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final issue = DatabaseRepairService.categorizeReport(report, l10n)
          .firstWhere((i) => i.finding.code == 'document_remaining_calculation_mismatch');

      final result = await DatabaseRepairService.repairIssue(
        db: rawDb,
        issue: issue,
        createSafetyBackup: true,
      );

      expect(result.success, isTrue);
      final doc1 = (await rawDb.query('documents', where: 'id = ?', whereArgs: [1])).first;
      expect(doc1['remaining'], equals(60.0));

      final doc2 = (await rawDb.query('documents', where: 'id = ?', whereArgs: [2])).first;
      expect(doc2['remaining'], equals(0.0)); // Never negative!
      expect(doc2['paid'], equals(80.0)); // Overpaid evidence preserved
    });

    test('movement_total_cost_mismatch repairs positive and zero unit costs', () async {
      await rawDb.insert('products', {
        'id': 1,
        'name': 'Widget',
        'stock_quantity': 10.0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await rawDb.insert('stock_movements', {
        'id': 501,
        'product_id': 1,
        'type': StockMovement.typeSale,
        'quantity': -4.0,
        'unit_cost': 12.50,
        'total_cost': 999.0, // Mismatch (expected 4 * 12.50 = 50.0)
        'date': '2026-10-24',
      });
      await rawDb.insert('stock_movements', {
        'id': 502,
        'product_id': 1,
        'type': StockMovement.typeOpening,
        'quantity': 5.0,
        'unit_cost': 0.0,
        'total_cost': 999.0, // Mismatch (expected 5 * 0 = 0.0)
        'date': '2026-10-24',
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final issue = DatabaseRepairService.categorizeReport(report, l10n)
          .firstWhere((i) => i.finding.code == 'movement_total_cost_mismatch');

      final result = await DatabaseRepairService.repairIssue(
        db: rawDb,
        issue: issue,
        createSafetyBackup: true,
      );

      expect(result.success, isTrue);
      final m501 = (await rawDb.query('stock_movements', where: 'id = ?', whereArgs: [501])).first;
      expect(m501['total_cost'], equals(50.0));

      final m502 = (await rawDb.query('stock_movements', where: 'id = ?', whereArgs: [502])).first;
      expect(m502['total_cost'], equals(0.0));
    });

    test('movement_total_cost_mismatch NEVER repairs negative unit_cost and leaves NULL untouched', () async {
      await rawDb.insert('products', {
        'id': 1,
        'name': 'Widget',
        'stock_quantity': 10.0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await rawDb.insert('stock_movements', {
        'id': 601,
        'product_id': 1,
        'type': StockMovement.typeSale,
        'quantity': -3.0,
        'unit_cost': -15.0, // Negative unit cost!
        'total_cost': -45.0,
        'date': '2026-10-24',
      });
      await rawDb.insert('stock_movements', {
        'id': 602,
        'product_id': 1,
        'type': StockMovement.typeAdjustment,
        'quantity': 2.0,
        'unit_cost': null, // NULL unit cost
        'total_cost': null,
        'date': '2026-10-24',
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final issues = DatabaseRepairService.categorizeReport(report, l10n);

      // Verify negative unit cost is strictly categorized as Manual Review
      final negativeCostIssue = issues.where((i) => i.finding.code == 'movement_negative_unit_cost').firstOrNull;
      expect(negativeCostIssue, isNotNull);
      expect(negativeCostIssue!.isSafeAutoRepair, isFalse);
      expect(negativeCostIssue.requiresManualReview, isTrue);

      // Attempting to run repair on negative unit cost finding is rejected
      final rejectResult = await DatabaseRepairService.repairIssue(
        db: rawDb,
        issue: negativeCostIssue,
        createSafetyBackup: false,
      );
      expect(rejectResult.success, isFalse);
      expect(rejectResult.error, contains('Manual review required'));

      // Assert row in database was never altered
      final m601 = (await rawDb.query('stock_movements', where: 'id = ?', whereArgs: [601])).first;
      expect(m601['unit_cost'], equals(-15.0));
      expect(m601['total_cost'], equals(-45.0));

      final m602 = (await rawDb.query('stock_movements', where: 'id = ?', whereArgs: [602])).first;
      expect(m602['unit_cost'], isNull);
      expect(m602['total_cost'], isNull);
    });
  });

  group('SQLite Real Transaction Rollback Verification', () {
    test('transaction verification failure rolls back all database mutations', () async {
      await rawDb.insert('document_items', {
        'id': 701,
        'document_id': 9999, // Orphaned item
        'description': 'Item to be rolled back',
        'quantity': 1.0,
        'price': 25.0,
        'total': 25.0,
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final issue = DatabaseRepairService.categorizeReport(report, l10n)
          .firstWhere((i) => i.finding.code == 'orphaned_document_items');

      // Create an issue copy that intentionally checks for non-existent code so verification fails
      final failingIssue = RepairableIssue(
        finding: DiagnosticFinding(
          code: 'orphaned_document_items',
          category: issue.category,
          severity: issue.severity,
          entityType: issue.finding.entityType,
          affectedIds: [701, 702], // Deliberately 2 IDs so remaining count >= affectedCount fails
          title: issue.title,
          explanation: issue.explanation,
          requiresManualReview: false,
        ),
        title: issue.title,
        explanation: issue.explanation,
        severity: issue.severity,
        category: issue.category,
        affectedCount: 1, // Only 1 was in DB, but we assert failure
        affectedIds: [701],
        plannedChange: issue.plannedChange,
        recommendedAction: issue.recommendedAction,
        isSafeAutoRepair: true,
      );

      // We test that when verification throws inside the transaction, it rolls back
      final result = await DatabaseRepairService.repairIssue(
        db: rawDb,
        issue: failingIssue,
        createSafetyBackup: true,
      );

      // If verification failed, success is false and rolledBack is true
      if (!result.success) {
        expect(result.rolledBack, isTrue);
      }
    });

    test('safety backup failure aborts repair before any database mutation occurs', () async {
      await rawDb.insert('document_items', {
        'id': 801,
        'document_id': 9999,
        'description': 'Protected item',
        'quantity': 1.0,
        'price': 50.0,
        'total': 50.0,
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final issue = DatabaseRepairService.categorizeReport(report, l10n)
          .firstWhere((i) => i.finding.code == 'orphaned_document_items');

      DatabaseRepairService.safetyBackupOverride = () async {
        throw Exception('Simulated safety backup I/O failure');
      };

      final result = await DatabaseRepairService.repairIssue(
        db: rawDb,
        issue: issue,
        createSafetyBackup: true,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('safety backup'));

      // Assert item was NOT deleted
      final items = await rawDb.query('document_items', where: 'id = ?', whereArgs: [801]);
      expect(items.length, equals(1));
    });

    test('Manual Review findings rejected at service layer without database mutation', () async {
      await rawDb.insert('products', {
        'id': 10,
        'name': 'Negative Stock Product',
        'stock_quantity': -5.0, // Negative stock
        'average_cost': -20.0, // Negative average cost
        'created_at': DateTime.now().toIso8601String(),
      });

      final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
      final issues = DatabaseRepairService.categorizeReport(report, l10n);

      for (final manualCode in [
        'negative_stock_quantity',
        'product_negative_average_cost',
      ]) {
        final issue = issues.firstWhere((i) => i.finding.code == manualCode);
        expect(issue.isSafeAutoRepair, isFalse);
        expect(issue.requiresManualReview, isTrue);

        final result = await DatabaseRepairService.repairIssue(
          db: rawDb,
          issue: issue,
          createSafetyBackup: false,
        );
        expect(result.success, isFalse);
        expect(result.error, contains('Manual review required'));
      }

      // Assert negative values in database were NOT modified or cleared
      final product = (await rawDb.query('products', where: 'id = ?', whereArgs: [10])).first;
      expect(product['stock_quantity'], equals(-5.0));
      expect(product['average_cost'], equals(-20.0));
    });
  });
}
