import '../models/entitlement.dart';

enum Feature {
  // Free — always accessible
  invoices,
  quotations,
  vouchers,
  customDocuments,
  customers,
  products,
  barcode,
  basicReports,
  backupRestore,
  // Pro — require active subscription
  purchases,
  inventory,
  advancedReports,
}

class FeatureAccess {
  FeatureAccess._();

  /// Single source of truth: features that require an active trial or a
  /// stored activation key. The transparency screen, the paywall, the
  /// locked-feature flow, and `docs/free-vs-pro.md` all derive from this
  /// set — do not maintain a parallel list anywhere else.
  static const Set<Feature> proFeatures = {
    Feature.purchases,
    Feature.inventory,
    Feature.advancedReports,
  };

  /// Complement of [proFeatures]: features that are always available,
  /// including after a trial expires or a license is revoked.
  static final Set<Feature> freeFeatures =
      Feature.values.toSet().difference(proFeatures);

  static bool isPro(Feature f) => proFeatures.contains(f);

  // Null entitlement means unavailable or still loading — fail closed for Pro.
  static bool canAccess(Feature f, EntitlementState? entitlement) {
    if (!isPro(f)) return true;
    return entitlement?.isSubscriptionActive ?? false;
  }
}
