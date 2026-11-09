import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/services/access/access_admin_service.dart';
import 'package:warqatek/services/access/access_seeder.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/recovery_service.dart';
import 'package:warqatek/services/access/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('crypto_audit_safety_test');
    AuditService.instance.setTestingDeviceId('test-device-crypto-001');
    AuthService.useCompute = false;
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

  group('Batch 8: Crypto Performance & Audit Chain Safety', () {
    late Database db;

    setUp(() async {
      AuthService.resetDeviceThrottle();
      AuthService.instance.setCalibratedIterationsForTesting(null);
      AuthService.testingIterations = 50;
      SessionManager.instance.resetForTesting();
      await DatabaseHelper.instance.closeDatabase();
      final dir = Directory.systemTemp.createTempSync('crypto_run_');
      await databaseFactory.setDatabasesPath(dir.path);
      db = await DatabaseHelper.instance.database;
      await SessionManager.instance.init();
    });

    tearDown(() async {
      AuthService.resetDeviceThrottle();
      AuthService.instance.setCalibratedIterationsForTesting(null);
      SessionManager.instance.resetForTesting();
      await DatabaseHelper.instance.closeDatabase();
    });

    test('D7: Concurrent audit logEvent calls are serialized without chain fork', () async {
      // Execute 10 concurrent logEvent calls
      final futures = List.generate(10, (i) {
        return AuditService.instance.logEvent(
          db,
          'concurrent_action_$i',
          entityType: 'test_entity',
          details: 'index=$i',
        );
      });

      await Future.wait(futures);

      // Verify chain integrity
      final result = await AuditService.instance.verifyChain(db: db);
      expect(result.isValid, isTrue);
      // Genesis + 10 events = 11 rows
      expect(result.verifiedCount, 11);
    });

    test('D7: Keyset-paged verifyChain validates entire chain across pages and detects tampering', () async {
      // Insert 12 sequential events
      for (int i = 0; i < 12; i++) {
        await AuditService.instance.logEvent(
          db,
          'paged_action_$i',
          entityType: 'item',
          details: 'page_item_$i',
        );
      }

      // Verify with small page size (pageSize = 3)
      final validResult = await AuditService.instance.verifyChain(
        db: db,
        pageSize: 3,
      );
      expect(validResult.isValid, isTrue);
      expect(validResult.verifiedCount, 13); // 1 genesis + 12 events

      // Tamper with payload details of row id=5 (drop trigger to simulate disk corruption)
      await db.execute('DROP TRIGGER IF EXISTS trg_audit_log_no_update');
      await db.rawUpdate('''
        UPDATE audit_log SET details = 'TAMPERED_PAYLOAD' WHERE id = 5
      ''');

      // Paged verification MUST detect the tampering
      final tamperedResult = await AuditService.instance.verifyChain(
        db: db,
        pageSize: 3,
      );
      expect(tamperedResult.isValid, isFalse);
      expect(tamperedResult.brokenAtId, 5);
      expect(tamperedResult.error, contains('hash mismatch'));

      // Tamper with prev_hash of row id=8
      await db.rawUpdate('''
        UPDATE audit_log SET prev_hash = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' WHERE id = 8
      ''');

      // Now it must fail at first broken row (id=5)
      final brokenFirst = await AuditService.instance.verifyChain(
        db: db,
        pageSize: 3,
      );
      expect(brokenFirst.brokenAtId, 5);
    });

    test('D8 & F5: Iteration calibration clamps between 20k and 200k', () async {
      // Unset testing override to test the calibration math
      AuthService.testingIterations = null;
      AuthService.instance.setCalibratedIterationsForTesting(null);

      final calibrated = await AuthService.instance.calibrateIterations();
      expect(calibrated, greaterThanOrEqualTo(AuthService.minIterations));
      expect(calibrated, lessThanOrEqualTo(AuthService.maxIterations));

      // Test getOrCalibrateIterations persists into app_settings
      final iters = await AuthService.instance.getOrCalibrateIterations(db);
      expect(iters, equals(calibrated));

      final rows = await db.query(
        'app_settings',
        where: "key = 'kdf_calibrated_iterations'",
      );
      expect(rows, isNotEmpty);
      expect(rows.first['value'], calibrated.toString());

      // Reset testing iterations for subsequent fast tests
      AuthService.testingIterations = 50;
    });

    test('N-NEW6: Recovery code stores iterations and verifies with custom iteration count', () async {
      const code = 'WARAQ-TEST-RECOVERY-CODE-1234';
      const customIters = 45000;

      // Save recovery code with custom iterations
      await RecoveryService.instance.saveRecoveryCode(
        code,
        executor: db,
        iterations: customIters,
      );

      // Verify app_settings has the iterations stored
      final iterRows = await db.query(
        'app_settings',
        where: "key = 'owner_recovery_code_iterations'",
      );
      expect(iterRows, isNotEmpty);
      expect(iterRows.first['value'], customIters.toString());

      // Verification succeeds using stored iterations
      final isValid = await RecoveryService.instance.verifyRecoveryCode(
        code,
        executor: db,
      );
      expect(isValid, isTrue);

      // Wrong code fails
      final isInvalid = await RecoveryService.instance.verifyRecoveryCode(
        'WARAQ-WRONG-CODE-0000',
        executor: db,
      );
      expect(isInvalid, isFalse);
    });

    test('F5: AccessAdminService.createUser and AuthService.setPassword persist kdf_iterations', () async {
      final owner = await AccessAdminService.instance.getUserById(
        AccessDao.ownerUserId,
        executor: db,
      );
      expect(owner, isNotNull);

      // Create user
      final user = await AccessAdminService.instance.createUser(
        actor: owner!,
        username: 'kdf_test_user',
        displayName: 'KDF Test User',
        roleId: AccessSeeder.roleTemplateSalesperson,
        password: 'Password123!',
        db: db,
      );

      // Verify kdf_iterations column in users table
      final userRows = await db.query(
        'users',
        columns: ['kdf_iterations', 'password_hash'],
        where: 'id = ?',
        whereArgs: [user.id],
      );
      expect(userRows.first['kdf_iterations'], isNotNull);
      expect(userRows.first['kdf_iterations'], equals(50)); // testingIterations

      // Set password updates kdf_iterations
      await AuthService.instance.setPassword(
        user.id,
        'NewSecurePass456',
        actor: owner,
        executor: db,
      );

      final updatedRows = await db.query(
        'users',
        columns: ['kdf_iterations'],
        where: 'id = ?',
        whereArgs: [user.id],
      );
      expect(updatedRows.first['kdf_iterations'], equals(50));
    });
  });
}
