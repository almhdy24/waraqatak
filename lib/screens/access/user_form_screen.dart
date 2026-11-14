import 'package:flutter/material.dart';
import '../../database/access_dao.dart';
import '../../localization/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/role.dart';
import '../../services/access/access_admin_service.dart';
import '../../services/access/access_messages.dart';
import '../../services/access/auth_service.dart';
import '../../services/access/permission_registry.dart';
import '../../services/access/session_manager.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';
import '../../widgets/access/pin_keypad.dart';

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
      final allRoles = await AccessAdminService.instance.getRoles();
      final roles = _isOwner
          ? allRoles
          : allRoles.where((r) => !r.isSystem && r.id != AccessDao.ownerRoleId).toList();

      if (!_isNew) {
        _overrides = await AccessAdminService.instance.getUserOverrides(widget.user!.id);
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
          username: _isOwner ? null : username,
          displayName: displayName,
          roleId: _isOwner ? null : _selectedRoleId,
          isActive: _isOwner ? null : _isActive,
          newPassword: _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null,
          newPin: _pinCtrl.text.trim().isNotEmpty ? _pinCtrl.text.trim() : null,
          overrides: _isOwner ? null : _overrides,
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

  Future<void> _handleDeactivate() async {
    if (_isOwner || widget.user == null) return;
    final l10n = AppLocalizations.of(context);

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.disableAction,
      message: l10n.disableUserConfirm(widget.user!.displayName),
      confirmLabel: l10n.disableAction,
      isDestructive: true,
    );

    if (confirmed && mounted) {
      try {
        await AccessAdminService.instance.setUserActive(
          userId: widget.user!.id,
          isActive: false,
        );
        if (!mounted) return;
        AppSnackBar.show(context, l10n.savedSuccessfully);
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          friendlyError(l10n, e),
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  void _showOverridesSheet() {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final currentUser = SessionManager.instance.currentUser;
    final isOwnerSession = currentUser?.isOwner == true;

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
                    // Filter out OWNER_ONLY keys for non-owner delegates
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
                          final currentEffect = _overrides[permItem.key];

                          return ListTile(
                            title: Text(
                              permItem.localizedName(l10n),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addUser : l10n.editUser),
        centerTitle: true,
        actions: [
          if (!_isNew && !_isOwner)
            IconButton(
              icon: const Icon(Icons.block_outlined),
              tooltip: l10n.disableAction,
              onPressed: _handleDeactivate,
            ),
        ],
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
                      enabled: !_isOwner,
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
                    if (!_isOwner) ...[
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
                            child: Text(role.name),
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
                    if (!_isOwner)
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
    );
  }
}
