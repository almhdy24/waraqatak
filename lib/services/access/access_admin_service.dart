import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../database/access_dao.dart';
import '../../database/database_helper.dart';
import '../../models/app_user.dart';
import '../../models/role.dart';
import 'access_error.dart';
import 'access_guard.dart';

export 'access_error.dart' show AdminException;
import 'access_policy.dart';
import 'audit_service.dart';
import 'auth_service.dart';
import 'permission_registry.dart';
import 'permission_service.dart';
import 'session_manager.dart';

/// Localized exception thrown by [AccessAdminService] for user-friendly error display.


/// Service owning all administrative mutations to access control tables:
/// `users`, `roles`, `role_permissions`, `user_permission_overrides`.
///
/// Every mutation is:
/// 1. Guarded and verified against [AccessPolicy] and [AccessGuard].
/// 2. Atomic inside a SQLite transaction.
/// 3. Attributed and recorded in the tamper-evident [audit_log].
/// 4. Cache-invalidating via [PermissionService.invalidateCache].
class AccessAdminService {
  AccessAdminService._();
  static final AccessAdminService instance = AccessAdminService._();

  AppUser _resolveActor(AppUser? explicitActor) {
    if (AccessGuard.isSystemContext) {
      return AppUser(
        id: 'system',
        workspaceId: AccessDao.defaultWorkspaceId,
        username: 'system',
        displayName: 'system',
        roleId: AccessDao.ownerRoleId,
        isOwner: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final actor = explicitActor ?? SessionManager.instance.currentUser;
    if (actor == null) {
      throw const AdminException(
        AccessErrorCode.unauthenticated,
        debugMessage: 'Unauthorized: session is not authenticated',
      );
    }
    return actor;
  }

  // ===========================================================================
  // READ HELPERS
  // ===========================================================================

  /// Fetches all users ordered by Owner first, active status, then display name.
  Future<List<AppUser>> getUsers({DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'users',
      orderBy: 'is_owner DESC, is_active DESC, display_name ASC',
    );
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  /// Fetches a user by ID.
  Future<AppUser?> getUserById(String id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  /// Fetches all roles ordered by system roles first, then name.
  Future<List<Role>> getRoles({DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'roles',
      orderBy: 'is_system DESC, name ASC',
    );
    return rows.map((r) => Role.fromMap(r)).toList();
  }

  /// Fetches permission keys granted to [roleId].
  Future<Set<String>> getRolePermissions(
    String roleId, {
    DatabaseExecutor? executor,
  }) async {
    if (roleId == AccessDao.ownerRoleId) {
      return PermissionRegistry.allKeys;
    }
    final db = executor ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'role_permissions',
      columns: ['permission_key'],
      where: 'role_id = ?',
      whereArgs: [roleId],
    );
    return rows
        .map((r) => r['permission_key'] as String)
        .where((k) => PermissionRegistry.get(k) != null)
        .toSet();
  }

  /// Fetches user permission overrides map (permissionKey -> 'allow' | 'deny').
  Future<Map<String, String>> getUserOverrides(
    String userId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final rows = await db.query(
      'user_permission_overrides',
      columns: ['permission_key', 'effect'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final map = <String, String>{};
    for (final r in rows) {
      final key = r['permission_key'] as String;
      final raw = r['effect']?.toString().toLowerCase().trim() ?? '';
      if (raw == 'allow' || raw == '1' || raw == 'true') {
        map[key] = 'allow';
      } else if (raw == 'deny' || raw == '0' || raw == 'false') {
        map[key] = 'deny';
      }
    }
    return map;
  }

  /// Returns count of users assigned to [roleId].
  Future<int> getAssignedUsersCount(
    String roleId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users WHERE role_id = ?',
      [roleId],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // ===========================================================================
  // USER WRITES
  // ===========================================================================

  /// Creates a new non-owner application user.
  Future<AppUser> createUser({
    AppUser? actor,
    required String username,
    required String displayName,
    required String roleId,
    required String password,
    String? pin,
    Map<String, String>? overrides,
    bool isActive = true,
    Database? db,
  }) async {
    final effectiveActor = _resolveActor(actor);
    final trimmedUsername = username.trim();
    final trimmedDisplayName = displayName.trim();

    if (trimmedUsername.length < 3 ||
        trimmedUsername.length > 32 ||
        !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(trimmedUsername)) {
      throw const AdminException(
        AccessErrorCode.usernameInvalid,
        debugMessage: 'Username must be 3-32 characters of [a-zA-Z0-9._-]',
      );
    }
    if (trimmedDisplayName.isEmpty) {
      throw const AdminException(
        AccessErrorCode.displayNameRequired,
        debugMessage: 'Display name is required',
      );
    }
    if (!AuthService.isValidPassword(password)) {
      throw const AdminException(
        AccessErrorCode.passwordTooShort,
        debugMessage: 'Password must be at least 6 characters',
      );
    }
    if (pin != null && pin.trim().isNotEmpty && !AuthService.isValidPin(pin.trim())) {
      throw const AdminException(
        AccessErrorCode.pinInvalid,
        debugMessage: 'PIN must be 4 to 8 digits',
      );
    }

    final database = db ?? await DatabaseHelper.instance.database;

    // 1. Fetch role and permissions
    final roleRows = await database.query('roles', where: 'id = ?', whereArgs: [roleId], limit: 1);
    if (roleRows.isEmpty) {
      throw const AdminException(
        AccessErrorCode.roleNotFound,
        debugMessage: 'Selected role does not exist',
      );
    }
    final targetRole = Role.fromMap(roleRows.first);
    final targetRolePerms = await getRolePermissions(roleId, executor: database);

    // 2. Policy check
    final actorPerms = await PermissionService.instance
        .getEffectivePermissions(effectiveActor, executor: database);

    final assignCheck = AccessPolicy.canAssignRole(
      actor: effectiveActor,
      role: targetRole,
      rolePermissions: targetRolePerms,
      actorPermissions: actorPerms,
    );
    if (!assignCheck.isAllowed) {
      await _auditEscalation(
        database,
        action: 'createUser.assignRole',
        actor: effectiveActor,
        targetUsername: trimmedUsername,
        policy: assignCheck,
      );
      throw AdminException(
        assignCheck.decision ?? AccessErrorCode.unexpected,
        permissionKey: assignCheck.permissionKey,
        debugMessage: assignCheck.debugReason,
      );
    }

    // 3. Check overrides policy
    final sanitizedOverrides = <String, String>{};
    if (overrides != null) {
      for (final entry in overrides.entries) {
        final key = entry.key;
        final effect = entry.value.toLowerCase().trim();
        if (effect != 'allow' && effect != 'deny') continue;

        if (effect == 'allow') {
          final grantCheck = AccessPolicy.canGrantPermission(
            actor: effectiveActor,
            permissionKey: key,
            actorPermissions: actorPerms,
          );
          if (!grantCheck.isAllowed) {
            await _auditEscalation(
              database,
              action: 'createUser.grantOverride',
              actor: effectiveActor,
              targetUsername: trimmedUsername,
              policy: grantCheck,
            );
            throw AdminException(
          grantCheck.decision ?? AccessErrorCode.unexpected,
          permissionKey: grantCheck.permissionKey,
          debugMessage: grantCheck.debugReason,
        );
          }
        }
        sanitizedOverrides[key] = effect;
      }
    }

    // 4. Crypto derivation
    final iterations = await AuthService.instance.getOrCalibrateIterations(database);
    final passwordSalt = AuthService.instance.generateSalt();
    final passwordHash = await AuthService.instance.hashSecret(
      password,
      passwordSalt,
      iterations: iterations,
    );

    String? pinSalt;
    String? pinHash;
    if (pin != null && pin.trim().isNotEmpty) {
      pinSalt = AuthService.instance.generateSalt();
      pinHash = await AuthService.instance.hashSecret(
        pin.trim(),
        pinSalt,
        iterations: iterations,
      );
    }

    final now = DateTime.now().toIso8601String();
    final newUserId = 'usr-${DateTime.now().millisecondsSinceEpoch}';

    // 5. Transactional execution
    late final AppUser createdUser;
    await database.transaction((txn) async {
      // Check username uniqueness
      final existing = await txn.query(
        'users',
        columns: ['id'],
        where: 'username = ? COLLATE NOCASE',
        whereArgs: [trimmedUsername],
      );
      if (existing.isNotEmpty) {
        throw const AdminException(
          AccessErrorCode.usernameTaken,
          debugMessage: 'Username already taken',
        );
      }

      final userMap = <String, dynamic>{
        'id': newUserId,
        'workspace_id': AccessDao.defaultWorkspaceId,
        'username': trimmedUsername,
        'display_name': trimmedDisplayName,
        'role_id': roleId,
        'password_hash': passwordHash,
        'password_salt': passwordSalt,
        'pin_hash': pinHash,
        'pin_salt': pinSalt,
        'kdf_iterations': iterations,
        'is_owner': 0,
        'is_active': isActive ? 1 : 0,
        'setup_complete': 1,
        'failed_attempts': 0,
        'created_at': now,
        'updated_at': now,
      };

      await txn.insert('users', userMap);

      for (final entry in sanitizedOverrides.entries) {
        await txn.insert('user_permission_overrides', {
          'user_id': newUserId,
          'permission_key': entry.key,
          'effect': entry.value,
        });
      }

      await AuditService.instance.logEvent(
        txn,
        'user_created',
        entityType: 'user',
        details: jsonEncode({
          'user_id': newUserId,
          'username': trimmedUsername,
          'display_name': trimmedDisplayName,
          'role_id': roleId,
          'is_active': isActive,
          'overrides_count': sanitizedOverrides.length,
        }),
      );

      createdUser = AppUser.fromMap(userMap);
    });

    PermissionService.instance.invalidateCache(newUserId);
    return createdUser;
  }

  /// Updates properties of an existing user.
  Future<AppUser> updateUser({
    AppUser? actor,
    required String userId,
    String? username,
    String? displayName,
    String? roleId,
    bool? isActive,
    String? newPassword,
    String? newPin,
    String? currentPassword,
    Map<String, String>? overrides,
    Database? db,
  }) async {
    final effectiveActor = _resolveActor(actor);
    final database = db ?? await DatabaseHelper.instance.database;

    final targetRows = await database.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (targetRows.isEmpty) {
      throw const AdminException(
        AccessErrorCode.userNotFound,
        debugMessage: 'User not found',
      );
    }
    final targetUser = AppUser.fromMap(targetRows.first);

    final actorPerms = await PermissionService.instance
        .getEffectivePermissions(effectiveActor, executor: database);
    final targetPerms = await PermissionService.instance
        .getEffectivePermissions(targetUser, executor: database);

    // 1. Check canEditUser
    final editCheck = AccessPolicy.canEditUser(
      actor: effectiveActor,
      target: targetUser,
      actorPermissions: actorPerms,
      targetPermissions: targetPerms,
    );
    if (!editCheck.isAllowed) {
      await _auditEscalation(
        database,
        action: 'updateUser.canEditUser',
        actor: effectiveActor,
        targetUsername: targetUser.username,
        policy: editCheck,
      );
      throw AdminException(
        editCheck.decision ?? AccessErrorCode.unexpected,
        permissionKey: editCheck.permissionKey,
        debugMessage: editCheck.debugReason,
      );
    }

    // 2. Owner immutability constraints
    if (targetUser.isOwner) {
      if (username != null && username.trim() != targetUser.username) {
        throw const AdminException(
          AccessErrorCode.ownerUsernameImmutable,
          debugMessage: 'Cannot change Owner username',
        );
      }
      if (roleId != null && roleId != targetUser.roleId) {
        throw const AdminException(
          AccessErrorCode.ownerRoleImmutable,
          debugMessage: 'Cannot change Owner role',
        );
      }
      if (isActive != null && !isActive) {
        throw const AdminException(
          AccessErrorCode.ownerCannotBeDisabled,
          debugMessage: 'Cannot disable Owner account',
        );
      }
    }

    // 3. If role is changing, check canAssignRole
    if (roleId != null && roleId != targetUser.roleId) {
      final newRoleRows = await database.query('roles', where: 'id = ?', whereArgs: [roleId], limit: 1);
      if (newRoleRows.isEmpty) {
        throw const AdminException(
        AccessErrorCode.roleNotFound,
        debugMessage: 'Selected role does not exist',
      );
      }
      final newRole = Role.fromMap(newRoleRows.first);
      final newRolePerms = await getRolePermissions(roleId, executor: database);

      final assignCheck = AccessPolicy.canAssignRole(
        actor: effectiveActor,
        role: newRole,
        rolePermissions: newRolePerms,
        actorPermissions: actorPerms,
      );
      if (!assignCheck.isAllowed) {
        await _auditEscalation(
          database,
          action: 'updateUser.assignRole',
          actor: effectiveActor,
          targetUsername: targetUser.username,
          policy: assignCheck,
        );
        throw AdminException(
        assignCheck.decision ?? AccessErrorCode.unexpected,
        permissionKey: assignCheck.permissionKey,
        debugMessage: assignCheck.debugReason,
      );
      }
    }

    // 4. If isActive is changing, check canDisableUser
    if (isActive != null && isActive != targetUser.isActive) {
      final disableCheck = AccessPolicy.canDisableUser(
        actor: effectiveActor,
        target: targetUser,
        actorPermissions: actorPerms,
        targetPermissions: targetPerms,
      );
      if (!disableCheck.isAllowed) {
        await _auditEscalation(
          database,
          action: 'updateUser.disableUser',
          actor: effectiveActor,
          targetUsername: targetUser.username,
          policy: disableCheck,
        );
        throw AdminException(
        disableCheck.decision ?? AccessErrorCode.unexpected,
        permissionKey: disableCheck.permissionKey,
        debugMessage: disableCheck.debugReason,
      );
      }
    }

    // 5. Validate and hash credentials if provided
    final targetIterations = targetUser.kdfIterations > 0
        ? targetUser.kdfIterations
        : await AuthService.instance.getOrCalibrateIterations(database);

    String? newPasswordHash;
    String? newPasswordSalt;
    if (newPassword != null && newPassword.isNotEmpty) {
      if (!AuthService.isValidPassword(newPassword)) {
        throw const AdminException(
          AccessErrorCode.passwordTooShort,
          debugMessage: 'Password must be at least 6 characters',
        );
      }
      // If self change, verify current password
      if (effectiveActor.id == targetUser.id && targetUser.hasPassword) {
        if (currentPassword == null || currentPassword.isEmpty) {
          throw const AdminException(
            AccessErrorCode.selfCredentialRequiresCurrentSecret,
            debugMessage: 'Current password required',
          );
        }
        final verified = await AuthService.instance.verifyPassword(
          targetUser.id,
          currentPassword,
          executor: database,
        );
        if (!verified) {
          throw const AdminException(
            AccessErrorCode.wrongCurrentPassword,
            debugMessage: 'Incorrect current password',
          );
        }
      } else if (effectiveActor.id != targetUser.id) {
        final credCheck = AccessPolicy.canResetCredentials(
          actor: effectiveActor,
          target: targetUser,
          actorPermissions: actorPerms,
          targetPermissions: targetPerms,
        );
        if (!credCheck.isAllowed) {
          await _auditEscalation(
            database,
            action: 'updateUser.resetPassword',
            actor: effectiveActor,
            targetUsername: targetUser.username,
            policy: credCheck,
          );
          throw AdminException(
            credCheck.decision ?? AccessErrorCode.unexpected,
            permissionKey: credCheck.permissionKey,
            debugMessage: credCheck.debugReason,
          );
        }
      }

      newPasswordSalt = AuthService.instance.generateSalt();
      newPasswordHash = await AuthService.instance.hashSecret(
        newPassword,
        newPasswordSalt,
        iterations: targetIterations,
      );
    }

    String? newPinHash;
    String? newPinSalt;
    if (newPin != null && newPin.trim().isNotEmpty) {
      if (!AuthService.isValidPin(newPin.trim())) {
        throw const AdminException(
          AccessErrorCode.pinInvalid,
          debugMessage: 'PIN must be 4 to 8 digits',
        );
      }

      // If self change, enforce canChangeOwnPin
      if (effectiveActor.id == targetUser.id) {
        bool currentSecretVerified = false;
        if (!targetUser.hasPassword && !targetUser.hasPin) {
          currentSecretVerified = true;
        } else if (currentPassword != null && currentPassword.isNotEmpty) {
          if (targetUser.hasPassword) {
            currentSecretVerified = await AuthService.instance.verifyPassword(
              targetUser.id,
              currentPassword,
              executor: database,
            );
          }
          if (!currentSecretVerified && targetUser.hasPin) {
            currentSecretVerified = await AuthService.instance.verifyPin(
              targetUser.id,
              currentPassword,
              executor: database,
            );
          }
        }

        final pinCheck = AccessPolicy.canChangeOwnPin(
          actor: effectiveActor,
          target: targetUser,
          currentPinOrPasswordVerified: currentSecretVerified,
        );
        if (!pinCheck.isAllowed) {
          await _auditEscalation(
            database,
            action: 'updateUser.canChangeOwnPin',
            actor: effectiveActor,
            targetUsername: targetUser.username,
            policy: pinCheck,
          );
          throw AdminException(
            pinCheck.decision ?? AccessErrorCode.selfCredentialRequiresCurrentSecret,
            debugMessage: pinCheck.debugReason,
          );
        }
      } else {
        final credCheck = AccessPolicy.canResetCredentials(
          actor: effectiveActor,
          target: targetUser,
          actorPermissions: actorPerms,
          targetPermissions: targetPerms,
        );
        if (!credCheck.isAllowed) {
          await _auditEscalation(
            database,
            action: 'updateUser.resetPin',
            actor: effectiveActor,
            targetUsername: targetUser.username,
            policy: credCheck,
          );
          throw AdminException(
            credCheck.decision ?? AccessErrorCode.unexpected,
            permissionKey: credCheck.permissionKey,
            debugMessage: credCheck.debugReason,
          );
        }
      }

      newPinSalt = AuthService.instance.generateSalt();
      newPinHash = await AuthService.instance.hashSecret(
        newPin.trim(),
        newPinSalt,
        iterations: targetIterations,
      );
    }

    // 6. Check overrides (Self-edit must NOT touch overrides - C4)
    Map<String, String>? sanitizedOverrides;
    final isSelf = effectiveActor.id == targetUser.id;
    if (overrides != null && !targetUser.isOwner && !isSelf) {
      sanitizedOverrides = {};
      for (final entry in overrides.entries) {
        final key = entry.key;
        final effect = entry.value.toLowerCase().trim();
        if (effect != 'allow' && effect != 'deny') continue;

        if (effect == 'allow') {
          final grantCheck = AccessPolicy.canGrantPermission(
            actor: effectiveActor,
            permissionKey: key,
            actorPermissions: actorPerms,
          );
          if (!grantCheck.isAllowed) {
            await _auditEscalation(
              database,
              action: 'updateUser.grantOverride',
              actor: effectiveActor,
              targetUsername: targetUser.username,
              policy: grantCheck,
            );
            throw AdminException(
              grantCheck.decision ?? AccessErrorCode.unexpected,
              permissionKey: grantCheck.permissionKey,
              debugMessage: grantCheck.debugReason,
            );
          }
        }
        sanitizedOverrides[key] = effect;
      }
    }

    final now = DateTime.now().toIso8601String();
    final updates = <String, dynamic>{
      'updated_at': now,
    };

    if (displayName != null && displayName.trim().isNotEmpty) {
      updates['display_name'] = displayName.trim();
    }
    if (username != null && !targetUser.isOwner && !isSelf) {
      final trimmedU = username.trim();
      if (trimmedU.isNotEmpty && trimmedU != targetUser.username) {
        if (trimmedU.length < 3 ||
            trimmedU.length > 32 ||
            !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(trimmedU)) {
          throw const AdminException(
            AccessErrorCode.usernameInvalid,
            debugMessage: 'Username must be 3-32 characters of [a-zA-Z0-9._-]',
          );
        }
        updates['username'] = trimmedU;
      }
    }
    if (roleId != null && !targetUser.isOwner && !isSelf) {
      updates['role_id'] = roleId;
    }
    if (isActive != null && !targetUser.isOwner && !isSelf) {
      updates['is_active'] = isActive ? 1 : 0;
    }
    if (newPasswordHash != null) {
      updates['password_hash'] = newPasswordHash;
      updates['password_salt'] = newPasswordSalt;
      updates['setup_complete'] = 1;
    }
    if (newPinHash != null) {
      updates['pin_hash'] = newPinHash;
      updates['pin_salt'] = newPinSalt;
    }
    if (targetUser.kdfIterations <= 0) {
      updates['kdf_iterations'] = targetIterations;
    }

    final overridesToApply = isSelf ? null : sanitizedOverrides;

    late final AppUser updatedUser;
    await database.transaction((txn) async {
      // Check username collision if changed
      if (updates.containsKey('username')) {
        final existing = await txn.query(
          'users',
          columns: ['id'],
          where: 'username = ? COLLATE NOCASE AND id != ?',
          whereArgs: [updates['username'], userId],
        );
        if (existing.isNotEmpty) {
          throw const AdminException(
            AccessErrorCode.usernameTaken,
            debugMessage: 'Username already taken',
          );
        }
      }

      await txn.update('users', updates, where: 'id = ?', whereArgs: [userId]);

      if (overridesToApply != null) {
        await txn.delete(
          'user_permission_overrides',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        for (final entry in overridesToApply.entries) {
          await txn.insert('user_permission_overrides', {
            'user_id': userId,
            'permission_key': entry.key,
            'effect': entry.value,
          });
        }
      }

      await AuditService.instance.logEvent(
        txn,
        'user_updated',
        entityType: 'user',
        details: jsonEncode({
          'user_id': userId,
          'target_username': targetUser.username,
          'updated_fields': updates.keys.toList(),
          if (overridesToApply != null) 'overrides_count': overridesToApply.length,
        }),
      );

      final fresh = await txn.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
      updatedUser = AppUser.fromMap(fresh.first);
    });

    PermissionService.instance.invalidateCache(userId);
    return updatedUser;
  }

  /// Soft-deactivates or activates a user. Users are never hard-deleted (F3).
  Future<void> setUserActive({
    AppUser? actor,
    required String userId,
    required bool isActive,
    Database? db,
  }) async {
    await updateUser(
      actor: actor,
      userId: userId,
      isActive: isActive,
      db: db,
    );
  }

  /// Owner-initiated unlock of a locked-out user (C11).
  /// Resets `failed_attempts` and `locked_until`, audited as `user_unlocked`.
  Future<void> unlockUser(
    String userId, {
    AppUser? actor,
    DatabaseExecutor? executor,
  }) async {
    final effectiveActor = _resolveActor(actor);
    final db = executor ?? await DatabaseHelper.instance.database;

    final targetRows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (targetRows.isEmpty) {
      throw const AdminException(
        AccessErrorCode.userNotFound,
        debugMessage: 'User not found',
      );
    }
    final targetUser = AppUser.fromMap(targetRows.first);

    final actorPerms = await PermissionService.instance
        .getEffectivePermissions(effectiveActor, executor: db);
    final targetPerms = await PermissionService.instance
        .getEffectivePermissions(targetUser, executor: db);

    final policy = AccessPolicy.canEditUser(
      actor: effectiveActor,
      target: targetUser,
      actorPermissions: actorPerms,
      targetPermissions: targetPerms,
    );
    if (!policy.isAllowed) {
      await _auditEscalation(
        db,
        action: 'unlockUser',
        actor: effectiveActor,
        targetUsername: targetUser.username,
        policy: policy,
      );
      throw AdminException(
        policy.decision ?? AccessErrorCode.unexpected,
        permissionKey: policy.permissionKey,
        debugMessage: policy.debugReason,
      );
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      'users',
      {
        'failed_attempts': 0,
        'locked_until': null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );

    await AuditService.instance.logEvent(
      db,
      'user_unlocked',
      entityType: 'user',
      entityId: int.tryParse(userId),
      details: jsonEncode({
        'target_user_id': userId,
        'target_username': targetUser.username,
        'unlocked_by': effectiveActor.username,
      }),
    );
  }

  // ===========================================================================
  // ROLE WRITES
  // ===========================================================================

  /// Creates a new custom role with atomic permissions insertion.
  Future<Role> createRole({
    AppUser? actor,
    required String name,
    String? description,
    required Set<String> permissions,
    Database? db,
  }) async {
    final effectiveActor = _resolveActor(actor);
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const AdminException(
        AccessErrorCode.roleNameRequired,
        debugMessage: 'Role name is required',
      );
    }

    final database = db ?? await DatabaseHelper.instance.database;
    final actorPerms = await PermissionService.instance
        .getEffectivePermissions(effectiveActor, executor: database);

    final roleId = 'role-custom-${DateTime.now().millisecondsSinceEpoch}';
    final customRole = Role(
      id: roleId,
      workspaceId: AccessDao.defaultWorkspaceId,
      name: trimmedName,
      description: description?.trim(),
      isSystem: false,
      isTemplate: false,
    );

    // Filter out unknown and OWNER_ONLY keys
    final sanitizedPerms = permissions
        .where((k) => PermissionRegistry.get(k) != null)
        .toSet()
        .difference(AccessPolicy.ownerOnlyKeys);

    final editCheck = AccessPolicy.canEditRole(
      actor: effectiveActor,
      role: customRole,
      rolePermissions: sanitizedPerms,
      actorPermissions: actorPerms,
    );
    if (!editCheck.isAllowed) {
      await _auditEscalation(
        database,
        action: 'createRole',
        actor: effectiveActor,
        targetUsername: trimmedName,
        policy: editCheck,
      );
      throw AdminException(
        editCheck.decision ?? AccessErrorCode.unexpected,
        permissionKey: editCheck.permissionKey,
        debugMessage: editCheck.debugReason,
      );
    }

    await database.transaction((txn) async {
      await txn.insert('roles', {
        'id': roleId,
        'workspace_id': AccessDao.defaultWorkspaceId,
        'name': trimmedName,
        'description': description?.trim(),
        'is_system': 0,
        'is_template': 0,
      });

      for (final pKey in sanitizedPerms) {
        await txn.insert('role_permissions', {
          'role_id': roleId,
          'permission_key': pKey,
        });
      }

      await AuditService.instance.logEvent(
        txn,
        'role_created',
        entityType: 'role',
        details: jsonEncode({
          'role_id': roleId,
          'name': trimmedName,
          'permissions_count': sanitizedPerms.length,
        }),
      );
    });

    PermissionService.instance.invalidateCache();
    return customRole;
  }

  /// Updates a custom role and atomically replaces its permissions.
  Future<Role> updateRole({
    AppUser? actor,
    required String roleId,
    required String name,
    String? description,
    required Set<String> permissions,
    Database? db,
  }) async {
    final effectiveActor = _resolveActor(actor);
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const AdminException(
        AccessErrorCode.roleNameRequired,
        debugMessage: 'Role name is required',
      );
    }

    final database = db ?? await DatabaseHelper.instance.database;
    final roleRows = await database.query('roles', where: 'id = ?', whereArgs: [roleId], limit: 1);
    if (roleRows.isEmpty) {
      throw const AdminException(
        AccessErrorCode.roleNotFound,
        debugMessage: 'Role not found',
      );
    }
    final existingRole = Role.fromMap(roleRows.first);

    final actorPerms = await PermissionService.instance
        .getEffectivePermissions(effectiveActor, executor: database);

    // Filter out unknown and OWNER_ONLY keys
    final sanitizedPerms = permissions
        .where((k) => PermissionRegistry.get(k) != null)
        .toSet()
        .difference(AccessPolicy.ownerOnlyKeys);

    final editCheck = AccessPolicy.canEditRole(
      actor: effectiveActor,
      role: existingRole,
      rolePermissions: sanitizedPerms,
      actorPermissions: actorPerms,
    );
    if (!editCheck.isAllowed) {
      await _auditEscalation(
        database,
        action: 'updateRole',
        actor: effectiveActor,
        targetUsername: existingRole.name,
        policy: editCheck,
      );
      throw AdminException(
        editCheck.decision ?? AccessErrorCode.unexpected,
        permissionKey: editCheck.permissionKey,
        debugMessage: editCheck.debugReason,
      );
    }

    await database.transaction((txn) async {
      await txn.update(
        'roles',
        {
          'name': trimmedName,
          'description': description?.trim(),
        },
        where: 'id = ?',
        whereArgs: [roleId],
      );

      // Atomic delete + insert within transaction
      await txn.delete(
        'role_permissions',
        where: 'role_id = ?',
        whereArgs: [roleId],
      );

      for (final pKey in sanitizedPerms) {
        await txn.insert('role_permissions', {
          'role_id': roleId,
          'permission_key': pKey,
        });
      }

      await AuditService.instance.logEvent(
        txn,
        'role_updated',
        entityType: 'role',
        details: jsonEncode({
          'role_id': roleId,
          'name': trimmedName,
          'permissions_count': sanitizedPerms.length,
        }),
      );
    });

    PermissionService.instance.invalidateCache();
    return existingRole.copyWith(
      name: trimmedName,
      description: description?.trim(),
    );
  }

  /// Duplicates an existing role into a new custom role.
  Future<Role> duplicateRole({
    AppUser? actor,
    required String sourceRoleId,
    required String newName,
    Database? db,
  }) async {
    final perms = await getRolePermissions(sourceRoleId, executor: db);
    return createRole(
      actor: actor,
      name: newName,
      description: 'Copy of role',
      permissions: perms,
      db: db,
    );
  }

  /// Deletes a custom role if not in use by any users.
  Future<void> deleteRole({
    AppUser? actor,
    required String roleId,
    Database? db,
  }) async {
    final effectiveActor = _resolveActor(actor);
    final database = db ?? await DatabaseHelper.instance.database;

    final roleRows = await database.query('roles', where: 'id = ?', whereArgs: [roleId], limit: 1);
    if (roleRows.isEmpty) {
      throw const AdminException(
        AccessErrorCode.roleNotFound,
        debugMessage: 'Role not found',
      );
    }
    final existingRole = Role.fromMap(roleRows.first);

    final assignedCount = await getAssignedUsersCount(roleId, executor: database);
    final actorPerms = await PermissionService.instance
        .getEffectivePermissions(effectiveActor, executor: database);
    final rolePerms = await getRolePermissions(roleId, executor: database);

    final deleteCheck = AccessPolicy.canDeleteRole(
      actor: effectiveActor,
      role: existingRole,
      rolePermissions: rolePerms,
      actorPermissions: actorPerms,
      assignedUsersCount: assignedCount,
    );
    if (!deleteCheck.isAllowed) {
      await _auditEscalation(
        database,
        action: 'deleteRole',
        actor: effectiveActor,
        targetUsername: existingRole.name,
        policy: deleteCheck,
      );
      throw AdminException(
        deleteCheck.decision ?? AccessErrorCode.unexpected,
        permissionKey: deleteCheck.permissionKey,
        debugMessage: deleteCheck.debugReason,
      );
    }

    await database.transaction((txn) async {
      await txn.delete(
        'role_permissions',
        where: 'role_id = ?',
        whereArgs: [roleId],
      );
      await txn.delete(
        'roles',
        where: 'id = ?',
        whereArgs: [roleId],
      );

      await AuditService.instance.logEvent(
        txn,
        'role_deleted',
        entityType: 'role',
        details: jsonEncode({
          'role_id': roleId,
          'name': existingRole.name,
        }),
      );
    });

    PermissionService.instance.invalidateCache();
  }

  // ===========================================================================
  // AUDIT HELPER
  // ===========================================================================

  static Future<void> _auditEscalation(
    DatabaseExecutor db, {
    required String action,
    required AppUser actor,
    required String targetUsername,
    required PolicyResult policy,
  }) async {
    try {
      await AuditService.instance.logEvent(
        db,
        'privilege_escalation_denied',
        entityType: 'security',
        details: jsonEncode({
          'action': action,
          'actor_user_id': actor.id,
          'actor_username': actor.username,
          'target': targetUsername,
          'decision': policy.decision?.name,
          'reason': policy.debugReason,
        }),
      );
    } catch (_) {}
  }
}
