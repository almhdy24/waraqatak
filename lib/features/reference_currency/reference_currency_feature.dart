import '../../core/feature_gate.dart';
import '../../models/exchange_rate.dart';
import '../../models/reference_pricing_types.dart';
import '../../services/reference_pricing_service.dart';

/// Public interface and facade for the Reference Currency Pricing & Exchange Rates feature.
///
/// Encapsulates availability gating (Pro feature), rate access, and safe fallbacks.
/// Core code (catalog, documents, invoices) interacts through this interface.
class ReferenceCurrencyFeature {
  ReferenceCurrencyFeature._();

  /// Whether the Reference Currency feature is available to the current user (active Pro license or trial).
  static bool get isAvailable => FeatureGate.isReferenceCurrencyEnabled;

  /// Throws [ReferencePricingException] with [ReferencePricingError.proFeatureRequired]
  /// if the feature is unavailable.
  static void assertAvailable() {
    if (!isAvailable) {
      throw const ReferencePricingException(
        ReferencePricingError.proFeatureRequired,
        'Exchange rates and reference currency pricing require an active Pro license.',
      );
    }
  }

  /// Fetches registered exchange rates.
  ///
  /// If the feature is unavailable to the current user, returns an empty list
  /// to ensure no reference currency controls or conversions are rendered.
  static Future<List<ExchangeRate>> getRates({bool activeOnly = false}) async {
    if (!isAvailable) return const [];
    return ReferencePricingService.getRates(activeOnly: activeOnly);
  }

  /// Checks if any exchange rates exist.
  ///
  /// Returns `false` if the feature is unavailable.
  static Future<bool> hasRates() async {
    if (!isAvailable) return false;
    return ReferencePricingService.hasRates();
  }

  /// Safe update method gated by Pro entitlement.
  static Future<RepriceResult> updateRateAndReprice(
    String code,
    double newRate,
  ) async {
    assertAvailable();
    return ReferencePricingService.updateRateAndReprice(code, newRate);
  }

  /// Safe recalculate method gated by Pro entitlement.
  static Future<RepriceResult> recalculateAll() async {
    assertAvailable();
    return ReferencePricingService.recalculateAll();
  }

  /// Safe add currency method gated by Pro entitlement.
  static Future<void> addCurrencyWithRate(ExchangeRate entry) async {
    assertAvailable();
    return ReferencePricingService.addCurrencyWithRate(entry);
  }

  /// Safe delete currency method gated by Pro entitlement.
  static Future<bool> deleteCustomCurrency(String code) async {
    assertAvailable();
    return ReferencePricingService.deleteCustomCurrency(code);
  }

  /// Safe active toggle method gated by Pro entitlement.
  static Future<void> setCurrencyActive(String code, bool active) async {
    assertAvailable();
    return ReferencePricingService.setCurrencyActive(code, active);
  }

  /// Safe rounding step getter. Returns 0 (no rounding) if unavailable.
  static Future<int> getRounding() async {
    if (!isAvailable) return 0;
    return ReferencePricingService.getRounding();
  }

  /// Safe rounding step setter gated by Pro entitlement.
  static Future<void> setRounding(int rounding) async {
    assertAvailable();
    return ReferencePricingService.setRounding(rounding);
  }
}
