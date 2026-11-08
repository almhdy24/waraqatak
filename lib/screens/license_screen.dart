import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/activation_service.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../widgets/activation_key_input_widget.dart';
import '../widgets/access/screen_access_gate.dart';
import '../widgets/access/sensitive_action_gate.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';

/// License & Subscription screen (Settings → License).
///
/// Designed for non-technical users to instantly know their status and what to do:
/// - Key action is presented first; details are collapsed by default.
/// - Licensed state: status card + collapsed details + remove key. No key input shown.
/// - Active trial: trial banner + key input card + help & support + collapsed free-vs-pro + collapsed details.
/// - Expired/Revoked: state banner + key input card FIRST + help & support + collapsed details.
/// - Pull-to-refresh supported; network failures handled with Retry states.
class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  EntitlementState? _state;
  String? _deviceModel;
  bool _busy = false;
  bool _storageFault = false;
  bool _reloadError = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _reloadError = false;
    });
    try {
      final s = await LicenseService.instance.checkEntitlement(force: true);
      final model = await LicenseService.instance.getDeviceModel();
      if (!mounted) return;
      setState(() {
        _state = s;
        _deviceModel = model;
        _storageFault = LicenseService.instance.hasStorageFault;
        _reloadError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reloadError = true;
      });
    }
  }

  bool get _hasStoredKey {
    final s = _state;
    if (s == null) return false;
    return s.status == EntitlementStatus.licensed ||
        s.status == EntitlementStatus.licenseExpired ||
        s.status == EntitlementStatus.licenseRevoked;
  }

  String _statusLabel(AppLocalizations l10n) {
    final s = _state;
    if (s == null) return '';
    return switch (s.status) {
      EntitlementStatus.trialActive => l10n.trialActiveStatusWithDays(
        s.trialDaysRemaining,
      ),
      EntitlementStatus.trialExpired => l10n.trialExpiredStatus,
      EntitlementStatus.licensed => l10n.activatedStatus,
      EntitlementStatus.licenseExpired => l10n.licenseExpiredStatus,
      EntitlementStatus.licenseRevoked => l10n.licenseRevokedStatus,
    };
  }

  String _typeLabel(AppLocalizations l10n) {
    final s = _state;
    if (s == null) return '';
    return switch (s.status) {
      EntitlementStatus.trialActive => l10n.licenseTypeTrial,
      EntitlementStatus.trialExpired => l10n.licenseTypeTrial,
      EntitlementStatus.licensed =>
        s.licenseExpiresAt == null
            ? l10n.licenseTypePerpetual
            : l10n.licenseTypeTimed,
      EntitlementStatus.licenseExpired => l10n.licenseTypeTimed,
      EntitlementStatus.licenseRevoked => l10n.licenseTypeActivated,
    };
  }

  String _expiryLabel(AppLocalizations l10n) {
    final s = _state;
    if (s == null) return '';
    final e = s.licenseExpiresAt;
    if (e == null) return l10n.licenseNoExpiryDate;
    return e.toLocal().toString().split(' ').first;
  }

  String _featureLabel(Feature f, AppLocalizations l10n) => switch (f) {
    Feature.invoices => l10n.featureInvoices,
    Feature.quotations => l10n.featureQuotations,
    Feature.vouchers => l10n.featureVouchers,
    Feature.customDocuments => l10n.featureCustomDocuments,
    Feature.customers => l10n.featureCustomers,
    Feature.products => l10n.featureProducts,
    Feature.barcode => l10n.featureBarcode,
    Feature.basicReports => l10n.featureBasicReports,
    Feature.backupRestore => l10n.featureBackupRestore,
    Feature.purchases => l10n.featurePurchases,
    Feature.inventory => l10n.featureInventory,
    Feature.advancedReports => l10n.featureAdvancedReports,
    Feature.stocktake => l10n.featureStocktake,
    Feature.bulkPriceUpdate => l10n.featureBulkPriceUpdate,
    Feature.csvImportExport => l10n.featureCsvImportExport,
    Feature.inventoryAudit => l10n.featureInventoryAudit,
    Feature.multiUser => l10n.multiUserTitle,
  };

  Future<void> _launchEmail(BuildContext context, AppLocalizations l10n) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {'subject': l10n.supportEmailSubject},
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        if (context.mounted) _showEmailFallback(context, l10n);
      }
    } catch (_) {
      if (context.mounted) _showEmailFallback(context, l10n);
    }
  }

  void _showEmailFallback(BuildContext context, AppLocalizations l10n) {
    AppSnackBar.show(
      context,
      l10n.emailLaunchFailedWithAddress(AppConstants.supportEmail),
      actionLabel: l10n.copyEmailAddress,
      onAction: () {
        Clipboard.setData(const ClipboardData(text: AppConstants.supportEmail));
        AppSnackBar.show(context, l10n.emailAddressCopied);
      },
      severity: AppSnackBarSeverity.warning,
    );
  }

  Future<void> _launchWhatsApp(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final uri = Uri.parse(AppConstants.whatsappUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        if (context.mounted) {
          AppSnackBar.show(
            context,
            l10n.whatsappNotInstalled,
            severity: AppSnackBarSeverity.error,
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          l10n.whatsappNotInstalled,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _removeKey() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeKeyConfirmTitle),
        content: Text(l10n.removeKeyConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.removeKeyConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final authed = await SensitiveActionGate.reauthenticate(
      context,
      title: l10n.isArabic ? 'إزالة ترخيص الجهاز' : 'Remove device license',
      requireOwner: true,
    );
    if (!authed || !mounted) return;

    setState(() => _busy = true);
    var released = true;
    try {
      final key = await LicenseService.instance.licenseKey;
      if (key != null && key.isNotEmpty) {
        final deviceId = await LicenseService.instance.getOrCreateDeviceId();
        released = await ActivationService.deactivate(
          key,
          deviceId,
        ).timeout(const Duration(seconds: 15), onTimeout: () => false);
      }
      await LicenseService.instance.clearLicense();
      await _reload();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        released ? l10n.keyRemovedSnack : l10n.keyRemovedServerNotReleased,
      );
    } catch (_) {
      try {
        await LicenseService.instance.clearLicense();
        await _reload();
      } catch (_) {}
      if (mounted) {
        AppSnackBar.show(context, l10n.keyRemovedServerNotReleased);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ScreenAccessGate(
      screenType: LicenseScreen,
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.licenseScreenRedesignTitle),
        centerTitle: true,
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: _state == null
              ? _buildLoadingOrError(l10n, cs, textTheme)
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 20.0,
                  ),
                  children: [
                    if (_storageFault) ...[
                      _buildStorageFaultBanner(l10n, cs, textTheme),
                      const SizedBox(height: 16),
                    ],
                    if (_reloadError) ...[
                      _buildReloadErrorCard(l10n, cs, textTheme),
                      const SizedBox(height: 16),
                    ],
                    ..._buildStateSpecificLayout(context, l10n, cs, textTheme),
                  ],
                ),
        ),
      ),
    ),
    );
  }

  Widget _buildStorageFaultBanner(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return Card(
      elevation: 0,
      color: cs.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.licenseStorageFault,
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onErrorContainer,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOrError(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    if (_reloadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text(
                l10n.licenseLoadError,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildReloadErrorCard(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.licenseLoadError,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onErrorContainer,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: _reload, child: Text(l10n.retry)),
        ],
      ),
    );
  }

  List<Widget> _buildStateSpecificLayout(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    final status = _state?.status;

    // 1. LICENSED STATE: Status card first, collapsed Details, Remove key.
    // Key input is NOT shown.
    if (status == EntitlementStatus.licensed) {
      return [
        _buildLicensedStatusCard(context, l10n, cs),
        const SizedBox(height: 16),
        _buildCollapsedDetails(context, l10n, cs, textTheme),
        if (_hasStoredKey) ...[
          const SizedBox(height: 24),
          _buildRemoveKeyButton(l10n, cs, textTheme),
        ],
      ];
    }

    // 2. TRIAL ACTIVE STATE: Banner with days left, key input card, Help & support,
    // collapsed Free-vs-Pro, collapsed Details.
    if (status == EntitlementStatus.trialActive) {
      return [
        _buildTrialBanner(l10n, cs, textTheme),
        const SizedBox(height: 16),
        _buildKeyInputCard(),
        const SizedBox(height: 16),
        _buildHelpAndSupportCard(context, l10n, cs, textTheme),
        const SizedBox(height: 16),
        _buildCollapsedFreeVsPro(l10n, cs, textTheme),
        const SizedBox(height: 16),
        _buildCollapsedDetails(context, l10n, cs, textTheme),
      ];
    }

    // 3. TRIAL EXPIRED / LICENSE EXPIRED / LICENSE REVOKED:
    // State banner, key input card FIRST, Help & support, collapsed Details.
    return [
      _buildExpiredOrRevokedBanner(l10n, cs, textTheme),
      const SizedBox(height: 16),
      _buildKeyInputCard(),
      const SizedBox(height: 16),
      _buildHelpAndSupportCard(context, l10n, cs, textTheme),
      const SizedBox(height: 16),
      _buildCollapsedDetails(context, l10n, cs, textTheme),
      if (_hasStoredKey) ...[
        const SizedBox(height: 24),
        _buildRemoveKeyButton(l10n, cs, textTheme),
      ],
    ];
  }

  Widget _buildLicensedStatusCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _row(context, l10n.licenseStatusLabel, _statusLabel(l10n)),
            const Divider(height: 1),
            _row(context, l10n.licenseTypeLabel, _typeLabel(l10n)),
            const Divider(height: 1),
            _row(context, l10n.licenseExpiryLabel, _expiryLabel(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialBanner(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    final days = _state?.trialDaysRemaining ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.trialActiveStatusWithDays(days),
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredOrRevokedBanner(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    final status = _state?.status;
    final message = status == EntitlementStatus.trialExpired
        ? l10n.trialExpiredStatusMessage
        : _statusLabel(l10n);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_off_outlined, size: 20, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInputCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ActivationKeyInputWidget(showHeader: true, onActivated: _reload),
      ),
    );
  }

  Widget _buildHelpAndSupportCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent_rounded, size: 22, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.supportCardTitle,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.supportCardSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchEmail(context, l10n),
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: Text(l10n.contactEmailAction),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchWhatsApp(context, l10n),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: Text(l10n.whatsappSupportAction),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedFreeVsPro(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Icon(Icons.compare_arrows_rounded, color: cs.primary),
          title: Text(
            l10n.freeVsProComparisonTitle,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            l10n.seeFreeVsPro,
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [_buildSectionFreeVsPro(l10n, cs, textTheme)],
        ),
      ),
    );
  }

  Widget _buildSectionFreeVsPro(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    final free = Feature.values
        .where(FeatureAccess.freeFeatures.contains)
        .toList(growable: false);
    final pro = Feature.values
        .where(FeatureAccess.proFeatures.contains)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.freeVsProIntroText,
          style: textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),

        // 1. Free list
        Text(
          l10n.freeTierHeader,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.secondary,
          ),
        ),
        const SizedBox(height: 6),
        for (final f in free)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: cs.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _featureLabel(f, l10n),
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // 2. Pro list
        Text(
          l10n.proTierHeader,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 6),
        for (final f in pro)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(Icons.star_outline_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _featureLabel(f, l10n),
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCollapsedDetails(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Icon(Icons.info_outline_rounded, color: cs.primary),
          title: Text(
            l10n.licenseDetailsTitle,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            l10n.licenseDetailsSubtitle,
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (_storageFault) ...[
              Card(
                elevation: 0,
                color: cs.errorContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: cs.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.licenseStorageFault,
                          style: textTheme.bodySmall?.copyWith(
                            color: cs.onErrorContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Device model & ID
            if (_deviceModel != null && _deviceModel!.isNotEmpty) ...[
              _row(context, l10n.deviceModelLabel, _deviceModel!),
              const Divider(height: 1),
            ],
            if (_state?.deviceId != null && _state!.deviceId.isNotEmpty) ...[
              _rowWithCopy(context, l10n.deviceIdLabel, _state!.deviceId, l10n),
              const Divider(height: 1),
            ],
            const SizedBox(height: 10),

            // Transfer notice
            Text(
              l10n.transferNoticeTitle,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.transferNoticeBody,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Expiry notes
            Text(
              l10n.licenseOnExpiryTitle,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.licenseOnExpiryBody,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoveKeyButton(
    AppLocalizations l10n,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _removeKey,
        icon: _busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.error,
                ),
              )
            : Icon(Icons.delete_outline, color: cs.error),
        label: Text(
          l10n.removeKeyFromDevice,
          style: textTheme.labelLarge?.copyWith(
            color: cs.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cs.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowWithCopy(
    BuildContext context,
    String label,
    String value,
    AppLocalizations l10n,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value.length > 14
                  ? '${value.substring(0, 8)}…${value.substring(value.length - 4)}'
                  : value,
              style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: l10n.copyDeviceId,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              AppSnackBar.show(context, l10n.deviceIdCopied);
            },
          ),
        ],
      ),
    );
  }
}
