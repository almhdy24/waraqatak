/// Reference currency model and built-in currency catalog.
library;

/// An item in the built-in reference currency catalog.
class ReferenceCurrencyItem {
  /// ISO currency code (e.g. USD).
  final String code;

  /// Arabic display name.
  final String nameAr;

  /// English display name.
  final String? nameEn;

  /// Currency symbol.
  final String symbol;

  /// Creates a reference currency item.
  const ReferenceCurrencyItem({
    required this.code,
    required this.nameAr,
    this.nameEn,
    required this.symbol,
  });
}

/// Catalog of built-in reference currencies.
abstract final class ReferenceCurrencyCatalog {
  /// List of built-in currencies.
  static const List<ReferenceCurrencyItem> builtIn = [
    ReferenceCurrencyItem(
      code: 'SDG',
      nameAr: 'الجنيه السوداني',
      nameEn: 'Sudanese Pound',
      symbol: 'ج.س',
    ),
    ReferenceCurrencyItem(
      code: 'AED',
      nameAr: 'الدرهم الإماراتي',
      nameEn: 'UAE Dirham',
      symbol: 'د.إ',
    ),
    ReferenceCurrencyItem(
      code: 'USD',
      nameAr: 'الدولار الأمريكي',
      nameEn: 'US Dollar',
      symbol: r'$',
    ),
    ReferenceCurrencyItem(
      code: 'SAR',
      nameAr: 'الريال السعودي',
      nameEn: 'Saudi Riyal',
      symbol: 'ر.س',
    ),
    ReferenceCurrencyItem(
      code: 'EGP',
      nameAr: 'الجنيه المصري',
      nameEn: 'Egyptian Pound',
      symbol: 'ج.م',
    ),
    ReferenceCurrencyItem(
      code: 'EUR',
      nameAr: 'اليورو',
      nameEn: 'Euro',
      symbol: '€',
    ),
    ReferenceCurrencyItem(
      code: 'QAR',
      nameAr: 'الريال القطري',
      nameEn: 'Qatari Riyal',
      symbol: 'ر.ق',
    ),
    ReferenceCurrencyItem(
      code: 'KWD',
      nameAr: 'الدينار الكويتي',
      nameEn: 'Kuwaiti Dinar',
      symbol: 'د.ك',
    ),
    ReferenceCurrencyItem(
      code: 'TRY',
      nameAr: 'الليرة التركية',
      nameEn: 'Turkish Lira',
      symbol: '₺',
    ),
    ReferenceCurrencyItem(
      code: 'GBP',
      nameAr: 'الجنيه الإسترليني',
      nameEn: 'British Pound',
      symbol: '£',
    ),
  ];
}

/// Model representing an exchange rate for reference pricing.
class ExchangeRate {
  /// ISO or custom currency code (e.g. USD).
  final String code;

  /// Arabic display name.
  final String nameAr;

  /// Optional English display name.
  final String? nameEn;

  /// Currency symbol (e.g. $).
  final String symbol;

  /// Exchange rate to convert 1 reference unit into base currency units.
  final double rate;

  /// Whether the exchange rate is active for new product assignments.
  final bool isActive;

  /// Whether the currency was user-defined rather than selected from catalog.
  final bool isCustom;

  /// Timestamp when the rate was last updated.
  final DateTime updatedAt;

  /// Creates an [ExchangeRate].
  const ExchangeRate({
    required this.code,
    required this.nameAr,
    this.nameEn,
    required this.symbol,
    required this.rate,
    this.isActive = true,
    this.isCustom = false,
    required this.updatedAt,
  });

  /// Creates a copy of this [ExchangeRate] with modified fields.
  ExchangeRate copyWith({
    String? code,
    String? nameAr,
    String? nameEn,
    String? symbol,
    double? rate,
    bool? isActive,
    bool? isCustom,
    DateTime? updatedAt,
  }) {
    return ExchangeRate(
      code: code ?? this.code,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      symbol: symbol ?? this.symbol,
      rate: rate ?? this.rate,
      isActive: isActive ?? this.isActive,
      isCustom: isCustom ?? this.isCustom,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts this [ExchangeRate] into a database row map.
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name_ar': nameAr,
      'name_en': nameEn,
      'symbol': symbol,
      'rate': rate,
      'is_active': isActive ? 1 : 0,
      'is_custom': isCustom ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Deserializes an [ExchangeRate] from a database row map.
  factory ExchangeRate.fromMap(Map<String, dynamic> map) {
    return ExchangeRate(
      code: map['code'] as String,
      nameAr: map['name_ar'] as String,
      nameEn: map['name_en'] as String?,
      symbol: map['symbol'] as String,
      rate: (map['rate'] as num).toDouble(),
      isActive: (map['is_active'] as int?) != 0,
      isCustom: (map['is_custom'] as int?) == 1,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
