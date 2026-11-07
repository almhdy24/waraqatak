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
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';

/// License & Subscription screen (Settings → License).
///
/// Designed for non-technical users to understand:
/// 1. What the license key is.
/// 2. Current trial or subscription status.
/// 3. Clear steps to obtain a key via WhatsApp (the official channel).
/// 4. Prominent WhatsApp contact action.
/// 5. Authoritative Free vs Pro breakdown derived from [FeatureAccess].
/// 6. Activation input section with inline guidance.
/// 7. Preserved device diagnostics, transfer notes, expiry notes, and removal action.
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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await LicenseService.instance.checkEntitlement(force: true);
    final model = await LicenseService.instance.getDeviceModel();
    if (!mounted) return;
    setState(() {
      _state = s;
      _deviceModel = model;
      _storageFault = LicenseService.instance.hasStorageFault;
    });
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
      EntitlementStatus.trialActive =>
        '${l10n.trialActiveStatus} — ${s.trialDaysRemaining} ${l10n.daysLeftInTrial}',
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
  };

  Future<void> _launchWhatsApp(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final uri = Uri.parse(AppConstants.whatsappUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
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

    setState(() => _busy = true);
    var released = true;
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
    setState(() => _busy = false);
    AppSnackBar.show(
      context,
      released ? l10n.keyRemovedSnack : l10n.keyRemovedServerNotReleased,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.licenseScreenRedesignTitle),
        centerTitle: true,
      ),
      body: ResponsiveCenter(
        child: _state == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                children: [
                  // 1. What is a license key (2 short lines)
                  _buildSectionWhatIsKey(l10n, cs),
                  const SizedBox(height: 18),

                  // 2. Trial status line
                  _buildTrialStatusLine(l10n, cs),
                  const SizedBox(height: 24),

                  // 3. How to get it (numbered steps + official notice)
                  _buildSectionHowToGet(l10n, cs),
                  const SizedBox(height: 20),

                  // 4. Primary WhatsApp button
                  _buildWhatsAppButton(context, l10n),
                  const SizedBox(height: 28),

                  // 5. Free vs Pro explanation
                  _buildSectionFreeVsPro(l10n, cs),
                  const SizedBox(height: 28),

                  // 6. "Already have a key?" activation section
                  ActivationKeyInputWidget(onActivated: _reload),
                  const SizedBox(height: 28),

                  const Divider(height: 32),

                  // 7. Preserved content moved to bottom
                  _buildPreservedBottomContent(context, l10n, cs),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionWhatIsKey(AppLocalizations l10n, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.vpn_key_outlined, size: 22, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.whatIsLicenseKeyTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.whatIsLicenseKeyBody,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTrialStatusLine(AppLocalizations l10n, ColorScheme cs) {
    final s = _state;
    if (s == null) return const SizedBox.shrink();

    // If activated with key: show existing status UI (license type + expiry)
    if (s.status == EntitlementStatus.licensed) {
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
              _row(l10n.licenseStatusLabel, _statusLabel(l10n)),
              const Divider(height: 1),
              _row(l10n.licenseTypeLabel, _typeLabel(l10n)),
              const Divider(height: 1),
              _row(l10n.licenseExpiryLabel, _expiryLabel(l10n)),
            ],
          ),
        ),
      );
    }

    if (s.status == EntitlementStatus.trialActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.trialActiveStatusWithDays(s.trialDaysRemaining),
                style: TextStyle(
                  fontSize: 13,
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

    if (s.status == EntitlementStatus.trialExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_off_outlined, size: 18, color: cs.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.trialExpiredStatusMessage,
                style: TextStyle(
                  fontSize: 13,
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

    // licenseExpired or licenseRevoked
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusLabel(l10n),
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHowToGet(AppLocalizations l10n, ColorScheme cs) {
    final contactName = l10n.isArabic
        ? 'المهدي عبدالله'
        : AppConstants.developerName;

    final steps = [
      l10n.howToGetKeyStep1,
      l10n.howToGetKeyStep2(contactName),
      l10n.howToGetKeyStep3,
      l10n.howToGetKeyStep4,
      l10n.howToGetKeyStep5,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.howToGetKeyTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < steps.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      color: cs.onSurface,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.whatsappOfficialNotice,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsAppButton(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: () => _launchWhatsApp(context, l10n),
        icon: const Icon(Icons.chat_outlined),
        label: Text(
          l10n.contactWhatsAppForActivationButton,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionFreeVsPro(AppLocalizations l10n, ColorScheme cs) {
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
          style: TextStyle(
            fontSize: 13.5,
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        // 1. Free list
        Text(
          l10n.freeTierHeader,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 6),
        for (final f in free)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _featureLabel(f, l10n),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // 2. Pro list
        Text(
          l10n.proTierHeader,
          style: TextStyle(
            fontSize: 15,
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
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPreservedBottomContent(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_storageFault) ...[
          Card(
            elevation: 0,
            color: cs.errorContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.licenseStorageFault,
                      style: TextStyle(
                        color: cs.onErrorContainer,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Device identifiers
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                if (_deviceModel != null && _deviceModel!.isNotEmpty) ...[
                  _row(l10n.deviceModelLabel, _deviceModel!),
                ],
                if (_state?.deviceId != null &&
                    _state!.deviceId.isNotEmpty) ...[
                  if (_deviceModel != null && _deviceModel!.isNotEmpty)
                    const Divider(height: 1),
                  _rowWithCopy(
                    context,
                    l10n.deviceIdLabel,
                    _state!.deviceId,
                    l10n,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Transfer notice
        Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.transferNoticeTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.transferNoticeBody,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Expiry notes
        Text(
          l10n.licenseOnExpiryTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.licenseOnExpiryBody,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),

        // Remove key button (if has stored key)
        if (_hasStoredKey) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _removeKey,
              icon: Icon(Icons.delete_outline, color: cs.error),
              label: Text(
                l10n.removeKeyFromDevice,
                style: TextStyle(color: cs.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value.length > 14
                  ? '${value.substring(0, 8)}…${value.substring(value.length - 4)}'
                  : value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
