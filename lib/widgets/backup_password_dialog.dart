import 'dart:convert';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/backup_encryption_service.dart';
import 'app_design_tokens.dart';

/// Dialog shown before backup creation asking if the user wants password protection.
///
/// Returns:
/// - `null`: user cancelled the backup.
/// - `""`: user chose unencrypted backup (default).
/// - `password`: user configured password protection.
class BackupPasswordCreateDialog extends StatefulWidget {
  const BackupPasswordCreateDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const BackupPasswordCreateDialog(),
    );
  }

  @override
  State<BackupPasswordCreateDialog> createState() =>
      _BackupPasswordCreateDialogState();
}

class _BackupPasswordCreateDialogState
    extends State<BackupPasswordCreateDialog> {
  bool _protectWithPassword = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onConfirm(AppLocalizations l10n) {
    if (!_protectWithPassword) {
      // Unencrypted backup chosen
      Navigator.of(context).pop('');
      return;
    }

    final normalized =
        BackupEncryptionService.normalizePassword(_passwordController.text);
    final normalizedConfirm =
        BackupEncryptionService.normalizePassword(_confirmController.text);

    if (normalized.isEmpty) {
      setState(() => _errorMessage = l10n.backupPasswordRequired);
      return;
    }

    if (normalized.length < 8) {
      setState(() => _errorMessage = l10n.backupPasswordMinLength);
      return;
    }

    if (normalized != normalizedConfirm) {
      setState(() => _errorMessage = l10n.backupPasswordsDoNotMatch);
      return;
    }

    Navigator.of(context).pop(_passwordController.text);
  }

  Widget _buildChoiceTile({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppDesignTokens.br8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: AppDesignTokens.space12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.br16),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      title: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            color: theme.colorScheme.primary,
            size: 26,
          ),
          const SizedBox(width: AppDesignTokens.space12),
          Expanded(
            child: Text(
              l10n.backupEncryptionQuestion,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Option 1: Without password (Default)
            _buildChoiceTile(
              context: context,
              title: l10n.backupWithoutPassword,
              isSelected: !_protectWithPassword,
              onTap: () {
                setState(() {
                  _protectWithPassword = false;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: AppDesignTokens.space4),
            // Option 2: With password
            _buildChoiceTile(
              context: context,
              title: l10n.backupWithPassword,
              isSelected: _protectWithPassword,
              onTap: () {
                setState(() {
                  _protectWithPassword = true;
                  _errorMessage = null;
                });
              },
            ),

            if (_protectWithPassword) ...[
              const SizedBox(height: AppDesignTokens.space12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l10n.backupPassword,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: AppDesignTokens.space12),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: l10n.backupConfirmPassword,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_clock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: AppDesignTokens.space8),
              Text(
                l10n.backupPasswordHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppDesignTokens.space16),
              // Warning box
              Container(
                padding: const EdgeInsets.all(AppDesignTokens.space12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: AppDesignTokens.br8,
                  border: Border.all(
                    color: Colors.amber.shade700,
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: AppDesignTokens.space8),
                    Expanded(
                      child: Text(
                        l10n.backupPasswordWarning,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: AppDesignTokens.space12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => _onConfirm(l10n),
          child: Text(l10n.continueAction),
        ),
      ],
    );
  }
}

/// Dialog shown when restoring an encrypted backup file.
///
/// Handles decryption, error feedback, and allows retry without re-picking the file.
/// Returns the decrypted JSON string on success, or `null` if cancelled.
class BackupPasswordPromptDialog extends StatefulWidget {
  final List<int> encryptedBytes;

  const BackupPasswordPromptDialog({
    super.key,
    required this.encryptedBytes,
  });

  static Future<String?> show(
    BuildContext context, {
    required List<int> encryptedBytes,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          BackupPasswordPromptDialog(encryptedBytes: encryptedBytes),
    );
  }

  @override
  State<BackupPasswordPromptDialog> createState() =>
      _BackupPasswordPromptDialogState();
}

class _BackupPasswordPromptDialogState
    extends State<BackupPasswordPromptDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _attemptDecrypt(AppLocalizations l10n) async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = l10n.backupPasswordRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jsonStr = await BackupEncryptionService.decryptJson(
        encryptedBytes: widget.encryptedBytes,
        password: password,
      );

      // Validate that it is valid backup JSON before popping
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.backupCorrupted;
          });
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).pop(jsonStr);
      }
    } on BackupDecryptionException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.backupIncorrectPassword;
        });
      }
    } on BackupUnsupportedVersionException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.backupUpdateRequired;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.backupCorrupted;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.br16),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      title: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: theme.colorScheme.primary,
            size: 26,
          ),
          const SizedBox(width: AppDesignTokens.space12),
          Expanded(
            child: Text(
              l10n.backupEncryptedTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.backupEnterPasswordMessage,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDesignTokens.space16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofocus: true,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: l10n.backupPassword,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              onSubmitted: (_) {
                if (!_isLoading) _attemptDecrypt(l10n);
              },
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
            const SizedBox(height: AppDesignTokens.space8),
            Text(
              l10n.backupPasswordHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: AppDesignTokens.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppDesignTokens.space12),
                  Text(
                    l10n.backupDecrypting,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppDesignTokens.space12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : () => _attemptDecrypt(l10n),
          child: Text(l10n.restore),
        ),
      ],
    );
  }
}
