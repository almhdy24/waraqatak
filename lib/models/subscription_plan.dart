import 'package:intl/intl.dart';

/// Central subscription plan catalogue — change prices here only.
class SubscriptionPlan {
  final String id;
  final String nameAr;
  final String nameEn;

  /// Current promotional price in SDG.
  final double priceSDG;

  /// Reference (original) price in SDG — shown struck-through when set.
  final double? originalPriceSDG;

  final int durationDays;
  final bool isMostPopular;

  const SubscriptionPlan({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.priceSDG,
    this.originalPriceSDG,
    required this.durationDays,
    this.isMostPopular = false,
  });

  bool get hasDiscount =>
      originalPriceSDG != null && originalPriceSDG! > priceSDG;

  double? get savingsSDG =>
      hasDiscount ? originalPriceSDG! - priceSDG : null;

  /// Cost per month (approximate — based on 30-day months).
  double get monthlyEquivalentSDG => priceSDG / (durationDays / 30.0);

  String name(String langCode) => langCode == 'ar' ? nameAr : nameEn;

  static final _fmt = NumberFormat('#,###');
  static String fmt(double v) => _fmt.format(v);

  // ── Catalogue ──────────────────────────────────────────────────────────────

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: 'monthly',
      nameAr: 'شهري',
      nameEn: 'Monthly',
      priceSDG: 20000,
      durationDays: 30,
    ),
    SubscriptionPlan(
      id: 'quarterly',
      nameAr: '٣ أشهر',
      nameEn: '3 Months',
      priceSDG: 55000,
      originalPriceSDG: 60000,
      durationDays: 90,
    ),
    SubscriptionPlan(
      id: 'biannual',
      nameAr: '٦ أشهر',
      nameEn: '6 Months',
      priceSDG: 100000,
      originalPriceSDG: 120000,
      durationDays: 180,
    ),
    SubscriptionPlan(
      id: 'annual',
      nameAr: 'سنوي',
      nameEn: 'Annual',
      priceSDG: 180000,
      originalPriceSDG: 240000,
      durationDays: 365,
      isMostPopular: true,
    ),
  ];
}
