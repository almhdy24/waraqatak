import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('journal_migration_test');
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('Fresh installation (v25) creates all journal tables and seeds accounts & settings', () async {
    final dbPath = '${tempDir.path}/fresh_v25.db';
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseHelper.dbVersion,
        onCreate: (db, version) async {
          await DatabaseHelper.instance.createTablesForTest(db, version);
        },
      ),
    );

    try {
      // 1. Verify tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains('accounts'), isTrue);
      expect(tableNames.contains('journal_entries'), isTrue);
      expect(tableNames.contains('journal_lines'), isTrue);
      expect(tableNames.contains('app_settings'), isTrue);

      // 2. Verify 13 standard accounts seeded
      final accounts = await db.query('accounts');
      expect(accounts.length, 13);
      final accountCodes = accounts.map((a) => a['code'] as String).toSet();
      expect(accountCodes, containsAll([
        '1110', '1120', '1130', '1140', '1150',
        '2110', '2120', '3100', '4100', '4900',
        '5100', '5200', '6100',
      ]));

      // 3. Verify default settings seeded
      final settings = await db.query('app_settings');
      final settingsMap = {for (final s in settings) s['key'] as String: s['value'] as String?};
      expect(settingsMap['journal_shadow_write'], 'true');
      expect(settingsMap['journal_reports_enabled'], 'false');

      // 4. Verify stock_movements columns
      final smCols = await db.rawQuery('PRAGMA table_info(stock_movements)');
      final smColNames = smCols.map((c) => c['name'] as String).toSet();
      expect(smColNames.contains('reason'), isTrue);
      expect(smColNames.contains('target_movement_id'), isTrue);
    } finally {
      await db.close();
    }
  });

  test('Upgrade from v24 with existing data creates tables, seeds accounts/settings, and is idempotent', () async {
    final dbPath = '${tempDir.path}/upgrade_v24_to_v25.db';

    // 1. Setup a v24 schema database
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 24,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE businesses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              owner_name TEXT NOT NULL,
              phone TEXT NOT NULL,
              address TEXT NOT NULL,
              currency_code TEXT DEFAULT 'SDG'
            )
          ''');
          await db.execute('''
            CREATE TABLE products (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              stock_quantity REAL DEFAULT 0,
              type TEXT DEFAULT 'product'
            )
          ''');
          await db.execute('''
            CREATE TABLE stock_movements (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_id INTEGER NOT NULL,
              type TEXT NOT NULL,
              quantity REAL NOT NULL,
              date TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE documents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL,
              document_number TEXT NOT NULL,
              date TEXT NOT NULL,
              total REAL NOT NULL,
              paid REAL NOT NULL
            )
          ''');

          // Seed existing data
          await db.insert('businesses', {
            'name': 'متجر النيل',
            'owner_name': 'عمر',
            'phone': '123',
            'address': 'الخرطوم',
          });
          await db.insert('products', {
            'name': 'سكر',
            'stock_quantity': 50,
          });
          await db.insert('documents', {
            'type': 'invoice',
            'document_number': 'INV-001',
            'date': '2026-01-01',
            'total': 1000.0,
            'paid': 1000.0,
          });
        },
      ),
    );

    try {
      // 2. Perform upgrade from v24 to v25
      await DatabaseHelper.instance.upgradeTablesForTest(db, 24, 25);

      // Verify existing data preserved
      final prods = await db.query('products');
      expect(prods.length, 1);
      expect(prods.first['name'], 'سكر');
      expect(prods.first['stock_quantity'], 50);

      final docs = await db.query('documents');
      expect(docs.length, 1);
      expect(docs.first['document_number'], 'INV-001');

      // Verify new tables created
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();
      expect(tableNames.contains('accounts'), isTrue);
      expect(tableNames.contains('journal_entries'), isTrue);
      expect(tableNames.contains('journal_lines'), isTrue);
      expect(tableNames.contains('app_settings'), isTrue);

      // Verify accounts and settings seeded
      final accounts = await db.query('accounts');
      expect(accounts.length, 13);

      final shadowWrite = await DatabaseHelper.instance.isJournalShadowWriteEnabled(txn: db);
      expect(shadowWrite, isTrue);

      final reportsEnabled = await DatabaseHelper.instance.isJournalReportsEnabled(txn: db);
      expect(reportsEnabled, isFalse);

      // Verify stock_movements columns added
      final smCols = await db.rawQuery('PRAGMA table_info(stock_movements)');
      final smColNames = smCols.map((c) => c['name'] as String).toSet();
      expect(smColNames.contains('reason'), isTrue);
      expect(smColNames.contains('target_movement_id'), isTrue);

      // 3. Re-run upgrade (idempotency check)
      await DatabaseHelper.instance.upgradeTablesForTest(db, 24, 25);

      // Verify counts still match exactly
      final accountsAfter = await db.query('accounts');
      expect(accountsAfter.length, 13);
      final prodsAfter = await db.query('products');
      expect(prodsAfter.length, 1);
    } finally {
      await db.close();
    }
  });
}
