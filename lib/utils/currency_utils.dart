import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';

class CurrencyUtils {
  static const List<String> allMethods = [
    'cash', 'bank', 'card', 'mobile', 'bankak', 'okash', 'mada', 'fawry', 'paypal',
  ];

  static const List<String> defaultMethods = ['cash', 'bank', 'card', 'mobile'];

  static const String _prefKey = 'payment_methods';

  /// Returns the user-configured payment methods, or defaults if none saved.
  static Future<List<String>> getConfiguredMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefKey);
    if (stored != null && stored.isNotEmpty) return stored;
    return defaultMethods;
  }

  static Future<void> saveConfiguredMethods(List<String> methods) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, methods.isEmpty ? defaultMethods : methods);
  }

  /// Kept for backward compatibility. Now returns all methods regardless of currency.
  static List<String> getPaymentMethodsForCurrency(String currencyCode) => allMethods;

  static bool isPaymentMethodAllowed(String method, String currencyCode) =>
      allMethods.contains(method);

  static String getPaymentMethodLabel(String method, AppLocalizations l10n) {
    switch (method) {
      case 'cash':   return l10n.cash;
      case 'bank':   return l10n.bankTransfer;
      case 'bankak': return l10n.bankak;
      case 'okash':  return l10n.okash;
      case 'mada':   return l10n.mada;
      case 'card':   return l10n.creditCard;
      case 'mobile': return l10n.mobileWallet;
      case 'fawry':  return l10n.fawry;
      case 'paypal': return l10n.paypal;
      default:       return method;
    }
  }
}
