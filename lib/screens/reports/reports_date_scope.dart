import 'package:flutter/material.dart';
import '../../models/date_range_filter.dart';

/// Holds the active session date range filter shared across reports.
class ReportsDateNotifier extends ChangeNotifier {
  static final ReportsDateNotifier instance = ReportsDateNotifier();

  DateRangeFilter _range;

  ReportsDateNotifier([DateRangeFilter? initialRange])
    : _range = initialRange ?? DateRangeFilter.thisMonth();

  DateRangeFilter get range => _range;

  void update(DateRangeFilter newRange) {
    if (_range != newRange) {
      _range = newRange;
      notifyListeners();
    }
  }

  void reset() {
    update(DateRangeFilter.thisMonth());
  }
}

/// An InheritedNotifier providing [ReportsDateNotifier] to child widgets.
class ReportsDateScope extends InheritedNotifier<ReportsDateNotifier> {
  const ReportsDateScope({
    super.key,
    required ReportsDateNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ReportsDateNotifier? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ReportsDateScope>()
        ?.notifier;
  }

  static DateRangeFilter of(BuildContext context) {
    return maybeOf(context)?.range ?? ReportsDateNotifier.instance.range;
  }

  static void update(BuildContext context, DateRangeFilter range) {
    final notifier = maybeOf(context) ?? ReportsDateNotifier.instance;
    notifier.update(range);
  }
}
