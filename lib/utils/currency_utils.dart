import '../localization/app_localizations.dart';

class CurrencyUtils {
  static const List<String> allMethods = [
    'cash', 'bank', 'card', 'mobile', 'bankak', 'okash', 'mada', 'fawry', 'paypal',
  ];

  static String getPaymentMethodLabel(
    String method,
    AppLocalizations l10n, {
    String? customLabelAr,
    String? customLabelEn,
  }) {
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
      default:
        if (l10n.langCode == 'ar' && customLabelAr != null) return customLabelAr;
        if (l10n.langCode != 'ar' && customLabelEn != null) return customLabelEn;
        return method;
    }
  }

  static bool isPaymentMethodAllowed(String method, String currencyCode) => true;
}
