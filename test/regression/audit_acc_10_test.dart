import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/inventory_costing_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_acc_10_test');
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
        name: 'ACC-10 Test Business',
        ownerName: 'Test Owner',
        phone: '0123456789',
        address: 'Khartoum',
        currencyCode: 'SDG',
        taxRate: 0.0,
        taxesEnabled: false,
        pricesIncludeTax: false,
      ),
    );
  });

  test('ACC-10 Regression: Reconciling product cost on existing stock must create an inventory journal entry', () async {
    final rawDb = await db.database;

    // 1. Setup product with existing physical stock of 20 units but unknown cost
    final pId = await db.insertProduct(
      Product(
        name: 'Unvalued Stock Item',
        salePrice: 100.0,
        stockQuantity: 20.0,
        costStatus: Product.costStatusUnknown,
      ),
    );

    // 2. Reconcile cost: establish audited cost of 50.0 SDG/unit (total value = 20 * 50 = 1,000 SDG)
    await InventoryCostingService.reconcileProductCost(
      rawDb,
      productId: pId,
      newUnitCost: 50.0,
      notes: 'Initial audited cost basis',
    );

    // 3. Inspect journal_lines for Account 1140 (Merchandise Inventory)
    final invLines = await rawDb.query(
      'journal_lines',
      where: 'account_code = ?',
      whereArgs: [Accounts.inventory.code],
    );

    // ACC-10 BUG: InventoryCostingService.reconcileProductCost updates `products.average_cost`
    // and logs an audit event, but inserts 0 rows into stock_movements and 0 entries into
    // journal_entries/journal_lines. The 1,000 SDG asset value is never brought onto the
    // general ledger balance sheet (Dr 1140 / Cr 3100), leading to inventory distortion and negative
    // inventory balance upon subsequent sale.
    expect(
      invLines,
      isNotEmpty,
      reason: 'ACC-10: Cost reconciliation for positive stock (20 units @ 50 SDG) must write Dr 1140 Inventory journal entry',
    );
  });
}
