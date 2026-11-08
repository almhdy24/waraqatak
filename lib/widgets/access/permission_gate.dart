import 'package:flutter/material.dart';
import '../../services/access/access_guard.dart';
import '../../services/access/session_manager.dart';

/// Declarative widget gating UI elements behind a required permission or Owner-only role.
///
/// In single-user mode, or when authorized, renders [child].
/// When unauthorized, renders [fallback] (defaults to [SizedBox.shrink]).
class PermissionGate extends StatelessWidget {
  final String? permission;
  final bool isOwnerOnly;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    this.permission,
    this.isOwnerOnly = false,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!SessionManager.instance.isMultiUserEnabled) {
      return child;
    }

    if (isOwnerOnly) {
      if (SessionManager.instance.currentUser?.isOwner == true) {
        return child;
      }
      return fallback ?? const SizedBox.shrink();
    }

    if (permission != null && AccessGuard.can(permission!)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}
