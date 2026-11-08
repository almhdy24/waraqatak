import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/access/session_manager.dart';
import '../services/analytics/analytics_service.dart';

/// Helper to show a non-blocking one-time privacy notice about usage statistics
/// and error reports on the first application launch after unlock.
class AnalyticsNoticeDialog {
  AnalyticsNoticeDialog._();

  /// Checks and shows the notice once.
  /// If the session is currently locked, aborts immediately without showing or marking.
  static Future<void> checkAndShow(
    BuildContext context, {
    VoidCallback? onOpenSettings,
  }) async {
    // 1. Guard against showing over the multi-user lock screen
    if (SessionManager.instance.isLocked) return;

    // 2. Check if already shown
    final alreadyShown = await AnalyticsService.instance.isFirstRunNoticeShown();
    if (alreadyShown) return;

    // 3. Mark as shown immediately so restarts/crashes never show it again
    await AnalyticsService.instance.markFirstRunNoticeShown();

    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.privacy_tip_outlined,
          color: theme.colorScheme.primary,
          size: 32,
        ),
        title: Text(l10n.analyticsNoticeTitle),
        content: Text(
          l10n.analyticsNoticeBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onOpenSettings?.call();
            },
            child: Text(l10n.analyticsNoticeSettings),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.analyticsNoticeOk),
          ),
        ],
      ),
    );
  }
}
