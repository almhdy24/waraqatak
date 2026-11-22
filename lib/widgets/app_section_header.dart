import 'package:flutter/material.dart';
import 'app_design_tokens.dart';

/// Clean, consistent section header with optional counter badge and action button.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final EdgeInsetsGeometry padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppDesignTokens.space16,
      vertical: AppDesignTokens.space12,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: AppDesignTokens.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesignTokens.space8,
                      vertical: AppDesignTokens.space2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: AppDesignTokens.brPill,
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: actionIcon != null
                  ? Icon(actionIcon, size: 16)
                  : const SizedBox.shrink(),
              label: Text(
                actionLabel!,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
