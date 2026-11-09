import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme_mode_scope.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/backup_service.dart';
import '../services/license_service.dart';
import '../services/app_diagnostics_service.dart';
import '../services/app_update_service.dart';
import '../utils/url_launcher_utils.dart';
import 'about_screen.dart';
import 'business_setup_screen.dart';
import 'database_diagnostic_screen.dart';
import 'google_drive_backup_screen.dart';
import 'license_screen.dart';
import 'financial_settings_screen.dart';
import 'exchange_rates_screen.dart';
import 'payment_methods_screen.dart';
import 'pdf_customize_screen.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/backup_password_dialog.dart';
import '../widgets/responsive.dart';
import '../services/access/permission_registry.dart';
import '../services/access/session_manager.dart';
import '../services/analytics/analytics_service.dart';
import '../services/backup_encryption_service.dart';
import '../services/feature_access.dart';
import '../widgets/access/permission_gate.dart';
import '../widgets/access/sensitive_action_gate.dart';
import '../widgets/pro_upgrade_sheet.dart';
import 'access/users_list_screen.dart';
import 'activation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  EntitlementState? _entitlement;
  bool _errorReportingConsent = true;
  bool _analyticsConsent = true;
  bool _wholesalePricingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadEntitlement();
    _loadConsent();
    _loadWholesaleStatus();
  }

  Future<void> _loadWholesaleStatus() async {
    final b = await DatabaseHelper.instance.getFirstBusiness();
    if (mounted) {
      setState(
        () => _wholesalePricingEnabled = b?.wholesalePricingEnabled ?? false,
      );
    }
  }

  Future<void> _loadConsent() async {
    final analyticsGranted = AnalyticsService.instance.isUsageEnabled;
    final errorReportingGranted =
        AnalyticsService.instance.isErrorReportingEnabled;
    if (mounted) {
      setState(() {
        _errorReportingConsent = errorReportingGranted;
        _analyticsConsent = analyticsGranted;
      });
    }
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

  Future<void> _openUsersAndPermissions() async {
    if (FeatureAccess.multiUserRequiresPro) {
      final entitlement = await LicenseService.instance.checkEntitlement();
      if (!FeatureAccess.canAccess(Feature.multiUser, entitlement)) {
        if (!mounted) return;
        final res = await ProUpgradeSheet.show(
          context,
          feature: Feature.multiUser,
        );
        if (res == true && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActivationScreen()),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UsersListScreen()),
    );
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

    final chevronIcon = AppIcons.chevronForward(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings), centerTitle: true),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ── Current User Profile (Multi-User Only) ──────────────────────
            const CurrentUserProfileCard(),

            // ── Activation ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                elevation: 0,
                color: cs.primaryContainer.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.cardRadius,
                  ),
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.workspace_premium_rounded,
                    color: cs.primary,
                    size: 28,
                  ),
                  title: Text(
                    l10n.licenseScreenTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_entitlementLabel(l10n)),
                  trailing: Icon(chevronIcon, color: cs.primary),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LicenseScreen()),
                    );
                    _loadEntitlement();
                  },
                ),
              ),
            ),

            section(l10n.settingsSectionBusiness),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.cardRadius,
                  ),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  children: [
                    PermissionGate(
                      permission: PermissionRegistry.settingsManage,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.business_outlined),
                            title: Text(l10n.businessData),
                            trailing: Icon(chevronIcon),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BusinessSetupScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    PermissionGate(
                      permission: PermissionRegistry.settingsManage,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    PermissionGate(
                      permission: PermissionRegistry.pricingRates,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.currency_exchange_outlined),
                            title: Text(l10n.exchangeRates),
                            subtitle: Text(l10n.exchangeRatesDesc),
                            trailing: Icon(chevronIcon),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ExchangeRatesScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    PermissionGate(
                      permission: PermissionRegistry.paymentMethodsManage,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.payment_outlined),
                            title: Text(l10n.paymentMethods),
                            subtitle: Text(l10n.configurePaymentMethods),
                            trailing: Icon(chevronIcon),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PaymentMethodsScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    PermissionGate(
                      permission: PermissionRegistry.settingsManage,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.picture_as_pdf_outlined),
                            title: Text(l10n.pdfCustomize),
                            subtitle: Text(l10n.pdfCustomizeDesc),
                            trailing: Icon(chevronIcon),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PdfCustomizeScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    PermissionGate(
                      permission: PermissionRegistry.settingsManage,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.storefront_outlined),
                            title: Text(l10n.wholesalePricing),
                            subtitle: Text(l10n.wholesalePricingDesc),
                            value: _wholesalePricingEnabled,
                            onChanged: (v) async {
                              if (!v && _wholesalePricingEnabled) {
                                final proceed = await AppConfirmDialog.show(
                                  context,
                                  title: l10n.wholesalePricing,
                                  message: l10n.wholesalePricingDisableWarning,
                                  confirmLabel: l10n.disableAction,
                                  isDestructive: false,
                                );
                                if (!proceed) return;
                              }
                              if (!mounted) return;
                              setState(() => _wholesalePricingEnabled = v);
                              final b = await DatabaseHelper.instance
                                  .getFirstBusiness();
                              if (b != null) {
                                await DatabaseHelper.instance.updateBusiness(
                                  b.copyWith(wholesalePricingEnabled: v),
                                );
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    PermissionGate(
                      permission: PermissionRegistry.usersManage,
                      child: ListTile(
                        leading: const Icon(Icons.manage_accounts_outlined),
                        title: Text(l10n.usersAndPermissions),
                        subtitle: Text(l10n.usersAndPermissionsDesc),
                        trailing: Icon(chevronIcon),
                        onTap: _openUsersAndPermissions,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            section(l10n.settingsSectionAppearance),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.cardRadius,
                  ),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language_rounded),
                      title: Text(l10n.languageLabel),
                      trailing: DropdownButton<String>(
                        value: provider?.langCode ?? 'ar',
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'ar', child: Text('العربية')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: (v) {
                          if (v != null) provider?.onChangeLanguage(v);
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.dark_mode_outlined),
                      title: Text(l10n.themeModeLabel),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  ],
                ),
              ),
            ),

            section(l10n.settingsSectionData),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.cardRadius,
                  ),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  children: [
                    PermissionGate(
                      permission: PermissionRegistry.backupCreate,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.save_outlined),
                            title: Text(l10n.saveBackupTo),
                            onTap: () async {
                              final password = await BackupPasswordCreateDialog.show(
                                context,
                              );
                              if (password == null) return;
                              if (!context.mounted) return;

                              if (password.isNotEmpty) {
                                final saved = await BackupProgressDialog.show(
                                  context,
                                  title: l10n.saveBackupTo,
                                  message: l10n.backupEncrypting,
                                  operation: (isCancelled) =>
                                      BackupService.createBackupUserChosen(
                                        password: password,
                                        isCancelled: isCancelled,
                                      ),
                                );
                                if (context.mounted && saved) {
                                  AppSnackBar.show(
                                    context,
                                    l10n.backupSavedTo,
                                    severity: AppSnackBarSeverity.success,
                                  );
                                }
                              } else {
                                try {
                                  final saved =
                                      await BackupService.createBackupUserChosen();
                                  if (context.mounted && saved) {
                                    AppSnackBar.show(
                                      context,
                                      l10n.backupSavedTo,
                                      severity: AppSnackBarSeverity.success,
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      l10n.backupSaveFailed,
                                      severity: AppSnackBarSeverity.error,
                                    );
                                  }
                                }
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    PermissionGate(
                      isOwnerOnly: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.restore),
                            title: Text(l10n.restore),
                            onTap: () async {
                              final confirmed = await AppConfirmDialog.show(
                                context,
                                title: l10n.confirmRestore,
                                message: l10n.restoreWarning,
                                confirmLabel: l10n.restore,
                                cancelLabel: l10n.cancel,
                                isDestructive: true,
                              );
                              if (confirmed != true || !context.mounted) return;

                              final authed = await SensitiveActionGate.reauthenticate(
                                context,
                                title: l10n.confirmRestore,
                                message: l10n.restoreWarning,
                                requireOwner: true,
                              );
                              if (!authed || !context.mounted) return;

                              try {
                                final success = await BackupService.restoreBackup(
                                  context: context,
                                );
                                  if (context.mounted && success) {
                                    AppSnackBar.show(
                                      context,
                                      l10n.operationSuccessful,
                                      severity: AppSnackBarSeverity.success,
                                    );
                                    // Return to home and reload data
                                    Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst);
                                  }
                                } on BackupUnsupportedVersionException {
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      l10n.backupUpdateRequired,
                                      severity: AppSnackBarSeverity.error,
                                    );
                                  }
                                } on BackupDecryptionException {
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      l10n.backupIncorrectPassword,
                                      severity: AppSnackBarSeverity.error,
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      l10n.operationFailed,
                                      severity: AppSnackBarSeverity.error,
                                    );
                                  }
                                }
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    PermissionGate(
                      isOwnerOnly: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    PermissionGate(
                      isOwnerOnly: true,
                      child: ListTile(
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
                    ),
                  ],
                ),
              ),
            ),

            section(l10n.settingsSectionSupport),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.cardRadius,
                  ),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  children: [
                    PermissionGate(
                      permission: PermissionRegistry.settingsManage,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.analytics_outlined),
                            title: Text(l10n.analyticsConsentTitle),
                            subtitle: Text(l10n.analyticsConsentDesc),
                            value: _analyticsConsent,
                            onChanged: (val) async {
                              await AnalyticsService.instance.setUsageEnabled(val);
                              if (mounted) {
                                setState(() => _analyticsConsent = val);
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          SwitchListTile(
                            secondary: const Icon(Icons.bug_report_outlined),
                            title: Text(l10n.errorReportsConsentTitle),
                            subtitle: Text(l10n.errorReportsConsentDesc),
                            value: _errorReportingConsent,
                            onChanged: (val) async {
                              await AnalyticsService.instance
                                  .setErrorReportingEnabled(val);
                              await AppDiagnosticsService.instance.setConsent(val);
                              if (mounted) {
                                setState(() => _errorReportingConsent = val);
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: Text(l10n.helpCenter),
                      subtitle: Text(l10n.helpCenterSubtitle),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => UrlLauncherUtils.launch(
                        context,
                        AppConstants.helpCenterUrl,
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
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
                    const Divider(height: 1, indent: 16, endIndent: 16),
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
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.system_update_outlined),
                      title: Text(l10n.checkForUpdates),
                      subtitle: Text(l10n.checkForUpdatesSubtitle),
                      trailing: AppUpdateService.instance.isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(chevronIcon),
                      onTap: AppUpdateService.instance.isChecking
                          ? null
                          : () async {
                              setState(() {});
                              await AppUpdateService.instance.checkForUpdate(
                                context: context,
                                manual: true,
                              );
                              if (mounted) setState(() {});
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile card displaying current user information and a logout button.
/// Visible ONLY when Multi-User mode is ON.
class CurrentUserProfileCard extends StatelessWidget {
  const CurrentUserProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionManager.instance,
      builder: (context, _) {
        final session = SessionManager.instance;
        if (!session.isMultiUserEnabled) {
          return const SizedBox.shrink();
        }

        final user = session.currentUser;
        if (user == null) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context);
        final cs = Theme.of(context).colorScheme;

        final roleName = user.isOwner
            ? (l10n.isArabic ? 'المالك' : 'Owner')
            : (user.roleId == 'role-template-admin'
                ? (l10n.isArabic ? 'مدير النظام' : 'Administrator')
                : (user.roleId == 'role-template-salesperson'
                    ? (l10n.isArabic ? 'بائع' : 'Salesperson')
                    : (user.roleId == 'role-template-accountant'
                        ? (l10n.isArabic ? 'محاسب' : 'Accountant')
                        : user.roleId)));

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
              side: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: user.isOwner
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    child: Icon(
                      user.isOwner
                          ? Icons.shield_rounded
                          : Icons.person_outline_rounded,
                      color: user.isOwner
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.username} • $roleName',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('logout_button'),
                    onPressed: () => _handleLogout(context),
                    icon: Icon(Icons.logout_rounded, size: 18, color: cs.error),
                    label: Text(
                      l10n.logout,
                      style: TextStyle(
                        color: cs.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(48, 40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _handleLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.logoutConfirmTitle,
      message: l10n.logoutConfirmMessage,
      confirmLabel: l10n.logout,
      cancelLabel: l10n.cancel,
      isDestructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed) {
      await SessionManager.instance.logout();
    }
  }
}
