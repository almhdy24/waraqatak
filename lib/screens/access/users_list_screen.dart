import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/app_user.dart';
import '../../services/access/access_guard.dart';
import '../../services/access/permission_registry.dart';
import '../../services/access/session_manager.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';
import 'audit_trail_screen.dart';
import 'multi_user_wizard_screen.dart';
import 'roles_screen.dart';
import 'user_form_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<AppUser> _users = [];
  Map<String, String> _roleNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;

      final roleRows = await db.query('roles');
      final roles = {
        for (final r in roleRows)
          r['id'] as String: r['name'] as String,
      };

      final userRows = await db.query(
        'users',
        orderBy: 'is_owner DESC, is_active DESC, display_name ASC',
      );
      final users = userRows.map((r) => AppUser.fromMap(r)).toList();

      if (!mounted) return;
      setState(() {
        _roleNames = roles;
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showAutoLockDialog() async {
    final l10n = AppLocalizations.of(context);
    final current = SessionManager.instance.autoLockMinutes;
    final options = [0, 1, 2, 5, 10, 15, 30];

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autoLockSetting),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((m) {
            return ListTile(
              title: Text(l10n.autoLockMinutesDesc(m)),
              trailing: m == current ? const Icon(Icons.check, color: Colors.teal) : null,
              onTap: () => Navigator.pop(ctx, m),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null && mounted) {
      await SessionManager.instance.setAutoLockMinutes(selected);
      setState(() {});
    }
  }

  Future<void> _toggleMultiUserMode() async {
    final l10n = AppLocalizations.of(context);
    final isEnabled = SessionManager.instance.isMultiUserEnabled;

    if (isEnabled) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: l10n.disableMultiUserButton,
        message: l10n.disableMultiUserConfirm,
        confirmLabel: l10n.disableMultiUserButton,
        isDestructive: true,
      );
      if (confirmed) {
        await SessionManager.instance.setMultiUserEnabled(false);
        if (!mounted) return;
        AppSnackBar.show(context, l10n.disableMultiUserButton);
        Navigator.pop(context);
      }
    } else {
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const MultiUserWizardScreen()),
      );
      if (res == true && mounted) {
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isMultiUser = SessionManager.instance.isMultiUserEnabled;
    final canManageUsers = AccessGuard.can(PermissionRegistry.usersManage);
    final canManageRoles = AccessGuard.can(PermissionRegistry.rolesManage);
    final canViewAudit = AccessGuard.can(PermissionRegistry.auditView);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.usersAndPermissions),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              switch (val) {
                case 'roles':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RolesScreen()),
                  );
                  break;
                case 'audit':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditTrailScreen()),
                  );
                  break;
                case 'lock':
                  SessionManager.instance.lock();
                  break;
                case 'autolock':
                  _showAutoLockDialog();
                  break;
                case 'toggle':
                  _toggleMultiUserMode();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (canManageRoles)
                PopupMenuItem(
                  value: 'roles',
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.rolesAndPermissions),
                    ],
                  ),
                ),
              if (canViewAudit)
                PopupMenuItem(
                  value: 'audit',
                  child: Row(
                    children: [
                      const Icon(Icons.history_edu_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.auditTrail),
                    ],
                  ),
                ),
              if (isMultiUser) ...[
                PopupMenuItem(
                  value: 'autolock',
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.autoLockSetting),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'lock',
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.lockNow),
                    ],
                  ),
                ),
              ],
              if (SessionManager.instance.currentUser?.isOwner == true)
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        isMultiUser ? Icons.power_settings_new : Icons.verified_user_outlined,
                        size: 20,
                        color: isMultiUser ? cs.error : cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isMultiUser ? l10n.disableMultiUserButton : l10n.enableMultiUserButton,
                        style: TextStyle(color: isMultiUser ? cs.error : null),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !isMultiUser
                ? _buildDisabledState(l10n, cs)
                : _users.isEmpty
                    ? AppEmptyState(
                        icon: Icons.people_outline,
                        title: l10n.users,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: _users.length,
                          itemBuilder: (ctx, i) {
                            final user = _users[i];
                            final roleName = _roleNames[user.roleId] ?? user.roleId;
                            final isCurrent = user.id == SessionManager.instance.currentUser?.id;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isCurrent
                                      ? cs.primary.withValues(alpha: 0.5)
                                      : cs.outlineVariant.withValues(alpha: 0.6),
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: user.isOwner
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerHighest,
                                  child: Icon(
                                    user.isOwner
                                        ? Icons.shield_rounded
                                        : Icons.person_outline,
                                    color: user.isOwner
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user.displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: user.isActive ? null : cs.outline,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          l10n.currentActiveUser,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: cs.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    if (!user.isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.errorContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          l10n.userInactive,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onErrorContainer,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '@${user.username} • $roleName',
                                  style: TextStyle(
                                    color: user.isActive ? cs.onSurfaceVariant : cs.outline,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  final changed = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserFormScreen(user: user),
                                    ),
                                  );
                                  if (changed == true) _load();
                                },
                              ),
                            );
                          },
                        ),
                      ),
      ),
      floatingActionButton: isMultiUser && canManageUsers
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_outlined),
              label: Text(l10n.addUser),
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const UserFormScreen()),
                );
                if (added == true) _load();
              },
            )
          : null,
    );
  }

  Widget _buildDisabledState(AppLocalizations l10n, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.people_outline_rounded, size: 72, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            l10n.multiUserTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.multiUserDisabledDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(l10n.enableMultiUserButton),
            onPressed: _toggleMultiUserMode,
          ),
        ],
      ),
    );
  }
}
