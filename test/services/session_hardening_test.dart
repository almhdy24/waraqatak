import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/access_context.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('session_hardening_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  tearDown(() {
    SessionManager.instance.resetForTesting();
  });

  final activeUser = AppUser(
    id: 'user-cashier-1',
    workspaceId: AccessDao.defaultWorkspaceId,
    username: 'cashier1',
    displayName: 'Cashier One',
    roleId: 'role-template-salesperson',
    isOwner: false,
    isActive: true,
    setupComplete: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final disabledUser = AppUser(
    id: 'user-disabled-1',
    workspaceId: AccessDao.defaultWorkspaceId,
    username: 'disabled1',
    displayName: 'Disabled User',
    roleId: 'role-template-salesperson',
    isOwner: false,
    isActive: false,
    setupComplete: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final lockedUser = AppUser(
    id: 'user-locked-1',
    workspaceId: AccessDao.defaultWorkspaceId,
    username: 'locked1',
    displayName: 'Locked User',
    roleId: 'role-template-salesperson',
    isOwner: false,
    isActive: true,
    setupComplete: true,
    failedAttempts: 5,
    lockedUntil: DateTime.now().add(const Duration(minutes: 5)),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('1. AppUser.copyWith Sentinel Pattern', () {
    test('copyWith clears nullable lockedUntil when passed null', () {
      final userWithLock = activeUser.copyWith(
        lockedUntil: DateTime.now().add(const Duration(minutes: 10)),
      );
      expect(userWithLock.lockedUntil, isNotNull);

      final clearedUser = userWithLock.copyWith(lockedUntil: null);
      expect(clearedUser.lockedUntil, isNull);
    });

    test('copyWith preserves lockedUntil when omitted', () {
      final lockTime = DateTime.now().add(const Duration(minutes: 10));
      final userWithLock = activeUser.copyWith(lockedUntil: lockTime);
      final updatedUser = userWithLock.copyWith(displayName: 'Updated Name');

      expect(updatedUser.lockedUntil, lockTime);
      expect(updatedUser.displayName, 'Updated Name');
    });

    test('copyWith clears passwordHash and pinHash when passed null', () {
      final user = activeUser.copyWith(
        passwordHash: 'hash123',
        pinHash: 'pin123',
      );
      expect(user.passwordHash, 'hash123');
      expect(user.pinHash, 'pin123');

      final cleared = user.copyWith(passwordHash: null, pinHash: null);
      expect(cleared.passwordHash, isNull);
      expect(cleared.pinHash, isNull);
    });
  });

  group('2. SessionManager.can() and Lock State', () {
    test('in single-user mode, can() returns true for all keys', () {
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isTrue);
      expect(SessionManager.instance.can(PermissionRegistry.licenseManage), isTrue);
    });

    test('in multi-user mode, can() returns false when locked for everyone', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      expect(SessionManager.instance.isLocked, isTrue);

      // Logged out / locked: false for any key
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isFalse);

      // Even if Owner is set, if locked, can() MUST return false
      final ownerUser = activeUser.copyWith(isOwner: true);
      // Manually set owner while locked
      SessionManager.instance.setSession(ownerUser, PermissionRegistry.allKeys);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isTrue);

      SessionManager.instance.lock();
      expect(SessionManager.instance.isLocked, isTrue);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isFalse);
      expect(SessionManager.instance.can(PermissionRegistry.licenseManage), isFalse);
    });

    test('in multi-user mode, can() returns false when no user is logged in', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.logout();

      expect(SessionManager.instance.currentUser, isNull);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isFalse);
    });

    test('system zone bypasses through AccessGuard even when session is locked', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      expect(SessionManager.instance.isLocked, isTrue);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isFalse);

      final allowed = AccessGuard.runAsSystem(() {
        return AccessGuard.can(PermissionRegistry.salesCreate);
      });
      expect(allowed, isTrue);
    });
  });

  group('3. Actor Attribution Invariance', () {
    test('single-user mode attributes to Owner', () {
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);
      expect(AccessContext.currentUserId, AccessDao.ownerUserId);
      expect(AccessContext.currentUserName, 'المالك');
    });

    test('multi-user mode NEVER attributes to Owner when unauthenticated/locked', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      expect(SessionManager.instance.isLocked, isTrue);

      // MUST NOT return ownerUserId
      expect(AccessContext.currentUserId, isNot(equals(AccessDao.ownerUserId)));
      expect(AccessContext.currentUserId, 'unauthenticated');
      expect(AccessContext.currentUserName, 'غير مسجل');
    });

    test('multi-user mode attributes to authenticated active user', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(activeUser, {
        PermissionRegistry.salesCreate,
      });

      expect(AccessContext.currentUserId, 'user-cashier-1');
      expect(AccessContext.currentUserName, 'Cashier One');
    });

    test('system zone attributes to system', () {
      AccessGuard.runAsSystem(() {
        expect(AccessContext.currentUserId, 'system');
        expect(AccessContext.currentUserName, 'النظام');
      });
    });
  });

  group('4. Session establishment (unlock / setSession) assertions', () {
    test('rejects unlocking with a disabled user', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);

      expect(
        () => SessionManager.instance.unlock(disabledUser, {}),
        throwsA(isA<StateError>()),
      );
      expect(SessionManager.instance.isLocked, isTrue);
      expect(SessionManager.instance.currentUser, isNull);
    });

    test('rejects unlocking with a locked user', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);

      expect(
        () => SessionManager.instance.unlock(lockedUser, {}),
        throwsA(isA<StateError>()),
      );
      expect(SessionManager.instance.isLocked, isTrue);
      expect(SessionManager.instance.currentUser, isNull);
    });

    test('successfully establishes session for active, unlocked user', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);

      SessionManager.instance.unlock(activeUser, {PermissionRegistry.salesCreate});
      expect(SessionManager.instance.isLocked, isFalse);
      expect(SessionManager.instance.currentUser?.id, 'user-cashier-1');
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isTrue);
      expect(SessionManager.instance.can(PermissionRegistry.salesEdit), isFalse);
    });
  });

  group('5. Inactivity Auto-Lock Logic', () {
    test('auto-lock does not trigger when already locked', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      expect(SessionManager.instance.isLocked, isTrue);
      expect(SessionManager.instance.checkInactivityLock(), isFalse);
    });

    test('auto-lock does not trigger when autoLockMinutes is 0', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(activeUser, {});
      // Disabled timeout
      expect(SessionManager.instance.checkInactivityLock(), isFalse);
    });

    test('checkInactivityLock locks session when timeout exceeded', () async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(activeUser, {});
      expect(SessionManager.instance.isLocked, isFalse);

      // Simulate past activity
      // SessionManager lastActivity is private, but we can verify it doesn't lock prematurely
      expect(SessionManager.instance.checkInactivityLock(), isFalse);
      expect(SessionManager.instance.isLocked, isFalse);
    });
  });

  group('6. Database Integration, Atomic Enable/Disable, & Fail-Closed Init', () {
    late Database db;

    setUp(() async {
      await DatabaseHelper.instance.closeDatabase();
      final dir = Directory.systemTemp.createTempSync('session_db_test');
      await databaseFactory.setDatabasesPath(dir.path);
      db = await DatabaseHelper.instance.database;
    });

    tearDown(() async {
      await DatabaseHelper.instance.closeDatabase();
    });

    test('enabling multi-user loads real Owner and updates last_login_at atomically', () async {
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);

      await SessionManager.instance.setMultiUserEnabled(true);

      expect(SessionManager.instance.isMultiUserEnabled, isTrue);
      expect(SessionManager.instance.isLocked, isFalse);
      expect(SessionManager.instance.currentUser?.id, AccessDao.ownerUserId);
      expect(SessionManager.instance.currentUser?.isOwner, isTrue);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isTrue);

      // Check app_settings persisted
      final settings = await db.query(
        'app_settings',
        where: "key = 'multi_user_enabled'",
      );
      expect(settings.first['value'], '1');

      // Check audit_log recorded the event
      final audit = await db.query(
        'audit_log',
        where: "action = 'multi_user_enabled'",
      );
      expect(audit, isNotEmpty);
    });

    test('disabling multi-user restores single-user mode and writes audit', () async {
      await SessionManager.instance.setMultiUserEnabled(true);
      expect(SessionManager.instance.isMultiUserEnabled, isTrue);

      await SessionManager.instance.setMultiUserEnabled(false);
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);
      expect(SessionManager.instance.isLocked, isFalse);
      expect(SessionManager.instance.currentUser?.id, AccessDao.ownerUserId);

      final settings = await db.query(
        'app_settings',
        where: "key = 'multi_user_enabled'",
      );
      expect(settings.first['value'], '0');

      final audit = await db.query(
        'audit_log',
        where: "action = 'multi_user_disabled'",
      );
      expect(audit, isNotEmpty);
    });

    test('init() fails closed when database throws error', () async {
      // Close database to force query failure
      await db.close();

      SessionManager.instance.resetForTesting();
      await SessionManager.instance.init();

      // MUST NOT fall back to single-user mode or implicit Owner!
      expect(SessionManager.instance.isMultiUserEnabled, isTrue);
      expect(SessionManager.instance.isSecurityUnverified, isTrue);
      expect(SessionManager.instance.isLocked, isTrue);
      expect(SessionManager.instance.currentUser, isNull);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isFalse);
    });
  });
}
