import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../services/access/session_manager.dart';
import '../services/analytics/analytics_service.dart';
import '../utils/url_launcher_utils.dart';

/// Helper to show a professional first-launch consent dialog for anonymous usage
/// data and crash reporting.
class AnalyticsNoticeDialog {
  AnalyticsNoticeDialog._();

  /// Checks and shows the consent dialog once on first launch.
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
    final cs = theme.colorScheme;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: Icon(
          Icons.insights_rounded,
          color: cs.primary,
          size: 36,
        ),
        title: Text(
          l10n.consentDialogTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.consentDialogBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => UrlLauncherUtils.launch(
                ctx,
                AppConstants.privacyPolicyUrl,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 8, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.privacyPolicy,
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await AnalyticsService.instance.setConsent(false);
                  },
                  child: Text(
                    l10n.consentDialogNotNow,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await AnalyticsService.instance.setConsent(true);
                  },
                  child: Text(
                    l10n.consentDialogAgree,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
