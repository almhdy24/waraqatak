import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';

enum DateRangePreset { today, last7Days, thisMonth, previousMonth, custom }

class DateRangeFilter {
  final DateRangePreset preset;
  final DateTime from;
  final DateTime to;

  const DateRangeFilter._({
    required this.preset,
    required this.from,
    required this.to,
  });

  factory DateRangeFilter.today() {
    final now = DateTime.now();
    return DateRangeFilter._(
      preset: DateRangePreset.today,
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );
  }

  factory DateRangeFilter.last7Days() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final start = DateTime(now.year, now.month, now.day - 6);
    return DateRangeFilter._(preset: DateRangePreset.last7Days, from: start, to: end);
  }

  factory DateRangeFilter.thisMonth() {
    final now = DateTime.now();
    return DateRangeFilter._(
      preset: DateRangePreset.thisMonth,
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );
  }

  factory DateRangeFilter.previousMonth() {
    final now = DateTime.now();
    // Dart DateTime handles year wrapping when month <= 0:
    final firstDayPrev = DateTime(now.year, now.month - 1, 1);
    final lastDayPrev = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
    return DateRangeFilter._(
      preset: DateRangePreset.previousMonth,
      from: firstDayPrev,
      to: lastDayPrev,
    );
  }

  factory DateRangeFilter.custom(DateTime from, DateTime to) {
    return DateRangeFilter._(
      preset: DateRangePreset.custom,
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day, 23, 59, 59, 999),
    );
  }

  String label(AppLocalizations l10n) {
    return switch (preset) {
      DateRangePreset.today => l10n.today,
      DateRangePreset.last7Days => l10n.last7Days,
      DateRangePreset.thisMonth => l10n.thisMonth,
      DateRangePreset.previousMonth => l10n.previousMonth,
      DateRangePreset.custom =>
        '${_fmt.format(from)} – ${_fmt.format(to)}',
    };
  }

  static final _fmt = DateFormat('d/M/yy');
}
