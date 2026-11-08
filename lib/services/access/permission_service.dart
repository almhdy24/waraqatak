import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/app_user.dart';
import 'access_policy.dart';
import 'permission_registry.dart';
import 'session_manager.dart';

/// Service computing and caching effective user permissions.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  final Map<String, Set<String>> _cache = {};

  /// Invalidates the permission cache for [userId] (or all users if null).
  void invalidateCache([String? userId]) {
    if (userId == null) {
      _cache.clear();
    } else {
      _cache.remove(userId);
    }

    // If current session user is affected, refresh their cached permissions
    final current = SessionManager.instance.currentUser;
    if (current != null && (userId == null || current.id == userId)) {
      getEffectivePermissions(current).then((perms) {
        SessionManager.instance.updateCachedPermissions(perms);
      }).catchError((_) {});
    }
  }

  /// Calculates effective permissions for [user]:
  /// effective = role permissions + allow overrides - deny overrides (DENY always wins).
  ///
  /// The Owner always receives all keys in [PermissionRegistry.allKeys].
  /// Deactivated users receive an empty set.
  Future<Set<String>> getEffectivePermissions(
    AppUser user, {
    DatabaseExecutor? executor,
    bool bypassCache = false,
  }) async {
    // 1. Deactivated users have zero permissions
    if (!user.isActive) {
      return {};
    }

    // 2. System Owner holds all registry permissions unconditionally
    if (user.isOwner) {
      return PermissionRegistry.allKeys;
    }

    // 3. Cache check
    if (!bypassCache && _cache.containsKey(user.id)) {
      return _cache[user.id]!;
    }

    final db = executor ?? await DatabaseHelper.instance.database;

    // 4. Role base permissions
    final roleRows = await db.query(
      'role_permissions',
      columns: ['permission_key'],
      where: 'role_id = ?',
      whereArgs: [user.roleId],
    );
    final effective = roleRows
        .map((r) => r['permission_key'] as String)
        .where((k) => PermissionRegistry.get(k) != null)
        .toSet();

    // 5. User-level overrides
    final overrideRows = await db.query(
      'user_permission_overrides',
      columns: ['permission_key', 'effect'],
      where: 'user_id = ?',
      whereArgs: [user.id],
    );

    for (final row in overrideRows) {
      final key = row['permission_key'] as String;
      final rawEffect = row['effect'];
      final effect = rawEffect?.toString().toLowerCase().trim() ?? '';

      // Unknown keys in DB are ignored safely
      if (PermissionRegistry.get(key) == null) continue;

      if (effect == 'allow' || effect == '1' || effect == 'true') {
        effective.add(key);
      } else if (effect == 'deny' || effect == '0' || effect == 'false') {
        effective.remove(key); // DENY always wins
      }
    }

    // 6. OWNER_ONLY keys are strictly stripped for all non-Owner accounts (H1)
    if (!user.isOwner) {
      effective.removeAll(AccessPolicy.ownerOnlyKeys);
    }

    _cache[user.id] = effective;
    return effective;
  }
}
