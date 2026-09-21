// TEMPORARY: Client-side marketing reference-price display.
// The Elmahdi API currently does not expose discount/compare-at pricing.
// When the backend adds real discount fields, remove this file and use server data.
// The reference price is NEVER sent to the backend. Only the server price is used
// for checkout.

enum PlanDurationType { monthly, semiAnnual, annual }

class MarketingPricing {
  // Temporary client-side discount percentages per plan duration.
  static const double _monthly = 0.10;
  static const double _semiAnnual = 0.17;
  static const double _annual = 0.25;

  /// Returns a clean, rounded reference/original price for display only.
  /// Formula: referencePrice = serverPrice / (1 − discountRate), rounded to
  /// the nearest 1,000 SDG.
  /// Returns null for unrecognised plan types — show server price only.
  /// NEVER send this value to the backend.
  static double? referencePrice(double serverPrice, PlanDurationType? type) {
    final rate = _rate(type);
    if (rate == null) return null;
    return _roundSdg(serverPrice / (1 - rate));
  }

  /// Returns the rounded display savings (referencePrice − serverPrice).
  /// Returns null when no reference price applies.
  static double? savings(double serverPrice, PlanDurationType? type) {
    final ref = referencePrice(serverPrice, type);
    if (ref == null) return null;
    return _roundSdg(ref - serverPrice);
  }

  /// Infers plan duration type from the server-provided plan name.
  /// Supports Arabic and English naming conventions.
  /// Returns null for unrecognised durations — no marketing discount applied.
  static PlanDurationType? inferFromName(String name) {
    final n = name.toLowerCase().trim();

    // Annual / yearly — check before generic "month" to avoid false matches
    if (n.contains('annual') || n.contains('yearly') || n.contains('year') ||
        n.contains('سنو')) {
      return PlanDurationType.annual;
    }

    // 6 months / semi-annual
    if ((n.contains('6') && (n.contains('month') || n.contains('شهر'))) ||
        n.contains('semi') ||
        n.contains('ستة أشهر') ||
        n.contains('ست أشهر') ||
        n.contains('٦ أشهر')) {
      return PlanDurationType.semiAnnual;
    }

    // Monthly (single month — not 3-month or 6-month)
    if ((n.contains('month') || n.contains('شهر') || n.contains('شهري')) &&
        !n.contains('3') &&
        !n.contains('٣') &&
        !n.contains('6') &&
        !n.contains('٦')) {
      return PlanDurationType.monthly;
    }

    return null;
  }

  /// Returns the canonical duration in days for a plan duration type.
  static int daysForType(PlanDurationType? type) => switch (type) {
        PlanDurationType.monthly => 30,
        PlanDurationType.semiAnnual => 180,
        PlanDurationType.annual => 365,
        null => 30,
      };

  static double _roundSdg(double v) => (v / 1000).round() * 1000.0;

  static double? _rate(PlanDurationType? type) => switch (type) {
        PlanDurationType.monthly => _monthly,
        PlanDurationType.semiAnnual => _semiAnnual,
        PlanDurationType.annual => _annual,
        null => null,
      };
}
