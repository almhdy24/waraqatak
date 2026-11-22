import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/stock_ledger.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_acc_08_test');
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

    // Base currency is KWD (Kuwaiti Dinar, 3 decimal digits)
    await db.insertBusiness(
      const Business(
        name: 'Kuwait Merchant',
        ownerName: 'Test Owner',
        phone: '0123456789',
        address: 'Kuwait City',
        currencyCode: 'KWD',
        taxRate: 0.0,
        taxesEnabled: false,
        pricesIncludeTax: false,
      ),
    );
  });

  test('ACC-08 Regression: Stock adjustment in 3-decimal currency must record correct minor units', () async {
    final rawDb = await db.database;

    // 1. Enable journal shadow writes
    await db.setSetting('journal_shadow_write_enabled', 'true');

    // 2. Setup product with unit cost 0.125 KWD
    final pId = await db.insertProduct(
      Product(
        name: 'Item KWD',
        salePrice: 0.500,
        purchasePrice: 0.125,
        averageCost: 0.125,
        costStatus: Product.costStatusKnown,
        stockQuantity: 100.0,
      ),
    );

    // 3. Record a stock adjustment: loss of 10 units @ 0.125 KWD = 1.250 KWD
    // In KWD (3 decimals), 1.250 KWD = 1250 minor units (fils).
    final movId = await StockLedger.record(
      rawDb,
      productId: pId,
      deltaQuantity: -10.0,
      type: StockMovement.typeAdjustment,
      unitCost: 0.125,
      reason: 'count_loss',
      date: DateTime(2026, 3, 1),
    );

    // 4. Query journal entry lines for this adjustment
    final entryRows = await rawDb.query(
      'journal_entries',
      where: 'entry_no LIKE ?',
      whereArgs: ['%-MOV-$movId%'],
    );
    expect(entryRows, isNotEmpty);
    final entryId = entryRows.first['id'] as int;

    final lines = await rawDb.query(
      'journal_lines',
      where: 'entry_id = ? AND account_code = ?',
      whereArgs: [entryId, Accounts.inventoryAdjustments.code],
    );
    expect(lines, isNotEmpty);

    // ACC-08 BUG: StockLedger.record hardcodes `decimalDigits: 2` at line 131.
    // MoneyUtils.toMinorUnits(1.250, 2) produces 125 minor units instead of 1250!
    // In KWD, this distorts the journal adjustment value by a factor of 10 (0.125 instead of 1.250).
    final debitMinor = lines.first['debit_minor'] as int;
    expect(
      debitMinor,
      equals(1250),
      reason: 'ACC-08: Stock adjustment of 1.250 KWD must be recorded as 1250 minor units (3 decimals), but was recorded as $debitMinor',
    );
  });
}
