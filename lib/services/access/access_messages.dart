import 'package:sqflite/sqflite.dart';
import '../../localization/app_localizations.dart';
import 'access_error.dart';
import 'permission_registry.dart';

/// Formats duration as mm:ss (Western Arabic numerals, LTR).
String formatDurationMmSs(Duration d) {
  final totalSeconds = d.inSeconds;
  if (totalSeconds <= 0) return '00:00';
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Resolves user-friendly localized permission name.
/// If [key] is unknown or unregistered, returns generic fallback text.
String localizedPermissionName(AppLocalizations l10n, String key) {
  if (PermissionRegistry.allKeys.contains(key)) {
    final name = l10n.permissionName(key);
    if (name.isNotEmpty && name != l10n.accessGenericPermission) {
      return name;
    }
  }
  return l10n.accessGenericPermission;
}

/// Resolves user-friendly localized role name.
/// For built-in system and template roles, returns localized label.
/// For custom roles, returns stored name.
String localizedRoleName(AppLocalizations l10n, String roleId, String rawName) {
  switch (roleId) {
    case 'role-owner':
      return l10n.roleOwner_name;
    case 'role-template-salesperson':
      return l10n.roleTemplate_salesperson_name;
    case 'role-template-inventory':
      return l10n.roleTemplate_inventory_name;
    case 'role-template-accountant':
      return l10n.roleTemplate_accountant_name;
    case 'role-template-manager':
      return l10n.roleTemplate_manager_name;
    default:
      return rawName;
  }
}

/// Resolves user-friendly localized role description.
String localizedRoleDescription(
  AppLocalizations l10n,
  String roleId,
  String? rawDescription,
) {
  switch (roleId) {
    case 'role-owner':
      return l10n.roleOwner_desc;
    case 'role-template-salesperson':
      return l10n.roleTemplate_salesperson_desc;
    case 'role-template-inventory':
      return l10n.roleTemplate_inventory_desc;
    case 'role-template-accountant':
      return l10n.roleTemplate_accountant_desc;
    case 'role-template-manager':
      return l10n.roleTemplate_manager_desc;
    default:
      return rawDescription ?? '';
  }
}

/// Resolves user-friendly localized actor name for audit logs.
String localizedActorName(AppLocalizations l10n, String rawName) {
  switch (rawName) {
    case 'system':
    case '\u0627\u0644\u0646\u0638\u0627\u0645':
      return l10n.actorSystem;
    case 'unauthenticated':
    case '\u063a\u064a\u0631 \u0645\u0633\u062c\u0644':
      return l10n.actorUnauthenticated;
    case 'owner':
    case '\u0627\u0644\u0645\u0627\u0644\u0643':
      return l10n.actorOwner;
    default:
      return rawName;
  }
}

/// Maps [code] and parameters to a user-facing localized string.
String localizeAccessError(
  AppLocalizations l10n,
  AccessErrorCode code, {
  String? permissionKey,
  Map<String, Object?> args = const {},
}) {
  String formatDuration(Object? raw) {
    if (raw is Duration) return formatDurationMmSs(raw);
    if (raw is int) return formatDurationMmSs(Duration(seconds: raw));
    if (raw is String) return raw;
    return '00:00';
  }

  switch (code) {
    case AccessErrorCode.unauthenticated:
      return l10n.errUnauthenticated;
    case AccessErrorCode.sessionLocked:
      return l10n.errSessionLocked;
    case AccessErrorCode.missingPermission:
      final perm = permissionKey ?? args['permissionKey'] as String?;
      if (perm != null && perm.isNotEmpty) {
        return l10n.accessDeniedMissingPerm(
          localizedPermissionName(l10n, perm),
        );
      }
      return l10n.accessDeniedMissingPerm(l10n.accessGenericPermission);
    case AccessErrorCode.ownerOnly:
      return l10n.errOwnerOnly;
    case AccessErrorCode.targetIsOwner:
      return l10n.errTargetIsOwner;
    case AccessErrorCode.targetIsPeerOrSuperior:
      return l10n.errTargetIsPeerOrSuperior;
    case AccessErrorCode.targetHasPermissionsActorLacks:
      return l10n.errTargetHasPermissionsActorLacks;
    case AccessErrorCode.assignRoleWithUnheldPermissions:
      return l10n.errAssignRoleWithUnheldPermissions;
    case AccessErrorCode.grantUnheldPermission:
      return l10n.errGrantUnheldPermission;
    case AccessErrorCode.editRoleWithUnheldPermissions:
      return l10n.errEditRoleWithUnheldPermissions;
    case AccessErrorCode.editOwnRole:
      return l10n.errEditOwnRole;
    case AccessErrorCode.changeOwnRole:
      return l10n.errChangeOwnRole;
    case AccessErrorCode.changeOwnActiveStatus:
      return l10n.errChangeOwnActiveStatus;
    case AccessErrorCode.createOwner:
      return l10n.errCreateOwner;
    case AccessErrorCode.deleteSystemRole:
      return l10n.errDeleteSystemRole;
    case AccessErrorCode.roleInUse:
      return l10n.errRoleInUse;
    case AccessErrorCode.selfCredentialRequiresCurrentSecret:
      return l10n.errSelfCredentialRequiresCurrentSecret;
    case AccessErrorCode.usernameRequired:
      return l10n.errUsernameRequired;
    case AccessErrorCode.displayNameRequired:
      return l10n.errDisplayNameRequired;
    case AccessErrorCode.usernameTaken:
      return l10n.errUsernameTaken;
    case AccessErrorCode.usernameInvalid:
      return l10n.errUsernameInvalid;
    case AccessErrorCode.passwordTooShort:
      return l10n.errPasswordTooShort;
    case AccessErrorCode.passwordsMismatch:
      return l10n.errPasswordsMismatch;
    case AccessErrorCode.pinInvalid:
      return l10n.errPinInvalid;
    case AccessErrorCode.roleNotFound:
      return l10n.errRoleNotFound;
    case AccessErrorCode.userNotFound:
      return l10n.errUserNotFound;
    case AccessErrorCode.userDisabled:
      return l10n.errUserDisabled;
    case AccessErrorCode.accountLocked:
      return l10n.errAccountLocked(formatDuration(args['duration']));
    case AccessErrorCode.deviceThrottled:
      return l10n.errDeviceThrottled(formatDuration(args['duration']));
    case AccessErrorCode.noPasswordSet:
      return l10n.errNoPasswordSet;
    case AccessErrorCode.noPinSet:
      return l10n.errNoPinSet;
    case AccessErrorCode.wrongPassword:
      return l10n.errWrongPassword;
    case AccessErrorCode.wrongPin:
      return l10n.errWrongPin;
    case AccessErrorCode.wrongCurrentPassword:
      return l10n.errWrongCurrentPassword;
    case AccessErrorCode.wrongCurrentSecret:
      return l10n.errWrongCurrentSecret;
    case AccessErrorCode.recoveryCodeInvalid:
      return l10n.errRecoveryCodeInvalid;
    case AccessErrorCode.recoveryLocked:
      return l10n.errRecoveryLocked(formatDuration(args['duration']));
    case AccessErrorCode.ownerCannotBeDisabled:
      return l10n.errOwnerCannotBeDisabled;
    case AccessErrorCode.ownerUsernameImmutable:
      return l10n.errOwnerUsernameImmutable;
    case AccessErrorCode.ownerRoleImmutable:
      return l10n.errOwnerRoleImmutable;
    case AccessErrorCode.undeclaredScreen:
      return l10n.errUndeclaredScreen;
    case AccessErrorCode.multiUserDisableOwnerOnly:
      return l10n.errMultiUserDisableOwnerOnly;
    case AccessErrorCode.noActiveOwner:
      return l10n.errNoActiveOwner;
    case AccessErrorCode.roleNameRequired:
      return l10n.errRoleNameRequired;
    case AccessErrorCode.unexpected:
      return l10n.errUnexpected;
  }
}

/// Maps any exception/error to a safe, user-friendly localized message.
/// NEVER exposes [error.toString()] or system/debug details to the user.
String friendlyError(AppLocalizations l10n, Object error) {
  if (error is AccessError) {
    return localizeAccessError(
      l10n,
      error.code,
      permissionKey: error.permissionKey,
      args: error.args,
    );
  }
  if (error is StateError) {
    return l10n.errUnexpected;
  }
  if (error is DatabaseException) {
    return l10n.errUnexpected;
  }
  return l10n.errUnexpected;
}

/// Resolves localized audit action label.
/// Returns null if [action] is unrecognized, allowing the UI to display fallback.
String? localizedAuditAction(AppLocalizations l10n, String action) {
  switch (action) {
    case 'audit_chain_genesis':
      return l10n.auditActionGenesis;
    case 'user_created':
      return l10n.auditActionUserCreated;
    case 'user_updated':
      return l10n.auditActionUserUpdated;
    case 'user_unlocked':
      return l10n.auditActionUserUnlocked;
    case 'role_created':
      return l10n.auditActionRoleCreated;
    case 'role_updated':
      return l10n.auditActionRoleUpdated;
    case 'role_deleted':
      return l10n.auditActionRoleDeleted;
    case 'privilege_escalation_denied':
      return l10n.auditActionEscalationDenied;
    case 'recovery_failed':
      return l10n.auditActionRecoveryFailed;
    case 'recovery_completed':
      return l10n.auditActionRecoveryCompleted;
    case 'multi_user_enabled':
      return l10n.auditActionMultiUserEnabled;
    case 'multi_user_disabled':
      return l10n.auditActionMultiUserDisabled;
    case 'user_logout':
      return l10n.auditActionUserLogout;
    case 'user_login':
      return l10n.auditActionUserLogin;
    case 'login_failed':
      return l10n.auditActionLoginFailed;
    case 'session_locked':
      return l10n.auditActionSessionLocked;
    case 'sensitive_action_reauth':
      return l10n.auditActionSensitiveReauth;
    default:
      return null;
  }
}

/// Resolves localized key for structured audit details.
String localizedAuditDetailKey(AppLocalizations l10n, String key) {
  switch (key) {
    case 'user_id':
    case 'target_user_id':
      return l10n.auditDetailUserId;
    case 'username':
    case 'target_username':
      return l10n.auditDetailUsername;
    case 'display_name':
      return l10n.auditDetailDisplayName;
    case 'role_id':
      return l10n.auditDetailRole;
    case 'permissions_count':
      return l10n.auditDetailPermissionsCount;
    case 'updated_fields':
      return l10n.auditDetailUpdatedFields;
    case 'action':
      return l10n.auditDetailAction;
    case 'decision':
      return l10n.auditDetailDecision;
    case 'reason':
      return l10n.auditDetailReason;
    case 'actor_username':
    case 'actor_user_id':
      return l10n.auditDetailActor;
    case 'failed_attempts':
      return l10n.auditDetailFailedAttempts;
    default:
      return key.replaceAll('_', ' ');
  }
}

