import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/role.dart';
import 'package:warqatek/services/access/access_policy.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/permission_service.dart';
import 'package:warqatek/services/access/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('access_policy_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    AuditService.instance.setTestingDeviceId('test-device-001');
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('AccessPolicy Pure Truth Table Tests', () {
    final ownerUser = AppUser(
      id: 'user-owner',
      workspaceId: 'default-workspace',
      username: 'owner',
      displayName: 'المالك',
      roleId: 'role-owner',
      isOwner: true,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final delegateUser = AppUser(
      id: 'user-manager',
      workspaceId: 'default-workspace',
      username: 'manager1',
      displayName: 'المدير 1',
      roleId: 'role-manager',
      isOwner: false,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final peerDelegateUser = AppUser(
      id: 'user-manager-2',
      workspaceId: 'default-workspace',
      username: 'manager2',
      displayName: 'المدير 2',
      roleId: 'role-manager',
      isOwner: false,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final cashierUser = AppUser(
      id: 'user-cashier',
      workspaceId: 'default-workspace',
      username: 'cashier1',
      displayName: 'كاشير 1',
      roleId: 'role-cashier',
      isOwner: false,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final managerPermissions = {
      PermissionRegistry.salesView,
      PermissionRegistry.salesCreate,
      PermissionRegistry.salesEdit,
      PermissionRegistry.usersManage,
      PermissionRegistry.rolesManage,
    };

    final cashierPermissions = {
      PermissionRegistry.salesView,
      PermissionRegistry.salesCreate,
    };

    test('canViewUser policy enforcement', () {
      // Owner can view anyone
      expect(
        AccessPolicy.canViewUser(
          actor: ownerUser,
          target: cashierUser,
          actorPermissions: PermissionRegistry.allKeys,
          targetPermissions: cashierPermissions,
        ).isAllowed,
        isTrue,
      );

      // Self-view is always allowed
      expect(
        AccessPolicy.canViewUser(
          actor: cashierUser,
          target: cashierUser,
          actorPermissions: cashierPermissions,
          targetPermissions: cashierPermissions,
        ).isAllowed,
        isTrue,
      );

      // User without users.manage cannot view others
      expect(
        AccessPolicy.canViewUser(
          actor: cashierUser,
          target: delegateUser,
          actorPermissions: cashierPermissions,
          targetPermissions: managerPermissions,
        ).decision,
        PolicyDecision.deniedMissingPermission,
      );

      // Delegate cannot inspect Owner account
      expect(
        AccessPolicy.canViewUser(
          actor: delegateUser,
          target: ownerUser,
          actorPermissions: managerPermissions,
          targetPermissions: PermissionRegistry.allKeys,
        ).decision,
        PolicyDecision.deniedTargetIsOwner,
      );

      // Delegate cannot inspect peer with privileged permissions
      expect(
        AccessPolicy.canViewUser(
          actor: delegateUser,
          target: peerDelegateUser,
          actorPermissions: managerPermissions,
          targetPermissions: managerPermissions,
        ).decision,
        PolicyDecision.deniedTargetIsPeerOrSuperior,
      );

      // Delegate can view subordinate
      expect(
        AccessPolicy.canViewUser(
          actor: delegateUser,
          target: cashierUser,
          actorPermissions: managerPermissions,
          targetPermissions: cashierPermissions,
        ).isAllowed,
        isTrue,
      );
    });

    test('canEditUser and canResetCredentials policy enforcement', () {
      // Owner can edit anyone
      expect(
        AccessPolicy.canEditUser(
          actor: ownerUser,
          target: cashierUser,
          actorPermissions: PermissionRegistry.allKeys,
          targetPermissions: cashierPermissions,
        ).isAllowed,
        isTrue,
      );

      // Non-owner cannot edit Owner
      expect(
        AccessPolicy.canEditUser(
          actor: delegateUser,
          target: ownerUser,
          actorPermissions: managerPermissions,
          targetPermissions: PermissionRegistry.allKeys,
        ).decision,
        PolicyDecision.deniedTargetIsOwner,
      );

      // Non-owner cannot reset Owner credentials
      expect(
        AccessPolicy.canResetCredentials(
          actor: delegateUser,
          target: ownerUser,
          actorPermissions: managerPermissions,
          targetPermissions: PermissionRegistry.allKeys,
        ).decision,
        PolicyDecision.deniedTargetIsOwner,
      );

      // Delegate can reset subordinate credentials
      expect(
        AccessPolicy.canResetCredentials(
          actor: delegateUser,
          target: cashierUser,
          actorPermissions: managerPermissions,
          targetPermissions: cashierPermissions,
        ).isAllowed,
        isTrue,
      );
    });

    test('canDisableUser policy enforcement', () {
      // Owner account cannot be disabled by anyone
      expect(
        AccessPolicy.canDisableUser(
          actor: ownerUser,
          target: ownerUser,
          actorPermissions: PermissionRegistry.allKeys,
          targetPermissions: PermissionRegistry.allKeys,
        ).decision,
        PolicyDecision.deniedTargetIsOwner,
      );

      // User cannot disable themselves
      expect(
        AccessPolicy.canDisableUser(
          actor: delegateUser,
          target: delegateUser,
          actorPermissions: managerPermissions,
          targetPermissions: managerPermissions,
        ).decision,
        PolicyDecision.deniedChangeOwnActiveStatus,
      );

      // Delegate can disable subordinate
      expect(
        AccessPolicy.canDisableUser(
          actor: delegateUser,
          target: cashierUser,
          actorPermissions: managerPermissions,
          targetPermissions: cashierPermissions,
        ).isAllowed,
        isTrue,
      );
    });

    test('canAssignRole and canGrantPermission (OWNER_ONLY stripping and subset check)', () {
      final customRole = const Role(
        id: 'role-custom',
        workspaceId: 'default-workspace',
        name: 'مخصص',
      );

      // Assigning role with OWNER_ONLY keys is denied for non-owner
      expect(
        AccessPolicy.canAssignRole(
          actor: delegateUser,
          role: customRole,
          rolePermissions: {PermissionRegistry.licenseManage},
          actorPermissions: managerPermissions,
        ).decision,
        PolicyDecision.deniedOwnerOnly,
      );

      // Assigning role with permissions actor lacks is denied
      expect(
        AccessPolicy.canAssignRole(
          actor: delegateUser,
          role: customRole,
          rolePermissions: {
            PermissionRegistry.salesView,
            PermissionRegistry.stockAdjust, // manager lacks stockAdjust
          },
          actorPermissions: managerPermissions,
        ).decision,
        PolicyDecision.deniedAssignRoleWithUnheldPermissions,
      );

      // Assigning role with subset of actor permissions is allowed
      expect(
        AccessPolicy.canAssignRole(
          actor: delegateUser,
          role: customRole,
          rolePermissions: cashierPermissions,
          actorPermissions: managerPermissions,
        ).isAllowed,
        isTrue,
      );

      // Granting OWNER_ONLY key is denied
      expect(
        AccessPolicy.canGrantPermission(
          actor: delegateUser,
          permissionKey: PermissionRegistry.backupRestore,
          actorPermissions: managerPermissions,
        ).decision,
        PolicyDecision.deniedOwnerOnly,
      );

      // Granting unheld key is denied
      expect(
        AccessPolicy.canGrantPermission(
          actor: delegateUser,
          permissionKey: PermissionRegistry.stockAdjust,
          actorPermissions: managerPermissions,
        ).decision,
        PolicyDecision.deniedGrantUnheldPermission,
      );

      // Granting held key is allowed
      expect(
        AccessPolicy.canGrantPermission(
          actor: delegateUser,
          permissionKey: PermissionRegistry.salesCreate,
          actorPermissions: managerPermissions,
        ).isAllowed,
        isTrue,
      );
    });

    test('canChangeOwn credentials require current secret', () {
      expect(
        AccessPolicy.canChangeOwnPassword(
          actor: cashierUser,
          target: cashierUser,
          currentPasswordVerified: false,
        ).decision,
        PolicyDecision.deniedSelfCredentialChangeRequiresCurrentSecret,
      );

      expect(
        AccessPolicy.canChangeOwnPassword(
          actor: cashierUser,
          target: cashierUser,
          currentPasswordVerified: true,
        ).isAllowed,
        isTrue,
      );

      expect(
        AccessPolicy.canChangeOwnPin(
          actor: cashierUser,
          target: cashierUser,
          currentPinOrPasswordVerified: false,
        ).decision,
        PolicyDecision.deniedSelfCredentialChangeRequiresCurrentSecret,
      );

      expect(
        AccessPolicy.canChangeOwnPin(
          actor: cashierUser,
          target: cashierUser,
          currentPinOrPasswordVerified: true,
        ).isAllowed,
        isTrue,
      );
    });
  });

  group('PermissionService OWNER_ONLY Stripping & Override Tolerance', () {
    late Database db;

    setUp(() async {
      final dbPath = '${tempDir.path}/perm_service_${DateTime.now().microsecondsSinceEpoch}.db';
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

    test('Non-owner has OWNER_ONLY keys stripped even if present in role or overrides', () async {
      // Create role that maliciously includes license.manage
      await db.insert('roles', {
        'id': 'role-test',
        'workspace_id': 'default-workspace',
        'name': 'Test Role',
        'is_system': 0,
        'is_template': 0,
      });
      await db.insert('role_permissions', {
        'role_id': 'role-test',
        'permission_key': PermissionRegistry.salesView,
      });
      await db.insert('role_permissions', {
        'role_id': 'role-test',
        'permission_key': PermissionRegistry.licenseManage, // OWNER_ONLY!
      });

      // Create non-owner user
      final testUser = AppUser(
        id: 'user-test-nonowner',
        workspaceId: 'default-workspace',
        username: 'testnonowner',
        displayName: 'Test Non Owner',
        roleId: 'role-test',
        isOwner: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add override with system.repair (another OWNER_ONLY key)
      await db.insert('user_permission_overrides', {
        'user_id': testUser.id,
        'permission_key': PermissionRegistry.systemRepair,
        'effect': 'allow',
      });

      final perms = await PermissionService.instance.getEffectivePermissions(
        testUser,
        executor: db,
        bypassCache: true,
      );

      // Normal permission is present
      expect(perms.contains(PermissionRegistry.salesView), isTrue);
      // OWNER_ONLY keys are stripped
      expect(perms.contains(PermissionRegistry.licenseManage), isFalse);
      expect(perms.contains(PermissionRegistry.systemRepair), isFalse);
      expect(perms.intersection(AccessPolicy.ownerOnlyKeys), isEmpty);
    });

    test('Tolerates legacy integer/boolean override effects', () async {
      final testUser = AppUser(
        id: 'user-override-test',
        workspaceId: 'default-workspace',
        username: 'overridetest',
        displayName: 'Override Test',
        roleId: 'role-cashier',
        isOwner: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Insert legacy '1' and '0' effects
      await db.insert('user_permission_overrides', {
        'user_id': testUser.id,
        'permission_key': PermissionRegistry.productsView,
        'effect': '1',
      });
      await db.insert('user_permission_overrides', {
        'user_id': testUser.id,
        'permission_key': PermissionRegistry.salesView,
        'effect': '0', // DENY
      });

      final perms = await PermissionService.instance.getEffectivePermissions(
        testUser,
        executor: db,
        bypassCache: true,
      );

      expect(perms.contains(PermissionRegistry.productsView), isTrue);
      expect(perms.contains(PermissionRegistry.salesView), isFalse);
    });
  });

  group('Database Security Triggers (Schema v30 Invariants)', () {
    late Database db;

    setUp(() async {
      final dbPath = '${tempDir.path}/triggers_${DateTime.now().microsecondsSinceEpoch}.db';
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

    test('1. trg_users_owner_no_delete blocks DELETE on Owner account', () async {
      expect(
        () => db.delete('users', where: 'id = ?', whereArgs: [AccessDao.ownerUserId]),
        throwsA(predicate((e) => e.toString().contains('Owner account is protected and cannot be deleted'))),
      );
    });

    test('2. trg_users_owner_protect_columns blocks modifying is_owner, is_active, role_id, username', () async {
      // Demote is_owner
      expect(
        () => db.update(
          'users',
          {'is_owner': 0},
          where: 'id = ?',
          whereArgs: [AccessDao.ownerUserId],
        ),
        throwsA(predicate((e) => e.toString().contains('Owner account core attributes'))),
      );

      // Deactivate Owner
      expect(
        () => db.update(
          'users',
          {'is_active': 0},
          where: 'id = ?',
          whereArgs: [AccessDao.ownerUserId],
        ),
        throwsA(predicate((e) => e.toString().contains('Owner account core attributes'))),
      );

      // Change Owner role
      expect(
        () => db.update(
          'users',
          {'role_id': 'role-cashier'},
          where: 'id = ?',
          whereArgs: [AccessDao.ownerUserId],
        ),
        throwsA(predicate((e) => e.toString().contains('Owner account core attributes'))),
      );

      // Change Owner username
      expect(
        () => db.update(
          'users',
          {'username': 'hacked_owner'},
          where: 'id = ?',
          whereArgs: [AccessDao.ownerUserId],
        ),
        throwsA(predicate((e) => e.toString().contains('Owner account core attributes'))),
      );
    });

    test('3. Credential updates and failed attempts on Owner row are ALLOWED by triggers', () async {
      final updatedRows = await db.update(
        'users',
        {
          'password_hash': 'new_hash_123',
          'failed_attempts': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [AccessDao.ownerUserId],
      );
      expect(updatedRows, 1);

      final row = await db.query('users', where: 'id = ?', whereArgs: [AccessDao.ownerUserId]);
      expect(row.first['password_hash'], 'new_hash_123');
      expect(row.first['failed_attempts'], 1);
    });

    test('4. trg_users_single_owner blocks inserting another Owner', () async {
      expect(
        () => db.insert('users', {
          'id': 'second-owner',
          'workspace_id': 'default-workspace',
          'username': 'owner2',
          'display_name': 'Owner 2',
          'role_id': 'role-owner',
          'is_owner': 1,
          'is_active': 1,
          'setup_complete': 1,
          'failed_attempts': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(predicate((e) => e.toString().contains('Only a single Owner account is permitted'))),
      );
    });

    test('5. trg_users_no_promote_to_owner blocks promoting a non-owner', () async {
      await db.insert('users', {
        'id': 'regular-user',
        'workspace_id': 'default-workspace',
        'username': 'regular',
        'display_name': 'Regular',
        'role_id': 'role-cashier',
        'is_owner': 0,
        'is_active': 1,
        'setup_complete': 1,
        'failed_attempts': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      expect(
        () => db.update(
          'users',
          {'is_owner': 1},
          where: 'id = ?',
          whereArgs: ['regular-user'],
        ),
        throwsA(predicate((e) => e.toString().contains('Cannot promote user to Owner'))),
      );
    });

    test('6. trg_roles_system_no_delete blocks deleting system roles', () async {
      expect(
        () => db.delete('roles', where: 'id = ?', whereArgs: ['role-owner']),
        throwsA(predicate((e) => e.toString().contains('System roles are protected and cannot be deleted'))),
      );
    });

    test('7. trg_owner_role_permissions_no_delete blocks removing Owner permissions', () async {
      await db.insert('role_permissions', {
        'role_id': 'role-owner',
        'permission_key': PermissionRegistry.salesView,
      });

      expect(
        () => db.delete('role_permissions', where: 'role_id = ?', whereArgs: ['role-owner']),
        throwsA(predicate((e) => e.toString().contains('Permissions cannot be deleted from the Owner role'))),
      );
    });
  });

  group('AuthService Privilege Escalation Checks & Audit Logging', () {
    late Database db;

    setUp(() async {
      final dbPath = '${tempDir.path}/auth_escalation_${DateTime.now().microsecondsSinceEpoch}.db';
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

    test('Delegate attempting to set Owner password is denied and logged as privilege_escalation_denied', () async {
      // Enable multi-user mode in session
      SessionManager.instance.setMultiUserEnabledForTesting(true);

      final delegateUser = AppUser(
        id: 'user-delegate-attacker',
        workspaceId: 'default-workspace',
        username: 'attacker',
        displayName: 'Attacker',
        roleId: 'role-manager',
        isOwner: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        await AuthService.instance.setPassword(
          AccessDao.ownerUserId,
          'hacked_password123',
          actor: delegateUser,
          executor: db,
        );
        fail('Expected AuthException');
      } on AuthException {
        // Expected
      }

      // Check audit log for privilege_escalation_denied event
      final logs = await db.query(
        'audit_log',
        where: 'action = ?',
        whereArgs: ['privilege_escalation_denied'],
      );
      expect(logs.isNotEmpty, isTrue);
      expect(logs.first['details'], contains('user-owner'));
    });
  });
}
