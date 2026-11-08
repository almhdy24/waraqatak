import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/access_admin_service.dart';
import 'package:warqatek/services/access/access_seeder.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/permission_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('access_admin_service_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    AuditService.instance.setTestingDeviceId('test-device-admin-001');
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('AccessAdminService Tests', () {
    late Database db;

    setUp(() async {
      final dbPath = '${tempDir.path}/admin_${DateTime.now().microsecondsSinceEpoch}.db';
      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: DatabaseHelper.dbVersion,
          onCreate: (db, version) async {
            await DatabaseHelper.instance.createTablesForTest(db, version);
          },
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    final ownerActor = AppUser(
      id: AccessDao.ownerUserId,
      workspaceId: AccessDao.defaultWorkspaceId,
      username: 'owner',
      displayName: 'المالك',
      roleId: AccessDao.ownerRoleId,
      isOwner: true,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('1. createUser creates user with overrides and writes audit event atomically', () async {
      final user = await AccessAdminService.instance.createUser(
        actor: ownerActor,
        username: 'cashier_new',
        displayName: 'كاشير جديد',
        roleId: AccessSeeder.roleTemplateSalesperson,
        password: 'password123',
        pin: '1234',
        overrides: {
          PermissionRegistry.productsView: 'allow',
        },
        db: db,
      );

      expect(user.username, 'cashier_new');
      expect(user.isOwner, isFalse);
      expect(user.isActive, isTrue);

      // Verify DB row
      final rows = await db.query('users', where: 'id = ?', whereArgs: [user.id]);
      expect(rows.length, 1);
      expect(rows.first['display_name'], 'كاشير جديد');

      // Verify overrides
      final overrides = await AccessAdminService.instance.getUserOverrides(user.id, executor: db);
      expect(overrides[PermissionRegistry.productsView], 'allow');

      // Verify audit event
      final auditRows = await db.query(
        'audit_log',
        where: 'action = ?',
        whereArgs: ['user_created'],
      );
      expect(auditRows.isNotEmpty, isTrue);
      expect(auditRows.first['details'], contains('cashier_new'));
    });

    test('2. createUser rejects duplicate username with localized AdminException', () async {
      await AccessAdminService.instance.createUser(
        actor: ownerActor,
        username: 'duplicate_user',
        displayName: 'مستخدم 1',
        roleId: AccessSeeder.roleTemplateSalesperson,
        password: 'password123',
        db: db,
      );

      expect(
        () => AccessAdminService.instance.createUser(
          actor: ownerActor,
          username: 'DUPLICATE_USER', // Case-insensitive check
          displayName: 'مستخدم 2',
          roleId: AccessSeeder.roleTemplateSalesperson,
          password: 'password123',
          db: db,
        ),
        throwsA(isA<AdminException>()),
      );
    });

    test('3. updateUser modifies properties, soft-disables user, and writes audit', () async {
      final user = await AccessAdminService.instance.createUser(
        actor: ownerActor,
        username: 'user_to_edit',
        displayName: 'قبل التعديل',
        roleId: AccessSeeder.roleTemplateSalesperson,
        password: 'password123',
        db: db,
      );

      final updated = await AccessAdminService.instance.updateUser(
        actor: ownerActor,
        userId: user.id,
        displayName: 'بعد التعديل',
        isActive: false, // Soft deactivation (F3)
        db: db,
      );

      expect(updated.displayName, 'بعد التعديل');
      expect(updated.isActive, isFalse);

      final rows = await db.query('users', where: 'id = ?', whereArgs: [user.id]);
      expect(rows.first['display_name'], 'بعد التعديل');
      expect(rows.first['is_active'], 0);

      // Verify audit event
      final auditRows = await db.query(
        'audit_log',
        where: 'action = ?',
        whereArgs: ['user_updated'],
      );
      expect(auditRows.isNotEmpty, isTrue);
    });

    test('4. updateUser rejects changing Owner username, role, or active status', () async {
      // Attempt to change Owner role
      expect(
        () => AccessAdminService.instance.updateUser(
          actor: ownerActor,
          userId: AccessDao.ownerUserId,
          roleId: AccessSeeder.roleTemplateSalesperson,
          db: db,
        ),
        throwsA(isA<AdminException>()),
      );

      // Attempt to deactivate Owner
      expect(
        () => AccessAdminService.instance.updateUser(
          actor: ownerActor,
          userId: AccessDao.ownerUserId,
          isActive: false,
          db: db,
        ),
        throwsA(isA<AdminException>()),
      );
    });

    test('5. createRole, updateRole, and deleteRole operate transactionally', () async {
      final role = await AccessAdminService.instance.createRole(
        actor: ownerActor,
        name: 'دور مبيعات متقدم',
        description: 'وصف الدور',
        permissions: {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
        },
        db: db,
      );

      expect(role.name, 'دور مبيعات متقدم');
      final perms = await AccessAdminService.instance.getRolePermissions(role.id, executor: db);
      expect(perms, containsAll([PermissionRegistry.salesView, PermissionRegistry.salesCreate]));

      // Update role permissions
      final updatedRole = await AccessAdminService.instance.updateRole(
        actor: ownerActor,
        roleId: role.id,
        name: 'دور مبيعات متقدم معدل',
        permissions: {
          PermissionRegistry.salesView,
        },
        db: db,
      );
      expect(updatedRole.name, 'دور مبيعات متقدم معدل');
      final updatedPerms = await AccessAdminService.instance.getRolePermissions(role.id, executor: db);
      expect(updatedPerms, {PermissionRegistry.salesView});

      // Assign user to this role
      await AccessAdminService.instance.createUser(
        actor: ownerActor,
        username: 'user_in_role',
        displayName: 'مستخدم الدور',
        roleId: role.id,
        password: 'password123',
        db: db,
      );

      // Attempt to delete role in use should fail (D4)
      expect(
        () => AccessAdminService.instance.deleteRole(
          actor: ownerActor,
          roleId: role.id,
          db: db,
        ),
        throwsA(isA<AdminException>()),
      );

      // Deactivate / move user to another role
      final users = await AccessAdminService.instance.getUsers(executor: db);
      final assignedUser = users.firstWhere((u) => u.username == 'user_in_role');
      await AccessAdminService.instance.updateUser(
        actor: ownerActor,
        userId: assignedUser.id,
        roleId: AccessSeeder.roleTemplateSalesperson,
        db: db,
      );

      // Delete role now succeeds
      await AccessAdminService.instance.deleteRole(
        actor: ownerActor,
        roleId: role.id,
        db: db,
      );

      final roleRows = await db.query('roles', where: 'id = ?', whereArgs: [role.id]);
      expect(roleRows.isEmpty, isTrue);
      final rolePermRows = await db.query('role_permissions', where: 'role_id = ?', whereArgs: [role.id]);
      expect(rolePermRows.isEmpty, isTrue);

      final auditRows = await db.query(
        'audit_log',
        where: 'action = ?',
        whereArgs: ['role_deleted'],
      );
      expect(auditRows.isNotEmpty, isTrue);
    });
  });
}
