import 'package:flutter/services.dart';
import '../localization/app_localizations.dart';

/// Centralized utility for date formatting, parsing, digit normalization,
/// and input masking with strict Western digit enforcement.
class AppDateUtils {
  AppDateUtils._();

  static const String arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const String persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  static const String westernDigits = '0123456789';

  /// Converts any Arabic-Indic (٠-٩) or Persian (۰-۹) digits in [input]
  /// to standard Western digits (0-9).
  static String normalizeDigits(String input) {
    var result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(arabicIndicDigits[i], westernDigits[i]);
      result = result.replaceAll(persianDigits[i], westernDigits[i]);
    }
    return result;
  }

  /// Normalizes date separators ('-', '.') to standard slash ('/').
  static String normalizeSeparators(String input) {
    return input.replaceAll('-', '/').replaceAll('.', '/');
  }

  /// Normalizes both digits and separators, trimming leading/trailing whitespace.
  static String normalizeInput(String input) {
    return normalizeSeparators(normalizeDigits(input.trim()));
  }

  /// Formats [date] strictly using Western digits `YYYY/MM/DD` (e.g. `2026/11/09`).
  static String formatDate(DateTime? date, {String fallback = '—'}) {
    if (date == null) return fallback;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  /// Formats [date] strictly using Western digits `DD/MM/YYYY` (e.g. `09/11/2026`).
  static String formatDateDayMonthYear(
    DateTime? date, {
    String fallback = '—',
  }) {
    if (date == null) return fallback;
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  /// Formats [date] with time in DD/MM/YYYY format: `DD/MM/YYYY HH:mm` in Western digits.
  static String formatDateTimeDayMonthYear(
    DateTime? date, {
    String fallback = '—',
  }) {
    if (date == null) return fallback;
    final dmy = formatDateDayMonthYear(date);
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dmy $h:$min';
  }

  /// Formats [date] with seconds in DD/MM/YYYY format: `DD/MM/YYYY HH:mm:ss` in Western digits.
  static String formatTimestampDayMonthYear(
    DateTime? date, {
    String fallback = '—',
  }) {
    if (date == null) return fallback;
    final dmy = formatDateDayMonthYear(date);
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    return '$dmy $h:$min:$s';
  }

  /// Formats [date] with time: `YYYY/MM/DD HH:mm` in Western digits.
  static String formatDateTime(DateTime? date, {String fallback = '—'}) {
    if (date == null) return fallback;
    final ymd = formatDate(date);
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$ymd $h:$min';
  }

  /// Formats [date] with full seconds: `YYYY/MM/DD HH:mm:ss` in Western digits.
  static String formatTimestamp(DateTime? date, {String fallback = '—'}) {
    if (date == null) return fallback;
    final ymd = formatDate(date);
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    return '$ymd $h:$min:$s';
  }

  /// Formats [date] in short day/month format: `DD/MM` in Western digits.
  static String formatDateShort(DateTime? date, {String fallback = '—'}) {
    if (date == null) return fallback;
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  /// Formats date range label (e.g. `2026/11/01 – 2026/11/09`).
  static String formatDateRange(DateTime from, DateTime to) {
    return '${formatDate(from)} – ${formatDate(to)}';
  }

  /// Returns true if [year] is a leap year.
  static bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Returns the number of days in [month] for [year], accounting for leap years.
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      return isLeapYear(year) ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month < 1 || month > 12) return 0;
    return days[month];
  }

  /// Validates calendar bounds for year, month, and day.
  static bool isValidDateBounds(int year, int month, int day) {
    if (year < 1900 || year > 2100) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1) return false;
    final maxDays = daysInMonth(year, month);
    return day <= maxDays;
  }

  /// Parses a date string supporting Western & Arabic/Persian digits and
  /// '/', '-', '.' separators.
  ///
  /// Supports both `YYYY/MM/DD` and `DD/MM/YYYY`.
  /// Performs strict calendar validation (leap years, 30/31-day months).
  /// Returns `null` if the string cannot be parsed into a real calendar date.
  static DateTime? parseDate(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final normalized = normalizeInput(input);
    final parts = normalized.split('/');
    if (parts.length != 3) return null;

    final p0 = int.tryParse(parts[0]);
    final p1 = int.tryParse(parts[1]);
    final p2 = int.tryParse(parts[2]);
    if (p0 == null || p1 == null || p2 == null) return null;

    int year;
    int month;
    int day;

    if (parts[0].length == 4 || p0 > 1000) {
      // YYYY/MM/DD format
      year = p0;
      month = p1;
      day = p2;
    } else if (parts[2].length == 4 || p2 > 1000) {
      // DD/MM/YYYY format
      day = p0;
      month = p1;
      year = p2;
    } else {
      // Ambiguous 2-digit year: if first part > 31, assume YY/MM/DD
      if (p0 > 31) {
        year = 2000 + p0;
        month = p1;
        day = p2;
      } else {
        // default to DD/MM/YY
        day = p0;
        month = p1;
        year = 2000 + p2;
      }
    }

    if (!isValidDateBounds(year, month, day)) return null;

    final result = DateTime(year, month, day);
    if (result.year != year || result.month != month || result.day != day) {
      return null;
    }
    return result;
  }

  /// Validates date input string and returns localized error string or null if valid.
  static String? validateDate(
    String? input, {
    AppLocalizations? l10n,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    if (input == null || input.trim().isEmpty) {
      return null;
    }

    final date = parseDate(input);
    if (date == null) {
      return l10n?.invalidDate ?? 'تاريخ غير صحيح (سنة/شهر/يوم)';
    }

    if (firstDate != null) {
      final start = DateTime(firstDate.year, firstDate.month, firstDate.day);
      if (date.isBefore(start)) {
        return l10n?.dateOutOfRange ?? 'التاريخ خارج النطاق المسموح';
      }
    }

    if (lastDate != null) {
      final end = DateTime(
        lastDate.year,
        lastDate.month,
        lastDate.day,
        23,
        59,
        59,
        999,
      );
      if (date.isAfter(end)) {
        return l10n?.dateOutOfRange ?? 'التاريخ خارج النطاق المسموح';
      }
    }

    return null;
  }

  /// Validates whether [from] date is before or equal to [to] date.
  static bool isValidRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return start.isBefore(end) || start.isAtSameMomentAs(end);
  }
}

