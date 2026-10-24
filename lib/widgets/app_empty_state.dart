import 'package:flutter/material.dart';
import 'app_design_tokens.dart';

/// Standard, calm empty state widget presenting clear guidance
/// and optional primary action.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color? iconColor;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = iconColor ?? cs.primary;

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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 38, color: color),
              ),
            ),
            const SizedBox(height: AppDesignTokens.space20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: AppDesignTokens.space8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDesignTokens.space24),
              FilledButton.icon(
                onPressed: onAction,
                icon: actionIcon != null ? Icon(actionIcon, size: 18) : const SizedBox.shrink(),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.br12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
