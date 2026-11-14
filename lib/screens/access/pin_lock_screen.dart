import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/app_user.dart';
import '../../services/access/access_admin_service.dart';
import '../../services/access/access_messages.dart';
import '../../services/access/auth_service.dart';
import '../../services/access/permission_registry.dart';
import '../../services/access/permission_service.dart';
import '../../services/access/session_manager.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';
import '../../widgets/access/pin_keypad.dart';
import 'recovery_screen.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  List<AppUser> _users = [];
  AppUser? _selectedUser;
  Map<String, String> _roleNames = {};
  String _enteredPin = '';
  bool _loading = true;
  bool _submitting = false;
  bool _hasError = false;
  int _lockoutRemainingSeconds = 0;
  Timer? _lockoutTimer;

  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context);

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'users',
        where: 'is_active = 1',
        orderBy: 'is_owner DESC, display_name ASC',
      );
      final users = rows.map((r) => AppUser.fromMap(r)).toList();

      final roles = await AccessAdminService.instance.getRoles(executor: db);
      final roleNames = <String, String>{};
      for (final r in roles) {
        roleNames[r.id] = localizedRoleName(l10n, r.id, r.name);
      }

      if (!mounted) return;
      setState(() {
        _users = users;
        _roleNames = roleNames;
        final current = SessionManager.instance.currentUser;
        if (current != null) {
          _selectedUser = users.firstWhere(
            (u) => u.id == current.id,
            orElse: () => users.firstOrNull ?? current,
          );
        } else {
          _selectedUser = users.firstOrNull;
        }
        _loading = false;
      });

      _checkLockout();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _reloadSelectedUser() async {
    final user = _selectedUser;
    if (user == null) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('users', where: 'id = ?', whereArgs: [user.id], limit: 1);
      if (rows.isNotEmpty && mounted) {
        final reloaded = AppUser.fromMap(rows.first);
        setState(() {
          _selectedUser = reloaded;
          final idx = _users.indexWhere((u) => u.id == user.id);
          if (idx != -1) _users[idx] = reloaded;
        });
      }
    } catch (_) {}
    if (mounted) _checkLockout();
  }

  void _checkLockout() {
    final user = _selectedUser;
    if (user == null) return;

    final now = DateTime.now();
    int rem = 0;

    // Check device throttle first
    if (AuthService.isDeviceThrottled) {
      rem = AuthService.deviceThrottledUntil!.difference(now).inSeconds + 1;
    } else if (user.isLocked) {
      rem = user.lockedUntil!.difference(now).inSeconds + 1;
    }

    if (rem > 0) {
      setState(() => _lockoutRemainingSeconds = rem);
      _startLockoutCountdown();
    } else {
      setState(() => _lockoutRemainingSeconds = 0);
    }
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutRemainingSeconds <= 1) {
        timer.cancel();
        setState(() => _lockoutRemainingSeconds = 0);
        _reloadSelectedUser();
      } else {
        setState(() => _lockoutRemainingSeconds--);
      }
    });
  }

  void _onDigitPress(String digit) {
    if (_enteredPin.length >= 6 || _submitting || _lockoutRemainingSeconds > 0) return;
    setState(() {
      _enteredPin += digit;
    });
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty || _submitting || _lockoutRemainingSeconds > 0) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onClear() {
    if (_submitting || _lockoutRemainingSeconds > 0) return;
    setState(() {
      _enteredPin = '';
    });
  }

  Future<void> _tryUnlock() async {
    final user = _selectedUser;
    if (user == null || _enteredPin.length < 4 || _submitting || _lockoutRemainingSeconds > 0) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _submitting = true);

    try {
      final authenticatedUser = await AuthService.instance.authenticateWithPin(
        user.id,
        _enteredPin,
      );

      final permissions = authenticatedUser.isOwner
          ? PermissionRegistry.allKeys
          : await PermissionService.instance.getEffectivePermissions(authenticatedUser);

      if (!mounted) return;
      SessionManager.instance.unlock(authenticatedUser, permissions);
    } on AuthException catch (e) {
      if (!mounted) return;
      _shakeKey.currentState?.shake();
      setState(() {
        _enteredPin = ''; // Clear immediately (D4)
        _hasError = true;
        _submitting = false;
      });
      AppSnackBar.show(
        context,
        friendlyError(l10n, e),
        severity: AppSnackBarSeverity.error,
      );
      await _reloadSelectedUser(); // Reload user row to update failed attempts / lockout (C7)
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() => _hasError = false);
      }
    } catch (e) {
      if (!mounted) return;
      _shakeKey.currentState?.shake();
      setState(() {
        _enteredPin = ''; // Clear immediately (D4)
        _hasError = true;
        _submitting = false;
      });
      AppSnackBar.show(
        context,
        friendlyError(l10n, e),
        severity: AppSnackBarSeverity.error,
      );
      await _reloadSelectedUser();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() => _hasError = false);
      }
    }
  }

  void _showUserPicker() {
    if (_users.length <= 1) return;

    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline_rounded, color: cs.primary),
                      const SizedBox(width: 12),
                      Text(
                        l10n.switchUser,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final u = _users[index];
                      final isSelected = u.id == _selectedUser?.id;
                      final roleName = _roleNames[u.roleId] ?? (u.isOwner ? l10n.ownerRole : u.roleId);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: u.isOwner
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          child: Icon(
                            u.isOwner ? Icons.shield_rounded : Icons.person_outline,
                            color: u.isOwner ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          u.displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '@${u.username} • $roleName',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: cs.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          if (!isSelected) {
                            setState(() {
                              _selectedUser = u;
                              _enteredPin = '';
                              _hasError = false;
                            });
                            _checkLockout();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPasswordLoginDialog() async {
    final l10n = AppLocalizations.of(context);
    final user = _selectedUser;
    if (user == null) return;

    final passwordCtrl = TextEditingController();
    bool obscure = true;
    bool dialogLoading = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(l10n.loginWithPassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.displayName} (@${user.username})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                autofocus: true,
                enabled: !dialogLoading,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  border: const OutlineInputBorder(),
                  errorText: dialogError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setDlgState(() => obscure = !obscure),
                  ),
                ),
                onChanged: (_) {
                  if (dialogError != null) {
                    setDlgState(() => dialogError = null);
                  } else {
                    setDlgState(() {});
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: dialogLoading ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: (dialogLoading || passwordCtrl.text.trim().isEmpty)
                  ? null
                  : () async {
                      setDlgState(() {
                        dialogLoading = true;
                        dialogError = null;
                      });

                      try {
                        final authenticatedUser = await AuthService.instance.authenticateWithPassword(
                          user.username,
                          passwordCtrl.text,
                        );
                        final permissions = authenticatedUser.isOwner
                            ? PermissionRegistry.allKeys
                            : await PermissionService.instance.getEffectivePermissions(authenticatedUser);

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);

                        if (!mounted) return;
                        SessionManager.instance.unlock(authenticatedUser, permissions);
                      } catch (e) {
                        await _reloadSelectedUser();
                        setDlgState(() {
                          dialogLoading = false;
                          dialogError = friendlyError(l10n, e);
                        });
                      }
                    },
              child: dialogLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.unlock),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
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

    if (SessionManager.instance.isSecurityUnverified) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gpp_maybe_rounded, size: 64, color: cs.error),
                  const SizedBox(height: 16),
                  Text(
                    l10n.securityInitFailedTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.securityInitFailedBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                    onPressed: () async {
                      await SessionManager.instance.retryInit();
                      if (mounted) _loadUsers();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final user = _selectedUser;
    final roleName = user != null
        ? (_roleNames[user.roleId] ?? (user.isOwner ? l10n.ownerRole : user.roleId))
        : '';
    final hasNoPin = user != null && !user.hasPin;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ResponsiveCenter(
            maxWidth: 420,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // User Selector Badge
                  if (user != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _users.length > 1 ? _showUserPicker : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: user.isOwner
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              child: Icon(
                                user.isOwner ? Icons.shield_rounded : Icons.person_outline,
                                size: 20,
                                color: user.isOwner ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    user.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: user.isOwner
                                              ? cs.primary.withValues(alpha: 0.15)
                                              : cs.secondaryContainer.withValues(alpha: 0.6),
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
                                      const SizedBox(width: 6),
                                      Text(
                                        '@${user.username}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (_users.length > 1)
                              Icon(
                                Icons.unfold_more_rounded,
                                color: cs.onSurfaceVariant,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Lockout Warning Card
                  if (_lockoutRemainingSeconds > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.error.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, color: cs.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.errAccountLocked(
                                formatDurationMmSs(Duration(seconds: _lockoutRemainingSeconds)),
                              ),
                              style: TextStyle(
                                color: cs.onErrorContainer,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Remaining attempts helper (D2)
                  if (_lockoutRemainingSeconds == 0 && user != null && user.failedAttempts > 0 && user.failedAttempts < 5)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l10n.errAttemptsRemaining(5 - user.failedAttempts),
                        style: TextStyle(
                          color: cs.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // If user has NO PIN set, show errNoPinSet and primary password button (D1)
                  if (hasNoPin)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 56, color: cs.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              l10n.errNoPinSet,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              icon: const Icon(Icons.password_outlined),
                              label: Text(l10n.enterPasswordToSignIn),
                              onPressed: _showPasswordLoginDialog,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Direction-safe PIN dots with shake container
                    ShakeWidget(
                      key: _shakeKey,
                      child: PinDotsView(
                        length: _enteredPin.length,
                        maxDigits: 6,
                        hasError: _hasError,
                      ),
                    ),

                    const Spacer(),

                    // Global LTR Keypad
                    PinKeypad(
                      enabled: !_submitting && _lockoutRemainingSeconds == 0,
                      onDigit: _onDigitPress,
                      onBackspace: _onBackspace,
                      onClear: _onClear,
                      leftAction: PinKeypadConfirmButton(
                        active: _enteredPin.length >= 4 && _lockoutRemainingSeconds == 0,
                        semanticsLabel: l10n.confirmAction,
                        onTap: (_enteredPin.length >= 4 && !_submitting && _lockoutRemainingSeconds == 0)
                            ? _tryUnlock
                            : null,
                      ),
                    ),

                    const Spacer(),
                  ],

                  // Actions: Password Login & Recovery
                  if (!hasNoPin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.password_outlined, size: 18),
                          label: Text(l10n.loginWithPassword),
                          onPressed: _showPasswordLoginDialog,
                        ),
                        if (_selectedUser?.isOwner == true) ...[
                          const Text(' • '),
                          TextButton(
                            child: Text(l10n.forgotPassword),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RecoveryScreen(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
