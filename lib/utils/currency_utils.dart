import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';

class CurrencyUtils {
  static const List<String> allMethods = [
    'cash', 'bank', 'card', 'mobile', 'bankak', 'okash', 'mada', 'fawry', 'paypal',
  ];

  static const List<String> defaultMethods = ['cash', 'bank', 'card', 'mobile'];

  static const String _prefKey = 'payment_methods';
  static const String _customKey = 'custom_payment_methods_v1';

  // ─── Predefined methods ───────────────────────────────────────────────────

  static Future<List<String>> getConfiguredMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final predefined = prefs.getStringList(_prefKey) ?? defaultMethods;
    final custom = await getCustomMethods();
    return [...predefined, ...custom.keys];
  }

  static Future<void> saveConfiguredMethods(List<String> methods) async {
    final prefs = await SharedPreferences.getInstance();
    // Only save predefined keys (custom keys are managed separately)
    final predefinedOnly = methods.where((m) => !m.startsWith('custom_')).toList();
    await prefs.setStringList(_prefKey, predefinedOnly.isEmpty ? defaultMethods : predefinedOnly);
  }

  // ─── Custom methods ───────────────────────────────────────────────────────

  static Future<Map<String, String>> getCustomMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveCustomMethods(Map<String, String> methods) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customKey, jsonEncode(methods));
  }

  static Future<String> addCustomMethod(String label) async {
    final methods = await getCustomMethods();
    final key = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    methods[key] = label.trim();
    await saveCustomMethods(methods);
    // Also add to enabled predefined list (conceptually it's enabled by default)
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getStringList(_prefKey) ?? defaultMethods;
    if (!enabled.contains(key)) {
      await prefs.setStringList(_prefKey, [...enabled, key]);
    }
    return key;
  }

  static Future<void> renameCustomMethod(String key, String newLabel) async {
    final methods = await getCustomMethods();
    if (methods.containsKey(key)) {
      methods[key] = newLabel.trim();
      await saveCustomMethods(methods);
    }
  }

  static Future<void> removeCustomMethod(String key) async {
    final methods = await getCustomMethods();
    methods.remove(key);
    await saveCustomMethods(methods);
    // Also remove from enabled list
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getStringList(_prefKey) ?? defaultMethods;
    await prefs.setStringList(_prefKey, enabled.where((m) => m != key).toList());
  }

  // ─── Label resolution ─────────────────────────────────────────────────────

  static String getPaymentMethodLabel(
    String method,
    AppLocalizations l10n, {
    Map<String, String>? customLabels,
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
        if (customLabels != null && customLabels.containsKey(method)) {
          return customLabels[method]!;
        }
        return method;
    }
  }

  /// Kept for backward compatibility.
  static List<String> getPaymentMethodsForCurrency(String currencyCode) => allMethods;

  static bool isPaymentMethodAllowed(String method, String currencyCode) => true;
}
