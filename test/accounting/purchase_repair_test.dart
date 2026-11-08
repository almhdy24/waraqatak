import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/database_diagnostic.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';
import 'package:warqatek/services/database_diagnostic_service.dart';
import 'package:warqatek/services/database_repair_service.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('purchase_repair_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    db = DatabaseHelper.instance;

    await db.insertBusiness(
      const Business(
        name: 'مؤسسة الاختبار المحاسبي',
        ownerName: 'المدير المالي',
        phone: '1234567890',
        address: 'شارع التجارة',
        taxRate: 0.0,
        taxesEnabled: false,
        pricesIncludeTax: false,
        currencyCode: 'SDG',
      ),
    );
  });

  tearDownAll(() async {
    await db.closeDatabase();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    final rawDb = await db.database;
    await rawDb.execute('PRAGMA foreign_keys = OFF');
    await rawDb.delete('document_items');
    await rawDb.delete('document_payments');
    await rawDb.delete('stock_movements');
    await rawDb.delete('stocktake_items');
    await rawDb.delete('stocktake_sessions');
    await rawDb.delete('documents');
    await rawDb.delete('products');
    await rawDb.delete('contacts');
  });

  test('Diagnostic detection accurately flags document movement mismatch and ledger inventory difference', () async {
    final rawDb = await db.database;
    final business = (await db.getFirstBusiness())!;

    // 1. Create product P1
    final pId = await db.insertProduct(
      const Product(
        name: 'منتج تالف الحركات',
        salePrice: 20.0,
        purchasePrice: 10.0,
        stockQuantity: 0.0,
        type: Product.typeProduct,
      ),
    );

    // 2. Issue purchase doc with 100 qty
    final itemInput = DocumentItemInput(
      productId: pId,
      description: 'شراء 100 وحدة',
      quantity: 100.0,
      price: 10.0,
      taxable: false,
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      contact: null,
      items: [itemInput],
      isDraft: false,
    );

    // 3. Simulate historical bug: insert duplicate movement for this purchase
    await rawDb.insert('stock_movements', {
      'product_id': pId,
      'quantity': 100.0,
      'unit_cost': 10.0,
      'total_cost': 1000.0,
      'date': DateTime.now().toIso8601String(),
      'type': StockMovement.typePurchase,
      'notes': 'Duplicate movement from buggy purchase edit',
      'reference_document_id': docId,
      'cost_status': StockMovement.costStatusKnown,
    });
    // Stock quantity is now 200
    await rawDb.rawUpdate('UPDATE products SET stock_quantity = 200.0 WHERE id = ?', [pId]);

    // 4. Run read-only diagnostics
    final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);

    // Verify document_movement_mismatch finding
    final docMismatch = report.findings.firstWhere(
      (f) => f.code == 'document_movement_mismatch',
    );
    expect(docMismatch.severity, equals(DiagnosticSeverity.error));
    expect(docMismatch.affectedIds, contains(docId));
    expect(docMismatch.requiresManualReview, isTrue);

    // Verify ledger_movement_inventory_mismatch finding
    final ledgerMismatch = report.findings.firstWhere(
      (f) => f.code == 'ledger_movement_inventory_mismatch',
    );
    expect(ledgerMismatch.severity, equals(DiagnosticSeverity.error));
    expect(ledgerMismatch.affectedIds, contains(pId));
    expect(ledgerMismatch.requiresManualReview, isTrue);
  });

  test('Guided repair preview: dry-run accurately reports movements, surplus, and confirmation token without mutating DB', () async {
    final rawDb = await db.database;
    final business = (await db.getFirstBusiness())!;

    final pId = await db.insertProduct(
      const Product(
        name: 'منتج معاينة الإصلاح',
        salePrice: 15.0,
        purchasePrice: 10.0,
        stockQuantity: 0.0,
        type: Product.typeProduct,
      ),
    );

    final itemInput = DocumentItemInput(
      productId: pId,
      description: 'شراء كمية للمعاينة',
      quantity: 100.0,
      price: 10.0,
      taxable: false,
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      contact: null,
      items: [itemInput],
      isDraft: false,
    );

    // Insert duplicate movement
    await rawDb.insert('stock_movements', {
      'product_id': pId,
      'quantity': 100.0,
      'unit_cost': 10.0,
      'total_cost': 1000.0,
      'date': DateTime.now().toIso8601String(),
      'type': StockMovement.typePurchase,
      'notes': 'Duplicate movement',
      'reference_document_id': docId,
      'cost_status': StockMovement.costStatusKnown,
    });

    final preview = await DatabaseRepairService.previewPurchaseMovementRepair(
      db: rawDb,
      documentId: docId,
      productId: pId,
      option: PurchaseRepairOption.optionA,
    );

    expect(preview.documentId, equals(docId));
    expect(preview.expectedMovement, equals(100.0));
    expect(preview.actualMovement, equals(200.0));
    expect(preview.surplusMovement, equals(100.0));
    expect(preview.affectedMovements.length, equals(2));
    expect(preview.confirmationToken, startsWith('CONFIRM-REPAIR-'));

    // DB state must be untouched after preview
    final pAfter = await db.getProductById(pId);
    expect(pAfter!.stockQuantity, equals(100.0)); // original doc inserted 100, rawDb didn't update product
  });

  test('Guided repair: confirmation token mismatch aborts without any modification', () async {
    final rawDb = await db.database;
    final business = (await db.getFirstBusiness())!;

    final pId = await db.insertProduct(
      const Product(
        name: 'منتج حماية التوكن',
        salePrice: 20.0,
        purchasePrice: 10.0,
        stockQuantity: 0.0,
        type: Product.typeProduct,
      ),
    );

    final itemInput = DocumentItemInput(
      productId: pId,
      description: 'شراء توكن',
      quantity: 50.0,
      price: 10.0,
      taxable: false,
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      contact: null,
      items: [itemInput],
      isDraft: false,
    );

    await rawDb.insert('stock_movements', {
      'product_id': pId,
      'quantity': 50.0,
      'unit_cost': 10.0,
      'total_cost': 500.0,
      'date': DateTime.now().toIso8601String(),
      'type': StockMovement.typePurchase,
      'notes': 'Duplicate',
      'reference_document_id': docId,
    });

    final preview = await DatabaseRepairService.previewPurchaseMovementRepair(
      db: rawDb,
      documentId: docId,
      productId: pId,
      option: PurchaseRepairOption.optionA,
    );

    bool backupCalled = false;
    DatabaseRepairService.safetyBackupOverride = () async {
      backupCalled = true;
      return '${tempDir.path}/mock_backup.waraq';
    };

    final result = await DatabaseRepairService.executePurchaseMovementRepair(
      db: rawDb,
      preview: preview,
      confirmationToken: 'WRONG_TOKEN',
    );

    expect(result.success, isFalse);
    expect(result.error, equals('Token mismatch'));
    expect(backupCalled, isFalse); // Did not even proceed to backup
  });

  test('Guided repair Option A: neutralizes surplus movement and restores stock and diagnostic consistency', () async {
    final rawDb = await db.database;
    final business = (await db.getFirstBusiness())!;

    final pId = await db.insertProduct(
      const Product(
        name: 'منتج إصلاح الخيار أ',
        salePrice: 25.0,
        purchasePrice: 10.0,
        stockQuantity: 0.0,
        type: Product.typeProduct,
      ),
    );

    final itemInput = DocumentItemInput(
      productId: pId,
      description: 'شراء الخيار أ',
      quantity: 100.0,
      price: 10.0,
      taxable: false,
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      contact: null,
      items: [itemInput],
      isDraft: false,
    );

    // Duplicate movement +100
    await rawDb.insert('stock_movements', {
      'product_id': pId,
      'quantity': 100.0,
      'unit_cost': 10.0,
      'total_cost': 1000.0,
      'date': DateTime.now().toIso8601String(),
      'type': StockMovement.typePurchase,
      'notes': 'Duplicate movement',
      'reference_document_id': docId,
      'cost_status': StockMovement.costStatusKnown,
    });
    await rawDb.rawUpdate('UPDATE products SET stock_quantity = 200.0 WHERE id = ?', [pId]);

    final preview = await DatabaseRepairService.previewPurchaseMovementRepair(
      db: rawDb,
      documentId: docId,
      productId: pId,
      option: PurchaseRepairOption.optionA,
    );

    bool backupCreated = false;
    DatabaseRepairService.safetyBackupOverride = () async {
      backupCreated = true;
      return '${tempDir.path}/safety_option_a.waraq';
    };

    final result = await DatabaseRepairService.executePurchaseMovementRepair(
      db: rawDb,
      preview: preview,
      confirmationToken: preview.confirmationToken,
    );

    expect(result.success, isTrue);
    expect(backupCreated, isTrue);
    expect(result.safetyBackupPath, isNotNull);

    // Verify stock_quantity restored to 100
    final product = await db.getProductById(pId);
    expect(product!.stockQuantity, equals(100.0));

    // Verify net movements for document equals 100.0
    final movements = await rawDb.rawQuery(
      'SELECT SUM(quantity) as net_qty FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    );
    expect((movements.first['net_qty'] as num).toDouble(), equals(100.0));

    // Verify compensating cancellation movement was appended (never hard deleted)
    final cancelRows = await rawDb.query(
      'stock_movements',
      where: 'reference_document_id = ? AND type = ?',
      whereArgs: [docId, StockMovement.typeCancellation],
    );
    expect(cancelRows.isNotEmpty, isTrue);
    expect((cancelRows.first['quantity'] as num).toDouble(), equals(-100.0));

    // Verify audit log entry
    final auditRows = await rawDb.query(
      'audit_log',
      where: 'action = ? AND entity_id = ?',
      whereArgs: ['REPAIR_MOVEMENT_OPTION_A', docId],
    );
    expect(auditRows, isNotEmpty);

    // Run diagnostics: document_movement_mismatch is CLEARED!
    final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
    final docMismatch = report.findings.where((f) => f.code == 'document_movement_mismatch').firstOrNull;
    expect(docMismatch, isNull);
  });

  test('Guided repair Option B: reproduces PURCHASE-0001 scenario, pairs duplicate with adjustment, removes phantom loss from Ledger', () async {
    final rawDb = await db.database;
    final business = (await db.getFirstBusiness())!;

    // 1. Create product P1
    final pId = await db.insertProduct(
      const Product(
        name: 'منتج السيناريو الكامل PURCHASE-0001',
        salePrice: 20.0,
        purchasePrice: 10.0,
        stockQuantity: 0.0,
        type: Product.typeProduct,
      ),
    );

    // 2. Issue PURCHASE-0001 with quantity 100 (initial stock increases to 100)
    final itemInput = DocumentItemInput(
      productId: pId,
      description: 'شراء سيناريو كامل',
      quantity: 100.0,
      price: 10.0,
      taxable: false,
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      contact: null,
      items: [itemInput],
      isDraft: false,
    );

    // 3. Simulate historical bug on edit: second stock movement of +100 referencing doc
    await rawDb.insert('stock_movements', {
      'product_id': pId,
      'quantity': 100.0,
      'unit_cost': 10.0,
      'total_cost': 1000.0,
      'date': DateTime.now().toIso8601String(),
      'type': StockMovement.typePurchase,
      'notes': 'Duplicate movement from editing PURCHASE-0001',
      'reference_document_id': docId,
      'cost_status': StockMovement.costStatusKnown,
    });
    // Physical stock was artificially at 200
    await rawDb.rawUpdate('UPDATE products SET stock_quantity = 200.0 WHERE id = ?', [pId]);

    // 4. User performed compensating manual stock adjustment of -100 to bring physical stock back to 100
    await rawDb.insert('stock_movements', {
      'product_id': pId,
      'quantity': -100.0,
      'unit_cost': 10.0,
      'total_cost': 1000.0,
      'date': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      'type': StockMovement.typeAdjustment,
      'notes': 'Manual stock adjustment to compensate duplicate purchase',
      'cost_status': StockMovement.costStatusKnown,
    });
    await rawDb.rawUpdate('UPDATE products SET stock_quantity = 100.0 WHERE id = ?', [pId]);

    // Before repair: check Ledger reports
    final bookBefore = await LedgerService.load(currencyCode: 'SDG');
    final isBefore = AccountingReports.incomeStatement(bookBefore.entries);
    // Prior to repair, the adjustment was booked as an inventory loss: 1000!
    expect(isBefore.inventoryAdjustments, equals(1000.0));
    final bsBefore = AccountingReports.balanceSheet(bookBefore.entries);
    // Ledger inventory was kept at 1000 via synthetic opening equity to reconcile with physical stock
    expect(bsBefore.assets[Accounts.inventory] ?? 0.0, equals(1000.0));
    expect(bsBefore.equity[Accounts.openingEquity] ?? 0.0, equals(1000.0));

    // 5. Preview Option B
    final preview = await DatabaseRepairService.previewPurchaseMovementRepair(
      db: rawDb,
      documentId: docId,
      productId: pId,
      option: PurchaseRepairOption.optionB,
    );

    expect(preview.surplusMovement, equals(100.0));
    expect(preview.compensatingAdjustment, isNotNull);
    expect((preview.compensatingAdjustment!['quantity'] as num).toDouble(), equals(-100.0));

    // 6. Execute Option B
    bool backupCreated = false;
    DatabaseRepairService.safetyBackupOverride = () async {
      backupCreated = true;
      return '${tempDir.path}/safety_option_b.waraq';
    };

    final result = await DatabaseRepairService.executePurchaseMovementRepair(
      db: rawDb,
      preview: preview,
      confirmationToken: preview.confirmationToken,
    );

    expect(result.success, isTrue);
    expect(backupCreated, isTrue);
    expect(result.repairedCount, equals(2));

    // 7. Verify audit trail: NO rows deleted
    final allMovements = await rawDb.query('stock_movements', where: 'product_id = ?', whereArgs: [pId]);
    expect(allMovements.length, equals(3)); // Original, Neutralized Duplicate, Neutralized Adjustment
    final neutralizedMovements = allMovements.where((m) => m['type'] == 'neutralized').toList();
    expect(neutralizedMovements.length, equals(2));

    // Physical stock remains exactly 100
    final productAfter = await db.getProductById(pId);
    expect(productAfter!.stockQuantity, equals(100.0));

    // Net movements referencing PURCHASE-0001 is now exactly 100.0
    final docMovementsAfter = await rawDb.rawQuery(
      'SELECT SUM(quantity) as net_qty, COUNT(*) as cnt FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    );
    expect((docMovementsAfter.first['net_qty'] as num).toDouble(), equals(100.0));
    expect(docMovementsAfter.first['cnt'], equals(1));

    // 8. Verify Ledger after Option B: Phantom adjustment loss is COMPLETELY REMOVED!
    final bookAfter = await LedgerService.load(currencyCode: 'SDG');
    final isAfter = AccountingReports.incomeStatement(bookAfter.entries);
    expect(isAfter.inventoryAdjustments, equals(0.0)); // Phantom loss GONE!

    final bsAfter = AccountingReports.balanceSheet(bookAfter.entries);
    expect(bsAfter.assets[Accounts.inventory] ?? 0.0, equals(1000.0)); // Ledger inventory correctly reflects 100 units @ 10 = 1000!
    expect(bsAfter.equity[Accounts.openingEquity] ?? 0.0, equals(0.0)); // Synthetic opening equity eliminated!

    // Trial balance balances perfectly
    final tb = AccountingReports.trialBalance(bookAfter.entries);
    expect(tb.isBalanced, isTrue);

    // Diagnostics report: all clear
    final report = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
    expect(report.findings.where((f) => f.code == 'document_movement_mismatch'), isEmpty);
    expect(report.findings.where((f) => f.code == 'ledger_movement_inventory_mismatch'), isEmpty);
  });
}
