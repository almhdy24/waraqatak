import '../../database/access_dao.dart';
import 'access_guard.dart';
import 'audit_service.dart';
import 'session_manager.dart';

/// Authoritative helper providing caller attribution context for writes.
abstract final class AccessContext {
  /// Returns current authenticated user ID, 'system' in system context,
  /// 'unauthenticated' when unauthenticated/locked in multi-user mode,
  /// or Owner ID in single-user mode.
  static String get currentUserId {
    if (AccessGuard.isSystemContext) return 'system';
    final session = SessionManager.instance;
    if (session.isMultiUserEnabled) {
      if (session.isLocked || session.currentUser == null) {
        return 'unauthenticated';
      }
      return session.currentUser!.id;
    }
    return session.currentUser?.id ?? AccessDao.ownerUserId;
  }

  /// Returns current caller's display name.
  static String get currentUserName {
    if (AccessGuard.isSystemContext) return 'النظام';
    final session = SessionManager.instance;
    if (session.isMultiUserEnabled) {
      if (session.isLocked || session.currentUser == null) {
        return 'غير مسجل';
      }
      return session.currentUser!.displayName;
    }
    return session.currentUser?.displayName ?? 'المالك';
  }

  /// Returns current origin device ID.
  static String get currentDeviceId => AuditService.instance.currentDeviceId;
}
