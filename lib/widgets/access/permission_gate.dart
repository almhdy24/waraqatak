import 'package:flutter/material.dart';
import '../../services/access/access_guard.dart';

/// Declarative widget gating UI elements behind a required permission.
///
/// In single-user mode, or when authorized, renders [child].
/// When unauthorized, renders [fallback] (defaults to [SizedBox.shrink]).
class PermissionGate extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (AccessGuard.can(permission)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
