import 'package:flutter/material.dart';
import '../../database/access_dao.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/role.dart';
import '../../services/access/access_guard.dart';
import '../../services/access/auth_service.dart';
import '../../services/access/permission_registry.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';

class UserFormScreen extends StatefulWidget {
  final AppUser? user;
  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _displayNameCtrl;
  final _passwordCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  List<Role> _availableRoles = [];
  String? _selectedRoleId;
  bool _isActive = true;
  bool _obscurePassword = true;
  bool _loading = true;
  bool _saving = false;

  Map<String, String> _overrides = {}; // permission_key -> 'allow' | 'deny'

  bool get _isNew => widget.user == null;
  bool get _isOwner => widget.user?.isOwner == true;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user?.username ?? '');
    _displayNameCtrl = TextEditingController(text: widget.user?.displayName ?? '');
    _isActive = widget.user?.isActive ?? true;
    _selectedRoleId = widget.user?.roleId;
    _loadData();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _passwordCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final roleRows = await db.query(
        'roles',
        where: _isOwner ? null : 'is_system = 0 OR id != ?',
        whereArgs: _isOwner ? null : [AccessDao.ownerRoleId],
        orderBy: 'name ASC',
      );
      final roles = roleRows.map((r) => Role.fromMap(r)).toList();

      if (!_isNew) {
        final overrideRows = await db.query(
          'user_permission_overrides',
          where: 'user_id = ?',
          whereArgs: [widget.user!.id],
        );
        _overrides = {
          for (final row in overrideRows)
            row['permission_key'] as String:
                (row['effect'] as int) == 1 ? 'allow' : 'deny',
        };
      }

      if (!mounted) return;
      setState(() {
        _availableRoles = roles;
        _selectedRoleId ??= roles.firstOrNull?.id;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();
      final username = _usernameCtrl.text.trim();
      final displayName = _displayNameCtrl.text.trim();

      if (_isNew) {
        // Enforce permissions
        AccessGuard.require(PermissionRegistry.usersManage);

        final userId = 'usr-${DateTime.now().millisecondsSinceEpoch}';
        final salt = AuthService.instance.generateSalt();
        final passHash = await AuthService.instance.hashSecret(_passwordCtrl.text, salt);

        final pinSalt = AuthService.instance.generateSalt();
        final pinHash = await AuthService.instance.hashSecret(_pinCtrl.text.trim(), pinSalt);

        await db.insert('users', {
          'id': userId,
          'workspace_id': AccessDao.defaultWorkspaceId,
          'username': username,
          'display_name': displayName,
          'password_hash': passHash,
          'password_salt': salt,
          'pin_hash': pinHash,
          'pin_salt': pinSalt,
          'role_id': _selectedRoleId,
          'is_owner': 0,
          'is_active': _isActive ? 1 : 0,
          'setup_complete': 1,
          'created_at': now,
          'updated_at': now,
        });

        // Insert overrides
        for (final entry in _overrides.entries) {
          await db.insert('user_permission_overrides', {
            'user_id': userId,
            'permission_key': entry.key,
            'effect': entry.value == 'allow' ? 1 : 0,
            'created_at': now,
          });
        }
      } else {
        final userId = widget.user!.id;
        if (!_isOwner) {
          AccessGuard.require(PermissionRegistry.usersManage);
        }

        final updateMap = <String, dynamic>{
          'display_name': displayName,
          'updated_at': now,
        };

        if (!_isOwner) {
          updateMap['username'] = username;
          updateMap['role_id'] = _selectedRoleId;
          updateMap['is_active'] = _isActive ? 1 : 0;
        }

        await db.update('users', updateMap, where: 'id = ?', whereArgs: [userId]);

        // Update password if changed
        if (_passwordCtrl.text.isNotEmpty) {
          await AuthService.instance.setPassword(userId, _passwordCtrl.text);
        }

        // Update PIN if changed
        if (_pinCtrl.text.trim().isNotEmpty) {
          await AuthService.instance.setPin(userId, _pinCtrl.text.trim());
        }

        // Update overrides if non-owner
        if (!_isOwner) {
          await db.delete(
            'user_permission_overrides',
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          for (final entry in _overrides.entries) {
            await db.insert('user_permission_overrides', {
              'user_id': userId,
              'permission_key': entry.key,
              'effect': entry.value == 'allow' ? 1 : 0,
              'created_at': now,
            });
          }
        }
      }

      if (!mounted) return;
      AppSnackBar.show(context, l10n.savedSuccessfully);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.show(
        context,
        e.toString(),
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  Future<void> _handleDelete() async {
    if (_isOwner) return;
    final l10n = AppLocalizations.of(context);

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.confirmDelete,
      message: '${l10n.confirmDelete}: ${widget.user!.displayName}',
      confirmLabel: l10n.delete,
      isDestructive: true,
    );

    if (confirmed && mounted) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('users', where: 'id = ?', whereArgs: [widget.user!.id]);
      if (!mounted) return;
      AppSnackBar.show(context, l10n.deletedSuccessfully);
      Navigator.pop(context, true);
    }
  }

  void _showOverridesSheet() {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final byGroup = PermissionRegistry.byGroup;

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(l10n.permissionOverrides),
                  automaticallyImplyLeading: false,
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      child: Text(l10n.save),
                    ),
                  ],
                ),
                body: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: byGroup.length,
                  itemBuilder: (ctx, i) {
                    final groupEntry = byGroup.entries.elementAt(i);
                    final items = groupEntry.value;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          groupEntry.key.label(l10n.isArabic),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${items.length} ${l10n.rolesAndPermissions}',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        children: items.map((permItem) {
                          final currentEffect = _overrides[permItem.key]; // null, 'allow', 'deny'

                          return ListTile(
                            title: Text(
                              permItem.name(l10n.isArabic),
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              permItem.key,
                              style: TextStyle(fontSize: 11, color: cs.outline),
                            ),
                            trailing: SegmentedButton<String>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(value: 'default', label: Text('—')),
                                ButtonSegment(value: 'allow', label: Text('✓')),
                                ButtonSegment(value: 'deny', label: Text('✗')),
                              ],
                              selected: {currentEffect ?? 'default'},
                              onSelectionChanged: (s) {
                                setSheetState(() {
                                  final val = s.first;
                                  if (val == 'default') {
                                    _overrides.remove(permItem.key);
                                  } else {
                                    _overrides[permItem.key] = val;
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addUser : l10n.editUser),
        actions: [
          if (!_isNew && !_isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: _handleDelete,
            ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 500,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isOwner)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_rounded, color: cs.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.cannotDeactivateOwner,
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Display Name
                TextFormField(
                  controller: _displayNameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.displayName,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.required;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Username
                TextFormField(
                  controller: _usernameCtrl,
                  enabled: !_isOwner,
                  decoration: InputDecoration(
                    labelText: l10n.username,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                    helperText: _isOwner ? l10n.cannotDeactivateOwner : null,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.required;
                    if (v.trim().length < 3) return l10n.invalidCredentials;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Role Dropdown
                if (!_isOwner && _availableRoles.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRoleId,
                    decoration: InputDecoration(
                      labelText: l10n.role,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: _availableRoles.map((r) {
                      return DropdownMenuItem(
                        value: r.id,
                        child: Text(r.name),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedRoleId = val),
                    validator: (v) => v == null ? l10n.required : null,
                  ),
                if (!_isOwner && _availableRoles.isNotEmpty) const SizedBox(height: 16),

                // Active Switch
                if (!_isOwner)
                  SwitchListTile(
                    title: Text(l10n.userActive),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                if (!_isOwner) const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: _isNew ? l10n.password : l10n.changePasswordOptional,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (_isNew && (v == null || v.length < 6)) {
                      return l10n.invalidPasswordLength;
                    }
                    if (!_isNew && v != null && v.isNotEmpty && v.length < 6) {
                      return l10n.invalidPasswordLength;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // PIN (4-6 digits)
                TextFormField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: _isNew ? l10n.pinCode : '${l10n.pinCode} (${l10n.optional})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.pin_outlined),
                  ),
                  validator: (v) {
                    if (_isNew && (v == null || v.length < 4 || v.length > 6)) {
                      return l10n.invalidPin;
                    }
                    if (!_isNew && v != null && v.isNotEmpty && (v.length < 4 || v.length > 6)) {
                      return l10n.invalidPin;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Permission Overrides button (Non-owner only)
                if (!_isOwner)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(
                      '${l10n.permissionOverrides} (${_overrides.length})',
                    ),
                    onPressed: _showOverridesSheet,
                  ),
                if (!_isOwner) const SizedBox(height: 24),

                FilledButton(
                  onPressed: _saving ? null : _handleSave,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
