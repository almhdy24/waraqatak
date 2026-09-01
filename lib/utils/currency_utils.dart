import '../localization/app_localizations.dart';

class CurrencyUtils {
  static List<String> getPaymentMethodsForCurrency(String currencyCode) {
    switch (currencyCode) {
      case 'SDG':
        return ['cash', 'bank', 'bankak', 'okash'];
      case 'SAR':
        return ['cash', 'bank', 'mada', 'card'];
      case 'AED':
        return ['cash', 'bank', 'card', 'mobile'];
      case 'EGP':
        return ['cash', 'bank', 'fawry', 'card'];
      case 'USD':
        return ['cash', 'bank', 'card', 'paypal'];
      default:
        return ['cash', 'bank'];
    }
  }

  static bool isPaymentMethodAllowed(String method, String currencyCode) {
    return getPaymentMethodsForCurrency(currencyCode).contains(method);
  }

  static String getPaymentMethodLabel(String method, AppLocalizations l10n) {
    switch (method) {
      case 'cash':
        return l10n.cash;
      case 'bank':
        return l10n.bankTransfer;
      case 'bankak':
        return l10n.bankak;
      case 'okash':
        return l10n.okash;
      case 'mada':
        return l10n.mada;
      case 'card':
        return l10n.creditCard;
      case 'mobile':
        return l10n.mobileWallet;
      case 'fawry':
        return l10n.fawry;
      case 'paypal':
        return l10n.paypal;
      default:
        return method;
    }
  }
}