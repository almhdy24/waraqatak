import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import 'app_design_tokens.dart';

/// Reusable confirmation dialog with clear destructive action affordances
/// and accessible >= 48dp touch targets.
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool isDestructive;
  final IconData? icon;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.isDestructive = false,
    this.icon,
  });

  /// Displays the confirmation dialog and resolves to `true` if confirmed, `false` otherwise.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final resolvedIcon = icon ??
        (isDestructive
            ? Icons.warning_amber_rounded
            : Icons.help_outline_rounded);

    final iconColor = isDestructive
        ? AppDesignTokens.semanticDanger(context)
        : cs.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.br20),
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(resolvedIcon, size: 22, color: iconColor),
          ),
          const SizedBox(width: AppDesignTokens.space12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            minimumSize: const Size(80, AppDesignTokens.minTouchTarget),
            shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.br12),
          ),
          child: Text(cancelLabel ?? l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive
                ? AppDesignTokens.semanticDanger(context)
                : cs.primary,
            foregroundColor: isDestructive
                ? Colors.white
                : cs.onPrimary,
            minimumSize: const Size(88, AppDesignTokens.minTouchTarget),
            shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.br12),
          ),
          child: Text(
            confirmLabel ?? (isDestructive ? l10n.delete : l10n.confirm),
          ),
        ),
      ],
    );
  }
}
