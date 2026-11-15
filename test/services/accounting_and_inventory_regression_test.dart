import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/stocktake_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Business business;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('acc_inv_reg_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final db = DatabaseHelper.instance;
    await AccessGuard.runAsSystem(() async {
      await db.insertBusiness(const Business(
        name: 'Test Business',
        ownerName: 'Owner',
        phone: '0123456789',
        address: 'Khartoum',
        currencyCode: 'SDG',
        taxRate: 0,
      ));
      business = (await db.getFirstBusiness())!;
    });
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Phase 2: ACC-01 Standalone Expense Vouchers', () {
    test(
      'Standalone expense voucher with plain-text payee does not insert contact and balances correctly',
      () async {
        final db = await DatabaseHelper.instance.database;
        final initialContactCount = (await db.rawQuery(
          'SELECT COUNT(*) as count FROM contacts',
        )).first['count'] as int;

        final docId = await AccessGuard.runAsSystem(() async {
          return await DocumentService.createDocument(
            type: 'expense_voucher',
            business: business,
            contact: null,
            recipientName: 'Electricity Authority',
            items: const [],
            paid: 350.0,
            notes: 'Office electric bill',
            paymentMethod: 'cash',
          );
        });

        expect(docId, isPositive);

        // 1. Verify no false contact was inserted
        final finalContactCount = (await db.rawQuery(
          'SELECT COUNT(*) as count FROM contacts',
        )).first['count'] as int;
        expect(finalContactCount, initialContactCount);

        // 2. Verify document contains plain-text recipientName and null contactId
        final doc = (await DatabaseHelper.instance.getDocumentById(docId))!;
        expect(doc.recipientName, 'Electricity Authority');
        expect(doc.contactId, isNull);
        expect(doc.total, 350.0);
        expect(doc.paid, 350.0);

        // 3. Verify journal entry posted Operating Expenses (5100) debit and Cash (1110) credit
        final lines = await db.rawQuery('''
          SELECT jl.*, jl.account_code as acc_code
          FROM journal_lines jl
          JOIN journal_entries je ON jl.entry_id = je.id
          WHERE je.source_id = ? AND je.source_type = 'voucher'
        ''', [docId]);

        expect(lines.length, 2);
        final expenseLine = lines.firstWhere((l) => l['acc_code'] == '6100');
        final cashLine = lines.firstWhere((l) => l['acc_code'] == '1110');
        expect(expenseLine['debit_minor'], 35000); // 350 * 100
        expect(cashLine['credit_minor'], 35000);
      },
    );
  });

  group('Phase 2: INV-01 Complete-Range Stock Movement Report Totals', () {
    test(
      'getStockMovementsReport calculates totals across entire date range, not just paginated limit',
      () async {
        final db = DatabaseHelper.instance;

        // Create product
        int pId = 0;
        await AccessGuard.runAsSystem(() async {
          pId = await db.insertProduct(Product(
            name: 'Report Test Product',
            stockQuantity: 0.0,
            salePrice: 100.0,
            purchasePrice: 50.0,
          ));
        });

        // Insert 4 stock movements: 3 in (+30, +40, +50) and 1 out (-20) -> Total In: 120, Total Out: 20
        final fromDate = DateTime.now().subtract(const Duration(days: 2));
        final toDate = DateTime.now().add(const Duration(days: 1));

        await AccessGuard.runAsSystem(() async {
          await db.adjustStock(productId: pId, delta: 30.0, reason: 'test_in_1');
          await db.adjustStock(productId: pId, delta: 40.0, reason: 'test_in_2');
          await db.adjustStock(productId: pId, delta: 50.0, reason: 'test_in_3');
          await db.adjustStock(productId: pId, delta: -20.0, reason: 'test_out_1');
        });

        // Query report with limit: 2 (paginating to only 2 items)
        final summary = await BusinessReportingService.instance
            .getStockMovementsReport(
          productId: pId,
          from: fromDate,
          to: toDate,
          limit: 2,
        );

        // Displayed items must be limited to 2
        expect(summary.items.length, 2);

        // Total In and Total Out MUST reflect the entire matching range (120 In, 20 Out)
        expect(summary.totalInQuantity, 120.0);
        expect(summary.totalOutQuantity, 20.0);
      },
    );
  });

  group('Phase 2: STK-01 Stocktake Finalization Reconciliation', () {
    test(
      'Stocktake finalization reconciles count discrepancy against baseline without overwriting intervening sales',
      () async {
        final db = DatabaseHelper.instance;

        // 1. Create product with 100 stock
        int pId = 0;
        await AccessGuard.runAsSystem(() async {
          pId = await db.insertProduct(Product(
            name: 'Stocktake Test Product',
            stockQuantity: 100.0,
            salePrice: 50.0,
            purchasePrice: 30.0,
          ));
        });

        // 2. Start stocktake session (baseline = 100)
        final session = await AccessGuard.runAsSystem(() async {
          return await StocktakeService.instance.startSession(
            notes: 'Test Session',
          );
        });

        final items = await StocktakeService.instance.getItems(session.id!);
        final pItem = items.firstWhere((it) => it.productId == pId);
        expect(pItem.baselineQuantity, 100.0);

        // 3. Counter counts 100 on the shelf (no discrepancy relative to baseline)
        await AccessGuard.runAsSystem(() async {
          await StocktakeService.instance.recordCount(
            pItem.id!,
            100.0,
          );
        });

        // 4. Intervening transaction: a sale of 15 units occurs before finalization
        await AccessGuard.runAsSystem(() async {
          await db.adjustStock(
            productId: pId,
            delta: -15.0,
            reason: 'intervening_sale',
          );
        });

        // Live stock is now 85
        final liveBeforeFinalize = await db.getProductById(pId);
        expect(liveBeforeFinalize?.stockQuantity, 85.0);

        // 5. Finalize stocktake session
        final result = await AccessGuard.runAsSystem(() async {
          return await StocktakeService.instance.finalizeSession(
            session.id!,
            confirmed: true,
          );
        });

        expect(result['interim_conflicts'], 1);

        // 6. VERIFY: Live stock remains 85! The intervening sale of 15 was NOT overwritten!
        final liveAfterFinalize = await db.getProductById(pId);
        expect(liveAfterFinalize?.stockQuantity, 85.0);
      },
    );

    test(
      'Stocktake with true count loss applies loss delta onto live stock preserving intervening sales',
      () async {
        final db = DatabaseHelper.instance;

        // 1. Create product with 50 stock
        int pId = 0;
        await AccessGuard.runAsSystem(() async {
          pId = await db.insertProduct(Product(
            name: 'Stocktake Loss Product',
            stockQuantity: 50.0,
            salePrice: 20.0,
            purchasePrice: 10.0,
          ));
        });

        // 2. Start stocktake session (baseline = 50)
        final session = await AccessGuard.runAsSystem(() async {
          return await StocktakeService.instance.startSession();
        });

        final items = await StocktakeService.instance.getItems(session.id!);
        final pItem = items.firstWhere((it) => it.productId == pId);

        // 3. Counter discovers 2 units missing on shelf: counted = 48 (discrepancy = -2)
        await AccessGuard.runAsSystem(() async {
          await StocktakeService.instance.recordCount(
            pItem.id!,
            48.0,
          );
        });

        // 4. Intervening sale of 10 occurs: live stock drops to 40
        await AccessGuard.runAsSystem(() async {
          await db.adjustStock(
            productId: pId,
            delta: -10.0,
            reason: 'intervening_sale_2',
          );
        });

        final liveBefore = await db.getProductById(pId);
        expect(liveBefore?.stockQuantity, 40.0);

        // 5. Finalize
        await AccessGuard.runAsSystem(() async {
          await StocktakeService.instance.finalizeSession(
            session.id!,
            confirmed: true,
          );
        });

        // 6. Reconciled stock must be 38 (40 current - 2 physical loss = 38)
        final liveAfter = await db.getProductById(pId);
        expect(liveAfter?.stockQuantity, 38.0);
      },
    );
  });
}
