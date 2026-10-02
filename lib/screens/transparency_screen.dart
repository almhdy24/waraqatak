import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/feature_access.dart';

/// Transparency screen — explicit free-vs-Pro breakdown.
///
/// The list is derived from [FeatureAccess.freeFeatures] and
/// [FeatureAccess.proFeatures] — the single source of truth for Pro gating.
/// Keep the data model in `feature_access.dart`; this screen only renders.
/// Contains no prices, URLs, phone numbers, or acquisition hints.
class TransparencyScreen extends StatelessWidget {
  const TransparencyScreen({super.key});

  static const Map<Feature, IconData> _icons = {
    Feature.invoices: Icons.receipt_long_rounded,
    Feature.quotations: Icons.request_quote_outlined,
    Feature.vouchers: Icons.payments_outlined,
    Feature.customDocuments: Icons.description_outlined,
    Feature.customers: Icons.people_alt_outlined,
    Feature.products: Icons.inventory_2_outlined,
    Feature.barcode: Icons.qr_code_scanner_rounded,
    Feature.basicReports: Icons.bar_chart_rounded,
    Feature.backupRestore: Icons.save_outlined,
    Feature.purchases: Icons.shopping_cart_outlined,
    Feature.inventory: Icons.warehouse_outlined,
    Feature.advancedReports: Icons.analytics_outlined,
  };

  String _label(Feature f, AppLocalizations l10n) => switch (f) {
        Feature.invoices        => l10n.featureInvoices,
        Feature.quotations      => l10n.featureQuotations,
        Feature.vouchers        => l10n.featureVouchers,
        Feature.customDocuments => l10n.featureCustomDocuments,
        Feature.customers       => l10n.featureCustomers,
        Feature.products        => l10n.featureProducts,
        Feature.barcode         => l10n.featureBarcode,
        Feature.basicReports    => l10n.featureBasicReports,
        Feature.backupRestore   => l10n.featureBackupRestore,
        Feature.purchases       => l10n.featurePurchases,
        Feature.inventory       => l10n.featureInventory,
        Feature.advancedReports => l10n.featureAdvancedReports,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    // Preserve declaration order from the Feature enum.
    final free = Feature.values
        .where(FeatureAccess.freeFeatures.contains)
        .toList(growable: false);
    final pro = Feature.values
        .where(FeatureAccess.proFeatures.contains)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transparencyTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.transparencyIntro,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader(
            context,
            l10n.transparencyFreeHeader,
            Icons.check_circle_outline,
            cs.primary,
          ),
          const SizedBox(height: 8),
          _group(context, [for (final f in free) (f, _label(f, l10n))],
              accent: cs.primary),
          const SizedBox(height: 24),
          _sectionHeader(
            context,
            l10n.transparencyProHeader,
            Icons.vpn_key_outlined,
            cs.tertiary,
          ),
          const SizedBox(height: 8),
          _group(context, [for (final f in pro) (f, _label(f, l10n))],
              accent: cs.tertiary),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: cs.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.freeDataAlwaysAvailable,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface,
                      height: 1.4,
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

  Widget _sectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    List<(Feature, String)> items, {
    required Color accent,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_icons[items[i].$1] ?? Icons.circle_outlined,
                        size: 18, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i].$2,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1)
              Divider(height: 1, indent: 58, color: cs.outlineVariant),
          ],
        ],
      ),
    );
  }
}
