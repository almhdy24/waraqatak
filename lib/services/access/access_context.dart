import '../../database/access_dao.dart';
import 'access_guard.dart';
import 'audit_service.dart';
import 'session_manager.dart';

/// Authoritative helper providing caller attribution context for writes.
abstract final class AccessContext {
  /// Returns current authenticated user ID, 'system' in system context,
  /// or Owner ID in single-user mode.
  static String get currentUserId {
    if (AccessGuard.isSystemContext) return 'system';
    return SessionManager.instance.currentUser?.id ?? AccessDao.ownerUserId;
  }

  /// Returns current caller's display name.
  static String get currentUserName {
    if (AccessGuard.isSystemContext) return 'النظام';
    return SessionManager.instance.currentUser?.displayName ?? 'المالك';
  }

  /// Returns current origin device ID.
  static String get currentDeviceId => AuditService.instance.currentDeviceId;
}
