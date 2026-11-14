import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/product.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── Helper: open an in-memory DB and create tables at a given version ──────

  Future<Database> openAt(int version) async {
    final helper = DatabaseHelper.instance;
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, v) => helper.createTablesForTest(db, v),
        onUpgrade: (db, old, nw) => helper.upgradeTablesForTest(db, old, nw),
      ),
    );
    return db;
  }

  // ── 1. Fresh DB at current version has image_path column ──────────────────

  test('fresh v${DatabaseHelper.dbVersion} DB has image_path column', () async {
    final db = await openAt(DatabaseHelper.dbVersion);
    final cols = await db.rawQuery('PRAGMA table_info(products)');
    final names = cols.map((c) => c['name'] as String).toList();
    expect(names, contains('image_path'));
    await db.close();
  });

  // ── 2. image_path defaults to NULL ───────────────────────────────────────

  test('image_path defaults to NULL for new product', () async {
    final db = await openAt(DatabaseHelper.dbVersion);
    final id = await db.insert('products', {
      'name': 'Test',
      'type': 'product',
      'sale_price': 10.0,
      'purchase_price': 5.0,
      'stock_quantity': 0.0,
      'min_stock': 0.0,
      'is_taxable': 1,
      'is_active': 1,
      'cost_status': 'unknown',
    });
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    expect(rows.first['image_path'], isNull);
    await db.close();
  });

  // ── 3. Product.fromMap handles null image_path gracefully ─────────────────

  test('Product.fromMap: null image_path → imagePath is null', () {
    final map = {
      'id': 1,
      'name': 'Test',
      'type': 'product',
      'sale_price': 10.0,
      'purchase_price': 5.0,
      'stock_quantity': 0.0,
      'min_stock': 0.0,
      'is_taxable': 1,
      'is_active': 1,
      'cost_status': 'unknown',
      'image_path': null,
    };
    final p = Product.fromMap(map);
    expect(p.imagePath, isNull);
  });

  // ── 4. Product.fromMap parses a path correctly ────────────────────────────

  test('Product.fromMap: image_path value is preserved', () {
    final map = {
      'id': 2,
      'name': 'WithImage',
      'type': 'product',
      'sale_price': 10.0,
      'purchase_price': 5.0,
      'stock_quantity': 0.0,
      'min_stock': 0.0,
      'is_taxable': 1,
      'is_active': 1,
      'cost_status': 'unknown',
      'image_path': '/docs/product_images/product_abc.jpg',
    };
    final p = Product.fromMap(map);
    expect(p.imagePath, equals('/docs/product_images/product_abc.jpg'));
  });

  // ── 5. Product.toMap round-trip ───────────────────────────────────────────

  test('Product.toMap includes image_path', () {
    const p = Product(name: 'X', salePrice: 1, imagePath: '/some/path.jpg');
    final map = p.toMap();
    expect(map['image_path'], equals('/some/path.jpg'));
  });

  test('Product.toMap: null imagePath stored as null', () {
    const p = Product(name: 'X', salePrice: 1);
    final map = p.toMap();
    expect(map.containsKey('image_path'), isTrue);
    expect(map['image_path'], isNull);
  });

  // ── 6. copyWith preserves and clears imagePath ───────────────────────────

  test('copyWith preserves imagePath when not specified', () {
    const p = Product(name: 'X', salePrice: 1, imagePath: '/old.jpg');
    final copy = p.copyWith(name: 'Y');
    expect(copy.imagePath, equals('/old.jpg'));
  });

  test('copyWith replaces imagePath', () {
    const p = Product(name: 'X', salePrice: 1, imagePath: '/old.jpg');
    final copy = p.copyWith(imagePath: '/new.jpg');
    expect(copy.imagePath, equals('/new.jpg'));
  });

  test('copyWith clears imagePath with clearImagePath flag', () {
    const p = Product(name: 'X', salePrice: 1, imagePath: '/old.jpg');
    final copy = p.copyWith(clearImagePath: true);
    expect(copy.imagePath, isNull);
  });

  // ── 7. Migration: v30 → v31 adds image_path without losing data ──────────

  test(
    'migration v30 → v31: adds image_path, existing rows preserved',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'waraqatak_product_image_migration_',
      );
      final databasePath = '${tempDir.path}/migration.sqlite';

      try {
        // Create a v30 database manually.
        final db = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 30,
            onCreate: (db, v) =>
                DatabaseHelper.instance.createTablesForTest(db, v),
          ),
        );

        // Insert a product without image_path (pre-migration state).
        final productId = await db.insert('products', {
          'name': 'OldProduct',
          'type': 'product',
          'sale_price': 99.0,
          'purchase_price': 50.0,
          'stock_quantity': 10.0,
          'min_stock': 0.0,
          'is_taxable': 1,
          'is_active': 1,
          'cost_status': 'unknown',
        });
        await db.close();

        // Re-open with upgrade from v30 → v31.
        final db2 = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 31,
            onUpgrade: (db, old, nw) =>
                DatabaseHelper.instance.upgradeTablesForTest(db, old, nw),
          ),
        );

        final cols = await db2.rawQuery('PRAGMA table_info(products)');
        final names = cols.map((c) => c['name'] as String).toList();
        expect(names, contains('image_path'));

        final rows = await db2.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
        );
        expect(rows, hasLength(1));
        expect(rows.first['name'], equals('OldProduct'));
        expect(
          rows.first['image_path'],
          isNull,
        ); // default NULL after migration

        await db2.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );
}
