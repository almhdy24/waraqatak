import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-device display preferences for the Quick Sale (POS) screen.
///
/// This preference is strictly per-device and does not affect database records
/// or organization-wide settings.
class QuickSaleSettings extends ChangeNotifier {
  QuickSaleSettings._();

  static final QuickSaleSettings instance = QuickSaleSettings._();

  static const String prefKey = 'quick_sale_show_product_images';
  static const String longPressHintDismissedKey =
      'quick_sale_long_press_hint_dismissed';

  bool _showProductImages = true;
  bool _hasDismissedLongPressHint = false;

  /// Whether product thumbnails are displayed on Quick Sale product tiles.
  bool get showProductImages => _showProductImages;

  /// Whether the user has dismissed the discoverability hint for long-pressing.
  bool get hasDismissedLongPressHint => _hasDismissedLongPressHint;

  /// Loads the setting from [SharedPreferences]. Never throws.
  Future<void> load([SharedPreferences? prefs]) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      _showProductImages = p.getBool(prefKey) ?? true;
      _hasDismissedLongPressHint =
          p.getBool(longPressHintDismissedKey) ?? false;
      notifyListeners();
    } catch (_) {
      // Best-effort startup loading; defaults to true if unreadable.
    }
  }

  /// Updates the setting, notifies listeners, and persists to [SharedPreferences].
  Future<void> setShowProductImages(bool value) async {
    if (_showProductImages == value) return;
    _showProductImages = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, value);
    } catch (_) {
      // Best-effort persistence
    }
  }

  /// Marks the one-time long-press hint as dismissed and persists to [SharedPreferences].
  Future<void> dismissLongPressHint() async {
    if (_hasDismissedLongPressHint) return;
    _hasDismissedLongPressHint = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(longPressHintDismissedKey, true);
    } catch (_) {
      // Best-effort persistence
    }
  }

  /// Testing helper to set the in-memory value without touching [SharedPreferences].
  @visibleForTesting
  void setShowProductImagesForTesting(bool value) {
    _showProductImages = value;
    notifyListeners();
  }

  /// Testing helper to set the dismissed hint in-memory value directly.
  @visibleForTesting
  void setDismissedLongPressHintForTesting(bool value) {
    _hasDismissedLongPressHint = value;
    notifyListeners();
  }
}
