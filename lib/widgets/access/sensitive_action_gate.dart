import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/app_user.dart';
import '../../services/access/access_messages.dart';
import '../../services/access/audit_service.dart';
import '../../services/access/auth_service.dart';
import '../../services/access/session_manager.dart';

/// Re-authentication gate for high-privilege and destructive operations (F10).
///
/// In multi-user mode: prompts the active user (or requires Owner) to enter their password.
/// In single-user mode: bypasses password check immediately.
abstract final class SensitiveActionGate {
  /// Prompts for password re-authentication if multi-user mode is active.
  ///
  /// Returns `true` if authorized (or if single-user mode is active), `false` if cancelled or unauthorized.
  static Future<bool> reauthenticate(
    BuildContext context, {
    required String title,
    String? message,
    bool requireOwner = false,
  }) async {
    // Single-user fast path: no password prompt
    if (!SessionManager.instance.isMultiUserEnabled) {
      return true;
    }

    final currentUser = SessionManager.instance.currentUser;
    if (currentUser == null) return false;

    if (requireOwner && !currentUser.isOwner) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SensitiveReauthDialog(
        title: title,
        message: message,
        user: currentUser,
      ),
    );

    return result == true;
  }
}

class _SensitiveReauthDialog extends StatefulWidget {
  final String title;
  final String? message;
  final AppUser user;

  const _SensitiveReauthDialog({
    required this.title,
    this.message,
    required this.user,
  });

  @override
  State<_SensitiveReauthDialog> createState() => _SensitiveReauthDialogState();
}

class _SensitiveReauthDialogState extends State<_SensitiveReauthDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _verifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final password = _controller.text;
    if (password.isEmpty) return;

    if (AuthService.isDeviceThrottled) {
      final rem = AuthService.deviceThrottledUntil!.difference(DateTime.now());
      setState(() {
        _errorMessage = l10n.errDeviceThrottled(formatDurationMmSs(rem));
      });
      return;
    }

    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    try {
      final isValid = await AuthService.instance.verifyPassword(
        widget.user.id,
        password,
      );

      if (!isValid) {
        AuthService.recordDeviceFailure();
        final db = await DatabaseHelper.instance.database;
        try {
          await AuditService.instance.logEvent(
            db,
            'reauth_failed',
            entityType: 'user',
            details: 'user=${widget.user.username}',
          );
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _verifying = false;
          _errorMessage = l10n.errWrongPassword;
        });
        return;
      }

      AuthService.recordDeviceSuccess();
      final db = await DatabaseHelper.instance.database;
      try {
        await AuditService.instance.logEvent(
          db,
          'reauth_success',
          entityType: 'user',
          details: 'action=${widget.title}',
        );
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorMessage = friendlyError(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security_rounded, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(
              widget.message!,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '${l10n.reauthenticateRequired}:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            enabled: !_verifying,
            decoration: InputDecoration(
              labelText: l10n.password,
              border: const OutlineInputBorder(),
              errorText: _errorMessage,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _verifying ? null : _submit,
          child: _verifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.confirm),
        ),
      ],
    );
  }
}
