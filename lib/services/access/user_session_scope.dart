import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import 'session_manager.dart';

/// Scoped inherited notifier providing access to the active [SessionManager] in the widget tree.
class UserSessionScope extends InheritedNotifier<SessionManager> {
  const UserSessionScope({
    super.key,
    required super.child,
    super.notifier,
  });

  static SessionManager of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<UserSessionScope>();
    return scope?.notifier ?? SessionManager.instance;
  }

  static AppUser? userOf(BuildContext context) => of(context).currentUser;

  static bool canOf(BuildContext context, String permissionKey) =>
      of(context).can(permissionKey);
}
