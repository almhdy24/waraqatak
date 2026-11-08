import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/access_dao.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/app_user.dart';
import '../../services/access/auth_service.dart';
import '../../services/access/permission_registry.dart';
import '../../services/access/recovery_service.dart';
import '../../services/access/session_manager.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _newRecoveryCode;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _newPasswordCtrl.dispose();
    _newPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRecover() async {
    if (!_formKey.currentState!.validate() || _loading) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);

    try {
      final code = _codeCtrl.text.trim();
      final newPass = _newPasswordCtrl.text;
      final newPin = _newPinCtrl.text.trim();

      // 1. Reset password via recovery code and obtain new recovery code
      final freshRecoveryCode =
          await RecoveryService.instance.resetOwnerPasswordWithRecoveryCode(
        code,
        newPass,
      );

      // 2. Set new PIN if provided
      if (newPin.isNotEmpty) {
        await AuthService.instance.setPin(AccessDao.ownerUserId, newPin);
      }

      // 3. Unlock session as Owner
      final db = await DatabaseHelper.instance.database;
      final ownerRows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [AccessDao.ownerUserId],
        limit: 1,
      );
      if (ownerRows.isNotEmpty) {
        final ownerUser = AppUser.fromMap(ownerRows.first);
        SessionManager.instance.unlock(ownerUser, PermissionRegistry.allKeys);
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _newRecoveryCode = freshRecoveryCode;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.show(
        context,
        e.message(l10n.isArabic),
        severity: AppSnackBarSeverity.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.show(
        context,
        l10n.invalidRecoveryCode,
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_newRecoveryCode != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.recoveryCodeTitle),
          automaticallyImplyLeading: false,
        ),
        body: ResponsiveCenter(
          maxWidth: 460,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 64, color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  l10n.recoverySuccess,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _newRecoveryCode!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: l10n.copy,
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _newRecoveryCode!));
                          AppSnackBar.show(context, l10n.copiedToClipboard);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.recoveryCodeWarning,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error, fontSize: 13),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.continueAction),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recoverOwnerAccess),
      ),
      body: ResponsiveCenter(
        maxWidth: 460,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.shield_outlined, size: 56, color: cs.primary),
                const SizedBox(height: 12),
                Text(
                  l10n.recoverOwnerAccess,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.recoveryCodeWarning,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codeCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.recoveryCodeInputLabel,
                    hintText: 'RC-XXXX-XXXX-XXXX',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.required;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.newOwnerPassword,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return l10n.invalidPasswordLength;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: l10n.newOwnerPin,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.pin_outlined),
                    helperText: l10n.pinCode,
                  ),
                  validator: (v) {
                    if (v == null || v.length < 4) {
                      return l10n.invalidPin;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _handleRecover,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.unlock),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
