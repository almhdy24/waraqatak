import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../../database/access_dao.dart';
import '../../database/database_helper.dart';
import '../../models/app_user.dart';
import 'access_error.dart';
import 'audit_service.dart';
import 'auth_service.dart';

/// Result returned by [RecoveryService.recoverOwnerCredentials].
class RecoveryResult {
  final String newRecoveryCode;
  final AppUser ownerUser;

  const RecoveryResult({
    required this.newRecoveryCode,
    required this.ownerUser,
  });
}

/// Service managing the single-use Owner Recovery Code.
class RecoveryService {
  RecoveryService._();
  static final RecoveryService instance = RecoveryService._();

  static const String _chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// Generates a human-readable recovery code in format: RC-XXXX-XXXX-XXXX
  String generateRecoveryCode() {
    final rand = Random.secure();
    String chunk(int len) =>
        List.generate(len, (_) => _chars[rand.nextInt(_chars.length)]).join();
    return 'RC-${chunk(4)}-${chunk(4)}-${chunk(4)}';
  }

  /// Normalizes recovery code for comparison (uppercase, strip RC prefix, dashes, spaces).
  static String normalizeCode(String code) {
    return code
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceFirst(RegExp(r'^RC'), '');
  }

  /// Saves a newly generated recovery code hash, salt, and iterations into [app_settings] (N-NEW6).
  Future<void> saveRecoveryCode(
    String code, {
    DatabaseExecutor? executor,
    int? iterations,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final iter = iterations ?? await AuthService.instance.getOrCalibrateIterations(db);
    final normalized = normalizeCode(code);
    final salt = AuthService.instance.generateSalt();
    final hash = await AuthService.instance.hashSecret(normalized, salt, iterations: iter);

    await db.rawInsert('''
      INSERT INTO app_settings (key, value) VALUES ('owner_recovery_code_hash', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''', [hash]);

    await db.rawInsert('''
      INSERT INTO app_settings (key, value) VALUES ('owner_recovery_code_salt', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''', [salt]);

    await db.rawInsert('''
      INSERT INTO app_settings (key, value) VALUES ('owner_recovery_code_iterations', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''', [iter.toString()]);
  }

  /// Verifies if [inputCode] matches the stored Owner Recovery Code hash using stored iterations.
  Future<bool> verifyRecoveryCode(
    String inputCode, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_settings',
      where: "key IN ('owner_recovery_code_hash', 'owner_recovery_code_salt', 'owner_recovery_code_iterations')",
    );
    final map = {for (final r in rows) r['key'] as String: r['value'] as String?};

    final storedHash = map['owner_recovery_code_hash'];
    final storedSalt = map['owner_recovery_code_salt'];
    if (storedHash == null || storedSalt == null) return false;

    final storedIters =
        int.tryParse(map['owner_recovery_code_iterations'] ?? '') ?? AuthService.defaultIterations;

    final normalized = normalizeCode(inputCode);
    final computed = await AuthService.instance.hashSecret(
      normalized,
      storedSalt,
      iterations: storedIters,
    );

    return AuthService.constantTimeEquals(computed, storedHash);
  }

  /// Atomically resets Owner credentials with [recoveryCode], rotates to a new recovery code,
  /// limits brute-force attempts, and writes an audit log inside a single SQLite transaction (F9).
  Future<RecoveryResult> recoverOwnerCredentials({
    required String recoveryCode,
    required String newPassword,
    String? newPin,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;

    // 1. Attempt limiting: check if recovery is locked
    final lockRows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['owner_recovery_locked_until'],
      limit: 1,
    );
    if (lockRows.isNotEmpty) {
      final lockedStr = lockRows.first['value'] as String?;
      if (lockedStr != null && lockedStr.isNotEmpty) {
        final lockedUntil = DateTime.tryParse(lockedStr);
        if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
          final rem = lockedUntil.difference(DateTime.now());
          throw AuthException(
            AccessErrorCode.recoveryLocked,
            args: {'duration': rem},
            debugMessage: 'Recovery attempts locked temporarily',
          );
        }
      }
    }

    // 2. Verify recovery code (read-only verification)
    final isValid = await verifyRecoveryCode(recoveryCode, executor: db);
    if (!isValid) {
      // Increment recovery failed attempts and persist outside transaction
      final failRows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['owner_recovery_failed_attempts'],
        limit: 1,
      );
      final currentFails =
          int.tryParse(failRows.firstOrNull?['value'] as String? ?? '0') ?? 0;
      final newFails = currentFails + 1;

