import 'package:flutter/foundation.dart';
import '../models/entitlement.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';

/// Central feature entitlement gate for Waraqatak.
///
/// Answers whether a feature is available for the current installation based
/// on active Pro license or trial status. Free users (unlicensed, expired trial,
/// expired license, revoked license) are locked out of Pro features.
class FeatureGate {
  FeatureGate._();

  static EntitlementState? _cachedEntitlement;
  static bool? _overrideProForTesting;

  /// Sets or updates the in-memory cached entitlement state.
  static void setEntitlement(EntitlementState? state) {
    _cachedEntitlement = state;
  }

  /// Current cached entitlement state (if loaded).
  static EntitlementState? get currentEntitlement => _cachedEntitlement;

  /// Refreshes entitlement state directly from [LicenseService].
  static Future<EntitlementState> refresh({bool force = false}) async {
    final state = await LicenseService.instance.checkEntitlement(force: force);
    _cachedEntitlement = state;
    return state;
  }

  /// Synchronously returns whether [feature] is available for the current user.
  static bool isAvailable(Feature feature) {
    if (_overrideProForTesting != null) {
      if (!FeatureAccess.isPro(feature)) return true;
      return _overrideProForTesting!;
    }
    return FeatureAccess.canAccess(feature, _cachedEntitlement);
  }

  /// Whether Reference Currency pricing (exchange rates) is accessible.
  static bool get isReferenceCurrencyEnabled =>
      isAvailable(Feature.referenceCurrency);

  /// Whether Wholesale / Retail tiered pricing is accessible.
  static bool get isWholesalePricingEnabled =>
      isAvailable(Feature.wholesalePricing);

  /// Overrides Pro status for testing.
  @visibleForTesting
  static void setOverrideForTesting(bool? isPro) {
    _overrideProForTesting = isPro;
  }

  /// Resets testing overrides and cached entitlement state.
  @visibleForTesting
  static void resetForTesting() {
    _overrideProForTesting = null;
    _cachedEntitlement = null;
  }
}
