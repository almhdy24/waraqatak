import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/access_dao.dart';
import '../../localization/app_localizations.dart';
import '../../services/access/auth_service.dart';
import '../../services/access/recovery_service.dart';
import '../../services/access/session_manager.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';

class MultiUserWizardScreen extends StatefulWidget {
  const MultiUserWizardScreen({super.key});

  @override
  State<MultiUserWizardScreen> createState() => _MultiUserWizardScreenState();
}

class _MultiUserWizardScreenState extends State<MultiUserWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  int _currentStep = 0;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _savedCodeConfirmed = false;
  bool _loading = false;
  late final String _recoveryCode;

  @override
  void initState() {
    super.initState();
    _recoveryCode = RecoveryService.instance.generateRecoveryCode();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (!_savedCodeConfirmed || _loading) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);

    try {
      final password = _passwordCtrl.text;
      final pin = _pinCtrl.text.trim();

      // 1. Set Owner password and PIN
      await AuthService.instance.setPassword(AccessDao.ownerUserId, password);
      await AuthService.instance.setPin(AccessDao.ownerUserId, pin);

      // 2. Save Recovery Code
      await RecoveryService.instance.saveRecoveryCode(_recoveryCode);

      // 3. Enable multi-user mode in settings & session
      await SessionManager.instance.setMultiUserEnabled(true);

      if (!mounted) return;
      AppSnackBar.show(context, l10n.multiUserEnabledLabel);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.show(
        context,
        e.toString(),
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setupOwnerCredentials),
      ),
      body: ResponsiveCenter(
        maxWidth: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _currentStep == 0 ? _buildStep1(l10n, cs) : _buildStep2(l10n, cs),
        ),
      ),
    );
  }

  Widget _buildStep1(AppLocalizations l10n, ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.admin_panel_settings_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            l10n.setupOwnerCredentials,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.multiUserDisabledDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Owner Password
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: l10n.ownerPasswordLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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

          // Confirm Password
          TextFormField(
            controller: _confirmPasswordCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: l10n.confirmPasswordLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v != _passwordCtrl.text) {
                return l10n.invalidCredentials;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Owner PIN
          TextFormField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: l10n.ownerPinLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.pin_outlined),
              helperText: l10n.pinCode,
            ),
            validator: (v) {
              if (v == null || v.length < 4 || v.length > 6) {
                return l10n.invalidPin;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                setState(() => _currentStep = 1);
              }
            },
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(AppLocalizations l10n, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.key_rounded, size: 56, color: cs.primary),
        const SizedBox(height: 16),
        Text(
          l10n.recoveryCodeTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.recoveryCodeWarning,
                  style: TextStyle(
                    color: cs.onErrorContainer,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Display Recovery Code
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  _recoveryCode,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: l10n.copy,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _recoveryCode));
                  AppSnackBar.show(context, l10n.copiedToClipboard);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Checkbox confirmation
        CheckboxListTile(
          value: _savedCodeConfirmed,
          title: Text(
            l10n.recoveryCodeSavedConfirm,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _savedCodeConfirmed = v ?? false),
        ),
        const SizedBox(height: 24),

        FilledButton(
          onPressed: _savedCodeConfirmed && !_loading ? _handleComplete : null,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.enableMultiUserButton),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _currentStep = 0),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
