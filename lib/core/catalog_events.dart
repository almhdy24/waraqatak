/// Catalog change notifications.
library;

import 'package:flutter/foundation.dart';

/// Notifier bumped after any committed change to catalog prices.
final class CatalogEvents {
  CatalogEvents._();

  /// ValueNotifier bumped on any committed price changes.
  static final ValueNotifier<int> pricesChanged = ValueNotifier<int>(0);

  /// Notifies listeners that catalog prices have changed in the database.
  static void notifyPricesChanged() => pricesChanged.value++;
}
