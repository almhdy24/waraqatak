import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme_mode_scope.dart';
import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/backup_service.dart';
import '../services/license_service.dart';
import '../services/app_diagnostics_service.dart';
import '../utils/url_launcher_utils.dart';
import 'about_screen.dart';
import 'business_setup_screen.dart';
import 'database_diagnostic_screen.dart';
import 'google_drive_backup_screen.dart';
import 'license_screen.dart';
import 'financial_settings_screen.dart';
import 'payment_methods_screen.dart';
import 'pdf_customize_screen.dart';
import '../widgets/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  EntitlementState? _entitlement;
  bool _diagnosticConsent = false;

  @override
  void initState() {
    super.initState();
    _loadEntitlement();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final granted = await AppDiagnosticsService.instance.isConsentGranted();
    if (mounted) setState(() => _diagnosticConsent = granted);
  }

  Future<void> _loadEntitlement() async {
    final s = await LicenseService.instance.checkEntitlement();
    if (mounted) setState(() => _entitlement = s);
  }

  String _entitlementLabel(AppLocalizations l10n) {
    final s = _entitlement;
    if (s == null) return '';

    return switch (s.status) {
      EntitlementStatus.trialActive =>
        '${s.trialDaysRemaining} ${l10n.daysLeftInTrial}',
      EntitlementStatus.licensed =>
        s.licenseExpiresAt != null
            ? '${l10n.licenseExpiresOn} ${s.licenseExpiresAt!.toLocal().toString().split(' ').first}'
            : l10n.activatedStatus,
      EntitlementStatus.trialExpired => l10n.trialExpiredStatus,
      EntitlementStatus.licenseExpired => l10n.licenseExpiredStatus,
      EntitlementStatus.licenseRevoked => l10n.licenseRevokedStatus,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = LanguageProvider.of(context);
    final themeScope = ThemeModeScope.of(context);
    final cs = Theme.of(context).colorScheme;
    Widget section(String title) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 6),
      child: Text(
        title,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );

    final chevronIcon = l10n.isArabic
        ? Icons.chevron_left
        : Icons.chevron_right;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings), centerTitle: true),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ── Activation ──────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(l10n.licenseScreenTitle),
              subtitle: Text(_entitlementLabel(l10n)),
              trailing: Icon(chevronIcon),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LicenseScreen()),
                );
                _loadEntitlement();
              },
            ),
            section(l10n.settingsSectionBusiness),
            ListTile(
              leading: const Icon(Icons.business),
              title: Text(l10n.businessData),
              trailing: Icon(chevronIcon),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessSetupScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(l10n.financialSettings),
              subtitle: Text(l10n.financialSettingsDesc),
              trailing: Icon(chevronIcon),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FinancialSettingsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.payment_outlined),
              title: Text(l10n.paymentMethods),
              subtitle: Text(l10n.configurePaymentMethods),
              trailing: Icon(chevronIcon),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l10n.pdfCustomize),
              subtitle: Text(l10n.pdfCustomizeDesc),
              trailing: Icon(chevronIcon),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfCustomizeScreen()),
              ),
            ),

            section(l10n.settingsSectionAppearance),
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
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(l10n.themeModeLabel),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(l10n.themeLight),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(l10n.themeDark),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(l10n.themeSystem),
                  ),
                ],
                selected: {themeScope?.themeMode ?? ThemeMode.light},
                onSelectionChanged: (s) =>
                    themeScope?.onChangeThemeMode(s.first),
              ),
            ),

            section(l10n.settingsSectionData),
            // Backup & Restore section
            ListTile(
              leading: const Icon(Icons.save_outlined),
              title: Text(l10n.saveBackupTo),
              onTap: () async {
                final proceed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.backupUnencryptedTitle),
                    content: Text(l10n.backupUnencryptedWarning),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.continueAction),
                      ),
                    ],
                  ),
                );
                if (proceed != true) return;
                try {
                  final saved = await BackupService.createBackupUserChosen();
                  if (context.mounted && saved) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.backupSavedTo)));
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
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
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
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: Text(l10n.googleDriveTitle),
              subtitle: Text(l10n.googleDriveSubtitle),
              trailing: Icon(chevronIcon),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GoogleDriveBackupScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(l10n.databaseDiagnosticsTitle),
              subtitle: Text(l10n.databaseDiagnosticsSubtitle),
              trailing: Icon(chevronIcon),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DatabaseDiagnosticScreen(),
                ),
              ),
            ),

            section(l10n.settingsSectionSupport),
            SwitchListTile(
              secondary: const Icon(Icons.bug_report_outlined),
              title: Row(
                children: [
                  Expanded(child: Text(l10n.diagnosticSharingTitle)),
                  IconButton(
                    icon: const Icon(Icons.help_outline, size: 20),
                    tooltip: l10n.diagnosticSharingModalTitle,
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.diagnosticSharingModalTitle),
                          content: SingleChildScrollView(
                            child: Text(l10n.diagnosticSharingModalBody),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                MaterialLocalizations.of(ctx).closeButtonLabel,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              subtitle: Text(l10n.diagnosticSharingDesc),
              value: _diagnosticConsent,
              onChanged: (val) async {
                await AppDiagnosticsService.instance.setConsent(val);
                if (mounted) {
                  setState(() => _diagnosticConsent = val);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              subtitle: Text(l10n.privacySettingsDescription),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => UrlLauncherUtils.launch(
                context,
                AppConstants.privacyPolicyUrl,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.about),
              subtitle: Text(l10n.aboutSubtitle),
              trailing: Icon(chevronIcon),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
