import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/screens/access/users_list_screen.dart';
import 'package:warqatek/screens/invoice_screen.dart';
import 'package:warqatek/screens/license_screen.dart';
import 'package:warqatek/services/access/access_admin_service.dart';
import 'package:warqatek/services/access/access_seeder.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/permission_service.dart';
import 'package:warqatek/services/access/recovery_service.dart';
import 'package:warqatek/services/access/screen_access_policy.dart';
import 'package:warqatek/services/access/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('flows_e2e_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    AuditService.instance.setTestingDeviceId('test-device-flows-001');
    AuthService.useCompute = false;
    AuthService.testingIterations = 50;
    SessionManager.enableInactivityTimer = false;
  });

  tearDownAll(() async {
    AuthService.useCompute = true;
    AuthService.testingIterations = null;
    SessionManager.enableInactivityTimer = true;
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('End-to-End Multi-User Lifecycle & Disaster Recovery Flow', () {
    late Database db;

    setUp(() async {
      AuthService.resetDeviceThrottle();
      AuthService.testingIterations = 50;
      SessionManager.instance.resetForTesting();
      await DatabaseHelper.instance.closeDatabase();

      final dir = Directory.systemTemp.createTempSync('flow_run_');
      await databaseFactory.setDatabasesPath(dir.path);
      db = await DatabaseHelper.instance.database;
    });

    tearDown(() async {
      AuthService.resetDeviceThrottle();
      SessionManager.instance.resetForTesting();
      await DatabaseHelper.instance.closeDatabase();
    });

    test('Complete Lifecycle: Single-User -> Wizard -> Cashier POS -> Lockout -> Re-Auth -> Disaster Recovery', () async {
      // -------------------------------------------------------------
      // Initial State: Single-User Fast Path
      // -------------------------------------------------------------
      await SessionManager.instance.init();
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);
      expect(SessionManager.instance.can('any.arbitrary.permission'), isTrue);

      // -------------------------------------------------------------
      // Flow 1: Setup Wizard Enables Multi-User
      // -------------------------------------------------------------
      const initialOwnerPassword = 'OwnerSecretPass123!';
      const initialRecoveryCode = 'WXYZ-1234-ABCD-5678';

      // Hash owner password and save recovery code atomically
      await AuthService.instance.setPassword(
        AccessDao.ownerUserId,
        initialOwnerPassword,
        executor: db,
      );
      await RecoveryService.instance.saveRecoveryCode(
        initialRecoveryCode,
        executor: db,
        iterations: 50,
      );

      // Persist multi_user_enabled in DB and initialize session
      await SessionManager.instance.setMultiUserEnabled(true);
      expect(SessionManager.instance.isMultiUserEnabled, isTrue);

      // -------------------------------------------------------------
      // Flow 2: Owner User Provisioning (Manager & Cashier)
      // -------------------------------------------------------------
      final ownerUser = SessionManager.instance.currentUser!;
      expect(ownerUser.isOwner, isTrue);

      final managerUser = await AccessAdminService.instance.createUser(
        username: 'john_manager',
        displayName: 'John Manager',
        roleId: AccessSeeder.roleTemplateManager,
        password: 'ManagerPassword123!',
        actor: ownerUser,
        db: db,
      );
      expect(managerUser.username, 'john_manager');

      final cashierUser = await AccessAdminService.instance.createUser(
        username: 'sara_cashier',
        displayName: 'Sara Cashier',
        roleId: AccessSeeder.roleTemplateSalesperson,
        password: 'CashierPassword123!',
        pin: '4321',
        actor: ownerUser,
        db: db,
      );
      expect(cashierUser.username, 'sara_cashier');
      expect(cashierUser.hasPin, isTrue);

      // -------------------------------------------------------------
      // Flow 3: Cashier Login & Screen Access Restrictions
      // -------------------------------------------------------------
      // Cashier logs in using PIN '4321'
      final authenticatedCashier = await AuthService.instance.authenticateWithPin(
        cashierUser.id,
        '4321',
        executor: db,
      );
      expect(authenticatedCashier.id, cashierUser.id);

      final cashierPerms = await PermissionService.instance.getEffectivePermissions(
        cashierUser,
        executor: db,
      );
      SessionManager.instance.setSession(authenticatedCashier, cashierPerms);

      // Cashier can perform sales actions
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isTrue);
      expect(ScreenAccessPolicy.evaluate(InvoiceScreen).isAllowed, isTrue);

      // Cashier is denied admin/owner screens
      expect(SessionManager.instance.can(PermissionRegistry.usersManage), isFalse);
      expect(SessionManager.instance.can(PermissionRegistry.licenseManage), isFalse);
      expect(ScreenAccessPolicy.evaluate(UsersListScreen).isAllowed, isFalse);
      expect(ScreenAccessPolicy.evaluate(LicenseScreen).isAllowed, isFalse);

      // -------------------------------------------------------------
      // Flow 4: Session Lock & Security Barrier
      // -------------------------------------------------------------
      SessionManager.instance.lock();
      expect(SessionManager.instance.isLocked, isTrue);

      // While locked, SessionManager.can() denies EVERYTHING (N3)
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isFalse);
      expect(SessionManager.instance.can(PermissionRegistry.salesView), isFalse);
      expect(ScreenAccessPolicy.evaluate(InvoiceScreen).isAllowed, isFalse);

      // Cashier unlocks with correct PIN
      final reauthed = await AuthService.instance.authenticateWithPin(
        cashierUser.id,
        '4321',
        executor: db,
      );
      SessionManager.instance.unlock(reauthed, cashierPerms);
      expect(SessionManager.instance.isLocked, isFalse);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isTrue);

      // -------------------------------------------------------------
      // Flow 5: Cashier Logout & Owner Login
      // -------------------------------------------------------------
      SessionManager.instance.logout();
      expect(SessionManager.instance.currentUser, isNull);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isFalse);

      // Owner logs in with password
      final authenticatedOwner = await AuthService.instance.authenticateWithPassword(
        'owner',
        initialOwnerPassword,
        executor: db,
      );
      expect(authenticatedOwner.isOwner, isTrue);
      SessionManager.instance.setSession(
        authenticatedOwner,
        PermissionRegistry.allKeys,
      );
      expect(SessionManager.instance.can(PermissionRegistry.usersManage), isTrue);

      // -------------------------------------------------------------
      // Flow 6: Sensitive Action Re-Authentication
      // -------------------------------------------------------------
      // Re-authentication with correct password succeeds
      final reauthOk = await AuthService.instance.verifyPassword(
        authenticatedOwner.id,
        initialOwnerPassword,
        executor: db,
      );
      expect(reauthOk, isTrue);

      // Re-authentication with wrong password fails
      final reauthFail = await AuthService.instance.verifyPassword(
        authenticatedOwner.id,
        'WrongPassword123!',
        executor: db,
      );
      expect(reauthFail, isFalse);

      // -------------------------------------------------------------
      // Flow 7: Emergency Disaster Recovery Flow (Atomic Rotation)
      // -------------------------------------------------------------
      // Simulate Owner forgetting password:
      SessionManager.instance.logout();

      // 1. Invalid recovery code fails with AuthException
      await expectLater(
        RecoveryService.instance.recoverOwnerCredentials(
          recoveryCode: 'INVALID-CODE-0000-0000',
          newPassword: 'NewPassword999!',
          executor: db,
        ),
        throwsA(isA<AuthException>()),
      );

      // 2. Valid recovery code succeeds atomically, resets credentials, rotates code
      const newOwnerPassword = 'BrandNewOwnerPassword789!';
      final recoveryResult = await RecoveryService.instance.recoverOwnerCredentials(
        recoveryCode: initialRecoveryCode,
        newPassword: newOwnerPassword,
        newPin: '9988',
        executor: db,
      );
      final newGeneratedCode = recoveryResult.newRecoveryCode;
      expect(newGeneratedCode, isNotEmpty);
      expect(newGeneratedCode, isNot(equals(initialRecoveryCode)));

      // 3. Old recovery code is DEAD and can never be reused (F9)
      await expectLater(
        RecoveryService.instance.recoverOwnerCredentials(
          recoveryCode: initialRecoveryCode,
          newPassword: 'AnotherPassword!',
          executor: db,
        ),
        throwsA(isA<AuthException>()),
      );

      // 4. Owner logs in with new password
      final recoveredOwner = await AuthService.instance.authenticateWithPassword(
        'owner',
        newOwnerPassword,
        executor: db,
      );
      expect(recoveredOwner.isOwner, isTrue);

      // 5. Owner can also log in with new PIN
      final pinRecoveredOwner = await AuthService.instance.authenticateWithPin(
        AccessDao.ownerUserId,
        '9988',
        executor: db,
      );
      expect(pinRecoveredOwner.isOwner, isTrue);

      // -------------------------------------------------------------
      // Flow 8: Audit Chain Cryptographic Integrity Verification
      // -------------------------------------------------------------
      final auditResult = await AuditService.instance.verifyChain(db: db, pageSize: 5);
      expect(auditResult.isValid, isTrue);
      // All actions (genesis, creates, logins, reauths, recovery) are verified
      expect(auditResult.verifiedCount, greaterThanOrEqualTo(6));
    });
  });
}
