/// Typed error codes and structured exceptions for granular access control and authentication.
library;

enum AccessErrorCode {
  unauthenticated,
  sessionLocked,
  missingPermission,
  ownerOnly,
  targetIsOwner,
  targetIsPeerOrSuperior,
  targetHasPermissionsActorLacks,
  assignRoleWithUnheldPermissions,
  grantUnheldPermission,
  editRoleWithUnheldPermissions,
  editOwnRole,
  changeOwnRole,
  changeOwnActiveStatus,
  createOwner,
  deleteSystemRole,
  roleInUse,
  selfCredentialRequiresCurrentSecret,
  usernameRequired,
  displayNameRequired,
  usernameTaken,
  usernameInvalid,
  passwordTooShort,
  passwordsMismatch,
  pinInvalid,
  roleNotFound,
  userNotFound,
  userDisabled,
  accountLocked,
  deviceThrottled,
  noPasswordSet,
  noPinSet,
  wrongPassword,
  wrongPin,
  wrongCurrentPassword,
  wrongCurrentSecret,
  recoveryCodeInvalid,
  recoveryLocked,
  ownerCannotBeDisabled,
  ownerUsernameImmutable,
  ownerRoleImmutable,
  undeclaredScreen,
  multiUserDisableOwnerOnly,
  noActiveOwner,
  roleNameRequired,
  unexpected;
}

/// Base structured exception representing access control and authentication failures.
class AccessError implements Exception {
  final AccessErrorCode code;
  final Map<String, Object?> args;
  final String? permissionKey;
  final String debugMessage;

  const AccessError(
    this.code, {
    this.args = const {},
    this.permissionKey,
    this.debugMessage = '',
  });

  @override
  String toString() {
    if (debugMessage.isNotEmpty) {
      return 'AccessError($code, debugMessage: $debugMessage)';
    }
    return 'AccessError($code)';
  }
}

/// Exception thrown by administrative user and role operations.
class AdminException extends AccessError {
  const AdminException(
    super.code, {
    super.args = const {},
    super.permissionKey,
    super.debugMessage = '',
  });

  @override
  String toString() {
    if (debugMessage.isNotEmpty) {
      return 'AdminException($code: $debugMessage)';
    }
    return 'AdminException($code)';
  }
}

/// Exception thrown by authentication and credential operations.
class AuthException extends AccessError {
  const AuthException(
    super.code, {
    super.args = const {},
    super.permissionKey,
    super.debugMessage = '',
  });

  @override
  String toString() {
    if (debugMessage.isNotEmpty) {
      return 'AuthException($code: $debugMessage)';
    }
    return 'AuthException($code)';
  }
}

/// Exception thrown when an action or screen is attempted without the required permission.
class PermissionDeniedException extends AccessError {
  const PermissionDeniedException(
    String permissionKey, [
    String? message,
  ]) : super(
          AccessErrorCode.missingPermission,
          permissionKey: permissionKey,
          debugMessage: message ?? 'Missing permission: $permissionKey',
        );

  const PermissionDeniedException.withCode(
    super.code, {
    super.args = const {},
    super.permissionKey,
    super.debugMessage = '',
  });

  @override
  String toString() {
    if (debugMessage.isNotEmpty) {
      return 'PermissionDeniedException($permissionKey, $code: $debugMessage)';
    }
    return 'PermissionDeniedException($permissionKey, $code)';
  }
}
