import '../../models/app_user.dart';
import '../../models/role.dart';
import 'permission_registry.dart';

/// Policy decisions and reason codes for granular authorization decisions.
enum PolicyDecision {
  allow,
  deniedOwnerOnly,
  deniedTargetIsOwner,
  deniedTargetIsPeerOrSuperior,
  deniedTargetHasPermissionsActorLacks,
  deniedAssignRoleWithUnheldPermissions,
  deniedGrantUnheldPermission,
  deniedEditRoleWithUnheldPermissions,
  deniedEditOwnRole,
  deniedChangeOwnRole,
  deniedChangeOwnActiveStatus,
  deniedCreateOwner,
  deniedDeleteSystemRole,
  deniedRoleInUse,
  deniedMissingPermission,
  deniedSelfCredentialChangeRequiresCurrentSecret,
  deniedUnauthenticated,
}

/// Result of evaluating an [AccessPolicy] rule.
class PolicyResult {
  final bool isAllowed;
  final PolicyDecision decision;
  final String reasonAr;
  final String reasonEn;

  const PolicyResult.allow()
      : isAllowed = true,
        decision = PolicyDecision.allow,
        reasonAr = '',
        reasonEn = '';

  const PolicyResult.deny(this.decision, this.reasonAr, this.reasonEn)
      : isAllowed = false;

  String reason(bool isArabic) => isArabic ? reasonAr : reasonEn;

  @override
  String toString() => isAllowed
      ? 'PolicyResult.allow'
      : 'PolicyResult.deny($decision: $reasonEn)';
}

