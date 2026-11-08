import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../../database/access_dao.dart';
import '../../database/database_helper.dart';
import 'auth_service.dart';

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

  /// Saves a newly generated recovery code hash and salt into [app_settings].
  Future<void> saveRecoveryCode(
    String code, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final normalized = normalizeCode(code);
    final salt = AuthService.instance.generateSalt();
    final hash = await AuthService.instance.hashSecret(normalized, salt);

    await db.rawInsert('''
      INSERT INTO app_settings (key, value) VALUES ('owner_recovery_code_hash', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''', [hash]);

    await db.rawInsert('''
      INSERT INTO app_settings (key, value) VALUES ('owner_recovery_code_salt', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''', [salt]);
  }

  /// Verifies if [inputCode] matches the stored Owner Recovery Code hash.
  Future<bool> verifyRecoveryCode(
    String inputCode, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final hashRows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['owner_recovery_code_hash'],
      limit: 1,
    );
    final saltRows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['owner_recovery_code_salt'],
      limit: 1,
    );

    if (hashRows.isEmpty || saltRows.isEmpty) return false;

    final storedHash = hashRows.first['value'] as String?;
    final storedSalt = saltRows.first['value'] as String?;
    if (storedHash == null || storedSalt == null) return false;

    final normalized = normalizeCode(inputCode);
    final computed = await AuthService.instance.hashSecret(
      normalized,
      storedSalt,
    );

    return AuthService.constantTimeEquals(computed, storedHash);
  }

  /// Resets the Owner's password using [recoveryCode] and issues a NEW recovery code.
  /// Returns the newly generated recovery code.
  Future<String> resetOwnerPasswordWithRecoveryCode(
    String recoveryCode,
    String newPassword, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;

    final isValid = await verifyRecoveryCode(recoveryCode, executor: db);
    if (!isValid) {
      throw const AuthException(
        'رمز الاسترداد غير صحيح',
        'Invalid recovery code',
      );
    }

    if (!AuthService.isValidPassword(newPassword)) {
      throw const AuthException(
        'كلمة المرور يجب أن لا تقل عن 6 أحرف',
        'Password must be at least 6 characters',
      );
    }

    // 1. Update Owner password & unlock owner
    final salt = AuthService.instance.generateSalt();
    final hash = await AuthService.instance.hashSecret(newPassword, salt);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'users',
      {
        'password_hash': hash,
        'password_salt': salt,
        'failed_attempts': 0,
        'locked_until': null,
        'setup_complete': 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [AccessDao.ownerUserId],
    );

    // 2. Invalidate old recovery code and issue a new one
    final newRecoveryCode = generateRecoveryCode();
    await saveRecoveryCode(newRecoveryCode, executor: db);

    return newRecoveryCode;
  }
}
