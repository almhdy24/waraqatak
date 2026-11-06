import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/activation_service.dart';
import '../services/license_service.dart';
import 'activation_screen.dart';
import 'transparency_screen.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';

/// Settings → License.
///
/// Shows the current entitlement in plain language — status, type, expiry
/// (or "no expiry date") — plus a brief note about what happens on expiry.
/// Lets the user open the activation flow, or remove the stored key from
/// this device (with confirmation).
///
/// Contains no pricing, URLs, phone numbers, or acquisition hints.
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
      EntitlementStatus.trialExpired   => l10n.trialExpiredStatus,
      EntitlementStatus.licensed       => l10n.activatedStatus,
      EntitlementStatus.licenseExpired => l10n.licenseExpiredStatus,
      EntitlementStatus.licenseRevoked => l10n.licenseRevokedStatus,
    };
  }

  String _typeLabel(AppLocalizations l10n) {
    final s = _state;
    if (s == null) return '';
    return switch (s.status) {
      EntitlementStatus.trialActive    => l10n.licenseTypeTrial,
      EntitlementStatus.trialExpired   => l10n.licenseTypeTrial,
      EntitlementStatus.licensed       => s.licenseExpiresAt == null
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
    final key = await LicenseService.instance.licenseKey;
    if (key != null && key.isNotEmpty) {
      final deviceId = await LicenseService.instance.getOrCreateDeviceId();
      await ActivationService.deactivate(key, deviceId);
    }
    await LicenseService.instance.clearLicense();
    await _reload();
    if (!mounted) return;
    setState(() => _busy = false);
    AppSnackBar.show(context, l10n.keyRemovedSnack);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.licenseScreenTitle),
        centerTitle: true,
      ),
      body: ResponsiveCenter(child: _state == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_storageFault)
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.errorContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Theme.of(context).colorScheme.onErrorContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).licenseStorageFault,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ActivationScreen()),
                              );
                              await _reload();
                            },
                            child: Text(AppLocalizations.of(context).enterOrChangeKey),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_storageFault) const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _row(l10n.licenseStatusLabel, _statusLabel(l10n)),
                        const Divider(height: 1),
                        _row(l10n.licenseTypeLabel, _typeLabel(l10n)),
                        const Divider(height: 1),
                        _row(l10n.licenseExpiryLabel, _expiryLabel(l10n)),
                        if (_deviceModel != null && _deviceModel!.isNotEmpty) ...[
                          const Divider(height: 1),
                          _row(l10n.deviceModelLabel, _deviceModel!),
                        ],
                        if (_state?.deviceId != null && _state!.deviceId.isNotEmpty) ...[
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
                Text(
                  l10n.licenseOnExpiryTitle,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.licenseOnExpiryBody,
                  style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                      height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ActivationScreen()),
                            );
                            await _reload();
                          },
                    icon: const Icon(Icons.vpn_key_outlined),
                    label: Text(l10n.enterOrChangeKey),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TransparencyScreen()),
                    ),
                    icon: const Icon(Icons.info_outline),
                    label: Text(l10n.seeFreeVsPro),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (_hasStoredKey) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
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
            )),
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
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
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
              style: const TextStyle(
                fontSize: 14,
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
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
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