/// Pure, unit-testable service implementing Waraqatak Privilege Hierarchy (H1–H4).
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
        PolicyDecision.deniedMissingPermission,
        'لا تملك صلاحية إدارة المستخدمين',
        'Missing users.manage permission',
      );
    }

    // A non-owner delegate cannot view or inspect the Owner account
    if (target.isOwner) {
      return const PolicyResult.deny(
        PolicyDecision.deniedTargetIsOwner,
        'لا يمكن للمفوض عرض أو إدارة حساب المالك',
        'Delegates cannot view or manage the Owner account',
      );
    }

    // A delegate cannot manage peers/superiors who hold privileged keys
    final targetHasPrivileged =
        targetPermissions.intersection(privilegedKeys).isNotEmpty;
    if (targetHasPrivileged) {
      return const PolicyResult.deny(
        PolicyDecision.deniedTargetIsPeerOrSuperior,
        'لا يمكن تعديل أو إدارة مستخدم يملك صلاحيات إدارية مماثلة أو عليا',
        'Cannot manage peer or superior administrative users',
      );
    }

    // A delegate cannot manage users holding permissions the delegate lacks
    final unheld = targetPermissions.difference(actorPermissions);
    if (unheld.isNotEmpty) {
      return const PolicyResult.deny(
        PolicyDecision.deniedTargetHasPermissionsActorLacks,
        'لا يمكن إدارة مستخدم يملك صلاحيات لا تملكها',
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
        PolicyDecision.deniedTargetIsOwner,
        'حساب المالك محمي ولا يمكن تعديله إلا بواسطة المالك نفسه',
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
        PolicyDecision.deniedMissingPermission,
        'لا تملك صلاحية إدارة المستخدمين',
        'Missing users.manage permission',
      );
    }

    // Peer / superior check
    final targetHasPrivileged =
        targetPermissions.intersection(privilegedKeys).isNotEmpty;
    if (targetHasPrivileged) {
      return const PolicyResult.deny(
        PolicyDecision.deniedTargetIsPeerOrSuperior,
        'لا يمكن تعديل مستخدم يملك صلاحيات إدارية مماثلة أو عليا',
        'Cannot edit peer or superior administrative users',
      );
    }

    // Unheld permissions check
    final unheld = targetPermissions.difference(actorPermissions);
    if (unheld.isNotEmpty) {
      return const PolicyResult.deny(
        PolicyDecision.deniedTargetHasPermissionsActorLacks,
        'لا يمكن تعديل مستخدم يملك صلاحيات لا تملكها',
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
        PolicyDecision.deniedTargetIsOwner,
        'لا يمكن إعادة تعيين بيانات اعتماد المالك من قبل أي مستخدم آخر',
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
        PolicyDecision.deniedTargetIsOwner,
        'لا يمكن تعطيل حساب المالك',
        'Cannot disable the Owner account',
      );
    }

    if (actor.id == target.id) {
      return const PolicyResult.deny(
        PolicyDecision.deniedChangeOwnActiveStatus,
        'لا يمكنك تعطيل حسابك الخاص',
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
        PolicyDecision.deniedCreateOwner,
        'لا يمكن تعيين دور المالك أو أدوار النظام',
        'Cannot assign Owner or system roles',
      );
    }

    if (!actorPermissions.contains(PermissionRegistry.usersManage)) {
      return const PolicyResult.deny(
        PolicyDecision.deniedMissingPermission,
        'لا تملك صلاحية إدارة المستخدمين',
        'Missing users.manage permission',
      );
    }

    // Role cannot contain OWNER_ONLY keys
    final containsOwnerOnly =
        rolePermissions.intersection(ownerOnlyKeys).isNotEmpty;
    if (containsOwnerOnly) {
      return const PolicyResult.deny(
        PolicyDecision.deniedOwnerOnly,
        'هذا الدور يحتوي على صلاحيات مقتصرة حصرياً على المالك',
        'This role contains OWNER_ONLY permissions',
      );
    }

    // Role permissions must be a strict subset of delegate's permissions
    final unheld = rolePermissions.difference(actorPermissions);
    if (unheld.isNotEmpty) {
      return const PolicyResult.deny(
        PolicyDecision.deniedAssignRoleWithUnheldPermissions,
        'لا يمكن تعيين دور يحتوي على صلاحيات لا تملكها بنفسك',
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
      return const PolicyResult.deny(
        PolicyDecision.deniedOwnerOnly,
        'هذه الصلاحية مقتصرة حصرياً على المالك ولا يمكن منحها',
        'This permission is strictly OWNER_ONLY and cannot be granted',
      );
    }

    if (!actorPermissions.contains(PermissionRegistry.usersManage)) {
      return const PolicyResult.deny(
        PolicyDecision.deniedMissingPermission,
        'لا تملك صلاحية إدارة المستخدمين',
        'Missing users.manage permission',
      );
    }

    if (!actorPermissions.contains(permissionKey)) {
      return const PolicyResult.deny(
        PolicyDecision.deniedGrantUnheldPermission,
        'لا يمكنك منح صلاحية لا تملكها بنفسك',
        'Cannot grant a permission you do not possess',
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
        PolicyDecision.deniedDeleteSystemRole,
        'لا يمكن تعديل أدوار النظام المحمية',
        'Cannot modify protected system roles',
      );
    }

    if (!actorPermissions.contains(PermissionRegistry.rolesManage)) {
      return const PolicyResult.deny(
        PolicyDecision.deniedMissingPermission,
        'لا تملك صلاحية إدارة الأدوار',
        'Missing roles.manage permission',
      );
    }

    // Cannot edit the role currently assigned to actor
    if (actor.roleId == role.id) {
      return const PolicyResult.deny(
        PolicyDecision.deniedEditOwnRole,
        'لا يمكنك تعديل الدور المعين لحسابك الخاص',
        'Cannot edit the role assigned to yourself',
      );
    }

    // Role cannot include OWNER_ONLY keys
    final containsOwnerOnly =
        rolePermissions.intersection(ownerOnlyKeys).isNotEmpty;
    if (containsOwnerOnly) {
      return const PolicyResult.deny(
        PolicyDecision.deniedOwnerOnly,
        'لا يمكن إضافة صلاحيات مقتصرة على المالك للأدوار',
        'Cannot add OWNER_ONLY permissions to roles',
      );
    }

    // Role permissions must be a subset of delegate's permissions
    final unheld = rolePermissions.difference(actorPermissions);
    if (unheld.isNotEmpty) {
      return const PolicyResult.deny(
        PolicyDecision.deniedEditRoleWithUnheldPermissions,
        'لا يمكنك تعديل دور يحتوي على صلاحيات لا تملكها',
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
        PolicyDecision.deniedDeleteSystemRole,
        'لا يمكن حذف أدوار النظام الأساسية',
        'Cannot delete core system roles',
      );
    }

    if (assignedUsersCount > 0) {
      return const PolicyResult.deny(
        PolicyDecision.deniedRoleInUse,
        'لا يمكن حذف الدور وهو معين لمستخدمين حاليين',
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
      PolicyDecision.deniedMissingPermission,
      'لا يمكنك تعديل الاسم التعريفي لمستخدم آخر عبر الخدمة الذاتية',
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
        PolicyDecision.deniedMissingPermission,
        'تغيير كلمة المرور الذاتية ينطبق فقط على الحساب الشخصي',
        'Self password change applies only to own account',
      );
    }
    if (!currentPasswordVerified) {
      return const PolicyResult.deny(
        PolicyDecision.deniedSelfCredentialChangeRequiresCurrentSecret,
        'يجب إدخال كلمة المرور الحالية لتغيير كلمة المرور',
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
        PolicyDecision.deniedMissingPermission,
        'تغيير رمز المرور الذاتي ينطبق فقط على الحساب الشخصي',
        'Self PIN change applies only to own account',
      );
    }
    if (!currentPinOrPasswordVerified) {
      return const PolicyResult.deny(
        PolicyDecision.deniedSelfCredentialChangeRequiresCurrentSecret,
        'يجب إدخال رمز المرور أو كلمة المرور الحالية لتغيير رمز المرور',
        'Current PIN or password required to change PIN',
      );
    }
    return const PolicyResult.allow();
  }
}
