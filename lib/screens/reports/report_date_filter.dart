import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../models/date_range_filter.dart';
import '../../utils/date_format_utils.dart';
import '../../widgets/app_date_picker.dart';

/// Reusable report date range filter component with quick chips,
/// a dedicated from/to range badge, and unified Western numerals.
class ReportDateFilter extends StatelessWidget {
  final DateRangeFilter range;
  final ValueChanged<DateRangeFilter> onChanged;

  const ReportDateFilter({
    super.key,
    required this.range,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Quick range presets required:
    // Today, Yesterday, This week, This month, Last month, This year, Custom
    final presets = [
      (DateRangePreset.today, l10n.today),
      (DateRangePreset.yesterday, l10n.yesterday),
      (DateRangePreset.thisWeek, l10n.thisWeek),
      (DateRangePreset.thisMonth, l10n.thisMonth),
      (DateRangePreset.lastMonth, l10n.lastMonth),
      (DateRangePreset.thisYear, l10n.thisYear),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horizontal scrollable quick chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              ...presets.map((p) {
                final selected = range.preset == p.$1;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: FilterChip(
                    label: Text(p.$2, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) => onChanged(_filterFor(p.$1)),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                );
              }),
              FilterChip(
                label: Text(
                  range.preset == DateRangePreset.custom
                      ? range.label(l10n)
                      : l10n.customRange,
                  style: const TextStyle(fontSize: 12),
                ),
                selected: range.preset == DateRangePreset.custom,
                onSelected: (_) => _pickCustom(context),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ],
          ),
        ),

        // Visual From / To range display bar with Western numerals
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _pickCustom(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.fromDate}: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    AppDateUtils.formatDate(range.from),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${l10n.toDate}: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    AppDateUtils.formatDate(range.to),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.edit_calendar_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  DateRangeFilter _filterFor(DateRangePreset preset) => switch (preset) {
    DateRangePreset.today => DateRangeFilter.today(),
    DateRangePreset.yesterday => DateRangeFilter.yesterday(),
    DateRangePreset.thisWeek => DateRangeFilter.thisWeek(),
    DateRangePreset.last7Days => DateRangeFilter.last7Days(),
    DateRangePreset.thisMonth => DateRangeFilter.thisMonth(),
    DateRangePreset.lastMonth => DateRangeFilter.lastMonth(),
    DateRangePreset.previousMonth => DateRangeFilter.previousMonth(),
    DateRangePreset.thisYear => DateRangeFilter.thisYear(),
    DateRangePreset.custom => range,
  };

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await AppDatePicker.showRange(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: range.from, end: range.to),
    );
    if (picked != null) {
      // Validate that start <= end
      final start = picked.start;
      final end = picked.end;
      if (AppDateUtils.isValidRange(start, end)) {
        onChanged(DateRangeFilter.custom(start, end));
      } else {
        onChanged(DateRangeFilter.custom(end, start));
      }
    }
  }
}
