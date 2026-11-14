import '../../models/app_user.dart';
import '../../models/role.dart';
import 'access_error.dart';
import 'permission_registry.dart';

/// Result of evaluating an [AccessPolicy] rule.
class PolicyResult {
  final bool isAllowed;
  final AccessErrorCode? decision;
  final String? permissionKey;
  final String debugReason;

  const PolicyResult.allow()
      : isAllowed = true,
        decision = null,
        permissionKey = null,
        debugReason = '';

  const PolicyResult.deny(
    AccessErrorCode this.decision,
    this.debugReason, {
    this.permissionKey,
  }) : isAllowed = false;

  @override
  String toString() => isAllowed
      ? 'PolicyResult.allow'
      : 'PolicyResult.deny($decision: $debugReason)';
}

abstract final class AccessPolicy {
  /// Keys that are strictly restricted to the system Owner and can never be
  /// granted to any other user or role (H1).
  static const Set<String> ownerOnlyKeys = {
    PermissionRegistry.licenseManage,
    PermissionRegistry.systemRepair,
    PermissionRegistry.backupRestore,
  };

  /// Privileged administrative keys that are delegable by the Owner but
  /// subject to strict delegation hierarchy rules (H3).
  static const Set<String> privilegedKeys = {
    PermissionRegistry.usersManage,
    PermissionRegistry.rolesManage,
  };

  /// Returns true if [key] is an OWNER_ONLY permission key.
  static bool isOwnerOnly(String key) => ownerOnlyKeys.contains(key);

  /// Returns true if [key] is a privileged permission key.
  static bool isPrivileged(String key) => privilegedKeys.contains(key);

  /// Asserts whether [actor] can view [target] user details and profile.
  static PolicyResult canViewUser({
    required AppUser actor,
    required AppUser target,
    required Set<String> actorPermissions,
    required Set<String> targetPermissions,
  }) {
    if (actor.isOwner) return const PolicyResult.allow();
    if (actor.id == target.id) return const PolicyResult.allow();

    if (!actorPermissions.contains(PermissionRegistry.usersManage)) {
      return const PolicyResult.deny(
        AccessErrorCode.missingPermission,
        'Missing users.manage permission',
      );
    }

    // A non-owner delegate cannot view or inspect the Owner account
    if (target.isOwner) {
      return const PolicyResult.deny(
        AccessErrorCode.targetIsOwner,
        'Delegates cannot view or manage the Owner account',
      );
    }

    // A delegate cannot manage peers/superiors who hold privileged keys
    final targetHasPrivileged =
        targetPermissions.intersection(privilegedKeys).isNotEmpty;
    if (targetHasPrivileged) {
      return const PolicyResult.deny(
        AccessErrorCode.targetIsPeerOrSuperior,
        'Cannot manage peer or superior administrative users',
      );
    }

    // A delegate cannot manage users holding permissions the delegate lacks
    final unheld = targetPermissions.difference(actorPermissions);
    if (unheld.isNotEmpty) {
      return const PolicyResult.deny(
        AccessErrorCode.targetHasPermissionsActorLacks,
        'Cannot manage user possessing permissions you lack',
      );
    }

    return const PolicyResult.allow();
  }

  /// Asserts whether [actor] can edit [target] user properties (H2, H3, H4).
  static PolicyResult canEditUser({
    required AppUser actor,
    required AppUser target,
    required Set<String> actorPermissions,
    required Set<String> targetPermissions,
  }) {
    if (actor.isOwner) return const PolicyResult.allow();

    // Target is Owner: blocked for everyone except the Owner themselves
    if (target.isOwner) {
      return const PolicyResult.deny(
        AccessErrorCode.targetIsOwner,
        'The Owner account is protected and can only be modified by the Owner',
      );
    }

    // Self-edit is governed by self-service rules (canChangeOwn...)
    if (actor.id == target.id) {
      return const PolicyResult.allow();
    }

    // Must have users.manage
    if (!actorPermissions.contains(PermissionRegistry.usersManage)) {
      return const PolicyResult.deny(
        AccessErrorCode.missingPermission,
        'Missing users.manage permission',
      );
    }

    // Peer / superior check
    final targetHasPrivileged =
        targetPermissions.intersection(privilegedKeys).isNotEmpty;
    if (targetHasPrivileged) {
      return const PolicyResult.deny(
        AccessErrorCode.targetIsPeerOrSuperior,
        'Cannot edit peer or superior administrative users',
      );
    }

    // Unheld permissions check
    final unheld = targetPermissions.difference(actorPermissions);
    if (unheld.isNotEmpty) {
      return const PolicyResult.deny(
        AccessErrorCode.targetHasPermissionsActorLacks,
        'Cannot edit user possessing permissions you lack',
      );
    }

    return const PolicyResult.allow();
  }

