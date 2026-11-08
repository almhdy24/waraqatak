import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/app_user.dart';
import 'access_guard.dart';
import 'access_policy.dart';
import 'audit_service.dart';
import 'permission_service.dart';
import 'session_manager.dart';

class _HashRequest {
  final String secret;
  final String salt;
  final int iterations;

  const _HashRequest({
    required this.secret,
    required this.salt,
    required this.iterations,
  });
}

Future<String> _derivePbkdf2(_HashRequest req) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: req.iterations,
    bits: 256,
  );
  final secretKey = SecretKey(utf8.encode(req.secret));
  final nonce = utf8.encode(req.salt);
  final newKey = await pbkdf2.deriveKey(secretKey: secretKey, nonce: nonce);
  final bytes = await newKey.extractBytes();
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Authentication service for local multi-user PIN and password verification.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const int defaultIterations = 100000;
  static const int minPinLength = 4;
  static const int maxPinLength = 6;
  static const int minPasswordLength = 6;

  // Device-level throttle to prevent brute-force and lockout DoS (E7)
  static int _deviceFailedAttempts = 0;
  static DateTime? _deviceThrottledUntil;

  static int get deviceFailedAttempts => _deviceFailedAttempts;
  static DateTime? get deviceThrottledUntil => _deviceThrottledUntil;
  static bool get isDeviceThrottled =>
      _deviceThrottledUntil != null && _deviceThrottledUntil!.isAfter(DateTime.now());

  static void recordDeviceFailure() {
    _deviceFailedAttempts++;
    if (_deviceFailedAttempts >= 10) {
      _deviceThrottledUntil = DateTime.now().add(const Duration(seconds: 120));
    } else if (_deviceFailedAttempts >= 5) {
      _deviceThrottledUntil = DateTime.now().add(const Duration(seconds: 30));
    }
  }

  static void recordDeviceSuccess() {
    _deviceFailedAttempts = 0;
    _deviceThrottledUntil = null;
  }

  @visibleForTesting
  static void resetDeviceThrottle() {
    _deviceFailedAttempts = 0;
    _deviceThrottledUntil = null;
  }

  /// Generates a cryptographically secure random hex salt (16 bytes = 32 hex chars).
  String generateSalt([int byteLength = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes a password or PIN with PBKDF2-HMAC-SHA256 (computed in an isolate).
  Future<String> hashSecret(
    String secret,
    String salt, {
    int iterations = defaultIterations,
  }) async {
    final req = _HashRequest(
      secret: secret,
      salt: salt,
      iterations: iterations,
    );
    // Use compute on release/VM so crypto never causes UI jank
    if (kIsWeb) {
      return _derivePbkdf2(req);
    }
    return compute(_derivePbkdf2, req);
  }

  /// Constant-time string equality comparison to prevent timing attacks.
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Validates PIN format (4 to 6 digits only).
  static bool isValidPin(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  /// Validates password format (minimum 6 characters).
  static bool isValidPassword(String password) {
    return password.length >= minPasswordLength;
  }

  /// Calculates escalating lockout duration based on consecutive failed attempts.
  /// 5 failures: 30s
  /// 6 failures: 60s
  /// 7 failures: 120s
  /// 8 failures: 240s
  /// 9 failures: 480s
  /// 10+ failures: 900s (15 min) — capped at 300s (5 min) for Owner (E7)
  static Duration getLockoutDuration(int failedAttempts, {bool isOwner = false}) {
    if (failedAttempts < 5) return Duration.zero;
    final exp = failedAttempts - 5;
    final seconds = 30 * (1 << exp);
    final maxSec = isOwner ? 300 : 900;
    return Duration(seconds: min(seconds, maxSec));
  }

  /// Authenticates user with username and password.
  /// Returns the authenticated [AppUser] or throws [AuthException].
  Future<AppUser> authenticateWithPassword(
    String username,
    String password, {
    DatabaseExecutor? executor,
  }) async {
    if (isDeviceThrottled) {
      final rem = _deviceThrottledUntil!.difference(DateTime.now());
      throw AuthException(
        'تم تجاوز محاولات الدخول على هذا الجهاز. حاول بعد ${rem.inSeconds + 1} ثانية',
        'Too many failed attempts on this device. Try again in ${rem.inSeconds + 1}s',
      );
    }
    final db = executor ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [username.trim()],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw const AuthException('المستخدم غير موجود', 'User not found');
    }

    final user = AppUser.fromMap(rows.first);

    if (!user.isActive) {
      throw const AuthException(
        'هذا الحساب معطل حالياً',
        'This account is currently disabled',
      );
    }

    if (user.isLocked) {
      final rem = user.lockedUntil!.difference(DateTime.now());
      throw AuthException(
        'الحساب مقفل مؤقتاً. حاول بعد ${rem.inSeconds + 1} ثانية',
        'Account is temporarily locked. Try again in ${rem.inSeconds + 1}s',
      );
    }

    if (!user.hasPassword) {
      throw const AuthException(
        'لم يتم تعيين كلمة مرور لهذا الحساب',
        'No password configured for this user',
      );
    }

    final computedHash = await hashSecret(
      password,
      user.passwordSalt!,
      iterations: user.kdfIterations,
    );

    if (!constantTimeEquals(computedHash, user.passwordHash!)) {
      recordDeviceFailure();
      await _recordFailedAttempt(user, db);
      throw const AuthException(
        'كلمة المرور غير صحيحة',
        'Incorrect password',
      );
    }

    // Success: reset failed attempts & update last login
    recordDeviceSuccess();
    await _recordSuccessfulLogin(user, db);
    return user.copyWith(
      failedAttempts: 0,
      lockedUntil: null,
      lastLoginAt: DateTime.now(),
    );
  }

  /// Authenticates user with PIN.
  Future<AppUser> authenticateWithPin(
    String userId,
    String pin, {
    DatabaseExecutor? executor,
  }) async {
    if (isDeviceThrottled) {
      final rem = _deviceThrottledUntil!.difference(DateTime.now());
      throw AuthException(
        'تم تجاوز محاولات الدخول على هذا الجهاز. حاول بعد ${rem.inSeconds + 1} ثانية',
        'Too many failed attempts on this device. Try again in ${rem.inSeconds + 1}s',
      );
    }
    final db = executor ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw const AuthException('المستخدم غير موجود', 'User not found');
    }

    final user = AppUser.fromMap(rows.first);

    if (!user.isActive) {
      throw const AuthException(
        'هذا الحساب معطل حالياً',
        'This account is currently disabled',
      );
    }

    if (user.isLocked) {
      final rem = user.lockedUntil!.difference(DateTime.now());
      throw AuthException(
        'الحساب مقفل مؤقتاً. حاول بعد ${rem.inSeconds + 1} ثانية',
        'Account is temporarily locked. Try again in ${rem.inSeconds + 1}s',
      );
    }

    if (!user.hasPin) {
      throw const AuthException(
        'لم يتم تعيين رمز PIN لهذا الحساب',
        'No PIN configured for this user',
      );
    }

    final computedHash = await hashSecret(
      pin,
      user.pinSalt!,
      iterations: user.kdfIterations,
    );

    if (!constantTimeEquals(computedHash, user.pinHash!)) {
      recordDeviceFailure();
      await _recordFailedAttempt(user, db);
      throw const AuthException(
        'رمز PIN غير صحيح',
        'Incorrect PIN',
      );
    }

    recordDeviceSuccess();
    await _recordSuccessfulLogin(user, db);
    return user.copyWith(
      failedAttempts: 0,
      lockedUntil: null,
      lastLoginAt: DateTime.now(),
    );
  }

  /// Re-authenticates a user using their password (required for sensitive actions).
  Future<bool> verifyPassword(
    String userId,
    String password, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final user = AppUser.fromMap(rows.first);
    if (!user.hasPassword) return false;

    final computed = await hashSecret(
      password,
      user.passwordSalt!,
      iterations: user.kdfIterations,
    );
    return constantTimeEquals(computed, user.passwordHash!);
  }

  /// Updates or sets password for [userId].
  Future<void> setPassword(
    String userId,
    String newPassword, {
    AppUser? actor,
    String? currentPassword,
    DatabaseExecutor? executor,
  }) async {
    if (!isValidPassword(newPassword)) {
      throw const AuthException(
        'كلمة المرور يجب أن لا تقل عن 6 أحرف',
        'Password must be at least 6 characters',
      );
    }
    final db = executor ?? await DatabaseHelper.instance.database;

    final enforcePolicy =
        !AccessGuard.isSystemContext && SessionManager.instance.isMultiUserEnabled;
    if (enforcePolicy) {
      final effectiveActor = actor ?? SessionManager.instance.currentUser;
      if (effectiveActor == null) {
        throw const AuthException(
          'غير مصرح: يجب تسجيل الدخول',
          'Unauthorized: session is not authenticated',
        );
      }

      final targetRows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (targetRows.isEmpty) {
        throw const AuthException('المستخدم غير موجود', 'User not found');
      }
      final targetUser = AppUser.fromMap(targetRows.first);

      if (effectiveActor.id == targetUser.id) {
        if (targetUser.hasPassword) {
          if (currentPassword == null || currentPassword.isEmpty) {
            throw const AuthException(
              'يجب إدخال كلمة المرور الحالية لتغيير كلمة المرور',
              'Current password required to change password',
            );
          }
          final verified = await verifyPassword(
            targetUser.id,
            currentPassword,
            executor: db,
          );
          if (!verified) {
            throw const AuthException(
              'كلمة المرور الحالية غير صحيحة',
              'Incorrect current password',
            );
          }
        }
      } else {
        final actorPerms = await PermissionService.instance
            .getEffectivePermissions(effectiveActor, executor: db);
        final targetPerms = await PermissionService.instance
            .getEffectivePermissions(targetUser, executor: db);

        final policy = AccessPolicy.canResetCredentials(
          actor: effectiveActor,
          target: targetUser,
          actorPermissions: actorPerms,
          targetPermissions: targetPerms,
        );

        if (!policy.isAllowed) {
          await AuditService.instance.logEvent(
            db,
            'privilege_escalation_denied',
            entityType: 'user',
            details: jsonEncode({
              'action': 'setPassword',
              'actor_user_id': effectiveActor.id,
              'actor_username': effectiveActor.username,
              'target_user_id': targetUser.id,
              'target_username': targetUser.username,
              'decision': policy.decision.name,
              'reason': policy.reasonEn,
            }),
          );
          throw AuthException(policy.reasonAr, policy.reasonEn);
        }
      }
    }

    final salt = generateSalt();
    final hash = await hashSecret(newPassword, salt);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'users',
      {
        'password_hash': hash,
        'password_salt': salt,
        'setup_complete': 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Updates or sets PIN for [userId].
  Future<void> setPin(
    String userId,
    String newPin, {
    AppUser? actor,
    String? currentPinOrPassword,
    DatabaseExecutor? executor,
  }) async {
    if (!isValidPin(newPin)) {
      throw const AuthException(
        'رمز PIN يجب أن يتكون من 4 إلى 6 أرقام',
        'PIN must be 4 to 6 digits',
      );
    }
    final db = executor ?? await DatabaseHelper.instance.database;

    final enforcePolicy =
        !AccessGuard.isSystemContext && SessionManager.instance.isMultiUserEnabled;
    if (enforcePolicy) {
      final effectiveActor = actor ?? SessionManager.instance.currentUser;
      if (effectiveActor == null) {
        throw const AuthException(
          'غير مصرح: يجب تسجيل الدخول',
          'Unauthorized: session is not authenticated',
        );
      }

      final targetRows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (targetRows.isEmpty) {
        throw const AuthException('المستخدم غير موجود', 'User not found');
      }
      final targetUser = AppUser.fromMap(targetRows.first);

      if (effectiveActor.id == targetUser.id) {
        if (targetUser.hasPin) {
          if (currentPinOrPassword == null || currentPinOrPassword.isEmpty) {
            throw const AuthException(
              'يجب إدخال رمز المرور أو كلمة المرور الحالية',
              'Current PIN or password required',
            );
          }
          bool verified = false;
          if (isValidPin(currentPinOrPassword)) {
            final pinHash = await hashSecret(
              currentPinOrPassword,
              targetUser.pinSalt!,
              iterations: targetUser.kdfIterations,
            );
            verified = constantTimeEquals(pinHash, targetUser.pinHash!);
          }
          if (!verified && targetUser.hasPassword) {
            verified = await verifyPassword(
              targetUser.id,
              currentPinOrPassword,
              executor: db,
            );
          }
          if (!verified) {
            throw const AuthException(
              'رمز المرور أو كلمة المرور الحالية غير صحيحة',
              'Incorrect current PIN or password',
            );
          }
        }
      } else {
        final actorPerms = await PermissionService.instance
            .getEffectivePermissions(effectiveActor, executor: db);
        final targetPerms = await PermissionService.instance
            .getEffectivePermissions(targetUser, executor: db);

        final policy = AccessPolicy.canResetCredentials(
          actor: effectiveActor,
          target: targetUser,
          actorPermissions: actorPerms,
          targetPermissions: targetPerms,
        );

        if (!policy.isAllowed) {
          await AuditService.instance.logEvent(
            db,
            'privilege_escalation_denied',
            entityType: 'user',
            details: jsonEncode({
              'action': 'setPin',
              'actor_user_id': effectiveActor.id,
              'actor_username': effectiveActor.username,
              'target_user_id': targetUser.id,
              'target_username': targetUser.username,
              'decision': policy.decision.name,
              'reason': policy.reasonEn,
            }),
          );
          throw AuthException(policy.reasonAr, policy.reasonEn);
        }
      }
    }

    final salt = generateSalt();
    final hash = await hashSecret(newPin, salt);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'users',
      {
        'pin_hash': hash,
        'pin_salt': salt,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> _recordFailedAttempt(AppUser user, DatabaseExecutor db) async {
    final newAttempts = user.failedAttempts + 1;
    DateTime? lockedUntil;
    if (newAttempts >= 5) {
      final lockDuration = getLockoutDuration(newAttempts, isOwner: user.isOwner);
      lockedUntil = DateTime.now().add(lockDuration);
    }

    await db.update(
      'users',
      {
        'failed_attempts': newAttempts,
        'locked_until': lockedUntil?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> _recordSuccessfulLogin(AppUser user, DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'users',
      {
        'failed_attempts': 0,
        'locked_until': null,
        'last_login_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }
}

class AuthException implements Exception {
  final String messageAr;
  final String messageEn;

  const AuthException(this.messageAr, this.messageEn);

  String message(bool isArabic) => isArabic ? messageAr : messageEn;

  @override
  String toString() => messageEn;
}
