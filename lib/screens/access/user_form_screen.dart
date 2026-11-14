import 'package:flutter/material.dart';
import '../../database/access_dao.dart';
import '../../localization/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/role.dart';
import '../../services/access/access_admin_service.dart';
import '../../services/access/access_messages.dart';
import '../../services/access/access_policy.dart';
import '../../services/access/auth_service.dart';
import '../../services/access/permission_registry.dart';
import '../../services/access/session_manager.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';
import '../../widgets/access/pin_keypad.dart';
import '../../widgets/access/screen_access_gate.dart';

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
  final _confirmPasswordCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  List<Role> _availableRoles = [];
  String? _selectedRoleId;
  bool _isActive = true;
  bool _obscurePassword = true;
  bool _obscureCurrentPassword = true;
  bool _loading = true;
  bool _saving = false;

  Map<String, String> _overrides = {}; // permission_key -> 'allow' | 'deny'
  late final Map<String, String> _initialOverrides;

  bool get _isNew => widget.user == null;
  bool get _isOwner => widget.user?.isOwner == true;
  bool get _isSelf => widget.user != null && widget.user!.id == SessionManager.instance.currentUser?.id;

  bool get _isDirty {
    if (_isNew) {
      return _usernameCtrl.text.isNotEmpty ||
          _displayNameCtrl.text.isNotEmpty ||
          _passwordCtrl.text.isNotEmpty ||
          _pinCtrl.text.isNotEmpty;
    }
    final originalUsername = widget.user?.username ?? '';
    final originalDisplayName = widget.user?.displayName ?? '';
    final originalRoleId = widget.user?.roleId;
    final originalActive = widget.user?.isActive ?? true;

    final fieldsChanged = _usernameCtrl.text != originalUsername ||
        _displayNameCtrl.text != originalDisplayName ||
        (!_isSelf && !_isOwner && _selectedRoleId != originalRoleId) ||
        (!_isSelf && !_isOwner && _isActive != originalActive) ||
        _passwordCtrl.text.isNotEmpty ||
        _pinCtrl.text.isNotEmpty;

    final overridesChanged = !_isSelf &&
        !_isOwner &&
        (_overrides.length != _initialOverrides.length ||
            _overrides.entries.any((e) => _initialOverrides[e.key] != e.value));

    return fieldsChanged || overridesChanged;
  }

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user?.username ?? '');
    _displayNameCtrl = TextEditingController(text: widget.user?.displayName ?? '');
    _isActive = widget.user?.isActive ?? true;
    _selectedRoleId = widget.user?.roleId;
    _initialOverrides = {};
    _loadData();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final allRoles = await AccessAdminService.instance.getRoles();
      final actor = SessionManager.instance.currentUser;
      final actorPerms = SessionManager.instance.cachedPermissions;

      // Filter roles: Owner can assign all; delegates only assign roles they hold (D11)
      final assignableRoles = <Role>[];
      for (final r in allRoles) {
        if (r.id == AccessDao.ownerRoleId || r.isSystem) continue;
        if (actor == null || actor.isOwner) {
          assignableRoles.add(r);
          continue;
        }
        final rolePerms = await AccessAdminService.instance.getRolePermissions(r.id);
        final check = AccessPolicy.canAssignRole(
          actor: actor,
          role: r,
          rolePermissions: rolePerms,
          actorPermissions: actorPerms,
        );
        if (check.isAllowed) {
          assignableRoles.add(r);
        }
      }

      if (!_isNew) {
        _overrides = await AccessAdminService.instance.getUserOverrides(widget.user!.id);
        _initialOverrides.addAll(_overrides);
      }

      if (!mounted) return;
      setState(() {
        _availableRoles = _isOwner ? allRoles : assignableRoles;
        _selectedRoleId ??= _availableRoles.firstOrNull?.id;
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
      final username = _usernameCtrl.text.trim();
      final displayName = _displayNameCtrl.text.trim();

      if (_isNew) {
        await AccessAdminService.instance.createUser(
          username: username,
          displayName: displayName,
          roleId: _selectedRoleId!,
          password: _passwordCtrl.text,
          pin: _pinCtrl.text.trim().isNotEmpty ? _pinCtrl.text.trim() : null,
          overrides: _overrides,
          isActive: _isActive,
        );
      } else {
        await AccessAdminService.instance.updateUser(
          userId: widget.user!.id,
          username: (_isOwner || _isSelf) ? null : username,
          displayName: displayName,
          roleId: (_isOwner || _isSelf) ? null : _selectedRoleId,
          isActive: (_isOwner || _isSelf) ? null : _isActive,
          newPassword: _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null,
          newPin: _pinCtrl.text.trim().isNotEmpty ? _pinCtrl.text.trim() : null,
          currentPassword: _currentPasswordCtrl.text.isNotEmpty ? _currentPasswordCtrl.text : null,
          overrides: (_isOwner || _isSelf) ? null : _overrides,
        );
      }

      if (!mounted) return;
      AppSnackBar.show(context, l10n.savedSuccessfully);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.show(
        context,
        friendlyError(l10n, e),
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  void _showOverridesSheet() {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final currentUser = SessionManager.instance.currentUser;
    final isOwnerSession = currentUser?.isOwner == true;
    final actorPerms = SessionManager.instance.cachedPermissions;

    // Working copy for cancel/save isolation (D13)
    final workingOverrides = Map<String, String>.from(_overrides);

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
                  leading: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.cancel),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _overrides.clear();
                          _overrides.addAll(workingOverrides);
                        });
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
                    final items = groupEntry.value.where((p) {
                      if (!isOwnerSession && p.isOwnerOnly) return false;
                      return true;
                    }).toList();

                    if (items.isEmpty) return const SizedBox.shrink();

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          groupEntry.key.localizedLabel(l10n),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${items.length} ${l10n.rolesAndPermissions}',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        children: items.map((permItem) {
                          final currentEffect = workingOverrides[permItem.key];
                          final canGrant = isOwnerSession || actorPerms.contains(permItem.key);

                          return ListTile(
                            title: Text(
                              permItem.localizedName(l10n),
                              style: TextStyle(
                                fontSize: 14,
                                color: canGrant ? null : cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            subtitle: canGrant
                                ? Text(
                                    permItem.key,
                                    style: TextStyle(fontSize: 11, color: cs.outline),
                                  )
                                : Text(
                                    l10n.cannotEditHeldPermissionsHelper,
                                    style: TextStyle(fontSize: 11, color: cs.error),
                                  ),
                            trailing: SegmentedButton<String>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(value: 'default', label: Text('—')),
                                ButtonSegment(value: 'allow', label: Text('✓')),
                                ButtonSegment(value: 'deny', label: Text('✗')),
                              ],
                              selected: {currentEffect ?? 'default'},
                              onSelectionChanged: canGrant
                                  ? (s) {
                                      setSheetState(() {
                                        final val = s.first;
                                        if (val == 'default') {
                                          workingOverrides.remove(permItem.key);
                                        } else {
                                          workingOverrides[permItem.key] = val;
                                        }
                                      });
                                    }
                                  : null,
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

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    final l10n = AppLocalizations.of(context);
    final discard = await AppConfirmDialog.show(
      context,
      title: l10n.unsavedChangesTitle,
      message: l10n.unsavedChangesMessage,
      confirmLabel: l10n.discardAction,
      isDestructive: true,
    );
    return discard;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return ScreenAccessGate(
      screenType: UserFormScreen,
      allowOverride: _isSelf,
      child: PopScope(
        canPop: !_isDirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          final discard = await _onWillPop();
          if (discard && mounted) {
            navigator.pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_isNew ? l10n.addUser : l10n.editUser),
            centerTitle: true,
          ),
          body: ResponsiveCenter(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_isOwner)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield, color: cs.onPrimaryContainer),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.cannotDeactivateOwner,
                                    style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        TextFormField(
                          controller: _displayNameCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.displayName,
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameCtrl,
                          enabled: !_isOwner && !_isSelf,
                          decoration: InputDecoration(
                            labelText: l10n.username,
                            prefixIcon: const Icon(Icons.person_outline),
                            border: const OutlineInputBorder(),
                            helperText: _isOwner ? l10n.ownerUsernameImmutable : null,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return l10n.required;
                            final trimmed = v.trim();
                            if (trimmed.length < 3 || trimmed.length > 32 || !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(trimmed)) {
                              return l10n.errUsernameInvalid;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (!_isOwner && !_isSelf) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRoleId,
                            decoration: InputDecoration(
                              labelText: l10n.role,
                              prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                              border: const OutlineInputBorder(),
                            ),
                            items: _availableRoles.map((role) {
                              return DropdownMenuItem(
                                value: role.id,
                                child: Text(localizedRoleName(l10n, role.id, role.name)),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedRoleId = v),
                            validator: (v) => v == null ? l10n.required : null,
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: Text(l10n.userActive),
                            subtitle: Text(
                              _isActive ? l10n.userActive : l10n.userInactive,
                              style: TextStyle(
                                color: _isActive ? cs.primary : cs.error,
                                fontSize: 12,
                              ),
                            ),
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            secondary: Icon(
                              _isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                              color: _isActive ? cs.primary : cs.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Current password field for self credentials update (C2)
                        if (_isSelf) ...[
                          TextFormField(
                            controller: _currentPasswordCtrl,
                            obscureText: _obscureCurrentPassword,
                            decoration: InputDecoration(
                              labelText: l10n.currentPasswordLabel,
                              helperText: l10n.currentPasswordHelper,
                              prefixIcon: const Icon(Icons.password_outlined),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureCurrentPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                              ),
                            ),
                            validator: (v) {
                              if ((_passwordCtrl.text.isNotEmpty || _pinCtrl.text.isNotEmpty) && (v == null || v.isEmpty)) {
                                return l10n.passwordRequired;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: _isNew ? l10n.password : l10n.changePasswordOptional,
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (_isNew && (v == null || v.length < 6)) {
                              return l10n.passwordMinLength;
                            }
                            if (!_isNew && v != null && v.isNotEmpty && v.length < 6) {
                              return l10n.passwordMinLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pinCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          inputFormatters: const [WesternPinInputFormatter(maxLength: 6)],
                          decoration: InputDecoration(
                            labelText: l10n.pinCode,
                            prefixIcon: const Icon(Icons.pin_outlined),
                            border: const OutlineInputBorder(),
                            counterText: '',
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty && !AuthService.isValidPin(v.trim())) {
                              return l10n.pinDigitsCount;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (!_isOwner && !_isSelf)
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.tune),
                              title: Text(l10n.permissionOverrides),
                              subtitle: Text(
                                _overrides.isEmpty
                                    ? l10n.noCustomOverrides
                                    : l10n.customPermissionsCount(_overrides.length),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _showOverridesSheet,
                            ),
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: Text(l10n.save),
                            onPressed: _saving ? null : _handleSave,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
