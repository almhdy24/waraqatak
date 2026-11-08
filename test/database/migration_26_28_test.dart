import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';

/// Integration tests for schema version 28 migrations.
/// Note: Requires Linux CI (sqflite FFI). Do NOT run in Termux.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('migration_26_28_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Schema Migration v26..v28 Tests', () {
    test(
      '1. Fresh installation (v28) creates exchange_rates, reference columns, and unique indexes',
      () async {
        final dbPath = '${tempDir.path}/fresh_v28.db';
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
          expect(DatabaseHelper.dbVersion >= 28, isTrue);

          // Check exchange_rates table
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='exchange_rates'",
          );
          expect(tables.isNotEmpty, isTrue);

          // Check products columns
          final prodCols = await db.rawQuery('PRAGMA table_info(products)');
          final prodColNames = prodCols.map((c) => c['name'] as String).toSet();
          expect(prodColNames.contains('price_currency'), isTrue);
          expect(prodColNames.contains('reference_sale_price'), isTrue);
          expect(prodColNames.contains('reference_wholesale_price'), isTrue);
          expect(prodColNames.contains('reference_purchase_price'), isTrue);

          // Check product_units columns
          final puCols = await db.rawQuery('PRAGMA table_info(product_units)');
          final puColNames = puCols.map((c) => c['name'] as String).toSet();
          expect(puColNames.contains('reference_sale_price'), isTrue);
          expect(puColNames.contains('reference_wholesale_price'), isTrue);
          expect(puColNames.contains('reference_currency'), isTrue);

          // Check indexes
          final indexes = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='index'",
          );
          final indexNames = indexes.map((i) => i['name'] as String).toSet();
          expect(indexNames.contains('idx_products_price_currency'), isTrue);
          expect(indexNames.contains('idx_products_barcode_unique'), isTrue);
          expect(
            indexNames.contains('idx_documents_type_docnum_unique'),
            isTrue,
          );
        } finally {
          await db.close();
        }
      },
    );

    test(
      '2. Upgrade 25 -> 28 applies reference currency schema, v27 cleanup, and unique indexes',
      () async {
        final dbPath = '${tempDir.path}/upgrade_25_28.db';
        // Simulate v25 schema
        final db = await databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 25,
            onCreate: (db, version) async {
              await DatabaseHelper.instance.createTablesForTest(db, version);
            },
          ),
        );

        try {
          // Seed sample data before upgrade
          await db.insert('products', {
            'name': 'Existing Product',
            'sale_price': 100.0,
            'barcode': 'BC-001',
          });
          await db.insert('documents', {
            'type': 'invoice',
            'document_number': 'INV-001',
            'date': '2026-11-01',
          });

          // Run upgrade from 25 to 28
          await DatabaseHelper.instance.upgradeTablesForTest(db, 25, 28);

          // Verify exchange_rates table exists
          final erTable = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='exchange_rates'",
          );
          expect(erTable.isNotEmpty, isTrue);

          // Verify reference columns added to products
          final prodCols = await db.rawQuery('PRAGMA table_info(products)');
          final prodColNames = prodCols.map((c) => c['name'] as String).toSet();
          expect(prodColNames.contains('price_currency'), isTrue);
          expect(prodColNames.contains('reference_sale_price'), isTrue);

          // Verify unique indexes created
          final indexes = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='index'",
          );
          final indexNames = indexes.map((i) => i['name'] as String).toSet();
          expect(indexNames.contains('idx_products_barcode_unique'), isTrue);
          expect(
            indexNames.contains('idx_documents_type_docnum_unique'),
            isTrue,
          );

          // Verify existing data preserved
          final products = await db.query(
            'products',
            where: 'barcode = ?',
            whereArgs: ['BC-001'],
          );
          expect(products.length, 1);
          expect(products.first['name'], 'Existing Product');
        } finally {
          await db.close();
        }
      },
    );

    test(
      '3. Upgrade 27 -> 28 adds reference currency columns and exchange_rates table',
      () async {
        final dbPath = '${tempDir.path}/upgrade_27_28.db';
        final db = await databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 27,
            onCreate: (db, version) async {
              await DatabaseHelper.instance.createTablesForTest(db, version);
            },
          ),
        );

        try {
          // Simulate a device that reached v27 without v26 reference currency:
          // Run upgrade to 28
          await DatabaseHelper.instance.upgradeTablesForTest(db, 27, 28);

          // Verify exchange_rates table exists
          final erTable = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='exchange_rates'",
          );
          expect(erTable.isNotEmpty, isTrue);

          // Verify reference pricing columns exist on product_units
          final puCols = await db.rawQuery('PRAGMA table_info(product_units)');
          final puColNames = puCols.map((c) => c['name'] as String).toSet();
          expect(puColNames.contains('reference_currency'), isTrue);
          expect(puColNames.contains('reference_sale_price'), isTrue);
        } finally {
          await db.close();
        }
      },
    );

    test('4. Repeated onUpgrade runs idempotently without error', () async {
      final dbPath = '${tempDir.path}/idempotent_upgrade.db';
      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 28,
          onCreate: (db, version) async {
            await DatabaseHelper.instance.createTablesForTest(db, version);
          },
        ),
      );

      try {
        // Run upgrade 25->28 again on already created v28 database
        await DatabaseHelper.instance.upgradeTablesForTest(db, 25, 28);
        // Run upgrade 27->28 again
        await DatabaseHelper.instance.upgradeTablesForTest(db, 27, 28);
        // Run upgrade 26->28 again
        await DatabaseHelper.instance.upgradeTablesForTest(db, 26, 28);

        // Ensure everything is still valid
        final integrity = await db.rawQuery('PRAGMA integrity_check');
        expect(integrity.first.values.first.toString().toLowerCase(), 'ok');
      } finally {
        await db.close();
      }
    });
  });
}