/// A [TextInputFormatter] that:
/// - Normalizes Arabic-Indic and Persian digits to Western 0-9.
/// - Normalizes '-' and '.' to '/'.
/// - Auto-inserts '/' while typing in YYYY/MM/DD format.
/// - Safely handles backspaces without getting stuck on slashes.
/// - Limits length to 10 characters (`YYYY/MM/DD`).
class DateTextInputFormatter extends TextInputFormatter {
  const DateTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var rawText = AppDateUtils.normalizeInput(newValue.text);
    // Keep only digits and slashes
    rawText = rawText.replaceAll(RegExp(r'[^0-9/]'), '');

    // If deleting (backspacing)
    if (oldValue.text.length > newValue.text.length) {
      return TextEditingValue(
        text: rawText,
        selection: TextSelection.collapsed(offset: rawText.length),
      );
    }

    final String formatted;
    if (rawText.contains('/')) {
      // Slashes already present (typed, pasted or prefilled): keep that layout
      // (DD/MM/YYYY or YYYY/MM/DD) instead of regrouping the digits as YYYY/MM/DD.
      var cleaned = rawText.replaceAll(RegExp(r'/+'), '/');
      if (cleaned.startsWith('/')) cleaned = cleaned.substring(1);
      final parts = cleaned.split('/');
      final dayFirst = parts[0].length <= 2;
      final limits = dayFirst ? const [2, 2, 4] : const [4, 2, 2];
      final kept = <String>[];
      for (int i = 0; i < parts.length && i < 3; i++) {
        final p = parts[i];
        kept.add(p.length > limits[i] ? p.substring(0, limits[i]) : p);
      }
      var out = kept.join('/');
      final last = kept.length - 1;
      if (parts.length == kept.length &&
          last < 2 &&
          kept[last].length == limits[last]) {
        out += '/';
      }
      formatted = out;
    } else {
      // Digits only: default YYYY/MM/DD masking (up to 8 digits).
      final digits = rawText;
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length && i < 8; i++) {
        buffer.write(digits[i]);
        if (i == 3 || i == 5) {
          buffer.write('/');
        }
      }
      formatted = buffer.toString();
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
