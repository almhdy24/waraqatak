import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_localizations.dart';
import '../models/subscription_plan.dart';
import '../services/license_service.dart';
import '../widgets/access/screen_access_gate.dart';
import '../widgets/activation_key_input_widget.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';

/// Screen for exploring Pro subscription plans and entering an activation key.
///
/// Features:
/// - Polished subscription landing page displaying 4 plans (1 month, 3 months, 6 months, 1 year).
/// - Annual plan highlighted as featured offer: 33% discount, saves 60,000 SDG, crossed out original price, 10,000 SDG/mo equivalent.
/// - Prominent "اشترك الآن" WhatsApp subscription button for each plan with prefilled message.
/// - Transparent activation steps guide (WhatsApp -> Payment -> Activation Key).
/// - Dedicated "لديك مفتاح تفعيل؟" section embedding [ActivationKeyInputWidget] with device ID display and copy action.
/// - Blocks back navigation via [PopScope] while key verification is in flight.
/// - On activation success: displays animated celebration and unlocks Pro, returning `true` to callers.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool _success = false;
  bool _loading = false;
  bool _animateCheck = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    try {
      final id = await LicenseService.instance.getOrCreateDeviceId();
      if (mounted) setState(() => _deviceId = id);
    } catch (_) {}
  }

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

  Future<void> _subscribeToPlan(SubscriptionPlan plan) async {
    final l10n = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final planTitle = _getPlanTitle(plan, l10n);
    final durationText = _getPlanDuration(plan, l10n);

    final uri = SubscriptionPlan.generateWhatsAppUri(
      plan: plan,
      planTitle: planTitle,
      durationText: durationText,
      deviceId: _deviceId,
      isArabic: isAr,
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        AppSnackBar.show(
          context,
          l10n.whatsappNotInstalled,
          severity: AppSnackBarSeverity.error,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          l10n.whatsappNotInstalled,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  String _getPlanTitle(SubscriptionPlan plan, AppLocalizations l10n) {
    switch (plan.id) {
      case '1_year':
        return l10n.plan1YearTitle;
      case '6_months':
        return l10n.plan6MonthsTitle;
      case '3_months':
        return l10n.plan3MonthsTitle;
      case '1_month':
      default:
        return l10n.plan1MonthTitle;
    }
  }

  String _getPlanDuration(SubscriptionPlan plan, AppLocalizations l10n) {
    switch (plan.id) {
      case '1_year':
        return l10n.plan1YearDuration;
      case '6_months':
        return l10n.plan6MonthsDuration;
      case '3_months':
        return l10n.plan3MonthsDuration;
      case '1_month':
      default:
        return l10n.plan1MonthDuration;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ScreenAccessGate(
      screenType: ActivationScreen,
      child: PopScope(
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
            title: Text(l10n.proSubscriptionTitle),
            centerTitle: true,
            leading: BackButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.pop(context, _success ? true : false),
            ),
          ),
          body: ResponsiveCenter(
            maxWidth: 680,
            child: SafeArea(
              child: _success
                  ? _buildSuccess(l10n, cs, textTheme)
                  : _buildSubscriptionLanding(l10n, cs, textTheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionLanding(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero & Value Proposition ─────────────────────────────────────
          _buildHeroHeader(l10n, cs, textTheme),
          const SizedBox(height: 24),

          // ── Subscription Plans Header ────────────────────────────────────
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 22, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.proSubscriptionTitle,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Pricing Cards ────────────────────────────────────────────────
          for (final plan in SubscriptionPlan.allPlans) ...[
            _buildPlanCard(plan, l10n, cs, textTheme),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 12),

          // ── How Activation Works Banner ──────────────────────────────────
          _buildActivationStepsGuide(l10n, cs, textTheme),
          const SizedBox(height: 24),

          // ── "Already Have Key?" Section ─────────────────────────────────
          _buildAlreadyHaveKeySection(l10n, cs, textTheme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Brand badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              l10n.proSubscriptionBrand,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Center Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.stars_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          // Subtitle / value proposition pitch
          Text(
            l10n.proSubscriptionSubtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),

          // 4 Pro Feature Highlights
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureChip(Icons.receipt_long_rounded, l10n.proValuePointInvoices, cs, textTheme),
              _buildFeatureChip(Icons.inventory_2_rounded, l10n.proValuePointInventory, cs, textTheme),
              _buildFeatureChip(Icons.analytics_rounded, l10n.proValuePointReports, cs, textTheme),
              _buildFeatureChip(Icons.draw_rounded, l10n.proValuePointBranding, cs, textTheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(
    IconData icon,
    String label,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    SubscriptionPlan plan,
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    final isFeatured = plan.isFeatured;
    final planTitle = _getPlanTitle(plan, l10n);
    final durationText = _getPlanDuration(plan, l10n);
    final priceStr = SubscriptionPlan.formatSdg(plan.priceSdg);

    // WhatsApp signature green
    const whatsAppGreen = Color(0xFF25D366);

    return Container(
      decoration: BoxDecoration(
        color: isFeatured
            ? cs.primaryContainer.withValues(alpha: 0.25)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFeatured ? cs.primary : cs.outlineVariant,
          width: isFeatured ? 2.0 : 1.0,
        ),
        boxShadow: isFeatured
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Featured Header Badge (Annual Plan)
          if (isFeatured)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    l10n.plan1YearFeaturedBadge,
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Plan Title and Duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        planTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isFeatured ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        durationText,
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Pricing Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      priceStr,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isFeatured ? cs.primary : cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.planCurrencySdg,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (plan.originalPriceSdg != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        l10n.originalAnnualPriceCrossing,
                        style: textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: cs.error,
                          decorationThickness: 2,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),

                // Badges Row (Savings, Discount %, Monthly Equivalent)
                if (plan.savingsSdg != null || plan.discountPercent != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (plan.savingsSdg != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            plan.id == '1_year'
                                ? l10n.save60kBadge
                                : plan.id == '6_months'
                                    ? l10n.save20kBadge
                                    : l10n.save5kBadge,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      if (plan.discountPercent != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.errorContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.discount33PercentBadge,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ),
                      if (plan.monthlyEquivalentSdg != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.equivalentMonthly10k,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // "اشترك الآن" WhatsApp Button
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    key: ValueKey('subscribe_${plan.id}'),
                    onPressed: _loading ? null : () => _subscribeToPlan(plan),
                    style: FilledButton.styleFrom(
                      backgroundColor: isFeatured ? whatsAppGreen : cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isFeatured ? 2 : 0,
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 20, color: Colors.white),
                    label: Text(
                      l10n.subscribeNowAction,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationStepsGuide(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                l10n.howToActivateTitle,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.howToActivateBody,
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyHaveKeySection(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.vpn_key_rounded, size: 20, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.alreadyHaveKeyHeader,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.alreadyHaveKeyDesc,
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Device ID row with quick copy action
          if (_deviceId != null && _deviceId!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.perm_device_information_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    l10n.myDeviceIdLabel,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _deviceId!,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: l10n.copyDeviceIdAction,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _deviceId!));
                      AppSnackBar.show(
                        context,
                        l10n.deviceIdCopiedSnack,
                        severity: AppSnackBarSeverity.success,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Embedded key input widget
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