      await db.rawInsert('''
        INSERT INTO app_settings (key, value) VALUES ('owner_recovery_failed_attempts', ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''', [newFails.toString()]);

      if (newFails >= 5) {
        final lockUntil = DateTime.now().add(const Duration(minutes: 15));
        await db.rawInsert('''
          INSERT INTO app_settings (key, value) VALUES ('owner_recovery_locked_until', ?)
          ON CONFLICT(key) DO UPDATE SET value = excluded.value
        ''', [lockUntil.toIso8601String()]);
      }

      try {
        await AuditService.instance.logEvent(
          db,
          'recovery_failed',
          entityType: 'user',
          details: 'failed_attempts=$newFails',
        );
      } catch (_) {}

      throw const AuthException(
        AccessErrorCode.recoveryCodeInvalid,
        debugMessage: 'Invalid recovery code',
      );
    }

    // 3. Atomically perform password reset, code rotation, and audit logging
    Future<RecoveryResult> runInTxn(DatabaseExecutor txn) async {
      // Clear failed attempts on valid recovery code
      await txn.rawInsert('''
        INSERT INTO app_settings (key, value) VALUES ('owner_recovery_failed_attempts', '0')
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''');
      await txn.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['owner_recovery_locked_until'],
      );

      // Validate password
      if (!AuthService.isValidPassword(newPassword)) {
        throw const AuthException(
          AccessErrorCode.passwordTooShort,
          debugMessage: 'Password must be at least 6 characters',
        );
      }

      // Optional PIN validation
      final iter = await AuthService.instance.getOrCalibrateIterations(txn);
      String? pinHash;
      String? pinSalt;
      if (newPin != null && newPin.trim().isNotEmpty) {
        final trimmedPin = newPin.trim();
        if (!AuthService.isValidPin(trimmedPin)) {
          throw const AuthException(
            AccessErrorCode.pinInvalid,
            debugMessage: 'PIN must be 4 to 8 digits',
          );
        }
        pinSalt = AuthService.instance.generateSalt();
        pinHash = await AuthService.instance.hashSecret(
          trimmedPin,
          pinSalt,
          iterations: iter,
        );
      }

      // Hash new password
      final passSalt = AuthService.instance.generateSalt();
      final passHash = await AuthService.instance.hashSecret(
        newPassword,
        passSalt,
        iterations: iter,
      );
      final now = DateTime.now().toIso8601String();

      final updateMap = <String, dynamic>{
        'password_hash': passHash,
        'password_salt': passSalt,
        'kdf_iterations': iter,
        'failed_attempts': 0,
        'locked_until': null,
        'setup_complete': 1,
        'updated_at': now,
      };
      if (pinHash != null) {
        updateMap['pin_hash'] = pinHash;
        updateMap['pin_salt'] = pinSalt;
      }

      await txn.update(
        'users',
        updateMap,
        where: 'id = ?',
        whereArgs: [AccessDao.ownerUserId],
      );

      // Atomic rotation of recovery code
      final newRecoveryCode = generateRecoveryCode();
      await saveRecoveryCode(newRecoveryCode, executor: txn, iterations: iter);

      // Log audit event
      try {
        await AuditService.instance.logEvent(
          txn,
          'recovery_completed',
          entityType: 'user',
          details: 'action=recover_owner_credentials',
        );
      } catch (_) {}

      // Load updated user row
      final ownerRows = await txn.query(
        'users',
        where: 'id = ?',
        whereArgs: [AccessDao.ownerUserId],
        limit: 1,
      );
      final updatedOwner = AppUser.fromMap(ownerRows.first);

      return RecoveryResult(
        newRecoveryCode: newRecoveryCode,
        ownerUser: updatedOwner,
      );
    }

    if (db is Database) {
      return await db.transaction(runInTxn);
    } else {
      return await runInTxn(db);
    }
  }

  /// Resets the Owner's password using [recoveryCode] and issues a NEW recovery code.
  /// Backward compatible wrapper around [recoverOwnerCredentials].
  Future<String> resetOwnerPasswordWithRecoveryCode(
    String recoveryCode,
    String newPassword, {
    DatabaseExecutor? executor,
  }) async {
    final result = await recoverOwnerCredentials(
      recoveryCode: recoveryCode,
      newPassword: newPassword,
      executor: executor,
    );
    return result.newRecoveryCode;
  }
}
