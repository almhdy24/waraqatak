import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/document_status.dart';
import 'app_design_tokens.dart';

/// Reusable status badge with semantic color, icon, and text.
///
/// Fully backwards-compatible with [StatusBadge], and can also display
/// custom operational statuses (active/inactive, stock status, etc.).
class StatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;
  final Color? customColor;
  final IconData? customIcon;
  final bool showIcon;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.customColor,
    this.customIcon,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (resolvedLabel, resolvedColor, resolvedIcon) =
        _resolve(status, l10n, context);

    final label = customLabel ?? resolvedLabel;
    final color = customColor ?? resolvedColor;
    final icon = customIcon ?? resolvedIcon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesignTokens.radius8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  static (String, Color, IconData) _resolve(
    String status,
    AppLocalizations l10n,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (status) {
      DocumentStatus.draft => (
        l10n.statusDraft,
        isDark ? AppDesignTokens.neutralMutedDark : AppDesignTokens.neutralMuted,
        Icons.edit_note_rounded,
      ),
      DocumentStatus.issued => (
        l10n.statusIssued,
        isDark ? AppDesignTokens.infoDark : AppDesignTokens.info,
        Icons.send_outlined,
      ),
      DocumentStatus.partiallyPaid => (
        l10n.statusPartiallyPaid,
        isDark ? AppDesignTokens.warningDark : AppDesignTokens.warning,
        Icons.timelapse_rounded,
      ),
      DocumentStatus.paid => (
        l10n.statusPaid,
        isDark ? AppDesignTokens.successDark : AppDesignTokens.success,
        Icons.check_circle_outline_rounded,
      ),
      DocumentStatus.cancelled => (
        l10n.statusCancelled,
        isDark ? AppDesignTokens.dangerDark : AppDesignTokens.danger,
        Icons.cancel_outlined,
      ),
      _ => (
        status,
        isDark ? AppDesignTokens.neutralMutedDark : AppDesignTokens.neutralMuted,
        Icons.help_outline_rounded,
      ),
    };
  }
}

/// Alias for [StatusBadge] adhering to app component naming conventions.
typedef AppStatusBadge = StatusBadge;
