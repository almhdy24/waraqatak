import 'dart:async';
import 'session_manager.dart';

/// Exception thrown when an action is attempted without the required permission.
class PermissionDeniedException implements Exception {
  final String permissionKey;
  final String? message;

  const PermissionDeniedException(this.permissionKey, [this.message]);

  @override
  String toString() {
    if (message != null && message!.isNotEmpty) {
      return 'PermissionDeniedException: $permissionKey ($message)';
    }
    return 'PermissionDeniedException: missing permission $permissionKey';
  }
}

/// Choke-point security facade for permission checks and system execution.
abstract final class AccessGuard {
  static const Symbol _systemContextKey = #waraqatak_system_context;

  /// Returns true if currently running within a system context (e.g. background repair/migration).
  static bool get isSystemContext => Zone.current[_systemContextKey] == true;

  /// Evaluates whether the current caller is permitted to perform [permissionKey].
  ///
  /// Always returns true if:
  /// 1. Multi-user mode is disabled (single-user fast path).
  /// 2. Executing within [runAsSystem].
  /// 3. The current authenticated user is the system Owner.
  /// 4. The current user has [permissionKey] granted (role + overrides).
  static bool can(String permissionKey) {
    if (isSystemContext) return true;
    return SessionManager.instance.can(permissionKey);
  }

  /// Requires [permissionKey], throwing [PermissionDeniedException] if not authorized.
  static void require(String permissionKey, [String? message]) {
    if (!can(permissionKey)) {
      throw PermissionDeniedException(permissionKey, message);
    }
  }

  /// Runs [action] within an authoritative system zone that bypasses all permission checks.
  /// Can be used for migrations, system maintenance, internal journal backfills, and tests.
  static T runAsSystem<T>(T Function() action) {
    return runZoned(action, zoneValues: {_systemContextKey: true});
  }
}
