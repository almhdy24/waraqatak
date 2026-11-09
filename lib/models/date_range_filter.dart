import '../localization/app_localizations.dart';
import '../utils/date_format_utils.dart';

enum DateRangePreset {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  last7Days,
  previousMonth,
  custom,
}

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

  factory DateRangeFilter.yesterday() {
    final now = DateTime.now();
    final y = now.subtract(const Duration(days: 1));
    return DateRangeFilter._(
      preset: DateRangePreset.yesterday,
      from: DateTime(y.year, y.month, y.day),
      to: DateTime(y.year, y.month, y.day, 23, 59, 59, 999),
    );
  }

  factory DateRangeFilter.thisWeek() {
    final now = DateTime.now();
    // Week starting Saturday (common in the region):
    final daysToSubtract = (now.weekday + 1) % 7;
    final start = DateTime(now.year, now.month, now.day - daysToSubtract);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return DateRangeFilter._(
      preset: DateRangePreset.thisWeek,
      from: start,
      to: end,
    );
  }

  factory DateRangeFilter.last7Days() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final start = DateTime(now.year, now.month, now.day - 6);
    return DateRangeFilter._(
      preset: DateRangePreset.last7Days,
      from: start,
      to: end,
    );
  }

  factory DateRangeFilter.thisMonth() {
    final now = DateTime.now();
    return DateRangeFilter._(
      preset: DateRangePreset.thisMonth,
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );
  }

  factory DateRangeFilter.lastMonth() {
    final now = DateTime.now();
    final firstDayPrev = DateTime(now.year, now.month - 1, 1);
    final lastDayPrev = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
    return DateRangeFilter._(
      preset: DateRangePreset.lastMonth,
      from: firstDayPrev,
      to: lastDayPrev,
    );
  }

  factory DateRangeFilter.previousMonth() => DateRangeFilter.lastMonth();

  factory DateRangeFilter.thisYear() {
    final now = DateTime.now();
    return DateRangeFilter._(
      preset: DateRangePreset.thisYear,
      from: DateTime(now.year, 1, 1),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );
  }

  factory DateRangeFilter.custom(DateTime from, DateTime to) {
    // Enforce invariant: from <= to
    final actualFrom = from.isAfter(to) ? to : from;
    final actualTo = from.isAfter(to) ? from : to;
    return DateRangeFilter._(
      preset: DateRangePreset.custom,
      from: DateTime(actualFrom.year, actualFrom.month, actualFrom.day),
      to: DateTime(actualTo.year, actualTo.month, actualTo.day, 23, 59, 59, 999),
    );
  }

  String label(AppLocalizations l10n) {
    return switch (preset) {
      DateRangePreset.today => l10n.today,
      DateRangePreset.yesterday => l10n.yesterday,
      DateRangePreset.thisWeek => l10n.thisWeek,
      DateRangePreset.last7Days => l10n.last7Days,
      DateRangePreset.thisMonth => l10n.thisMonth,
      DateRangePreset.lastMonth => l10n.lastMonth,
      DateRangePreset.previousMonth => l10n.previousMonth,
      DateRangePreset.thisYear => l10n.thisYear,
      DateRangePreset.custom =>
        AppDateUtils.formatDateRange(from, to),
    };
  }
}
