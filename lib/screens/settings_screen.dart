import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../services/backup_service.dart';
import 'about_screen.dart';
import 'business_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launchPrivacyPolicy(BuildContext context) async {
    final url = Uri.parse(AppConstants.privacyPolicyUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).operationFailed),
          ),
        );
      }
    }
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
          ListTile(
            leading: const Icon(Icons.business),
            title: Text(l10n.businessData),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusinessSetupScreen()),
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
            leading: const Icon(Icons.backup),
            title: Text(l10n.backup),
            subtitle: Text(l10n.backupDescription),
            onTap: () async {
              try {
                await BackupService.createBackup();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.operationSuccessful)),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.operationFailed)),
                  );
                }
              }
            },
          ),
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

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            subtitle: Text(l10n.privacySettingsDescription),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchPrivacyPolicy(context),
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