  /// Asserts whether [actor] can reset [target]'s credentials (password or PIN).
  static PolicyResult canResetCredentials({
    required AppUser actor,
    required AppUser target,
    required Set<String> actorPermissions,
    required Set<String> targetPermissions,
  }) {
    if (actor.isOwner) return const PolicyResult.allow();

    // Owner credentials can NEVER be reset by a delegate
    if (target.isOwner) {
      return const PolicyResult.deny(
        AccessErrorCode.targetIsOwner,
        'Owner credentials cannot be reset by another user',
      );
    }

    // Self credentials require current credentials verification
    if (actor.id == target.id) {
      return const PolicyResult.allow();
    }

    return canEditUser(
      actor: actor,
      target: target,
      actorPermissions: actorPermissions,
      targetPermissions: targetPermissions,
    );
  }

  /// Asserts whether [actor] can disable [target] user account.
  static PolicyResult canDisableUser({
    required AppUser actor,
    required AppUser target,
    required Set<String> actorPermissions,
    required Set<String> targetPermissions,
  }) {
    if (target.isOwner) {
      return const PolicyResult.deny(
        AccessErrorCode.targetIsOwner,
        'Cannot disable the Owner account',
      );
    }

    if (actor.id == target.id) {
      return const PolicyResult.deny(
        AccessErrorCode.changeOwnActiveStatus,
        'Cannot disable your own account',
      );
    }

    return canEditUser(
      actor: actor,
      target: target,
      actorPermissions: actorPermissions,
      targetPermissions: targetPermissions,
    );
  }

  /// Asserts whether [actor] can assign [role] to a user.
  static PolicyResult canAssignRole({
    required AppUser actor,
    required Role role,
    required Set<String> rolePermissions,
    required Set<String> actorPermissions,
  }) {
    if (actor.isOwner) return const PolicyResult.allow();

    // Non-owner cannot assign Owner role or create an Owner
    if (role.isSystem || role.id == 'role-owner') {
      return const PolicyResult.deny(
        AccessErrorCode.createOwner,
        'Cannot assign Owner or system roles',
      );
    }

    if (!actorPermissions.contains(PermissionRegistry.usersManage)) {
      return const PolicyResult.deny(
        AccessErrorCode.missingPermission,
        'Missing users.manage permission',
      );
    }

    // Role cannot contain OWNER_ONLY keys
    final containsOwnerOnly =
        rolePermissions.intersection(ownerOnlyKeys).isNotEmpty;
    if (containsOwnerOnly) {
      return const PolicyResult.deny(
        AccessErrorCode.ownerOnly,
        'This role contains OWNER_ONLY permissions',
      );
    }

    // Role permissions must be a strict subset of delegate's permissions
    final unheld = rolePermissions.difference(actorPermissions);
    if (unheld.isNotEmpty) {
      return const PolicyResult.deny(
        AccessErrorCode.assignRoleWithUnheldPermissions,
        'Cannot assign role granting permissions you do not possess',
      );
    }

    return const PolicyResult.allow();
  }

  /// Asserts whether [actor] can grant [permissionKey] as a user override.
  static PolicyResult canGrantPermission({
    required AppUser actor,
    required String permissionKey,
    required Set<String> actorPermissions,
  }) {
    if (actor.isOwner) return const PolicyResult.allow();

    if (isOwnerOnly(permissionKey)) {
      return PolicyResult.deny(
        AccessErrorCode.ownerOnly,
        'This permission is strictly OWNER_ONLY and cannot be granted',
        permissionKey: permissionKey,
      );
    }

    if (!actorPermissions.contains(PermissionRegistry.usersManage)) {
      return const PolicyResult.deny(
        AccessErrorCode.missingPermission,
        'Missing users.manage permission',
        permissionKey: PermissionRegistry.usersManage,
      );
    }

    if (!actorPermissions.contains(permissionKey)) {
      return PolicyResult.deny(
        AccessErrorCode.grantUnheldPermission,
        'Cannot grant a permission you do not possess',
        permissionKey: permissionKey,
      );
    }

    return const PolicyResult.allow();
  }

