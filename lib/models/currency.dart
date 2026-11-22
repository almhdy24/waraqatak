class Currency {
  final String code;
  final String symbol;
  final String nameAr;
  final String nameEn;
  final int decimalDigits;

  const Currency({
    required this.code,
    required this.symbol,
    required this.nameAr,
    required this.nameEn,
    this.decimalDigits = 2,
  });

  static const List<Currency> supportedCurrencies = [
    Currency(
      code: 'SDG',
      symbol: 'ج.س',
      nameAr: 'الجنيه السوداني',
      nameEn: 'Sudanese Pound',
      decimalDigits: 2,
    ),
    Currency(
      code: 'SAR',
      symbol: 'ر.س',
      nameAr: 'الريال السعودي',
      nameEn: 'Saudi Riyal',
      decimalDigits: 2,
    ),
    Currency(
      code: 'AED',
      symbol: 'د.إ',
      nameAr: 'الدرهم الإماراتي',
      nameEn: 'UAE Dirham',
      decimalDigits: 2,
    ),
    Currency(
      code: 'EGP',
      symbol: 'ج.م',
      nameAr: 'الجنيه المصري',
      nameEn: 'Egyptian Pound',
      decimalDigits: 2,
    ),
    Currency(
      code: 'USD',
      symbol: r'$',
      nameAr: 'الدولار الأمريكي',
      nameEn: 'US Dollar',
      decimalDigits: 2,
    ),
  ];

  static Currency fromCode(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies.first,
    );
  }

  static String symbolForCode(String code) => fromCode(code).symbol;

  static int decimalDigitsForCode(String? code) {
    if (code == null || code.trim().isEmpty) return 2;
    final upper = code.trim().toUpperCase();
    for (final c in supportedCurrencies) {
      if (c.code == upper) return c.decimalDigits;
    }
    // Standard ISO 4217 3-decimal currencies (Kuwait, Bahrain, Oman, Jordan, Iraq, Tunisia, Libya)
    if (upper == 'KWD' ||
        upper == 'BHD' ||
        upper == 'OMR' ||
        upper == 'JOD' ||
        upper == 'IQD' ||
        upper == 'TND' ||
        upper == 'LYD') {
      return 3;
    }
    // Standard ISO 4217 0-decimal currencies (Japan, South Korea, etc.)
    if (upper == 'JPY' ||
        upper == 'KRW' ||
        upper == 'CLP' ||
        upper == 'VND' ||
        upper == 'BIF' ||
        upper == 'DJF' ||
        upper == 'GNF' ||
        upper == 'KMF' ||
        upper == 'RWF' ||
        upper == 'UGX') {
      return 0;
    }
    return 2;
  }
}
