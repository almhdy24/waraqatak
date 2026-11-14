import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/access_admin_service.dart';
import 'package:warqatek/services/access/access_seeder.dart';
import 'package:warqatek/services/access/access_error.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/recovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('login_pin_recovery_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    AuditService.instance.setTestingDeviceId('test-device-login-001');
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Batch 6: Login, PIN, Wizard & Recovery Tests', () {
    late Database db;

    setUp(() async {
      AuthService.resetDeviceThrottle();
      final dbPath = '${tempDir.path}/rec_${DateTime.now().microsecondsSinceEpoch}.db';
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
      AuthService.resetDeviceThrottle();
      await db.close();
    });

    test('D1 & F4: Supports 4, 5, and 6 digit PINs explicitly', () async {
      // 4-digit PIN
      expect(AuthService.isValidPin('1234'), isTrue);
      // 5-digit PIN
      expect(AuthService.isValidPin('12345'), isTrue);
      // 6-digit PIN
      expect(AuthService.isValidPin('123456'), isTrue);
      // < 4 or > 6
      expect(AuthService.isValidPin('123'), isFalse);
      expect(AuthService.isValidPin('1234567'), isFalse);
      expect(AuthService.isValidPin('123a'), isFalse);

      // Create a user with 5-digit PIN and verify authentication
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

      final user = await AccessAdminService.instance.createUser(
        actor: ownerActor,
        username: 'cashier5',
        displayName: 'Cashier Five',
        roleId: AccessSeeder.roleTemplateSalesperson,
        password: 'CashierPassword123',
        pin: '54321',
        db: db,
      );

      final authUser = await AuthService.instance.authenticateWithPin(
        user.id,
        '54321',
        executor: db,
      );
      expect(authUser.id, user.id);
    });

    test('E7: Owner lockout duration is strictly capped at 5 minutes', () {
      // Normal user: 5th fail = 30s, 6th = 60s, 7th = 120s, 8th = 240s, 9th = 480s, 10th+ = 900s (15 min)
      expect(AuthService.getLockoutDuration(4, isOwner: false), Duration.zero);
      expect(AuthService.getLockoutDuration(5, isOwner: false).inSeconds, 30);
      expect(AuthService.getLockoutDuration(9, isOwner: false).inSeconds, 480);
      expect(AuthService.getLockoutDuration(10, isOwner: false).inSeconds, 900);
      expect(AuthService.getLockoutDuration(15, isOwner: false).inSeconds, 900);

      // Owner user: capped at 300s (5 minutes)
      expect(AuthService.getLockoutDuration(4, isOwner: true), Duration.zero);
      expect(AuthService.getLockoutDuration(5, isOwner: true).inSeconds, 30);
      expect(AuthService.getLockoutDuration(9, isOwner: true).inSeconds, 300); // capped from 480
      expect(AuthService.getLockoutDuration(10, isOwner: true).inSeconds, 300); // capped from 900
      expect(AuthService.getLockoutDuration(20, isOwner: true).inSeconds, 300);
    });

    test('E7: Device-level throttle triggers on consecutive failures', () async {
      expect(AuthService.isDeviceThrottled, isFalse);

      for (int i = 0; i < 4; i++) {
        AuthService.recordDeviceFailure();
      }
      expect(AuthService.isDeviceThrottled, isFalse);

      // 5th failure triggers 30s throttle
      AuthService.recordDeviceFailure();
      expect(AuthService.isDeviceThrottled, isTrue);
      expect(AuthService.deviceThrottledUntil!.difference(DateTime.now()).inSeconds, greaterThan(20));

      // Reset on successful login
      AuthService.recordDeviceSuccess();
      expect(AuthService.isDeviceThrottled, isFalse);
      expect(AuthService.deviceFailedAttempts, 0);

      // 10 failures trigger 120s throttle
      for (int i = 0; i < 10; i++) {
        AuthService.recordDeviceFailure();
      }
      expect(AuthService.isDeviceThrottled, isTrue);
      expect(AuthService.deviceThrottledUntil!.difference(DateTime.now()).inSeconds, greaterThan(100));
    });

    test('N7 & F9: Atomic recovery flow with code rotation and audit logging', () async {
      const initialRecoveryCode = 'RC-AAAA-BBBB-CCCC';
      await RecoveryService.instance.saveRecoveryCode(initialRecoveryCode, executor: db);

      // Verify code works
      final valid = await RecoveryService.instance.verifyRecoveryCode(initialRecoveryCode, executor: db);
      expect(valid, isTrue);

      // Perform atomic recovery
      final result = await RecoveryService.instance.recoverOwnerCredentials(
        recoveryCode: initialRecoveryCode,
        newPassword: 'OwnerNewPassword2026',
        newPin: '9876',
        executor: db,
      );

      expect(result.newRecoveryCode, isNotEmpty);
      expect(result.newRecoveryCode, isNot(equals(initialRecoveryCode)));
      expect(result.ownerUser.id, AccessDao.ownerUserId);

      // Old recovery code is invalidated
      final oldValid = await RecoveryService.instance.verifyRecoveryCode(initialRecoveryCode, executor: db);
      expect(oldValid, isFalse);

      // New recovery code is valid
      final newValid = await RecoveryService.instance.verifyRecoveryCode(result.newRecoveryCode, executor: db);
      expect(newValid, isTrue);

      // Owner can login with new password and new PIN
      final ownerAuthPass = await AuthService.instance.authenticateWithPassword(
        'owner',
        'OwnerNewPassword2026',
        executor: db,
      );
      expect(ownerAuthPass.id, AccessDao.ownerUserId);

      final ownerAuthPin = await AuthService.instance.authenticateWithPin(
        AccessDao.ownerUserId,
        '9876',
        executor: db,
      );
      expect(ownerAuthPin.id, AccessDao.ownerUserId);

      // Audit trail contains recovery_completed event
      final logs = await db.query(
        'audit_log',
        where: 'action = ?',
        whereArgs: ['recovery_completed'],
      );
      expect(logs.isNotEmpty, isTrue);
    });

    test('N7: Recovery code attempt limiting triggers 15m lockout after 5 fails', () async {
      const recoveryCode = 'RC-XXXX-YYYY-ZZZZ';
      await RecoveryService.instance.saveRecoveryCode(recoveryCode, executor: db);

      // Fail 4 times with bad code
      for (int i = 0; i < 4; i++) {
        await expectLater(
          RecoveryService.instance.recoverOwnerCredentials(
            recoveryCode: 'RC-WRONG-CODE-$i',
            newPassword: 'ValidPassword123',
            executor: db,
          ),
          throwsA(isA<AuthException>()),
        );
      }

      // 5th failure triggers lockout
      await expectLater(
        RecoveryService.instance.recoverOwnerCredentials(
          recoveryCode: 'RC-WRONG-CODE-5',
          newPassword: 'ValidPassword123',
          executor: db,
        ),
        throwsA(isA<AuthException>()),
      );

      // Now even with the CORRECT recovery code, attempts are locked
      await expectLater(
        RecoveryService.instance.recoverOwnerCredentials(
          recoveryCode: recoveryCode,
          newPassword: 'ValidPassword123',
          executor: db,
        ),
        throwsA(predicate((e) => e is AuthException && e.code == AccessErrorCode.recoveryLocked)),
      );
    });
  });
}
