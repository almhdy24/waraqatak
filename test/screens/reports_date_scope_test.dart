import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/date_range_filter.dart';
import 'package:warqatek/screens/reports/reports_date_scope.dart';

void main() {
  group('ReportsDateNotifier & ReportsDateScope', () {
    test('notifies listeners when range changes', () {
      final notifier = ReportsDateNotifier(DateRangeFilter.thisMonth());
      var callCount = 0;
      notifier.addListener(() => callCount++);

      final newRange = DateRangeFilter.today();
      notifier.update(newRange);

      expect(notifier.range, equals(newRange));
      expect(callCount, equals(1));

      // Same range should not notify
      notifier.update(newRange);
      expect(callCount, equals(1));
    });

    testWidgets('provides active range to descendants through scope', (
      tester,
    ) async {
      final notifier = ReportsDateNotifier(DateRangeFilter.thisMonth());
      DateRangeFilter? observedRange;

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsDateScope(
            notifier: notifier,
            child: Builder(
              builder: (context) {
                observedRange = ReportsDateScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(observedRange?.preset, equals(DateRangePreset.thisMonth));

      notifier.update(DateRangeFilter.today());
      await tester.pump();

      expect(observedRange?.preset, equals(DateRangePreset.today));
    });

    testWidgets('ReportsDateScope.update modifies the scoped notifier', (
      tester,
    ) async {
      final notifier = ReportsDateNotifier(DateRangeFilter.thisMonth());

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsDateScope(
            notifier: notifier,
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ReportsDateScope.update(context, DateRangeFilter.today());
                  },
                  child: const Text('Update'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(notifier.range.preset, equals(DateRangePreset.today));
    });
  });
}
