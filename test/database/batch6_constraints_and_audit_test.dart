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
    tempDir = Directory.systemTemp.createTempSync('batch6_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Batch 6: DB Constraints & Audit Atomicity Tests', () {
    test(
      '1. Fresh installation (v27) creates unique indexes for barcodes and document numbers',
      () async {
        final dbPath = '${tempDir.path}/fresh_v27.db';
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
          final indexes = await db.rawQuery(
            "SELECT name, sql FROM sqlite_master WHERE type='index'",
          );
          final indexNames = indexes.map((r) => r['name'] as String).toSet();

          expect(indexNames.contains('idx_products_barcode_unique'), isTrue);
          expect(
            indexNames.contains('idx_documents_type_docnum_unique'),
            isTrue,
          );

          // Verify barcode uniqueness (partial index: non-null and non-empty)
          await db.insert('products', {'name': 'P1', 'barcode': '1234567890'});

          // Inserting same barcode must throw unique constraint error
          expect(
            () =>
                db.insert('products', {'name': 'P2', 'barcode': '1234567890'}),
            throwsA(isA<DatabaseException>()),
          );

          // Multiple null or empty barcodes are allowed
          final p3 = await db.insert('products', {
            'name': 'P3',
            'barcode': null,
          });
          final p4 = await db.insert('products', {
            'name': 'P4',
            'barcode': null,
          });
          expect(p3, isPositive);
          expect(p4, isPositive);

          // Verify document number uniqueness per type
          await db.insert('documents', {
            'type': 'invoice',
            'document_number': 'INV-00001',
            'date': '2026-03-01T00:00:00.000',
            'status': 'issued',
          });

          // Duplicate invoice number fails
          expect(
            () => db.insert('documents', {
              'type': 'invoice',
              'document_number': 'INV-00001',
              'date': '2026-03-02T00:00:00.000',
              'status': 'issued',
            }),
            throwsA(isA<DatabaseException>()),
          );

          // Same document number under a different type is allowed
          final purId = await db.insert('documents', {
            'type': 'purchase',
            'document_number': 'INV-00001',
            'date': '2026-03-02T00:00:00.000',
            'status': 'issued',
          });
          expect(purId, isPositive);
        } finally {
          await db.close();
        }
      },
    );

    test(
      '2. Migration v25 -> v27 non-destructively resolves duplicates with audit logs',
      () async {
        final dbPath = '${tempDir.path}/upgrade_v25_v27.db';
        // Create v25 database with duplicate barcodes and duplicate document numbers
        final db = await databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 25,
            onCreate: (db, version) async {
              await DatabaseHelper.instance.createTablesForTest(db, 25);
            },
          ),
        );

        // Seed duplicate barcodes
        final p1 = await db.insert('products', {
          'name': 'Prod 1',
          'barcode': 'DUP-BAR',
        });
        final p2 = await db.insert('products', {
          'name': 'Prod 2',
          'barcode': 'DUP-BAR',
        });
        final p3 = await db.insert('products', {
          'name': 'Prod 3',
          'barcode': '   ',
        }); // empty string

        // Seed duplicate document numbers
        final d1 = await db.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-DUP-1',
          'date': '2026-01-01T00:00:00.000',
        });
        final d2 = await db.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-DUP-1',
          'date': '2026-01-02T00:00:00.000',
        });

        await db.close();

        // Now open with version 27 to trigger migration
        final upgradedDb = await databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 27,
            onUpgrade: (db, oldV, newV) async {
              await DatabaseHelper.instance.upgradeTablesForTest(
                db,
                oldV,
                newV,
              );
            },
          ),
        );

        try {
          // Earliest product barcode preserved
          final prod1 = await upgradedDb.query(
            'products',
            where: 'id = ?',
            whereArgs: [p1],
          );
          expect(prod1.first['barcode'], 'DUP-BAR');

          // Subsequent duplicate product renamed with deterministic suffix
          final prod2 = await upgradedDb.query(
            'products',
            where: 'id = ?',
            whereArgs: [p2],
          );
          expect(prod2.first['barcode'], 'DUP-BAR_dup_$p2');

          // Empty string barcode normalized to NULL
          final prod3 = await upgradedDb.query(
            'products',
            where: 'id = ?',
            whereArgs: [p3],
          );
          expect(prod3.first['barcode'], isNull);

          // Earliest document number preserved
          final doc1 = await upgradedDb.query(
            'documents',
            where: 'id = ?',
            whereArgs: [d1],
          );
          expect(doc1.first['document_number'], 'INV-DUP-1');

          // Subsequent duplicate document renamed with deterministic suffix
          final doc2 = await upgradedDb.query(
            'documents',
            where: 'id = ?',
            whereArgs: [d2],
          );
          expect(doc2.first['document_number'], 'INV-DUP-1_dup_$d2');

          // Audit log entries recorded for renames
          final auditLogs = await upgradedDb.query('audit_log');
          final actions = auditLogs.map((r) => r['action'] as String).toList();
          expect(actions, contains('migration_v27_resolve_duplicate_barcode'));
          expect(
            actions,
            contains('migration_v27_resolve_duplicate_document_number'),
          );
        } finally {
          await upgradedDb.close();
        }
      },
    );

    test(
      '3. getNextDocumentNumber skips pre-existing document numbers',
      () async {
        final dbPath = '${tempDir.path}/counter_skip_test.db';
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
          // Manually insert INV-00001
          await db.insert('documents', {
            'type': 'invoice',
            'document_number': 'INV-00001',
            'date': '2026-03-01T00:00:00.000',
          });

          // getNextDocumentNumber should detect INV-00001 exists and yield INV-00002
          final num1 = await DatabaseHelper.instance.getNextDocumentNumber(
            db,
            'invoice',
          );
          expect(num1, 'INV-00002');

          // Next call should yield INV-00003
          final num2 = await DatabaseHelper.instance.getNextDocumentNumber(
            db,
            'invoice',
          );
          expect(num2, 'INV-00003');
        } finally {
          await db.close();
        }
      },
    );
  });
}
