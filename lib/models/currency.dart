class Currency {
  final String code;
  final String symbol;
  final String nameAr;
  final String nameEn;

  const Currency({
    required this.code,
    required this.symbol,
    required this.nameAr,
    required this.nameEn,
  });

  static const List<Currency> supportedCurrencies = [
    Currency(
      code: 'SDG',
      symbol: 'ج.س',
      nameAr: 'الجنيه السوداني',
      nameEn: 'Sudanese Pound',
    ),
    Currency(
      code: 'SAR',
      symbol: 'ر.س',
      nameAr: 'الريال السعودي',
      nameEn: 'Saudi Riyal',
    ),
    Currency(
      code: 'AED',
      symbol: 'د.إ',
      nameAr: 'الدرهم الإماراتي',
      nameEn: 'UAE Dirham',
    ),
    Currency(
      code: 'EGP',
      symbol: 'ج.م',
      nameAr: 'الجنيه المصري',
      nameEn: 'Egyptian Pound',
    ),
    Currency(
      code: 'USD',
      symbol: r'$',
      nameAr: 'الدولار الأمريكي',
      nameEn: 'US Dollar',
    ),
  ];

  static Currency fromCode(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies.first,
    );
  }

  static String symbolForCode(String code) => fromCode(code).symbol;
}