import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/backup_service.dart';
import '../services/license_service.dart';
import '../utils/print_settings.dart';
import '../utils/url_launcher_utils.dart';
import 'about_screen.dart';
import 'business_setup_screen.dart';
import 'financial_settings_screen.dart';
import 'payment_methods_screen.dart';
import 'subscription_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PaperSize _paperSize = PaperSize.a4;
  EntitlementState? _entitlement;

  @override
  void initState() {
    super.initState();
    _loadPaperSize();
    _loadEntitlement();
  }

  Future<void> _loadPaperSize() async {
    final size = await PrintSettings.getDefaultSize();
    if (mounted) setState(() => _paperSize = size);
  }

  Future<void> _loadEntitlement() async {
    final s = await LicenseService.instance.checkEntitlement();
    if (mounted) setState(() => _entitlement = s);
  }

  String _entitlementLabel(AppLocalizations l10n) {
    final s = _entitlement;
    if (s == null) return '';

    // Order state takes precedence in the label.
    if (s.orderStatus == PendingOrderStatus.pending) return l10n.orderPendingStatus;
    if (s.orderStatus == PendingOrderStatus.rejected) return l10n.orderRejectedStatus;

    return switch (s.status) {
      EntitlementStatus.trialActive =>
          '${s.trialDaysRemaining} ${l10n.daysLeftInTrial}',
      EntitlementStatus.licensed => s.licenseExpiresAt != null
          ? '${l10n.licenseExpiresOn} ${s.licenseExpiresAt!.toLocal().toString().split(' ').first}'
          : l10n.licensedStatus,
      EntitlementStatus.trialExpired   => l10n.trialExpiredStatus,
      EntitlementStatus.licenseExpired => l10n.licenseExpiredStatus,
      EntitlementStatus.licenseRevoked => l10n.licenseRevokedStatus,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = LanguageProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // ── Subscription ────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(l10n.subscription),
            subtitle: Text(_entitlementLabel(l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
              _loadEntitlement();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.business),
            title: Text(l10n.businessData),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusinessSetupScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(l10n.financialSettings),
            subtitle: Text(l10n.financialSettingsDesc),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const FinancialSettingsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.payment_outlined),
            title: Text(l10n.paymentMethods),
            subtitle: Text(l10n.configurePaymentMethods),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.languageLabel),
            trailing: DropdownButton<String>(
              value: provider?.langCode ?? 'ar',
              items: const [
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v != null) provider?.onChangeLanguage(v);
              },
            ),
          ),
          const Divider(),

          // Backup & Restore section
          ListTile(
            leading: const Icon(Icons.save_outlined),
            title: Text(l10n.saveBackupTo),
            onTap: () async {
              try {
                final saved = await BackupService.createBackupUserChosen();
                if (context.mounted && saved) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.backupSavedTo)),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.backupSaveFailed)),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(l10n.restore),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.confirmRestore),
                  content: Text(l10n.restoreWarning),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l10n.restore),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                try {
                  final success = await BackupService.restoreBackup();
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.operationSuccessful)),
                    );
                    // Return to home and reload data
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.operationFailed)),
                    );
                  }
                }
              }
            },
          ),
          const Divider(),

          // Print settings
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: Text(l10n.printSettings),
          ),
          ListTile(
            leading: const SizedBox(width: 24),
            title: Text(l10n.defaultPaperSize),
            trailing: DropdownButton<PaperSize>(
              value: _paperSize,
              items: PaperSize.values.map((size) => DropdownMenuItem(
                value: size,
                child: Text(PrintSettings.labelFor(size, l10n)),
              )).toList(),
              onChanged: (v) async {
                if (v == null) return;
                await PrintSettings.setDefaultSize(v);
                if (mounted) setState(() => _paperSize = v);
              },
            ),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            subtitle: Text(l10n.privacySettingsDescription),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => UrlLauncherUtils.launch(context, AppConstants.privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }
}