import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../widgets/activation_key_input_widget.dart';
import '../widgets/responsive.dart';

/// Screen for entering an activation key.
///
/// Features:
/// - Reuses [ActivationKeyInputWidget] as the single source of activation UI/logic.
/// - Blocks back navigation via [PopScope] while key verification is in flight.
/// - On success: plays haptic feedback and displays an animated implicit-animation
///   check with a concise list of unlocked Pro capabilities.
/// - Back navigation (system or AppBar) returns `true` on success to notify caller.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool _success = false;
  bool _loading = false;
  bool _animateCheck = false;

  void _onSuccess() {
    HapticFeedback.mediumImpact();
    setState(() {
      _success = true;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _animateCheck = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    return PopScope(
      canPop: !_loading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_success) {
          Navigator.pop(context, true);
        } else if (!_loading) {
          Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.activation),
          centerTitle: true,
          leading: BackButton(
            onPressed: _loading
                ? null
                : () => Navigator.pop(context, _success ? true : false),
          ),
        ),
        body: ResponsiveCenter(
          child: SafeArea(
            child: _success
                ? _buildSuccess(l10n, cs, textTheme)
                : _buildForm(l10n, cs, textTheme),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.vpn_key_outlined, size: 36, color: cs.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.proFeaturesActivation,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.getActivationKeyInfo,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          ActivationKeyInputWidget(
            showHeader: false,
            onLoadingChanged: (loading) {
              if (mounted) setState(() => _loading = loading);
            },
            onActivated: _onSuccess,
            onOutcome: (_) {
              if (mounted) setState(() => _loading = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    final proFeatures = [
      l10n.proUnlockedPurchases,
      l10n.proUnlockedInventory,
      l10n.proUnlockedReports,
      l10n.proUnlockedWholesale,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Center(
            child: AnimatedScale(
              scale: _animateCheck ? 1.0 : 0.2,
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              child: AnimatedOpacity(
                opacity: _animateCheck ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.activationSuccessTitle,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.activationSuccessBody,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.whatProUnlockedTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in proFeatures) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item,
                            style: textTheme.bodyMedium?.copyWith(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l10n.continueUsingApp,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
