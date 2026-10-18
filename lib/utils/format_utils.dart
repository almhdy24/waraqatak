import 'package:intl/intl.dart';

class FormatUtils {
  static final NumberFormat _qtyFormat = NumberFormat('#,##0.####');

  /// Formats a stock or movement quantity with up to 4 decimal places,
  /// omitting redundant trailing zeros.
  /// Preserves integer display (e.g. 2 -> "2").
  /// Preserves fractional values (e.g. 1.5 -> "1.5", 0.25 -> "0.25", 0.125 -> "0.125").
  /// Appends [unit] if provided and non-empty.
  static String formatQuantity(num? quantity, {String? unit}) {
    if (quantity == null) return '0';
    final q = quantity.toDouble();
    if (q.abs() < 1e-9) {
      const zeroStr = '0';
      return (unit != null && unit.trim().isNotEmpty)
          ? '$zeroStr ${unit.trim()}'
          : zeroStr;
    }
    final formatted = _qtyFormat.format(q);
    if (unit != null && unit.trim().isNotEmpty) {
      return '$formatted ${unit.trim()}';
    }
    return formatted;
  }
}
