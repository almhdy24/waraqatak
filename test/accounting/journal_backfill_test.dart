import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/journal_backfill_service.dart';
import 'package:warqatek/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('journal_backfill_test');
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
        name: 'شركة الاستيراد والتصدير',
        ownerName: 'المدير العام',
        phone: '0912345678',
        address: 'الخرطوم',
        taxRate: 0.15,
        taxesEnabled: true,
        pricesIncludeTax: false,
        currencyCode: 'SDG',
      ),
    );
  });

  test('1. Clean database: backfillIfNeeded marks completed with 0 entries', () async {
    final rawDb = await db.database;
    // Clear any settings
    await rawDb.delete('app_settings');

    final count = await JournalBackfillService.backfillIfNeeded();
    expect(count, equals(0));

    final isDone = await JournalBackfillService.isBackfillCompleted();
    expect(isDone, isTrue);

    final entries = await rawDb.query('journal_entries');
    expect(entries.isEmpty, isTrue);
  });

  test('2. Historical legacy data: backfills journal with origin=legacy_backfill and exact parity', () async {
    // 1. Temporarily disable shadow writing and backfilled flag to simulate legacy data
    await db.setSetting('journal_shadow_write', 'false');
    final rawDb = await db.database;
    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');
    await rawDb.delete('app_settings', where: 'key = ?', whereArgs: [JournalBackfillService.settingKeyBackfilledAt]);

    // 2. Insert historical product with stock and purchases
    final pId = await db.insertProduct(
      Product(
        name: 'سلعة تاريخية',
        salePrice: 150.0,
        purchasePrice: 100.0,
        averageCost: 100.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 40.0,
      ),
    );

    // 3. Insert historical purchase
    final pur = Document(
      type: 'purchase',
      documentNumber: 'PUR-HIST-1',
      date: DateTime(2025, 1, 10),
      subtotal: 1000.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 150.0,
      total: 1150.0,
      paid: 500.0,
      remaining: 650.0,
      paymentMethod: 'bank',
      status: DocumentStatus.partiallyPaid,
      currencyCode: 'SDG',
    );
    final purItems = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'شراء تاريخي',
        quantity: 10.0,
        price: 100.0,
        total: 1000.0,
      ),
    ];
    await db.insertDocumentWithItems(pur, purItems);

    // 4. Insert historical invoice
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-HIST-1',
      date: DateTime(2025, 1, 15),
      subtotal: 300.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 45.0,
      total: 345.0,
      paid: 345.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    final invItems = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'بيع تاريخي',
        quantity: 2.0,
        price: 150.0,
        total: 300.0,
      ),
    ];
    await db.insertDocumentWithItems(inv, invItems);

    // Clear any journal rows that might have been written
    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');

    final journalCountBefore = (await rawDb.query('journal_entries')).length;
    expect(journalCountBefore, equals(0), reason: 'Simulated pre-migration legacy database');

    // 5. Execute Backfill
    final backfilledCount = await JournalBackfillService.backfillIfNeeded();
    expect(backfilledCount, greaterThan(0));

    // 6. Verify origin flag
    final backfilledEntries = await rawDb.query('journal_entries');
    for (final e in backfilledEntries) {
      expect(e['origin'], equals('legacy_backfill'));
    }

    // 7. Verify parity
    await JournalBackfillService.verifyParity();
    expect(await JournalBackfillService.isBackfillCompleted(), isTrue);
  });

  test('3. Idempotent re-run: subsequent call does not duplicate entries', () async {
    final rawDb = await db.database;
    final count1 = (await rawDb.query('journal_entries')).length;

    final secondRun = await JournalBackfillService.backfillIfNeeded();
    expect(secondRun, equals(0));

    final count2 = (await rawDb.query('journal_entries')).length;
    expect(count2, equals(count1));
  });

  test('4. Legacy Backup Restore triggers automatic backfill with parity', () async {
    // 1. Create a product and document
    final pId = await db.insertProduct(
      Product(
        name: 'منتج النسخة الاحتياطية',
        salePrice: 200.0,
        purchasePrice: 120.0,
        averageCost: 120.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 20.0,
      ),
    );

    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-BK-1',
      date: DateTime(2026, 2, 1),
      subtotal: 200.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 200.0,
      paid: 200.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(inv, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'عنصر',
        quantity: 1.0,
        price: 200.0,
        total: 200.0,
      ),
    ]);

    // 2. Export database JSON for test
    final backupJson = await BackupService.buildBackupJsonForTest();

    // 3. Strip journal tables to create a simulated legacy backup
    final legacyMap = jsonDecode(backupJson) as Map<String, dynamic>;
    final dataMap = legacyMap['data'] as Map<String, dynamic>;
    dataMap.remove('journal_entries');
    dataMap.remove('journal_lines');
    dataMap.remove('app_settings');

    // 4. Restore the legacy backup
    final ok = await BackupService.restoreFromJsonMap(legacyMap);
    expect(ok, isTrue);

    // 5. Verify backfill was automatically executed
    final rawDb = await db.database;
    final backfillSetting = await rawDb.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [JournalBackfillService.settingKeyBackfilledAt],
    );
    expect(backfillSetting.isNotEmpty, isTrue, reason: 'Backfill executed after legacy restore');

    final backfilledRows = await rawDb.query(
      'journal_entries',
      where: "origin = 'legacy_backfill'",
    );
    expect(backfilledRows, isNotEmpty);

    // 6. Verify parity passes
    await JournalBackfillService.verifyParity();
  });
}
