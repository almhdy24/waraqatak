import '../database/database_helper.dart';
import '../models/currency.dart';

/// Central accessor and cache for the application's single base currency.
///
/// Waraqatak runs on strictly ONE base currency per installation, defined
/// in `businesses.currency_code` and locked permanently upon first financial activity.
class CurrencyContext {
  CurrencyContext._();

  static Currency? _cachedCurrency;

  /// Invalidates the cached base currency (e.g. after business settings update).
  static void invalidateCache() {
    _cachedCurrency = null;
  }

  /// Sets the cached base currency explicitly (e.g. after business profile load or in tests).
  static void setCachedCurrency(Currency currency) {
    _cachedCurrency = currency;
  }

  /// Returns the current base currency object, fetching from database if not cached.
  static Future<Currency> getBaseCurrency({DatabaseHelper? db}) async {
    if (_cachedCurrency != null) return _cachedCurrency!;
    final helper = db ?? DatabaseHelper.instance;
    final business = await helper.getFirstBusiness();
    final code = business?.currencyCode.trim();
    final resolvedCode = (code != null && code.isNotEmpty) ? code : 'SDG';
    final currency = Currency.fromCode(resolvedCode);
    _cachedCurrency = currency;
    return currency;
  }

  /// Returns the current base currency code (e.g. 'SDG').
  static Future<String> getBaseCurrencyCode({DatabaseHelper? db}) async {
    final currency = await getBaseCurrency(db: db);
    return currency.code;
  }

  /// Returns the base currency symbol (e.g. 'ج.س').
  static Future<String> getBaseCurrencySymbol({DatabaseHelper? db}) async {
    final currency = await getBaseCurrency(db: db);
    return currency.symbol;
  }

  /// Returns the decimal digits for the base currency (default: 2).
  static Future<int> getBaseCurrencyDecimals({DatabaseHelper? db}) async {
    final currency = await getBaseCurrency(db: db);
    return currency.decimalDigits;
  }

  /// Helper to test if a given document currency matches the base currency.
  /// Null or empty currency is treated as matching the base currency.
  static bool isBaseCurrency(String? code, String baseCurrencyCode) {
    if (code == null || code.trim().isEmpty) return true;
    return code.trim().toUpperCase() == baseCurrencyCode.trim().toUpperCase();
  }
}
