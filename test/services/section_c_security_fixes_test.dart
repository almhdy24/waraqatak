import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/role.dart';
import 'package:warqatek/services/access/access_admin_service.dart';
import 'package:warqatek/services/access/access_error.dart';
import 'package:warqatek/services/access/access_policy.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/recovery_service.dart';
import 'package:warqatek/services/access/screen_access_policy.dart';
import 'package:warqatek/services/access/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Directory? tempDir;
  var sqliteAvailable = false;

  setUpAll(() async {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tempDir = Directory.systemTemp.createTempSync('section_c_test');
      await databaseFactory.setDatabasesPath(tempDir!.path);
      final testDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await testDb.close();
      sqliteAvailable = true;
    } catch (_) {
      sqliteAvailable = false;
    }
    AuditService.instance.setTestingDeviceId('test-device-sec-c');
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir?.existsSync() == true) tempDir!.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('C8: AuthService.getLockoutDuration exponent clamping', () {
    test('failedAttempts below 5 returns Duration.zero', () {
      expect(AuthService.getLockoutDuration(0), Duration.zero);
      expect(AuthService.getLockoutDuration(1), Duration.zero);
      expect(AuthService.getLockoutDuration(4), Duration.zero);
    });

    test('failedAttempts 5 returns 30s', () {
      expect(AuthService.getLockoutDuration(5).inSeconds, 30);
      expect(AuthService.getLockoutDuration(5, isOwner: true).inSeconds, 30);
    });

    test('failedAttempts 9 returns 480s (non-owner) and capped at 300s (owner)', () {
      expect(AuthService.getLockoutDuration(9, isOwner: false).inSeconds, 480);
      expect(AuthService.getLockoutDuration(9, isOwner: true).inSeconds, 300);
    });

    test('failedAttempts 10 returns 900s (non-owner) and 300s (owner)', () {
      expect(AuthService.getLockoutDuration(10, isOwner: false).inSeconds, 900);
      expect(AuthService.getLockoutDuration(10, isOwner: true).inSeconds, 300);
    });

    test('failedAttempts 68 never overflows and stays capped at 900s / 300s', () {
      final nonOwner = AuthService.getLockoutDuration(68, isOwner: false);
      final owner = AuthService.getLockoutDuration(68, isOwner: true);
      expect(nonOwner.inSeconds, 900);
      expect(owner.inSeconds, 300);
      expect(nonOwner.inSeconds > 0, isTrue);
    });

    test('failedAttempts 200 never overflows and stays capped at 900s / 300s', () {
      final nonOwner = AuthService.getLockoutDuration(200, isOwner: false);
      final owner = AuthService.getLockoutDuration(200, isOwner: true);
      expect(nonOwner.inSeconds, 900);
      expect(owner.inSeconds, 300);
      expect(nonOwner.inSeconds > 0, isTrue);
    });
  });

  group('C2 & C3: Self credential and PIN policy enforcement', () {
    final owner = AppUser(
      id: AccessDao.ownerUserId,
      workspaceId: AccessDao.defaultWorkspaceId,
      username: 'owner',
      displayName: 'Owner',
      roleId: AccessDao.ownerRoleId,
      isOwner: true,
      isActive: true,
      passwordHash: 'passhash',
      passwordSalt: 'passsalt',
      pinHash: 'pinhash',
      pinSalt: 'pinsalt',
      kdfIterations: 50000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final delegate = AppUser(
      id: 'usr-1',
      workspaceId: AccessDao.defaultWorkspaceId,
      username: 'cashier',
      displayName: 'Cashier',
      roleId: 'role-cashier',
      isOwner: false,
      isActive: true,
      passwordHash: 'passhash',
      passwordSalt: 'passsalt',
      pinHash: 'pinhash',
      pinSalt: 'pinsalt',
      kdfIterations: 50000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('canChangeOwnPassword requires actor to be target and current password verified', () {
      // Different user -> deny
      final r1 = AccessPolicy.canChangeOwnPassword(
        actor: delegate,
        target: owner,
        currentPasswordVerified: true,
      );
      expect(r1.isAllowed, isFalse);

      // Unverified current password -> deny
      final r2 = AccessPolicy.canChangeOwnPassword(
        actor: delegate,
        target: delegate,
        currentPasswordVerified: false,
      );
      expect(r2.isAllowed, isFalse);
      expect(r2.decision, AccessErrorCode.selfCredentialRequiresCurrentSecret);

      // Verified current password -> allow
      final r3 = AccessPolicy.canChangeOwnPassword(
        actor: delegate,
        target: delegate,
        currentPasswordVerified: true,
      );
      expect(r3.isAllowed, isTrue);
    });

    test('canChangeOwnPin requires actor to be target and current PIN/password verified', () {
      // Different user -> deny
      final r1 = AccessPolicy.canChangeOwnPin(
        actor: delegate,
        target: owner,
        currentPinOrPasswordVerified: true,
      );
      expect(r1.isAllowed, isFalse);

      // Unverified current secret -> deny
      final r2 = AccessPolicy.canChangeOwnPin(
        actor: delegate,
        target: delegate,
        currentPinOrPasswordVerified: false,
      );
      expect(r2.isAllowed, isFalse);
      expect(r2.decision, AccessErrorCode.selfCredentialRequiresCurrentSecret);

      // Verified current secret -> allow
      final r3 = AccessPolicy.canChangeOwnPin(
        actor: delegate,
        target: delegate,
        currentPinOrPasswordVerified: true,
      );
      expect(r3.isAllowed, isTrue);
    });
  });

  group('C10: Cryptographic audit chain tamper proofing (v2 with userName)', () {
    test('formatPayload includes v2 and userName when provided', () {
      final p1 = AuditService.instance.formatPayload(
        action: 'user_created',
        entityType: 'user',
        entityId: 1,
        details: 'created',
        timestamp: '2026-11-14T00:00:00Z',
        userId: 'u1',
        userName: 'AdminUser',
        deviceId: 'd1',
        prevHash: 'prev',
      );
      expect(p1.startsWith('v2|user_created|'), isTrue);
      expect(p1.contains('|AdminUser|'), isTrue);

      // Without userName (v1 legacy format)
      final p0 = AuditService.instance.formatPayload(
        action: 'user_created',
        entityType: 'user',
        entityId: 1,
        details: 'created',
        timestamp: '2026-11-14T00:00:00Z',
        userId: 'u1',
        userName: null,
        deviceId: 'd1',
        prevHash: 'prev',
      );
      expect(p0.startsWith('user_created|'), isTrue);
      expect(p0.contains('v2|'), isFalse);
    });

    test('modifying user_name produces different hash', () async {
      final audit = AuditService.instance;
      final h1 = await audit.computeHash(
        action: 'test_action',
        entityType: 'user',
        entityId: 10,
        details: 'details',
        timestamp: '2026-11-14T00:00:00Z',
        userId: 'u1',
        userName: 'OriginalName',
        deviceId: 'dev1',
        prevHash: AuditService.genesisHash,
      );

      final h2 = await audit.computeHash(
        action: 'test_action',
        entityType: 'user',
        entityId: 10,
        details: 'details',
        timestamp: '2026-11-14T00:00:00Z',
        userId: 'u1',
        userName: 'TamperedName',
        deviceId: 'dev1',
        prevHash: AuditService.genesisHash,
      );

      expect(h1, isNot(equals(h2)));
    });
  });

  group('C11: unlockUser policy enforcement', () {
    final owner = AppUser(
      id: AccessDao.ownerUserId,
      workspaceId: AccessDao.defaultWorkspaceId,
      username: 'owner',
      displayName: 'Owner',
      roleId: AccessDao.ownerRoleId,
      isOwner: true,
      isActive: true,
      passwordHash: 'passhash',
      passwordSalt: 'passsalt',
      pinHash: 'pinhash',
      pinSalt: 'pinsalt',
      kdfIterations: 50000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final delegate = AppUser(
      id: 'usr-1',
      workspaceId: AccessDao.defaultWorkspaceId,
      username: 'manager',
      displayName: 'Manager',
      roleId: 'role-manager',
      isOwner: false,
      isActive: true,
      passwordHash: 'passhash',
      passwordSalt: 'passsalt',
      pinHash: 'pinhash',
      pinSalt: 'pinsalt',
      kdfIterations: 50000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final cashier = AppUser(
      id: 'usr-2',
      workspaceId: AccessDao.defaultWorkspaceId,
      username: 'cashier',
      displayName: 'Cashier',
      roleId: 'role-cashier',
      isOwner: false,
      isActive: true,
      passwordHash: 'passhash',
      passwordSalt: 'passsalt',
      pinHash: 'pinhash',
      pinSalt: 'pinsalt',
      kdfIterations: 50000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('Owner can edit/unlock any user', () {
      final res = AccessPolicy.canEditUser(
        actor: owner,
        target: cashier,
        actorPermissions: PermissionRegistry.allKeys,
        targetPermissions: {'sales.view'},
      );
      expect(res.isAllowed, isTrue);
    });

    test('Delegate cannot unlock Owner (targetIsOwner)', () {
      final res = AccessPolicy.canEditUser(
        actor: delegate,
        target: owner,
        actorPermissions: {PermissionRegistry.usersManage},
        targetPermissions: PermissionRegistry.allKeys,
      );
      expect(res.isAllowed, isFalse);
      expect(res.decision, AccessErrorCode.targetIsOwner);
    });

    test('Delegate without users.manage cannot unlock users', () {
      final res = AccessPolicy.canEditUser(
        actor: cashier,
        target: delegate,
        actorPermissions: {'sales.view'},
        targetPermissions: {'sales.view'},
      );
      expect(res.isAllowed, isFalse);
      expect(res.decision, AccessErrorCode.missingPermission);
    });
  });

  group('C5: ScreenAccessPolicy Manifest coverage and denial for non-owners', () {
    final delegate = AppUser(
      id: 'usr-unprivileged',
      workspaceId: AccessDao.defaultWorkspaceId,
      username: 'noperms',
      displayName: 'No Perms',
      roleId: 'role-none',
      isOwner: false,
      isActive: true,
      passwordHash: 'passhash',
      passwordSalt: 'passsalt',
      pinHash: 'pinhash',
      pinSalt: 'pinsalt',
      kdfIterations: 50000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('All non-public screens deny unprivileged user', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      for (final entry in ScreenAccessPolicy.manifest.entries) {
        final screenType = entry.key;
        final policy = entry.value;

        if (policy.isPublic) continue;

        final res = ScreenAccessPolicy.evaluate(
          screenType,
          actor: delegate,
          permissions: {},
        );

        expect(
          res.isAllowed,
          isFalse,
          reason: 'Expected screen $screenType to be denied for unprivileged user',
        );
        expect(res.decision, isNotNull);
      }
    });
  });
}
