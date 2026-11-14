import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../services/access/access_error.dart';
import '../../services/access/access_messages.dart';
import '../../services/access/session_manager.dart';

/// User-facing bilingual Access Denied view.
class AccessDeniedView extends StatelessWidget {
  final Type? screenType;
  final String? actionName;
  final AccessErrorCode decision;
  final String? permissionKey;
  final String? debugReason;

  const AccessDeniedView({
    super.key,
    this.screenType,
    this.actionName,
    this.decision = AccessErrorCode.missingPermission,
    this.permissionKey,
    this.debugReason,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final String screenOrAction = actionName != null
        ? l10n.accessDeniedActionBody(actionName!)
        : screenType != null
            ? l10n.accessDeniedScreenBody(screenType.toString())
            : l10n.accessDeniedScreenBody(l10n.accessGenericScreen);

    final String hint;
    if (decision == AccessErrorCode.ownerOnly) {
      hint = l10n.accessDeniedOwnerOnlyHint;
    } else if (decision == AccessErrorCode.missingPermission) {
      final permName = permissionKey != null
          ? localizedPermissionName(l10n, permissionKey!)
          : l10n.accessGenericPermission;
      hint = '${l10n.accessDeniedMissingPerm(permName)}\n${l10n.accessDeniedDelegateHint}';
    } else if (decision == AccessErrorCode.sessionLocked ||
        decision == AccessErrorCode.unauthenticated) {
      hint = l10n.accessDeniedLockedHint;
    } else {
      hint = localizeAccessError(l10n, decision);
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Semantics(
          label: l10n.accessDeniedTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: cs.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.accessDeniedTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                screenOrAction,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              if (hint.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsetsDirectional.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.accessDeniedBack),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                      }
                    },
                  ),
                  if (SessionManager.instance.isMultiUserEnabled)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.lock_person_outlined),
                      label: Text(l10n.accessDeniedGoToLock),
                      onPressed: () {
                        SessionManager.instance.lock();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