  /// Asserts whether [actor] can create or edit [role].
  static PolicyResult canEditRole({
    required AppUser actor,
    required Role role,
    required Set<String> rolePermissions,
    required Set<String> actorPermissions,
  }) {
    if (actor.isOwner) return const PolicyResult.allow();

    if (role.isSystem || role.id == 'role-owner') {
      return const PolicyResult.deny(
        AccessErrorCode.deleteSystemRole,
        'Cannot modify protected system roles',
      );
    }

    if (!actorPermissions.contains(PermissionRegistry.rolesManage)) {
      return const PolicyResult.deny(
        AccessErrorCode.missingPermission,
        'Missing roles.manage permission',
      );
    }

    // Cannot edit the role currently assigned to actor
    if (actor.roleId == role.id) {
      return const PolicyResult.deny(
        AccessErrorCode.editOwnRole,
        'Cannot edit the role assigned to yourself',
      );
    }

    // Role cannot include OWNER_ONLY keys
    final containsOwnerOnly =
        rolePermissions.intersection(ownerOnlyKeys).isNotEmpty;
    if (containsOwnerOnly) {
      return const PolicyResult.deny(
        AccessErrorCode.ownerOnly,
        'Cannot add OWNER_ONLY permissions to roles',
      );
    }

    // Role permissions must be a subset of delegate's permissions
    final unheld = rolePermissions.difference(actorPermissions);
    if (unheld.isNotEmpty) {
      return const PolicyResult.deny(
        AccessErrorCode.editRoleWithUnheldPermissions,
        'Cannot edit role containing permissions you lack',
      );
    }

    return const PolicyResult.allow();
  }

  /// Asserts whether [actor] can delete [role].
  static PolicyResult canDeleteRole({
    required AppUser actor,
    required Role role,
    required Set<String> rolePermissions,
    required Set<String> actorPermissions,
    required int assignedUsersCount,
  }) {
    if (role.isSystem || role.id == 'role-owner') {
      return const PolicyResult.deny(
        AccessErrorCode.deleteSystemRole,
        'Cannot delete core system roles',
      );
    }

    if (assignedUsersCount > 0) {
      return const PolicyResult.deny(
        AccessErrorCode.roleInUse,
        'Cannot delete role while assigned to active users',
      );
    }

    return canEditRole(
      actor: actor,
      role: role,
      rolePermissions: rolePermissions,
      actorPermissions: actorPermissions,
    );
  }

  /// Asserts whether [actor] can change their own display name (H4).
  static PolicyResult canChangeOwnDisplayName({
    required AppUser actor,
    required AppUser target,
  }) {
    if (actor.id == target.id) return const PolicyResult.allow();
    return const PolicyResult.deny(
        AccessErrorCode.missingPermission,
        'Cannot change display name of another user via self-service',
      );
  }

  /// Asserts whether [actor] can change their own password (H4).
  static PolicyResult canChangeOwnPassword({
    required AppUser actor,
    required AppUser target,
    required bool currentPasswordVerified,
  }) {
    if (actor.id != target.id) {
      return const PolicyResult.deny(
        AccessErrorCode.missingPermission,
        'Self password change applies only to own account',
      );
    }
    if (!currentPasswordVerified) {
      return const PolicyResult.deny(
        AccessErrorCode.selfCredentialRequiresCurrentSecret,
        'Current password required to change password',
      );
    }
    return const PolicyResult.allow();
  }

  /// Asserts whether [actor] can change their own PIN (H4).
  static PolicyResult canChangeOwnPin({
    required AppUser actor,
    required AppUser target,
    required bool currentPinOrPasswordVerified,
  }) {
    if (actor.id != target.id) {
      return const PolicyResult.deny(
        AccessErrorCode.missingPermission,
        'Self PIN change applies only to own account',
      );
    }
    if (!currentPinOrPasswordVerified) {
      return const PolicyResult.deny(
        AccessErrorCode.selfCredentialRequiresCurrentSecret,
        'Current PIN or password required to change PIN',
      );
    }
    return const PolicyResult.allow();
  }
}
