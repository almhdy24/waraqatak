import 'package:intl/intl.dart';

import 'date_format_utils.dart';
import 'number_input.dart';

class FormatUtils {
  static final NumberFormat _qtyFormat = NumberFormat('#,##0.####');

  /// Formats a [DateTime] into standard user-facing date 'dd/MM/yyyy' in Western digits.
  static String formatDate(DateTime? date, {String fallback = '—'}) {
    return AppDateUtils.formatDateDayMonthYear(date, fallback: fallback);
  }

  /// Formats a [DateTime] into standard user-facing datetime 'dd/MM/yyyy HH:mm' in Western digits.
  static String formatDateTime(DateTime? dateTime, {String fallback = '—'}) {
    return AppDateUtils.formatDateTimeDayMonthYear(dateTime, fallback: fallback);
  }

  /// Formats a [DateTime] into standard timestamp with seconds 'dd/MM/yyyy HH:mm:ss' in Western digits.
  static String formatTimestamp(DateTime? dateTime, {String fallback = '—'}) {
    return AppDateUtils.formatTimestampDayMonthYear(dateTime, fallback: fallback);
  }

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

  /// Parses user-typed numbers. Accepts Arabic digits. ',' '،' are thousands separators; '.' and '٫' are decimal separators. Returns null if empty or invalid.
  static double? parseQuantity(String? text) {
    return NumberInput.parse(text);
  }

  /// Formats a tax rate cleanly, preserving decimal precision without showing
  /// trailing zeros (e.g. 15.0 -> "15%", 15.5 -> "15.5%", 5.25 -> "5.25%").
  static String formatTaxRate(double rate) {
    if (rate % 1 == 0) {
      return '${rate.toStringAsFixed(0)}%';
    }
    return '${NumberFormat('#,##0.##').format(rate)}%';
  }
}
