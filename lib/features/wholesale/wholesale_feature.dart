import '../../core/feature_gate.dart';
import '../../localization/app_localizations.dart';
import '../../models/business.dart';

/// Public interface for the Wholesale / Retail Tiered Pricing feature.
///
/// Encapsulates availability gating (Pro feature), category constants,
/// and tier resolution logic. Core business flows (sales, POS, invoicing,
/// product catalog) must depend solely on this public interface rather
/// than checking raw business flags or licensing internals directly.
class WholesaleFeature {
  WholesaleFeature._();

  /// Standard pricing category constants.
  static const String categoryRetail = 'retail';
  static const String categoryWholesale = 'wholesale';

  /// Whether the Wholesale feature is available to the current user (Pro license or trial).
  static bool get isAvailable => FeatureGate.isWholesalePricingEnabled;

  /// Whether wholesale pricing is active for the given business.
  ///
  /// Returns `true` ONLY IF the user is entitled to Pro AND the business
  /// has wholesale pricing enabled in its settings. Free users always evaluate
  /// to `false`, effectively falling back to single retail pricing.
  static bool isEnabledForBusiness(Business? business) {
    if (!isAvailable) return false;
    return business?.wholesalePricingEnabled ?? false;
  }

  /// Evaluates an explicit wholesale boolean flag under current Pro entitlement.
  ///
  /// Returns `false` if the user is Free, regardless of what [businessWholesaleEnabled] says.
  static bool isWholesaleActive(bool? businessWholesaleEnabled) {
    if (!isAvailable) return false;
    return businessWholesaleEnabled ?? false;
  }

  /// Resolves the effective pricing category.
  ///
  /// If wholesale is disabled or unavailable, always resolves to [categoryRetail].
  static String resolveCategory({
    required String? requestedCategory,
    required bool wholesalePricingEnabled,
  }) {
    if (!isWholesaleActive(wholesalePricingEnabled)) {
      return categoryRetail;
    }
    return requestedCategory == categoryWholesale
        ? categoryWholesale
        : categoryRetail;
  }

  /// Returns the localized label for a pricing category.
  static String getCategoryLabel(String? category, AppLocalizations l10n) {
    if (category == categoryWholesale) {
      return l10n.wholesale;
    }
    return l10n.retail;
  }
}
