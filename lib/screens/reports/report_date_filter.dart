import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../models/date_range_filter.dart';

class ReportDateFilter extends StatelessWidget {
  final DateRangeFilter range;
  final ValueChanged<DateRangeFilter> onChanged;

  const ReportDateFilter({super.key, required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final presets = [
      (DateRangePreset.today,         l10n.today),
      (DateRangePreset.last7Days,     l10n.last7Days),
      (DateRangePreset.thisMonth,     l10n.thisMonth),
      (DateRangePreset.previousMonth, l10n.previousMonth),
    ];

    // Scrolls when the chips are wider than the screen (long labels,
    // narrow phones).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          ...presets.map((p) {
            final selected = range.preset == p.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(p.$2, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => onChanged(_filterFor(p.$1)),
                visualDensity: VisualDensity.compact,
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
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  DateRangeFilter _filterFor(DateRangePreset preset) => switch (preset) {
    DateRangePreset.today         => DateRangeFilter.today(),
    DateRangePreset.last7Days     => DateRangeFilter.last7Days(),
    DateRangePreset.thisMonth     => DateRangeFilter.thisMonth(),
    DateRangePreset.previousMonth => DateRangeFilter.previousMonth(),
    DateRangePreset.custom        => range,
  };

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: range.from, end: range.to),
    );
    if (picked != null) {
      onChanged(DateRangeFilter.custom(picked.start, picked.end));
    }
  }
}
