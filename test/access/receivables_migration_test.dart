import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/services/access/access_seeder.dart';
import 'package:warqatek/services/access/permission_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Receivables Permission Migration Unit Tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Create necessary tables simulating an existing v30/v31 database
      await db.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE role_permissions (
          role_id TEXT NOT NULL,
          permission_key TEXT NOT NULL,
          PRIMARY KEY (role_id, permission_key)
        )
      ''');
      await db.execute('''
        CREATE TABLE user_permission_overrides (
          user_id TEXT NOT NULL,
          permission_key TEXT NOT NULL,
          effect TEXT NOT NULL,
          PRIMARY KEY (user_id, permission_key)
        )
      ''');

      // Seed test roles
      // 1. Cashier role: holds contactsViewBalances
      await db.insert('role_permissions', {
        'role_id': 'role_cashier',
        'permission_key': PermissionRegistry.contactsViewBalances,
      });
      await db.insert('role_permissions', {
        'role_id': 'role_cashier',
        'permission_key': PermissionRegistry.salesCreate,
      });

      // 2. Viewer role: holds productsView only (no contactsViewBalances)
      await db.insert('role_permissions', {
        'role_id': 'role_viewer',
        'permission_key': PermissionRegistry.productsView,
      });

      // 3. Admin role: already holds both permissions
      await db.insert('role_permissions', {
        'role_id': 'role_admin',
        'permission_key': PermissionRegistry.contactsViewBalances,
      });
      await db.insert('role_permissions', {
        'role_id': 'role_admin',
        'permission_key': PermissionRegistry.reportsViewReceivables,
      });

      // Seed test user overrides
      // User 1: holds contactsViewBalances (effect = 'allow')
      await db.insert('user_permission_overrides', {
        'user_id': 'usr_override_1',
        'permission_key': PermissionRegistry.contactsViewBalances,
        'effect': 'allow',
      });

      // User 2: holds productsView only
      await db.insert('user_permission_overrides', {
        'user_id': 'usr_override_2',
        'permission_key': PermissionRegistry.productsView,
        'effect': 'allow',
      });

      // User 3: has contactsViewBalances revoked (effect = 'deny')
      await db.insert('user_permission_overrides', {
        'user_id': 'usr_override_3',
        'permission_key': PermissionRegistry.contactsViewBalances,
        'effect': 'deny',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'migrates existing roles and user overrides and sets app_settings flag',
      () async {
        // Prior to migration: flag does not exist
        final beforeFlag = await db.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['receivables_permission_migrated'],
        );
        expect(beforeFlag.isEmpty, isTrue);

        // Run post-open migrations
        await DatabaseHelper.runPostOpenMigrations(db);

        // 1. Verify flag is set
        final afterFlag = await db.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['receivables_permission_migrated'],
        );
        expect(afterFlag.isNotEmpty, isTrue);
        expect(afterFlag.first['value'], 'true');

        // 2. Verify role grants
        final cashierPerms = await db.query(
          'role_permissions',
          where: 'role_id = ?',
          whereArgs: ['role_cashier'],
        );
        final cashierKeys = cashierPerms
            .map((r) => r['permission_key'])
            .toSet();
        expect(
          cashierKeys.contains(PermissionRegistry.reportsViewReceivables),
          isTrue,
        );

        final viewerPerms = await db.query(
          'role_permissions',
          where: 'role_id = ?',
          whereArgs: ['role_viewer'],
        );
        final viewerKeys = viewerPerms.map((r) => r['permission_key']).toSet();
        expect(
          viewerKeys.contains(PermissionRegistry.reportsViewReceivables),
          isFalse,
        );

        final adminPerms = await db.query(
          'role_permissions',
          where: 'role_id = ?',
          whereArgs: ['role_admin'],
        );
        expect(
          adminPerms
              .where(
                (r) =>
                    r['permission_key'] ==
                    PermissionRegistry.reportsViewReceivables,
              )
              .length,
          1,
        );

        // 3. Verify user override grants
        final u1Perms = await db.query(
          'user_permission_overrides',
          where: 'user_id = ?',
          whereArgs: ['usr_override_1'],
        );
        final u1Keys = u1Perms.map((r) => r['permission_key']).toSet();
        expect(
          u1Keys.contains(PermissionRegistry.reportsViewReceivables),
          isTrue,
        );
        expect(
          u1Perms.firstWhere(
            (r) =>
                r['permission_key'] ==
                PermissionRegistry.reportsViewReceivables,
          )['effect'],
          'allow',
        );

        final u2Perms = await db.query(
          'user_permission_overrides',
          where: 'user_id = ?',
          whereArgs: ['usr_override_2'],
        );
        final u2Keys = u2Perms.map((r) => r['permission_key']).toSet();
        expect(
          u2Keys.contains(PermissionRegistry.reportsViewReceivables),
          isFalse,
        );

        final u3Perms = await db.query(
          'user_permission_overrides',
          where: 'user_id = ? AND permission_key = ?',
          whereArgs: [
            'usr_override_3',
            PermissionRegistry.reportsViewReceivables,
          ],
        );
        expect(u3Perms.isNotEmpty, isTrue);
        expect(u3Perms.first['effect'], 'deny');

        // 4. Assert idempotency on second run
        await DatabaseHelper.runPostOpenMigrations(db);

        final roleCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM role_permissions',
        );
        expect(
          roleCount.first['count'],
          6,
        ); // cashier(3) + viewer(1) + admin(2)

        final userCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM user_permission_overrides',
        );
        expect(userCount.first['count'], 4); // u1(2) + u2(1) + u3(1)
      },
    );

    test(
      'direct AccessSeeder.migrateReceivablesPermissions is idempotent',
      () async {
        await AccessSeeder.migrateReceivablesPermissions(db);
        await AccessSeeder.migrateReceivablesPermissions(db);

        final cashierPerms = await db.query(
          'role_permissions',
          where: 'role_id = ? AND permission_key = ?',
          whereArgs: [
            'role_cashier',
            PermissionRegistry.reportsViewReceivables,
          ],
        );
        expect(cashierPerms.length, 1);
      },
    );

    test('runPostOpenMigrations is safe when tables are missing', () async {
      final emptyDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
      // Calling on a blank DB with no tables must not throw
      await expectLater(
        DatabaseHelper.runPostOpenMigrations(emptyDb),
        completes,
      );
      await emptyDb.close();
    });
  });
}
