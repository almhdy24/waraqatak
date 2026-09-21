import 'package:intl/intl.dart';

/// UI plan model populated from server Products→Plans→Prices.
///
/// [priceSDG] is the server price — the real final amount the user pays.
/// [originalPriceSDG] is a client-computed marketing reference price for
/// display only; it is never sent to the backend.
/// [priceId] is the server Price.id required for order creation.
class SubscriptionPlan {
  final String id;
  final String nameAr;
  final String nameEn;

  /// Server price in SDG — the real checkout amount. Never modify.
  final double priceSDG;

  /// Client-computed marketing reference price for display only.
  /// Calculated by [MarketingPricing]. NEVER sent to the backend.
  final double? originalPriceSDG;

  final int durationDays;
  final bool isMostPopular;

  /// Server Price.id — required for [SubscriptionService.createOrder].
  final int? priceId;

  const SubscriptionPlan({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.priceSDG,
    this.originalPriceSDG,
    required this.durationDays,
    this.isMostPopular = false,
    this.priceId,
  });

  bool get hasDiscount =>
      originalPriceSDG != null && originalPriceSDG! > priceSDG;

  double? get savingsSDG =>
      hasDiscount ? originalPriceSDG! - priceSDG : null;

  /// Cost per month (approximate — based on 30-day months).
  double get monthlyEquivalentSDG => priceSDG / (durationDays / 30.0);

  String name(String langCode) => langCode == 'ar' ? nameAr : nameEn;

  SubscriptionPlan copyWith({bool? isMostPopular}) => SubscriptionPlan(
        id: id,
        nameAr: nameAr,
        nameEn: nameEn,
        priceSDG: priceSDG,
        originalPriceSDG: originalPriceSDG,
        durationDays: durationDays,
        isMostPopular: isMostPopular ?? this.isMostPopular,
        priceId: priceId,
      );

  static final _fmt = NumberFormat('#,###');
  static String fmt(double v) => _fmt.format(v);
}
