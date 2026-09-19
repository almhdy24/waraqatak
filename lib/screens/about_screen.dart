import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../utils/url_launcher_utils.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchWhatsApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await UrlLauncherUtils.launch(
      context,
      'https://wa.me/${AppConstants.whatsappNumber}'
      '?text=${Uri.encodeComponent(l10n.contactMessage)}',
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {'subject': l10n.contactEmailSubject},
    );
    await UrlLauncherUtils.launchUri(context, uri);
  }

  Future<void> _launchFacebook(BuildContext context) async {
    await UrlLauncherUtils.launch(context, AppConstants.facebookPage);
  }

  Future<void> _launchPrivacyPolicy(BuildContext context) async {
    await UrlLauncherUtils.launch(context, AppConstants.privacyPolicyUrl);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.about),
        centerTitle: true,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? '1.0.0';

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _buildHero(context, l10n),
              const SizedBox(height: 32),
              _buildAboutSection(context, l10n),
              const SizedBox(height: 30),
              _buildSectionHeader(
                context,
                icon: Icons.receipt_long_rounded,
                title: l10n.documents,
              ),
              const SizedBox(height: 12),
              _buildFeatureGroup(
                context,
                [
                  _Feature(Icons.receipt_long_rounded, l10n.invoice),
                  _Feature(Icons.shopping_cart_outlined, l10n.purchase),
                  _Feature(Icons.request_quote_outlined, l10n.quotation),
                  _Feature(Icons.payments_outlined, l10n.paymentReceipt),
                  _Feature(Icons.money_off_csred_outlined, l10n.expenseVoucher),
                  _Feature(Icons.description_outlined, l10n.customDocument),
                  _Feature(Icons.picture_as_pdf_outlined, l10n.sharePdf),
                  _Feature(Icons.sync_alt_rounded, l10n.documentStatusTracking),
                  _Feature(Icons.account_balance_wallet_outlined, l10n.paymentTracking),
                  _Feature(Icons.published_with_changes_rounded, l10n.convertToInvoice),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(
                context,
                icon: Icons.business_center_outlined,
                title: l10n.businessData,
              ),
              const SizedBox(height: 12),
              _buildFeatureGroup(
                context,
                [
                  _Feature(Icons.people_alt_outlined, l10n.customers),
                  _Feature(Icons.store_outlined, l10n.suppliers),
                  _Feature(Icons.inventory_2_outlined, l10n.products),
                  _Feature(Icons.warehouse_outlined, l10n.stock),
                  _Feature(Icons.qr_code_scanner_rounded, l10n.barcodeScanner),
                  _Feature(Icons.bar_chart_rounded, l10n.reports),
                  _Feature(Icons.percent_rounded, l10n.taxProfiles),
                  _Feature(Icons.language_rounded, l10n.arabicEnglishSupport),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(
                context,
                icon: Icons.security_outlined,
                title: l10n.backupRestore,
              ),
              const SizedBox(height: 12),
              _buildFeatureGroup(
                context,
                [
                  _Feature(Icons.wifi_off_rounded, l10n.offlineFirst),
                  _Feature(Icons.save_outlined, l10n.saveBackupTo),
                  _Feature(Icons.restore_rounded, l10n.restore),
                  _Feature(Icons.workspace_premium_outlined, l10n.trialFreeDays),
                  _Feature(Icons.shield_outlined, l10n.dataAlwaysSafe),
                ],
              ),
              const SizedBox(height: 30),
              _buildSectionHeader(
                context,
                icon: Icons.support_agent_rounded,
                title: l10n.contact,
              ),
              const SizedBox(height: 12),
              _buildSupportSection(context, l10n),
              const SizedBox(height: 30),
              _buildSectionHeader(
                context,
                icon: Icons.code_rounded,
                title: l10n.developer,
              ),
              const SizedBox(height: 12),
              _buildDeveloperSection(context, l10n),
              const SizedBox(height: 30),
              _buildPrivacySection(context, l10n),
              const SizedBox(height: 32),
              _buildFooter(context, l10n, version),
            ],
          );
        },
      ),
    );
  }

  // ─── Hero ────────────────────────────────────────────
  Widget _buildHero(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(18),
          child: SvgPicture.asset(
            'assets/logo.svg',
            colorFilter: ColorFilter.mode(
              colors.onPrimaryContainer,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.tagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_android_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 7),
              Text(
                l10n.fromYourPhone,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── About Section ──────────────────────────────────
  Widget _buildAboutSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.about,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.aboutDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.65,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Header ─────────────────────────────────
  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  // ─── Feature Group ──────────────────────────────────
  Widget _buildFeatureGroup(BuildContext context, List<_Feature> features) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < features.length; i++) ...[
            _featureRow(context, features[i]),
            if (i < features.length - 1)
              Divider(height: 1, indent: 62, endIndent: 16, color: colors.outlineVariant),
          ],
        ],
      ),
    );
  }

  Widget _featureRow(BuildContext context, _Feature feature) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.icon, size: 19, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature.title,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.check_circle_rounded, size: 19, color: colors.primary),
        ],
      ),
    );
  }

  // ─── Support Section ────────────────────────────────
  Widget _buildSupportSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        _supportTile(
          context: context, // ✅ fixed: named argument
          icon: Icons.chat_rounded,
          title: l10n.contactWhatsApp,
          subtitle: AppConstants.whatsappNumber,
          onTap: () => _launchWhatsApp(context),
        ),
        const SizedBox(height: 10),
        _supportTile(
          context: context, // ✅ fixed
          icon: Icons.email_outlined,
          title: l10n.contactEmail,
          subtitle: AppConstants.supportEmail,
          onTap: () => _launchEmail(context),
        ),
        const SizedBox(height: 10),
        _supportTile(
          context: context, // ✅ fixed
          icon: Icons.facebook_rounded,
          title: l10n.facebook,
          subtitle: null,
          onTap: () => _launchFacebook(context),
        ),
      ],
    );
  }

  Widget _supportTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colors.onPrimaryContainer, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Developer Section ──────────────────────────────
  Widget _buildDeveloperSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        _supportTile(
          context: context,
          icon: Icons.person_rounded,
          title: AppConstants.developerName,
          subtitle: AppConstants.developerBrand,
          onTap: () => UrlLauncherUtils.launch(context, AppConstants.githubUrl),
        ),
        const SizedBox(height: 10),
        _supportTile(
          context: context,
          icon: Icons.language_rounded,
          title: l10n.visitWebsite,
          subtitle: AppConstants.websiteUrl,
          onTap: () => UrlLauncherUtils.launch(context, AppConstants.websiteUrl),
        ),
        const SizedBox(height: 10),
        _supportTile(
          context: context,
          icon: Icons.open_in_new_rounded,
          title: l10n.waraqatakProductPage,
          subtitle: AppConstants.waraqatakProductUrl,
          onTap: () =>
              UrlLauncherUtils.launch(context, AppConstants.waraqatakProductUrl),
        ),
      ],
    );
  }

  // ─── Privacy Section (Link) ─────────────────────────
  Widget _buildPrivacySection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _launchPrivacyPolicy(context),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.privacyPolicy,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.privacySettingsDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Footer ──────────────────────────────────────────
  Widget _buildFooter(BuildContext context, AppLocalizations l10n, String version) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 18),
        Text(
          l10n.appTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${l10n.version} $version',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          '${l10n.madeBy} ${AppConstants.developerName}',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─── Helper data class ───────────────────────────────
class _Feature {
  final IconData icon;
  final String title;
  const _Feature(this.icon, this.title);
}