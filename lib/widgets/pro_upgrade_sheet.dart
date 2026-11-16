import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../screens/activation_screen.dart';
import '../services/analytics/analytics_service.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';

class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        AppLocalizations.of(context).proBadgeLabel,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ProUpgradeSheet extends StatelessWidget {
  final Feature feature;

  const ProUpgradeSheet({super.key, required this.feature});

  static Future<bool> show(BuildContext context, {required Feature feature}) async {
    try {
      AnalyticsService.instance.track(AnalyticsEvent.paywallViewed, {
        'feature': _mapFeature(feature),
      });
    } catch (_) {}

    final proceedToActivation = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ProUpgradeSheet(feature: feature),
    );

    if (proceedToActivation == true && context.mounted) {
      final activated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const ActivationScreen()),
      );
      if (activated == true) {
        LicenseService.instance.invalidateCache();
        return true;
      }
    }
    return false;
  }

  static String _mapFeature(Feature feature) {
    switch (feature) {
      case Feature.multiUser:
        return 'multi_user';
      case Feature.purchases:
        return 'purchases';
      case Feature.inventory:
        return 'inventory';
      case Feature.stocktake:
        return 'stocktake';
      case Feature.referenceCurrency:
        return 'reference_currencies';
      case Feature.advancedReports:
        return 'advanced_reports';
      case Feature.bulkPriceUpdate:
        return 'bulk_pricing';
      case Feature.csvImportExport:
        return 'csv_import_export';
      case Feature.wholesalePricing:
        return 'wholesale_pricing';
      default:
        return feature.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    color: cs.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.proFeatureTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _featureLabel(l10n),
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.proFeaturesActivation,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.getActivationKeyInfo,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _bullet(context, l10n.proIncludesPurchases),
            _bullet(context, l10n.proIncludesInventory),
            _bullet(context, l10n.featureStocktake),
            _bullet(context, l10n.exchangeRates),
            _bullet(context, l10n.proIncludesReports),
            _bullet(context, l10n.pdfSealsSection),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.freeDataAlwaysAvailable,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.enterActivationKeyAction),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _featureLabel(AppLocalizations l10n) {
    return switch (feature) {
      Feature.purchases => l10n.purchases,
      Feature.inventory => l10n.inventory,
      Feature.advancedReports => l10n.proAdvancedReports,
      Feature.stocktake => l10n.featureStocktake,
      Feature.bulkPriceUpdate => l10n.featureBulkPriceUpdate,
      Feature.csvImportExport => l10n.featureCsvImportExport,
      Feature.inventoryAudit => l10n.featureInventoryAudit,
      Feature.referenceCurrency => l10n.exchangeRates,
      Feature.wholesalePricing => l10n.wholesalePricing,
      Feature.multiUser => l10n.usersAndPermissions,
      _ => l10n.proFeatureTitle,
    };
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            Icons.check,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
