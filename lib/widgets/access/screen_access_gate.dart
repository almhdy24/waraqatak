import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../services/access/screen_access_policy.dart';
import '../../services/access/session_manager.dart';

/// Screen-level security gate wrapping protected screen bodies.
///
/// If authorized, renders [child].
/// If unauthorized, intercepts rendering with [AccessDeniedScaffold].
class ScreenAccessGate extends StatelessWidget {
  final Type screenType;
  final Widget child;

  const ScreenAccessGate({
    super.key,
    required this.screenType,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!SessionManager.instance.isMultiUserEnabled) {
      return child;
    }

    final decision = ScreenAccessPolicy.evaluate(screenType);
    if (decision.isAllowed) {
      return child;
    }

    return AccessDeniedScaffold(
      screenType: screenType,
      reasonAr: decision.reasonAr,
      reasonEn: decision.reasonEn,
    );
  }
}

/// Standalone scaffold rendered when a user attempts to enter an unauthorized screen.
class AccessDeniedScaffold extends StatelessWidget {
  final Type screenType;
  final String? reasonAr;
  final String? reasonEn;

  const AccessDeniedScaffold({
    super.key,
    required this.screenType,
    this.reasonAr,
    this.reasonEn,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final message = l10n.isArabic
        ? (reasonAr ?? 'لا تملك الصلاحية للوصول إلى هذه الصفحة')
        : (reasonEn ?? 'You lack the required permission to access this page');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.isArabic ? 'غير مصرح' : 'Access Denied'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_person_outlined,
                size: 72,
                color: cs.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.isArabic ? 'صلاحية غير كافية' : 'Insufficient Permissions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.error,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.isArabic ? 'رجوع' : 'Go Back'),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
