import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/csv_service.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Product testProduct;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('reports_and_csv_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر التقارير',
        ownerName: 'أحمد',
        phone: '0912345678',
        address: 'الخرطوم',
        taxRate: 0,
      ),
    );
    final pid = await ProductService.createProduct(
      name: 'زيت طعام',
      salePrice: 5000,
      stockQuantity: 0.0,
      unit: 'لتر',
    );
    testProduct = (await db.getProductById(pid))!;
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('CsvService._parseNum', () {
    test('parses Arabic-Indic digits ٤٥٠٠٠ to 45000.0', () {
      expect(CsvService.parseNumberForTest('٤٥٠٠٠'), 45000.0);
    });

    test('parses comma decimal 12,50 to 12.5', () {
      expect(CsvService.parseNumberForTest('12,50'), 12.5);
    });

    test('rejects 3 decimals with comma 12,345 (returns null)', () {
      expect(CsvService.parseNumberForTest('12,345'), isNull);
    });

    test('parses Arabic comma decimal ١٢٫٥ to 12.5', () {
      expect(CsvService.parseNumberForTest('١٢٫٥'), 12.5);
    });

    test('returns null for invalid string', () {
      expect(CsvService.parseNumberForTest('invalid'), isNull);
    });
  });

  group('CsvService CSV delimiter and in-file duplicate detection', () {
    test('CSV import with ; delimiter parses successfully', () async {
      const csvContent = 'name;saleprice\nمنتج سيمي;150.5';
      final bytes = utf8.encode(csvContent);
      final preview = await CsvService.instance.previewImport(bytes);

      expect(preview.errorCount, 0);
      expect(preview.validNewCount, 1);
      expect(preview.rows.first.name, 'منتج سيمي');
      expect(preview.rows.first.salePrice, 150.5);
    });

    test(
      'CSV import with duplicate name in the file flags the second row with صف مكرر داخل الملف',
      () async {
        const csvContent = 'name,saleprice\nمنتج فريد,100\nمنتج فريد,200';
        final bytes = utf8.encode(csvContent);
        final preview = await CsvService.instance.previewImport(bytes);

        expect(preview.validNewCount, 1);
        expect(preview.errorCount, 1);
        expect(preview.rows.length, 2);
        expect(preview.rows[0].isValid, true);
        expect(preview.rows[1].isValid, false);
        expect(preview.rows[1].errorMessage, 'صف مكرر داخل الملف');
      },
    );
  });

  group('Stock movement running balance and reporting correctness', () {
    test(
      'stock movement running balance with limit/offset and type filtering',
      () async {
        final db = await DatabaseHelper.instance.database;

        // Insert 5 movements chronologically
        final baseDate = DateTime(2026, 1, 1, 10, 0);
        final qtys = [10.0, 20.0, -5.0, 15.0, -8.0];
        final types = ['in', 'in', 'out', 'in', 'out'];

        for (int i = 0; i < 5; i++) {
          await db.insert('stock_movements', {
            'product_id': testProduct.id!,
            'type': types[i],
            'quantity': qtys[i],
            'date': baseDate.add(Duration(days: i)).toIso8601String(),
            'notes': 'Movement $i',
          });
        }

        // Query with limit: 2, offset: 1
        // Chronological:
        // Mov 0: qty 10 -> balance = 10
        // Mov 1: qty 20 -> balance = 30
        // Mov 2: qty -5 -> balance = 25
        // Mov 3: qty 15 -> balance = 40
        // Mov 4: qty -8 -> balance = 32
        //
        // Ordered DESC:
        // index 0: Mov 4 (qty -8)
        // index 1: Mov 3 (qty 15)  <-- offset: 1, limit: 2 starts here
        // index 2: Mov 2 (qty -5)
        // index 3: Mov 1 (qty 20)
        // index 4: Mov 0 (qty 10)
        final report = await BusinessReportingService.instance
            .getStockMovementsReport(
              productId: testProduct.id!,
              limit: 2,
              offset: 1,
            );

        expect(report.items.length, 2);

        // Newest displayed row is Mov 3
        final newestDisplayed = report.items.first;
        expect(newestDisplayed.movement.quantity, 15.0);
        expect(newestDisplayed.isBalanceReliable, true);
        // Balance after Mov 3 = 10 + 20 - 5 + 15 = 40.0
        expect(newestDisplayed.balanceAfter, 40.0);
        expect(newestDisplayed.balanceBefore, 25.0);

        // Oldest displayed row in this page is Mov 2
        final olderDisplayed = report.items.last;
        expect(olderDisplayed.movement.quantity, -5.0);
        expect(olderDisplayed.isBalanceReliable, true);
        expect(olderDisplayed.balanceAfter, 25.0);
        expect(olderDisplayed.balanceBefore, 30.0);

        // Total-in and total-out should reflect the complete range, not just the page
        // In = 10 + 20 + 15 = 45.0
        // Out = 5 + 8 = 13.0
        expect(report.totalInQuantity, 45.0);
        expect(report.totalOutQuantity, 13.0);

        // Filter by type -> isBalanceReliable == false and balances are null
        final typeFilteredReport = await BusinessReportingService.instance
            .getStockMovementsReport(productId: testProduct.id!, type: 'in');

        expect(typeFilteredReport.items.isNotEmpty, true);
        for (final item in typeFilteredReport.items) {
          expect(item.isBalanceReliable, false);
          expect(item.balanceBefore, isNull);
          expect(item.balanceAfter, isNull);
        }
      },
    );
  });
}
