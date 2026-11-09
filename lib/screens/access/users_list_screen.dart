import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../models/app_user.dart';
import '../../services/access/access_admin_service.dart';
import '../../services/access/access_guard.dart';
import '../../services/access/permission_registry.dart';
import '../../services/access/session_manager.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/access/sensitive_action_gate.dart';
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
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rolesList = await AccessAdminService.instance.getRoles();
      final roles = {
        for (final r in rolesList) r.id: r.name,
      };

      final users = await AccessAdminService.instance.getUsers();

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
    if (SessionManager.instance.isMultiUserEnabled &&
        !SessionManager.instance.isOwnerSession) {
      return;
    }
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

  Future<void> _confirmLogout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.logoutConfirmTitle,
      message: l10n.logoutConfirmMessage,
      confirmLabel: l10n.logout,
      cancelLabel: l10n.cancel,
      isDestructive: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed) {
      await SessionManager.instance.logout();
    }
  }

  Future<void> _toggleMultiUserMode() async {
    final l10n = AppLocalizations.of(context);
    final isEnabled = SessionManager.instance.isMultiUserEnabled;

    if (isEnabled) {
      if (!SessionManager.instance.isOwnerSession) {
        AppSnackBar.show(
          context,
          l10n.isArabic
              ? 'فقط المالك يمكنه تعطيل وضع تعدد المستخدمين'
              : 'Only the Owner can disable multi-user mode',
          severity: AppSnackBarSeverity.error,
        );
        return;
      }

      // Sensitive action re-auth gate
      final reauthed = await SensitiveActionGate.reauthenticate(
        context,
        title: l10n.isArabic ? 'تعطيل وضع تعدد المستخدمين' : 'Disable Multi-User Mode',
        message: l10n.isArabic
            ? 'يتطلب تعطيل وضع تعدد المستخدمين تأكيد كلمة مرور المالك لحماية بيانات المتجر.'
            : 'Disabling multi-user mode requires confirming the Owner password.',
        requireOwner: true,
      );
      if (!reauthed || !mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.disableMultiUserButton),
          content: Text(
            l10n.isArabic
                ? 'هل أنت متأكد من رغبتك في تعطيل وضع تعدد المستخدمين والعودة لنمط المستخدم الفردي؟'
                : 'Are you sure you want to disable multi-user mode and return to single-user mode?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.isArabic ? 'تعطيل' : 'Disable'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        try {
          await SessionManager.instance.setMultiUserEnabled(false);
          if (mounted) {
            AppSnackBar.show(
              context,
              l10n.isArabic
                  ? 'تم تعطيل وضع تعدد المستخدمين بنجاح'
                  : 'Multi-user mode disabled successfully',
            );
            _load();
          }
        } catch (e) {
          if (!mounted) return;
          AppSnackBar.show(context, e.toString(), severity: AppSnackBarSeverity.error);
        }
      }
    } else {
      final enabled = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const MultiUserWizardScreen()),
      );
      if (enabled == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isMultiUser = SessionManager.instance.isMultiUserEnabled;
    final canManageUsers = isMultiUser &&
        (SessionManager.instance.isOwnerSession ||
            AccessGuard.can(PermissionRegistry.usersManage));
    final canManageRoles = isMultiUser &&
        (SessionManager.instance.isOwnerSession ||
            AccessGuard.can(PermissionRegistry.rolesManage));
    final canViewAudit = isMultiUser &&
        (SessionManager.instance.isOwnerSession ||
            AccessGuard.can(PermissionRegistry.auditView));

    final filteredUsers = _users.where((u) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.displayName.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          (_roleNames[u.roleId]?.toLowerCase().contains(q) ?? false);
    }).toList();

    return ScreenAccessGate(
      screenType: UsersListScreen,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.isArabic ? 'بحث عن مستخدم...' : 'Search user...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                )
              : Text(l10n.users),
          actions: [
            if (isMultiUser) ...[
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                tooltip: _isSearching ? l10n.cancel : (l10n.isArabic ? 'بحث' : 'Search'),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      _isSearching = false;
                      _searchQuery = '';
                      _searchCtrl.clear();
                    } else {
                      _isSearching = true;
                    }
                  });
                },
              ),
              if (canManageRoles)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  tooltip: l10n.isArabic ? 'الأدوار والصلحيات' : 'Roles & Permissions',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RolesScreen()),
                  ),
                ),
              if (canViewAudit)
                IconButton(
                  icon: const Icon(Icons.history_edu_outlined),
                  tooltip: l10n.auditTrail,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditTrailScreen()),
                  ),
                ),
            ],
            PopupMenuButton<String>(
              onSelected: (val) {
                switch (val) {
                  case 'auto_lock':
                    _showAutoLockDialog();
                    break;
                  case 'lock':
                    SessionManager.instance.lock();
                    break;
                  case 'logout':
                    _confirmLogout();
                    break;
                  case 'toggle':
                    _toggleMultiUserMode();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (isMultiUser) ...[
                  if (SessionManager.instance.isOwnerSession)
                    PopupMenuItem(
                      value: 'auto_lock',
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
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 20, color: cs.error),
                        const SizedBox(width: 8),
                        Text(
                          l10n.logout,
                          style: TextStyle(color: cs.error),
                        ),
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
                  : filteredUsers.isEmpty
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
                            itemCount: filteredUsers.length + (_users.length == 1 ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (_users.length == 1 && i == 0) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: cs.primary, size: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          l10n.isArabic
                                              ? 'وضع تعدد المستخدمين مفعل. يمكنك الآن إضافة كاشير أو محاسب أو مدير لتوزيع المهام بأمان.'
                                              : 'Multi-User Mode is active. Add cashiers or managers to safely delegate store operations.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: cs.onSurface,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final userIndex = (_users.length == 1 && i > 0) ? i - 1 : i;
                              final user = filteredUsers[userIndex];
                              final roleName = _roleNames[user.roleId] ?? user.roleId;
                              final isCurrent = user.id == SessionManager.instance.currentUser?.id;

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isCurrent
                                        ? cs.primary
                                        : cs.outlineVariant.withValues(alpha: 0.5),
                                    width: isCurrent ? 1.5 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: user.isOwner
                                        ? cs.primaryContainer
                                        : cs.surfaceContainerHighest,
                                    child: Icon(
                                      user.isOwner
                                          ? Icons.shield_rounded
                                          : Icons.person_outline_rounded,
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
                                            fontSize: 15,
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
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: user.isOwner
                                                ? cs.primary.withValues(alpha: 0.12)
                                                : cs.secondaryContainer.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            roleName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: user.isOwner ? cs.primary : cs.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '@${user.username}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: user.isActive ? cs.onSurfaceVariant : cs.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    final currentUser = SessionManager.instance.currentUser;
                                    final isOwnerSession = currentUser?.isOwner == true;

                                    // E1/E2 protection: non-owners cannot inspect or edit Owner account
                                    if (user.isOwner && !isOwnerSession) {
                                      AppSnackBar.show(
                                        context,
                                        l10n.isArabic
                                            ? 'حساب المالك محمي ولا يمكن تعديله إلا بواسطة المالك'
                                            : 'The Owner account is protected and can only be modified by the Owner',
                                        severity: AppSnackBarSeverity.error,
                                      );
                                      return;
                                    }

                                    // Non-owners need users.manage unless viewing their own profile
                                    final canManage = AccessGuard.can(PermissionRegistry.usersManage);
                                    final isSelf = currentUser?.id == user.id;
                                    if (!isOwnerSession && !isSelf && !canManage) {
                                      AppSnackBar.show(
                                        context,
                                        l10n.isArabic
                                            ? 'لا تملك صلاحية إدارة المستخدمين'
                                            : 'Missing users.manage permission',
                                        severity: AppSnackBarSeverity.error,
                                      );
                                      return;
                                    }

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
                icon: const Icon(Icons.person_add_rounded),
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
      ),
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
