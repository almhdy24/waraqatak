import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import 'app_design_tokens.dart';

/// Reusable full-width or centered error state presentation
/// with an optional retry button.
class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final String? title;
  final IconData icon;

  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.title,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final dangerColor = AppDesignTokens.semanticDanger(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.space24,
          vertical: AppDesignTokens.space32,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: dangerColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 36, color: dangerColor),
              ),
            ),
            const SizedBox(height: AppDesignTokens.space16),
            Text(
              title ?? l10n.operationFailed,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: AppDesignTokens.space8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppDesignTokens.space20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel ?? l10n.retry),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, AppDesignTokens.minTouchTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesignTokens.br12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
