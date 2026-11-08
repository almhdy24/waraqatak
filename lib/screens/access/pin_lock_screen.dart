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
  AppUser? _selectedUser;
  String _enteredPin = '';
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
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
      if (!mounted) return;
      setState(() {
        _users = users;
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onDigitPress(String digit) {
    if (_submitting || _enteredPin.length >= 6) return;
    setState(() {
      _enteredPin += digit;
    });
    if (_enteredPin.length >= 4 && _enteredPin.length == (_selectedUser?.isOwner == true ? 4 : _enteredPin.length)) {
      // If 4 digits entered, attempt auto-check if user PIN is 4 digits
      _tryUnlock();
    }
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
    if (user == null || _enteredPin.length < 4 || _submitting) return;

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
      AppSnackBar.show(
        context,
        l10n.invalidPin,
        severity: AppSnackBarSeverity.error,
      );
    }
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
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          l10n.invalidCredentials,
          severity: AppSnackBarSeverity.error,
        );
      }
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
                  Icon(Icons.lock_outline_rounded, size: 48, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    l10n.enterPin,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // User Selector
                  if (_users.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AppUser>(
                          value: _selectedUser,
                          isExpanded: true,
                          items: _users.map((u) {
                            return DropdownMenuItem(
                              value: u,
                              child: Row(
                                children: [
                                  Icon(
                                    u.isOwner ? Icons.shield_rounded : Icons.person_outline,
                                    size: 20,
                                    color: u.isOwner ? cs.primary : cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${u.displayName} (@${u.username})',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: u.isOwner ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (u) {
                            if (u != null) {
                              setState(() {
                                _selectedUser = u;
                                _enteredPin = '';
                              });
                            }
                          },
                        ),
                      ),
                    )
                  else if (_selectedUser != null)
                    Text(
                      _selectedUser!.displayName,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
                    ),

                  const SizedBox(height: 24),

                  // PIN Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final filled = i < _enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? cs.primary : cs.outlineVariant,
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
                        icon: Icons.clear_rounded,
                        onTap: _onClear,
                      ),
                      _KeypadButton(
                        label: '0',
                        onTap: () => _onDigitPress('0'),
                      ),
                      _KeypadIconButton(
                        icon: Icons.backspace_outlined,
                        onTap: _onBackspace,
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
  final VoidCallback onTap;

  const _KeypadIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 24),
          ),
        ),
      ),
    );
  }
}
