import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../utils/url_launcher_utils.dart';
import '../widgets/app_icons.dart';
import '../widgets/responsive.dart';
import 'transparency_screen.dart';

/// About screen: what the app does, how to reach support, and legal links.
///
/// Support channels (email, WhatsApp, Facebook, website) are offered for
/// help only. This screen must not mention prices, purchasing or where to
/// get an activation key (see docs/play-compliance.md).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {'subject': l10n.contactEmailSubject},
    );
    await UrlLauncherUtils.launchUri(context, uri);
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.parse(AppConstants.whatsappUrl).replace(
      queryParameters: {'text': l10n.supportWhatsAppGreeting},
    );
    await UrlLauncherUtils.launchUri(context, uri);
  }

  Future<void> _shareApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await SharePlus.instance.share(
      ShareParams(text: '${l10n.shareAppMessage}\n${AppConstants.playStoreUrl}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ResponsiveCenter(
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            final version = info == null
                ? ''
                : '${info.version} (${info.buildNumber})';

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Hero(version: version),
                const SizedBox(height: 16),
                _QuickActions(
                  onRate: () =>
                      UrlLauncherUtils.launch(context, AppConstants.playStoreUrl),
                  onShare: () => _shareApp(context),
                  onSupport: () => _launchWhatsApp(context),
                ),
                const SizedBox(height: 24),

                _SectionTitle(l10n.supportAndContact),
                _Group(children: [
                  _LinkTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: l10n.helpCenter,
                    subtitle: 'almhdy24.com/products/waraqatak/help',
                    onTap: () => UrlLauncherUtils.launch(
                        context, AppConstants.helpCenterUrl),
                  ),
                  _LinkTile(
                    icon: Icons.chat_rounded,
                    iconColor: const Color(0xFF25D366),
                    title: l10n.whatsappSupport,
                    subtitle: l10n.whatsappSupportDesc,
                    onTap: () => _launchWhatsApp(context),
                  ),
                  _LinkTile(
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFFEA4335),
                    title: l10n.contactEmail,
                    subtitle: AppConstants.supportEmail,
                    onTap: () => _launchEmail(context),
                  ),
                  _LinkTile(
                    icon: Icons.facebook_rounded,
                    iconColor: const Color(0xFF1877F2),
                    title: l10n.facebookPage,
                    subtitle: l10n.facebookPageDesc,
                    onTap: () => UrlLauncherUtils.launch(
                        context, AppConstants.facebookPageUrl),
                  ),
                  _LinkTile(
                    icon: Icons.language_rounded,
                    title: l10n.developerWebsite,
                    subtitle: 'almhdy24.com',
                    onTap: () =>
                        UrlLauncherUtils.launch(context, AppConstants.websiteUrl),
                  ),
                ]),
                const SizedBox(height: 24),

                _SectionTitle(l10n.whatYouCanDo),
                _FeatureGrid(features: [
                  _Feature(Icons.receipt_long_rounded, l10n.invoice),
                  _Feature(Icons.request_quote_outlined, l10n.quotation),
                  _Feature(Icons.shopping_cart_outlined, l10n.purchase),
                  _Feature(Icons.payments_outlined, l10n.paymentReceipt),
                  _Feature(Icons.money_off_csred_outlined, l10n.expenseVoucher),
                  _Feature(Icons.picture_as_pdf_outlined, l10n.sharePdf),
                  _Feature(Icons.people_alt_outlined, l10n.customers),
                  _Feature(Icons.inventory_2_outlined, l10n.products),
                  _Feature(Icons.warehouse_outlined, l10n.stock),
                  _Feature(Icons.qr_code_scanner_rounded, l10n.barcodeScanner),
                  _Feature(Icons.bar_chart_rounded, l10n.reports),
                  _Feature(Icons.wifi_off_rounded, l10n.offlineFirst),
                ]),
                const SizedBox(height: 24),

                _SectionTitle(l10n.legalAndPrivacy),
                _Group(children: [
                  _LinkTile(
                    icon: Icons.info_outline,
                    title: l10n.transparencyTitle,
                    subtitle: l10n.seeFreeVsPro,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TransparencyScreen()),
                    ),
                  ),
                  _LinkTile(
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.privacyPolicy,
                    subtitle: l10n.privacySettingsDescription,
                    onTap: () => UrlLauncherUtils.launch(
                        context, AppConstants.privacyPolicyUrl),
                  ),
                  _LinkTile(
                    icon: Icons.gavel_outlined,
                    title: l10n.termsOfUse,
                    subtitle: l10n.termsDescription,
                    onTap: () =>
                        UrlLauncherUtils.launch(context, AppConstants.termsUrl),
                  ),
                  _LinkTile(
                    icon: Icons.delete_sweep_outlined,
                    title: l10n.deleteAccountData,
                    subtitle: l10n.deleteAccountDataDescription,
                    onTap: () => UrlLauncherUtils.launch(
                        context, AppConstants.deleteDataUrl),
                  ),
                  _LinkTile(
                    icon: Icons.description_outlined,
                    title: l10n.openSourceLicenses,
                    subtitle: l10n.openSourceLicensesDescription,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: l10n.appName,
                      applicationVersion: version,
                      applicationLegalese: l10n.openSourceLicensesLegalese,
                    ),
                  ),
                ]),
                const SizedBox(height: 28),
                _Footer(version: version),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final String version;
  const _Hero({required this.version});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const brand = Color(0xFF155E63);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brand, Color(0xFF1F8A8A)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Semantics(
            label: l10n.appLogoLabel,
            image: true,
            // The logo carries its own rounded brand background.
            child: Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SvgPicture.asset('assets/logo.svg'),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.appTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.aboutDescription,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.6,
            ),
          ),
          if (version.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${l10n.version} $version',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Quick actions ───────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final VoidCallback onRate;
  final VoidCallback onShare;
  final VoidCallback onSupport;
  const _QuickActions({
    required this.onRate,
    required this.onShare,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: _Card(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Column(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        action(Icons.star_rate_rounded, l10n.rateApp, onRate),
        const SizedBox(width: 10),
        action(Icons.share_rounded, l10n.shareApp, onShare),
        const SizedBox(width: 10),
        action(Icons.support_agent_rounded, l10n.getHelp, onSupport),
      ],
    );
  }
}

// ─── Building blocks ─────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Card({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 64, color: cs.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LinkTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = iconColor ?? cs.primary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: c, size: 21),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
      ),
      trailing: Icon(
        AppIcons.chevronForward(context),
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  const _Feature(this.icon, this.title);
}

class _FeatureGrid extends StatelessWidget {
  final List<_Feature> features;
  const _FeatureGrid({required this.features});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 3 : 2;
      const gap = 10.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final f in features)
            SizedBox(
              width: width,
              child: _Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(f.icon, size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Footer extends StatelessWidget {
  final String version;
  const _Footer({required this.version});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      children: [
        Text('${l10n.madeBy} ${AppConstants.developerName} · ${AppConstants.developerBrand}',
            textAlign: TextAlign.center, style: muted),
        const SizedBox(height: 4),
        Text('© ${DateTime.now().year} ${AppConstants.developerBrand}',
            textAlign: TextAlign.center, style: muted),
      ],
    );
  }
}
