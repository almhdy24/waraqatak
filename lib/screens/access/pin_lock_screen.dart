import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/app_user.dart';
import '../../services/access/auth_service.dart';
import '../../services/access/permission_registry.dart';
import '../../services/access/permission_service.dart';
import '../../services/access/session_manager.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';
import 'recovery_screen.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  List<AppUser> _users = [];
  Map<String, String> _roleNames = {};
  AppUser? _selectedUser;
  String _enteredPin = '';
  bool _loading = true;
  bool _submitting = false;
  int _lockoutRemainingSeconds = 0;
  Timer? _lockoutTimer;

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
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'users',
        where: 'is_active = 1',
        orderBy: 'is_owner DESC, display_name ASC',
      );
      final users = rows.map((r) => AppUser.fromMap(r)).toList();

      // Load role names for chips
      final roleRows = await db.query('roles');
      final roleNames = {
        for (final r in roleRows) r['id'] as String: r['name'] as String,
      };

      if (!mounted) return;
      setState(() {
        _users = users;
        _roleNames = roleNames;
        // Default to current user or Owner
        final currentId = SessionManager.instance.currentUser?.id;
        _selectedUser = users.firstWhere(
          (u) => u.id == currentId,
          orElse: () => users.firstWhere(
            (u) => u.isOwner,
            orElse: () => users.first,
          ),
        );
        _loading = false;
      });
      _checkLockout();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
      } else {
        setState(() => _lockoutRemainingSeconds--);
      }
    });
  }

  void _onDigitPress(String digit) {
    if (_submitting || _lockoutRemainingSeconds > 0 || _enteredPin.length >= 6) return;
    setState(() {
      _enteredPin += digit;
    });
  }

  void _onBackspace() {
    if (_submitting || _enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onClear() {
    if (_submitting) return;
    setState(() => _enteredPin = '');
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
      setState(() {
        _enteredPin = '';
        _submitting = false;
      });
      _checkLockout();
      AppSnackBar.show(
        context,
        e.message(l10n.isArabic),
        severity: AppSnackBarSeverity.error,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enteredPin = '';
        _submitting = false;
      });
      _checkLockout();
      AppSnackBar.show(
        context,
        l10n.invalidPin,
        severity: AppSnackBarSeverity.error,
      );
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                        l10n.isArabic ? 'تبديل المستخدم' : 'Switch User',
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
                      final roleName = _roleNames[u.roleId] ?? (u.isOwner ? (l10n.isArabic ? 'المالك' : 'Owner') : u.roleId);

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
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text('@${u.username} • $roleName'),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: cs.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedUser = u;
                            _enteredPin = '';
                          });
                          _checkLockout();
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

    final success = await showDialog<bool>(
      context: context,
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
                decoration: InputDecoration(
                  labelText: l10n.password,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setDlgState(() => obscure = !obscure),
                  ),
                ),
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.unlock),
            ),
          ],
        ),
      ),
    );

    if (success == true && mounted) {
      try {
        final authenticatedUser = await AuthService.instance.authenticateWithPassword(
          user.username,
          passwordCtrl.text,
        );
        final permissions = authenticatedUser.isOwner
            ? PermissionRegistry.allKeys
            : await PermissionService.instance.getEffectivePermissions(authenticatedUser);

        if (!mounted) return;
        SessionManager.instance.unlock(authenticatedUser, permissions);
      } on AuthException catch (e) {
        if (!mounted) return;
        _checkLockout();
        AppSnackBar.show(
          context,
          e.message(l10n.isArabic),
          severity: AppSnackBarSeverity.error,
        );
      } catch (e) {
        if (!mounted) return;
        _checkLockout();
        AppSnackBar.show(
          context,
          l10n.invalidCredentials,
          severity: AppSnackBarSeverity.error,
        );
      } finally {
        passwordCtrl.dispose();
      }
    } else {
      passwordCtrl.dispose();
    }
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
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gpp_maybe_rounded, size: 64, color: cs.error),
                  const SizedBox(height: 16),
                  Text(
                    l10n.isArabic
                        ? 'تعذر التحقق من إعدادات الأمان'
                        : 'Cannot verify security settings',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.isArabic
                        ? 'فشلت قراءة إعدادات الأمان. تم إبقاء التطبيق مقفلاً لحماية البيانات.'
                        : 'Failed to read security configuration. Kept locked to protect data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.isArabic ? 'إعادة المحاولة' : 'Retry'),
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
        ? (_roleNames[user.roleId] ?? (user.isOwner ? (l10n.isArabic ? 'المالك' : 'Owner') : user.roleId))
        : '';

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
                  const SizedBox(height: 12),
                  // Lock Icon Badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_rounded, size: 36, color: cs.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.enterPin,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Enhanced User Switcher Card
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
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: user.isOwner
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHigh,
                              child: Icon(
                                user.isOwner ? Icons.shield_rounded : Icons.person_rounded,
                                size: 20,
                                color: user.isOwner
                                    ? cs.onPrimaryContainer
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                              l10n.isArabic
                                  ? 'الحساب معلق مؤقتاً. يرجى الانتظار $_lockoutRemainingSeconds ثانية'
                                  : 'Account paused. Try again in $_lockoutRemainingSeconds s',
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

                  // PIN Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final filled = i < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        width: filled ? 18 : 14,
                        height: filled ? 18 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
                          border: Border.all(
                            color: filled ? cs.primary : cs.outlineVariant,
                            width: filled ? 2 : 1,
                          ),
                        ),
                      );
                    }),
                  ),

                  const Spacer(),

                  // Number Keypad
                  for (var row = 0; row < 3; row++) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var col = 1; col <= 3; col++)
                          _KeypadButton(
                            label: '${row * 3 + col}',
                            onTap: () => _onDigitPress('${row * 3 + col}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _KeypadIconButton(
                        icon: Icons.backspace_outlined,
                        onTap: _onBackspace,
                        onLongPress: _onClear,
                      ),
                      _KeypadButton(
                        label: '0',
                        onTap: () => _onDigitPress('0'),
                      ),
                      _KeypadIconButton(
                        icon: Icons.check_circle_rounded,
                        color: _enteredPin.length >= 4 && _lockoutRemainingSeconds == 0
                            ? cs.onPrimary
                            : cs.outlineVariant,
                        backgroundColor: _enteredPin.length >= 4 && _lockoutRemainingSeconds == 0
                            ? cs.primary
                            : cs.surfaceContainerHighest.withValues(alpha: 0.2),
                        onTap: (_enteredPin.length >= 4 && !_submitting && _lockoutRemainingSeconds == 0)
                            ? _tryUnlock
                            : null,
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Actions: Password Login & Recovery
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

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? backgroundColor;

  const _KeypadIconButton({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Center(
            child: Icon(icon, size: 26, color: color),
          ),
        ),
      ),
    );
  }
}
