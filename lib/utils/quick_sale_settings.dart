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

  bool _showProductImages = true;

  /// Whether product thumbnails are displayed on Quick Sale product tiles.
  bool get showProductImages => _showProductImages;

  /// Loads the setting from [SharedPreferences]. Never throws.
  Future<void> load([SharedPreferences? prefs]) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      _showProductImages = p.getBool(prefKey) ?? true;
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

  /// Testing helper to set the in-memory value without touching [SharedPreferences].
  @visibleForTesting
  void setShowProductImagesForTesting(bool value) {
    _showProductImages = value;
    notifyListeners();
  }
}
