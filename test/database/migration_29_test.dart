import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('migration_29_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Schema Migration v29 Tests', () {
    test('1. Fresh installation (v29) creates access tables, columns, and default seeds', () async {
      final dbPath = '${tempDir.path}/fresh_v29.db';
      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 29,
          onCreate: (db, version) async {
            await DatabaseHelper.instance.createTablesForTest(db, version);
          },
        ),
      );

      try {
        expect(DatabaseHelper.dbVersion, 29);

        // Verify new access control tables
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('workspaces', 'users', 'roles', 'role_permissions', 'user_permission_overrides')",
        );
        final tableNames = tables.map((t) => t['name'] as String).toSet();
        expect(tableNames, containsAll([
          'workspaces',
          'users',
          'roles',
          'role_permissions',
          'user_permission_overrides',
        ]));

        // Verify attribution columns
        Future<Set<String>> cols(String tbl) async {
          final res = await db.rawQuery('PRAGMA table_info($tbl)');
          return res.map((c) => c['name'] as String).toSet();
        }

        expect(await cols('documents'), containsAll(['created_by', 'updated_by', 'origin_device_id']));
        expect(await cols('products'), containsAll(['created_by', 'updated_by', 'origin_device_id']));
        expect(await cols('contacts'), containsAll(['created_by', 'updated_by', 'origin_device_id']));
        expect(await cols('document_payments'), containsAll(['created_by', 'origin_device_id']));
        expect(await cols('stock_movements'), containsAll(['created_by', 'origin_device_id']));
        expect(await cols('journal_entries'), containsAll(['created_by', 'origin_device_id']));
        expect(await cols('stocktake_sessions'), contains('created_by'));
        expect(await cols('businesses'), contains('updated_by'));
        expect(await cols('audit_log'), containsAll([
          'user_id',
          'user_name',
          'device_id',
          'workspace_id',
          'prev_hash',
          'hash',
        ]));

        // Verify default seeding
        final ws = await db.query('workspaces');
        expect(ws.length, 1);
        expect(ws.first['id'], AccessDao.defaultWorkspaceId);

        final roles = await db.query('roles');
        expect(roles.length, 5);
        expect(roles.any((r) => r['id'] == AccessDao.ownerRoleId && r['is_system'] == 1), isTrue);

        final users = await db.query('users');
        expect(users.length, 1);
        expect(users.first['id'], AccessDao.ownerUserId);
        expect(users.first['username'], 'owner');
        expect(users.first['is_owner'], 1);
        expect(users.first['setup_complete'], 0);

        final settings = await db.query('app_settings');
        final settingsMap = {for (final s in settings) s['key']: s['value']};
        expect(settingsMap['multi_user_enabled'], '0');
        expect(settingsMap['workspace_id'], AccessDao.defaultWorkspaceId);
        expect(settingsMap['auto_lock_minutes'], '5');
      } finally {
        await db.close();
      }
    });

    test('2. Upgrade v28 -> v29 on realistic dataset preserves all data, balances, and leaves created_by NULL', () async {
      final dbPath = '${tempDir.path}/upgrade_28_29.db';
      // Step A: Create v28 DB
      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 28,
          onCreate: (db, version) async {
            await DatabaseHelper.instance.createTablesForTest(db, 28);
          },
        ),
      );

      try {
        // Step B: Insert realistic v28 records
        await db.insert('businesses', {
          'name': 'متجر النيل',
          'owner_name': 'محمد عثمان',
          'phone': '0123456789',
          'address': 'الخرطوم',
        });

        final p1 = await db.insert('products', {
          'name': 'سكر كنانة 50ك',
          'barcode': 'SUGAR-50K',
          'sale_price': 50000.0,
          'purchase_price': 42000.0,
          'stock_quantity': 20.0,
        });

        final c1 = await db.insert('contacts', {
          'name': 'مكتبة الأمل',
          'phone': '0912345678',
          'type': 'customer',
        });

        final docId = await db.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-2026-001',
          'date': '2026-11-01T10:00:00Z',
          'contact_id': c1,
          'subtotal': 100000.0,
          'total': 100000.0,
          'paid': 60000.0,
          'remaining': 40000.0,
          'status': 'issued',
        });

        await db.insert('document_items', {
          'document_id': docId,
          'product_id': p1,
          'description': 'سكر كنانة',
          'quantity': 2.0,
          'price': 50000.0,
          'total': 100000.0,
        });

        await db.insert('document_payments', {
          'document_id': docId,
          'amount': 60000.0,
          'payment_method': 'cash',
          'date': '2026-11-01T10:05:00Z',
        });

        await db.insert('stock_movements', {
          'product_id': p1,
          'type': 'sale',
          'quantity': -2.0,
          'reference_document_id': docId,
          'date': '2026-11-01T10:00:00Z',
        });

        final jEntryId = await db.insert('journal_entries', {
          'entry_no': 'J-2026-0001',
          'effective_date': '2026-11-01',
          'posted_at': '2026-11-01T10:00:00Z',
          'source_type': 'invoice',
          'source_id': docId,
          'origin': 'live',
        });

        await db.insert('journal_lines', {
          'entry_id': jEntryId,
          'account_code': '1130',
          'debit_minor': 10000000,
          'credit_minor': 0,
          'contact_id': c1,
        });
        await db.insert('journal_lines', {
          'entry_id': jEntryId,
          'account_code': '4100',
          'debit_minor': 0,
          'credit_minor': 10000000,
        });

        final stSessionId = await db.insert('stocktake_sessions', {
          'session_number': 'ST-001',
          'status': 'completed',
          'started_at': '2026-11-01T08:00:00Z',
          'created_at': '2026-11-01T08:00:00Z',
          'updated_at': '2026-11-01T09:00:00Z',
        });

        await db.insert('audit_log', {
          'action': 'legacy_event_1',
          'entity_type': 'document',
          'entity_id': docId,
          'details': 'Legacy invoice created',
          'timestamp': '2026-11-01T10:00:00Z',
        });

        // Step C: Execute migration from 28 to 29
        await DatabaseHelper.instance.upgradeTablesForTest(db, 28, 29);

        // Step D: Verify data integrity & null created_by on legacy rows
        final docRow = (await db.query('documents', where: 'id = ?', whereArgs: [docId])).first;
        expect(docRow['document_number'], 'INV-2026-001');
        expect(docRow['total'], 100000.0);
        expect(docRow['created_by'], isNull);
        expect(docRow['updated_by'], isNull);
        expect(docRow['origin_device_id'], isNull);

        final prodRow = (await db.query('products', where: 'id = ?', whereArgs: [p1])).first;
        expect(prodRow['name'], 'سكر كنانة 50ك');
        expect(prodRow['created_by'], isNull);
        expect(prodRow['updated_by'], isNull);

        final contactRow = (await db.query('contacts', where: 'id = ?', whereArgs: [c1])).first;
        expect(contactRow['name'], 'مكتبة الأمل');
        expect(contactRow['created_by'], isNull);

        final pmtRow = (await db.query('document_payments')).first;
        expect(pmtRow['amount'], 60000.0);
        expect(pmtRow['created_by'], isNull);

        final smRow = (await db.query('stock_movements')).first;
        expect(smRow['quantity'], -2.0);
        expect(smRow['created_by'], isNull);

        final jeRow = (await db.query('journal_entries')).first;
        expect(jeRow['entry_no'], 'J-2026-0001');
        expect(jeRow['created_by'], isNull);

        final stRow = (await db.query('stocktake_sessions', where: 'id = ?', whereArgs: [stSessionId])).first;
        expect(stRow['session_number'], 'ST-001');
        expect(stRow['created_by'], isNull);

        final bizRow = (await db.query('businesses')).first;
        expect(bizRow['name'], 'متجر النيل');
        expect(bizRow['updated_by'], isNull);

        final auditRow = (await db.query('audit_log', where: 'action = ?', whereArgs: ['legacy_event_1'])).first;
        expect(auditRow['details'], 'Legacy invoice created');
        expect(auditRow['user_id'], isNull);

        // Verify journal balance (INV-14 identity check)
        final lines = await db.query('journal_lines');
        int totalDebit = 0;
        int totalCredit = 0;
        for (final l in lines) {
          totalDebit += (l['debit_minor'] as int);
          totalCredit += (l['credit_minor'] as int);
        }
        expect(totalDebit, totalCredit);
        expect(totalDebit, 10000000);

        // Step E: Re-running migration 28->29 is safe and idempotent
        await DatabaseHelper.instance.upgradeTablesForTest(db, 28, 29);
        expect((await db.query('workspaces')).length, 1);
        expect((await db.query('users')).length, 1);
        expect((await db.query('roles')).length, 5);
      } finally {
        await db.close();
      }
    });

    test('3. Schema parity between fresh install v29 and upgraded v28->v29', () async {
      final freshDb = await databaseFactory.openDatabase(
        '${tempDir.path}/parity_fresh.db',
        options: OpenDatabaseOptions(
          version: 29,
          onCreate: (db, version) async {
            await DatabaseHelper.instance.createTablesForTest(db, version);
          },
        ),
      );

      final upgradedDb = await databaseFactory.openDatabase(
        '${tempDir.path}/parity_upgraded.db',
        options: OpenDatabaseOptions(
          version: 28,
          onCreate: (db, version) async {
            await DatabaseHelper.instance.createTablesForTest(db, 28);
          },
        ),
      );
      await DatabaseHelper.instance.upgradeTablesForTest(upgradedDb, 28, 29);

      try {
        final tablesToCheck = [
          'workspaces',
          'users',
          'roles',
          'role_permissions',
          'user_permission_overrides',
          'documents',
          'products',
          'contacts',
          'document_payments',
          'stock_movements',
          'journal_entries',
          'stocktake_sessions',
          'businesses',
          'audit_log',
        ];

        for (final tbl in tablesToCheck) {
          final freshCols = await freshDb.rawQuery('PRAGMA table_info($tbl)');
          final upgradedCols = await upgradedDb.rawQuery('PRAGMA table_info($tbl)');

          final freshColNames = freshCols.map((c) => c['name'] as String).toSet();
          final upgradedColNames = upgradedCols.map((c) => c['name'] as String).toSet();

          expect(
            upgradedColNames,
            equals(freshColNames),
            reason: 'Mismatch in columns for table $tbl between fresh and upgraded schemas',
          );
        }
      } finally {
        await freshDb.close();
        await upgradedDb.close();
      }
    });
  });
}
