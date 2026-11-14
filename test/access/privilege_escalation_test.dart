import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/screens/access/audit_trail_screen.dart';
import 'package:warqatek/screens/access/roles_screen.dart';
import 'package:warqatek/screens/access/users_list_screen.dart';
import 'package:warqatek/screens/activation_screen.dart';
import 'package:warqatek/screens/bulk_pricing_screen.dart';
import 'package:warqatek/screens/database_diagnostic_screen.dart';
import 'package:warqatek/screens/financial_settings_screen.dart';
import 'package:warqatek/screens/google_drive_backup_screen.dart';
import 'package:warqatek/screens/license_screen.dart';
import 'package:warqatek/screens/tax_profiles_screen.dart';
import 'package:warqatek/services/access/access_admin_service.dart';
import 'package:warqatek/services/access/access_error.dart';
import 'package:warqatek/services/access/access_seeder.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/screen_access_policy.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/backup_service.dart';
import 'package:warqatek/services/bulk_pricing_service.dart';
import 'package:warqatek/services/database_repair_service.dart';

// Dummy screen class for testing deny-by-default undeclared screen policy
class UndeclaredRogueScreen {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('privilege_escalation_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    AuditService.instance.setTestingDeviceId('test-device-redteam-001');
    AuthService.useCompute = false;
    AuthService.testingIterations = 50;
    SessionManager.enableInactivityTimer = false;
  });

  tearDownAll(() async {
    AuthService.useCompute = false;
    AuthService.testingIterations = 50;
    SessionManager.enableInactivityTimer = true;
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Threat Model Red-Team Tests: Hostile Non-Owner / Cashier Scenarios', () {
    late Database db;
    late AppUser ownerUser;
    late AppUser managerUser;
    late AppUser cashierUser;

    setUp(() async {
      AuthService.resetDeviceThrottle();
      AuthService.testingIterations = 50;
      SessionManager.instance.resetForTesting();
      await DatabaseHelper.instance.closeDatabase();

      final dir = Directory.systemTemp.createTempSync('redteam_run_');
      await databaseFactory.setDatabasesPath(dir.path);
      db = await DatabaseHelper.instance.database;

      // Create owner user representation matching seeded owner
      ownerUser = AppUser(
        id: AccessDao.ownerUserId,
        workspaceId: AccessDao.defaultWorkspaceId,
        username: 'owner',
        displayName: 'Owner User',
        roleId: AccessDao.ownerRoleId,
        isOwner: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create manager user
      managerUser = await AccessAdminService.instance.createUser(
        username: 'manager_bob',
        displayName: 'Manager Bob',
        roleId: AccessSeeder.roleTemplateManager,
        password: 'Password123!',
        actor: ownerUser,
        db: db,
      );

      // Create cashier user
      cashierUser = await AccessAdminService.instance.createUser(
        username: 'cashier_alice',
        displayName: 'Cashier Alice',
        roleId: AccessSeeder.roleTemplateSalesperson,
        password: 'Password123!',
        actor: ownerUser,
        db: db,
      );

      // Enable multi-user mode
      await db.rawInsert('''
        INSERT INTO app_settings (key, value) VALUES ('multi_user_enabled', '1')
        ON CONFLICT(key) DO UPDATE SET value = '1'
      ''');
      SessionManager.instance.resetForTesting();
      await SessionManager.instance.init();
    });

    tearDown(() async {
      AuthService.resetDeviceThrottle();
      SessionManager.instance.resetForTesting();
      await DatabaseHelper.instance.closeDatabase();
    });

    test(
      'Attack 1: Cashier attempts to change or reset Owner/Manager credentials or names',
      () async {
        // 1. Cashier attempts to update Owner display name/role via AccessAdminService
        await expectLater(
          AccessAdminService.instance.updateUser(
            userId: ownerUser.id,
            displayName: 'Pawned Owner',
            actor: cashierUser,
            db: db,
          ),
          throwsA(isA<AdminException>()),
        );

        // 2. Cashier attempts to update Manager display name/role via AccessAdminService
        await expectLater(
          AccessAdminService.instance.updateUser(
            userId: managerUser.id,
            displayName: 'Pawned Manager',
            actor: cashierUser,
            db: db,
          ),
          throwsA(isA<AdminException>()),
        );

        // 3. Cashier attempts to call AuthService.setPassword targeting Owner without credentials
        await expectLater(
          AuthService.instance.setPassword(
            ownerUser.id,
            'MaliciousPassword123!',
            actor: cashierUser,
            executor: db,
          ),
          throwsA(isA<AuthException>()),
        );

        // 4. Cashier attempts to call AuthService.setPin targeting Owner without credentials
        await expectLater(
          AuthService.instance.setPin(
            ownerUser.id,
            '9999',
            actor: cashierUser,
            executor: db,
          ),
          throwsA(isA<AuthException>()),
        );

        // 5. Verify escalation attempts logged 'privilege_escalation_denied' in audit_log
        final auditEvents = await db.query(
          'audit_log',
          where: "action = 'privilege_escalation_denied'",
        );
        expect(auditEvents, isNotEmpty);
      },
    );

    test(
      'Attack 2: Cashier attempts to reach Settings, Licensing, Financial, Diagnostic and Admin screens',
      () {
        final cashierPermissions = {
          PermissionRegistry.salesCreate,
          PermissionRegistry.salesView,
          PermissionRegistry.contactsView,
        };

        // Owner-only screens must deny Cashier
        expect(
          ScreenAccessPolicy.evaluate(
            LicenseScreen,
            actor: cashierUser,
            permissions: cashierPermissions,
          ).isAllowed,
          isFalse,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            ActivationScreen,
            actor: cashierUser,
            permissions: cashierPermissions,
          ).isAllowed,
          isFalse,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            DatabaseDiagnosticScreen,
            actor: cashierUser,
            permissions: cashierPermissions,
          ).isAllowed,
          isFalse,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            GoogleDriveBackupScreen,
            actor: cashierUser,
            permissions: cashierPermissions,
          ).isAllowed,
          isFalse,
        );

        // Admin & Management screens must deny Cashier
        expect(
          ScreenAccessPolicy.evaluate(
            FinancialSettingsScreen,
            actor: cashierUser,
            permissions: cashierPermissions,
          ).isAllowed,
          isFalse,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            UsersListScreen,
            actor: cashierUser,
            permissions: cashierPermissions,
          ).isAllowed,
          isFalse,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            RolesScreen,
            actor: cashierUser,
            permissions: cashierPermissions,
          ).isAllowed,
          isFalse,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            AuditTrailScreen,
            actor: cashierUser,
            permissions: cashierPermissions,
          ).isAllowed,
          isFalse,
        );

        // Deny by default: undeclared rogue screen MUST be denied (H5)
        final rogueResult = ScreenAccessPolicy.evaluate(
          UndeclaredRogueScreen,
          actor: cashierUser,
          permissions: cashierPermissions,
        );
        expect(rogueResult.isAllowed, isFalse);
        expect(rogueResult.decision, AccessErrorCode.undeclaredScreen);
        expect(
          rogueResult.debugReason,
          contains('Undeclared screen security policy'),
        );
      },
    );

    test(
      'Attack 3: Cashier attempts to alter business info, prices, stock, or tax profiles',
      () async {
        // Set active session as cashier
        SessionManager.instance.setSession(cashierUser, {
          PermissionRegistry.salesCreate,
          PermissionRegistry.salesView,
        });

        // 1. Bulk price adjustment requires pricing.manage
        expect(
          () => BulkPricingService.instance.applyBatch(
            items: [],
            opType: BulkPriceOpType.percentageIncrease,
            opValue: 10,
            target: BulkPriceTarget.sellingPrice,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 2. Direct stock adjustment requires stock.adjust
        expect(
          () => DatabaseHelper.instance.adjustStock(productId: 1, delta: 100),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 3. Screen checks
        expect(
          ScreenAccessPolicy.evaluate(
            BulkPricingScreen,
            actor: cashierUser,
            permissions: {PermissionRegistry.salesCreate},
          ).isAllowed,
          isFalse,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            TaxProfilesScreen,
            actor: cashierUser,
            permissions: {PermissionRegistry.salesCreate},
          ).isAllowed,
          isFalse,
        );
      },
    );

    test(
      'Attack 4: Cashier attempts to turn off auto-lock or multi-user mode',
      () async {
        // Set active session as cashier
        SessionManager.instance.setSession(cashierUser, {
          PermissionRegistry.salesCreate,
        });

        // 1. Turning off auto-lock (minutes = 0) is OWNER_ONLY (H1, E5)
        expect(
          () => SessionManager.instance.setAutoLockMinutes(0),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 2. Disabling multi-user mode is OWNER_ONLY (N5)
        expect(
          () => SessionManager.instance.setMultiUserEnabled(false),
          throwsA(isA<PermissionDeniedException>()),
        );
      },
    );

    test(
      'Attack 5: Cashier attempts to delete, restore backup, or run database repairs',
      () async {
        // Set active session as cashier
        SessionManager.instance.setSession(cashierUser, {
          PermissionRegistry.salesCreate,
        });

        // 1. Restore backup requires backup.restore (owner-only key)
        expect(
          () => BackupService.restoreFromJsonMap({'version': 5}),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 2. Repair database requires system.repair (owner-only key)
        expect(
          () => DatabaseRepairService.repairAllSafe(db: db, issues: []),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 3. Screen check
        expect(
          ScreenAccessPolicy.evaluate(
            GoogleDriveBackupScreen,
            actor: cashierUser,
            permissions: {PermissionRegistry.salesCreate},
          ).isAllowed,
          isFalse,
        );
      },
    );

    test(
      'Attack 6: Cashier elevates permissions or grants self higher roles',
      () async {
        // 1. Cashier attempts to change their own role to 'role-owner'
        expect(
          () => AccessAdminService.instance.updateUser(
            userId: cashierUser.id,
            roleId: AccessDao.ownerRoleId,
            actor: cashierUser,
            db: db,
          ),
          throwsA(isA<AdminException>()),
        );

        // 2. Cashier attempts to grant themselves 'users.manage' or 'license.manage' override
        expect(
          () => AccessAdminService.instance.updateUser(
            userId: cashierUser.id,
            overrides: {
              PermissionRegistry.usersManage: 'allow',
              PermissionRegistry.licenseManage: 'allow',
            },
            actor: cashierUser,
            db: db,
          ),
          throwsA(isA<AdminException>()),
        );

        // 3. Cashier attempts to create or save a role
        expect(
          () => AccessAdminService.instance.createRole(
            name: 'Rogue Role',
            permissions: {PermissionRegistry.usersManage},
            actor: cashierUser,
            db: db,
          ),
          throwsA(isA<AdminException>()),
        );

        // 4. Manager attempts to grant owner-only permission in role
        expect(
          () => AccessAdminService.instance.createRole(
            name: 'Elevated Manager',
            permissions: {
              PermissionRegistry.usersManage,
              PermissionRegistry.licenseManage, // OWNER_ONLY!
            },
            actor: managerUser,
            db: db,
          ),
          throwsA(isA<AdminException>()),
        );
      },
    );

    test(
      'Attack 7: Owner lockout DoS capped at 5 minutes and device throttle pauses brute-force',
      () async {
        // Set password for Owner
        await AuthService.instance.setPassword(
          ownerUser.id,
          'OwnerSecret123!',
          actor: ownerUser,
          executor: db,
        );

        // Attacker enters wrong password 5 times targeting Owner
        for (int i = 0; i < 5; i++) {
          try {
            await AuthService.instance.authenticateWithPassword(
              ownerUser.username,
              'WrongPassword!',
              executor: db,
            );
          } catch (_) {}
        }

        // Check Owner record in DB
        final rows = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [ownerUser.id],
        );
        final lockedUntilIso = rows.first['locked_until'] as String?;
        expect(lockedUntilIso, isNotNull);
        final lockedUntil = DateTime.parse(lockedUntilIso!);

        // Maximum Owner lockout is 5 minutes (E7)
        final diffSeconds = lockedUntil.difference(DateTime.now()).inSeconds;
        expect(diffSeconds, lessThanOrEqualTo(300)); // 5 minutes max

        // Device throttle is active after 5 failures
        expect(AuthService.isDeviceThrottled, isTrue);
      },
    );

    test(
      'Attack 8: Database SQLite triggers protect Owner row from direct SQL manipulation',
      () async {
        // 1. Direct DELETE FROM users for Owner row
        expect(
          () => db.delete(
            'users',
            where: 'id = ?',
            whereArgs: [AccessDao.ownerUserId],
          ),
          throwsA(
            predicate(
              (e) => e.toString().contains(
                'Owner account is protected and cannot be deleted',
              ),
            ),
          ),
        );

        // 2. Direct UPDATE is_owner = 0 for Owner row
        expect(
          () => db.update(
            'users',
            {'is_owner': 0},
            where: 'id = ?',
            whereArgs: [AccessDao.ownerUserId],
          ),
          throwsA(
            predicate(
              (e) => e.toString().contains('Owner account core attributes'),
            ),
          ),
        );

        // 3. Direct UPDATE role_id for Owner row
        expect(
          () => db.update(
            'users',
            {'role_id': 'cashier'},
            where: 'id = ?',
            whereArgs: [AccessDao.ownerUserId],
          ),
          throwsA(
            predicate(
              (e) => e.toString().contains('Owner account core attributes'),
            ),
          ),
        );

        // 4. Direct UPDATE username for Owner row
        expect(
          () => db.update(
            'users',
            {'username': 'hacked_owner'},
            where: 'id = ?',
            whereArgs: [AccessDao.ownerUserId],
          ),
          throwsA(
            predicate(
              (e) => e.toString().contains('Owner account core attributes'),
            ),
          ),
        );

        // 5. Direct DELETE FROM roles for system Owner role
        expect(
          () => db.delete(
            'roles',
            where: 'id = ?',
            whereArgs: [AccessDao.ownerRoleId],
          ),
          throwsA(
            predicate(
              (e) => e.toString().contains(
                'System roles are protected and cannot be deleted',
              ),
            ),
          ),
        );
      },
    );

    test(
      'Attack 9: Audit log triggers prevent SQL tamper and chain verification passes legitimate logs',
      () async {
        // 1. Direct UPDATE audit_log fails via trigger
        expect(
          () => db.rawUpdate(
            "UPDATE audit_log SET details = 'erased' WHERE id = 1",
          ),
          throwsA(
            predicate(
              (e) => e.toString().contains(
                'audit_log is append-only and cannot be updated',
              ),
            ),
          ),
        );

        // 2. Direct DELETE FROM audit_log fails via trigger
        expect(
          () => db.rawDelete("DELETE FROM audit_log WHERE id = 1"),
          throwsA(
            predicate(
              (e) => e.toString().contains(
                'audit_log is append-only and cannot be deleted',
              ),
            ),
          ),
        );

        // 3. Legitimate audit chain verifies with valid cryptographic integrity
        final chainResult = await AuditService.instance.verifyChain(db: db);
        expect(chainResult.isValid, isTrue);
        expect(chainResult.verifiedCount, greaterThan(0));
      },
    );
  });
}
