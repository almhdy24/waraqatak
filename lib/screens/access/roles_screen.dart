import 'package:flutter/material.dart';
import '../../database/access_dao.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/role.dart';
import '../../services/access/access_guard.dart';
import '../../services/access/permission_registry.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<Role> _roles = [];
  Map<String, Set<String>> _rolePerms = {};
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
      final rows = await db.query(
        'roles',
        orderBy: 'is_system DESC, name ASC',
      );
      final roles = rows.map((r) => Role.fromMap(r)).toList();

      final permRows = await db.query('role_permissions');
      final permsMap = <String, Set<String>>{};
      for (final pr in permRows) {
        final rId = pr['role_id'] as String;
        final pKey = pr['permission_key'] as String;
        permsMap.putIfAbsent(rId, () => {}).add(pKey);
      }

      if (!mounted) return;
      setState(() {
        _roles = roles;
        _rolePerms = permsMap;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openRoleEditor({Role? role}) async {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isNew = role == null;
    final isOwnerRole = role?.id == AccessDao.ownerRoleId;
    final isSystem = role?.isSystem == true;

    final nameCtrl = TextEditingController(text: role?.name ?? '');
    final descCtrl = TextEditingController(text: role?.description ?? '');
    final Set<String> selectedPerms = Set<String>.from(
      isOwnerRole ? PermissionRegistry.allKeys : (_rolePerms[role?.id] ?? {}),
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final byGroup = PermissionRegistry.byGroup;

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(isNew
                      ? l10n.addRole
                      : (isSystem
                          ? '${role.name} (${l10n.isSystemRole})'
                          : l10n.editRole)),
                  actions: [
                    if (!isSystem)
                      TextButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            AppSnackBar.show(ctx, l10n.required,
                                severity: AppSnackBarSeverity.error);
                            return;
                          }
                          try {
                            final db = await DatabaseHelper.instance.database;
                            final now = DateTime.now().toIso8601String();
                            final roleId = role?.id ??
                                'role-custom-${DateTime.now().millisecondsSinceEpoch}';

                            if (isNew) {
                              AccessGuard.require(PermissionRegistry.rolesManage);
                              await db.insert('roles', {
                                'id': roleId,
                                'workspace_id': AccessDao.defaultWorkspaceId,
                                'name': nameCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                                'is_system': 0,
                                'is_template': 0,
                                'created_at': now,
                                'updated_at': now,
                              });
                            } else {
                              AccessGuard.require(PermissionRegistry.rolesManage);
                              await db.update(
                                'roles',
                                {
                                  'name': nameCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'updated_at': now,
                                },
                                where: 'id = ?',
                                whereArgs: [roleId],
                              );
                            }

                            // Update role_permissions
                            await db.delete(
                              'role_permissions',
                              where: 'role_id = ?',
                              whereArgs: [roleId],
                            );
                            for (final pKey in selectedPerms) {
                              await db.insert('role_permissions', {
                                'role_id': roleId,
                                'permission_key': pKey,
                              });
                            }

                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (ctx.mounted) {
                              AppSnackBar.show(ctx, e.toString(),
                                  severity: AppSnackBarSeverity.error);
                            }
                          }
                        },
                        child: Text(l10n.save),
                      ),
                  ],
                ),
                body: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (!isSystem) ...[
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.roleName,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.roleDescription,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      if (role?.description != null)
                        Text(
                          role!.description!,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      l10n.rolesAndPermissions,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    for (final groupEntry in byGroup.entries)
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.6)),
                        ),
                        child: ExpansionTile(
                          title: Text(
                            groupEntry.key.label(l10n.isArabic),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          children: groupEntry.value.map((item) {
                            final checked = isOwnerRole || selectedPerms.contains(item.key);
                            return CheckboxListTile(
                              title: Text(
                                item.name(l10n.isArabic),
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(item.key,
                                  style: TextStyle(
                                      fontSize: 11, color: cs.outline)),
                              value: checked,
                              enabled: !isSystem && !isOwnerRole,
                              onChanged: (isSystem || isOwnerRole)
                                  ? null
                                  : (v) {
                                      setSheetState(() {
                                        if (v == true) {
                                          selectedPerms.add(item.key);
                                        } else {
                                          selectedPerms.remove(item.key);
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    if (saved == true) _load();
  }

  Future<void> _handleDeleteRole(Role role) async {
    if (role.isSystem) return;
    final l10n = AppLocalizations.of(context);

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.confirmDelete,
      message: '${l10n.confirmDelete}: ${role.name}',
      confirmLabel: l10n.delete,
      isDestructive: true,
    );

    if (confirmed && mounted) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('roles', where: 'id = ?', whereArgs: [role.id]);
      await db.delete('role_permissions', where: 'role_id = ?', whereArgs: [role.id]);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final canManageRoles = AccessGuard.can(PermissionRegistry.rolesManage);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rolesAndPermissions),
        centerTitle: true,
      ),
      body: ResponsiveCenter(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _roles.length,
                itemBuilder: (ctx, i) {
                  final role = _roles[i];
                  final isOwnerRole = role.id == AccessDao.ownerRoleId;
                  final permCount = isOwnerRole
                      ? PermissionRegistry.allKeys.length
                      : (_rolePerms[role.id]?.length ?? 0);

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: role.isSystem
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        child: Icon(
                          isOwnerRole
                              ? Icons.shield_rounded
                              : Icons.admin_panel_settings_outlined,
                          color: role.isSystem
                              ? cs.onPrimaryContainer
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        role.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isOwnerRole
                            ? l10n.isSystemRole
                            : (role.description?.isNotEmpty == true
                                ? role.description!
                                : '$permCount ${l10n.rolesAndPermissions}'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!role.isSystem && canManageRoles)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: l10n.delete,
                              onPressed: () => _handleDeleteRole(role),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => _openRoleEditor(role: role),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: canManageRoles
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add_moderator_outlined),
              label: Text(l10n.addRole),
              onPressed: () => _openRoleEditor(),
            )
          : null,
    );
  }
}
