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

  static const _proFeatures = {
    Feature.purchases,
    Feature.inventory,
    Feature.advancedReports,
  };

  static bool isPro(Feature f) => _proFeatures.contains(f);

  // Null entitlement means still loading — allow Pro to avoid blocking on startup.
  static bool canAccess(Feature f, EntitlementState? entitlement) {
    if (!isPro(f)) return true;
    return entitlement?.isSubscriptionActive ?? true;
  }
}
