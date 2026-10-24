import 'package:flutter/material.dart';
import 'app_design_tokens.dart';

/// Standard metric KPI card used across HomeScreen, ReportsScreen,
/// and financial summary sections.
class AppMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool compact;

  const AppMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color,
    this.onTap,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = color ?? cs.primary;
    final iconBgColor = isDark
        ? accentColor.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.10);

    final cardContent = Padding(
      padding: EdgeInsets.all(compact ? AppDesignTokens.space12 : AppDesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDesignTokens.space8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: AppDesignTokens.br8,
                ),
                child: Icon(icon, size: compact ? 18 : 22, color: accentColor),
              ),
              const SizedBox(width: AppDesignTokens.space12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: compact ? AppDesignTokens.space8 : AppDesignTokens.space12),
          Text(
            value,
            style: (compact ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: AppDesignTokens.space4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppDesignTokens.br16,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: AppDesignTokens.softShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppDesignTokens.br16,
        child: onTap != null
            ? InkWell(
                borderRadius: AppDesignTokens.br16,
                onTap: onTap,
                child: cardContent,
              )
            : cardContent,
      ),
    );
  }
}
