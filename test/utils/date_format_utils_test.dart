import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/date_range_filter.dart';
import 'package:warqatek/screens/reports/report_date_filter.dart';
import 'package:warqatek/utils/date_format_utils.dart';
import 'package:warqatek/widgets/app_date_picker.dart';

void main() {
  group('AppDateUtils digit & separator normalization', () {
    test('Normalizes Arabic-Indic digits to Western digits', () {
      expect(AppDateUtils.normalizeDigits('٠١٢٣٤٥٦٧٨٩'), equals('0123456789'));
      expect(
        AppDateUtils.normalizeDigits('٢٠٢٦/١١/٠٩'),
        equals('2026/11/09'),
      );
    });

    test('Normalizes Persian/Eastern Arabic digits to Western digits', () {
      expect(AppDateUtils.normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), equals('0123456789'));
      expect(
        AppDateUtils.normalizeDigits('۲۰۲۶/۱۱/۰۹'),
        equals('2026/11/09'),
      );
    });

    test('Normalizes separators - and . to /', () {
      expect(AppDateUtils.normalizeSeparators('2026-11-09'), equals('2026/11/09'));
      expect(AppDateUtils.normalizeSeparators('2026.11.09'), equals('2026/11/09'));
    });

    test('normalizeInput handles mixed digits, separators, and spaces', () {
      expect(
        AppDateUtils.normalizeInput('  ٢٠٢٦-١١.٠٩  '),
        equals('2026/11/09'),
      );
    });
  });

  group('AppDateUtils formatting', () {
    test('formatDate outputs strictly Western digits YYYY/MM/DD', () {
      final dt = DateTime(2026, 11, 9);
      expect(AppDateUtils.formatDate(dt), equals('2026/11/09'));
      expect(AppDateUtils.formatDate(null), equals('—'));
      expect(AppDateUtils.formatDate(null, fallback: 'None'), equals('None'));
    });

    test('formatDateDayMonthYear outputs strictly Western digits DD/MM/YYYY', () {
      final dt = DateTime(2026, 11, 9);
      expect(AppDateUtils.formatDateDayMonthYear(dt), equals('09/11/2026'));
    });

    test('formatDateTime & formatTimestamp format with Western digits', () {
      final dt = DateTime(2026, 11, 9, 8, 5, 3);
      expect(AppDateUtils.formatDateTime(dt), equals('2026/11/09 08:05'));
      expect(
        AppDateUtils.formatTimestamp(dt),
        equals('2026/11/09 08:05:03'),
      );
    });

    test('formatDateRange formats correctly with Western digits', () {
      final from = DateTime(2026, 11, 1);
      final to = DateTime(2026, 11, 9);
      expect(AppDateUtils.formatDateRange(from, to), equals('2026/11/01 – 2026/11/09'));
    });
  });

  group('AppDateUtils calendar parsing & validation', () {
    test('Parses valid YYYY/MM/DD dates with various separators', () {
      final d1 = AppDateUtils.parseDate('2026/11/09');
      expect(d1, equals(DateTime(2026, 11, 9)));

      final d2 = AppDateUtils.parseDate('2026-11-09');
      expect(d2, equals(DateTime(2026, 11, 9)));

      final d3 = AppDateUtils.parseDate('2026.11.09');
      expect(d3, equals(DateTime(2026, 11, 9)));
    });

    test('Parses Arabic-Indic input seamlessly', () {
      final d = AppDateUtils.parseDate('٢٠٢٦/١١/٠٩');
      expect(d, equals(DateTime(2026, 11, 9)));
    });

    test('Parses DD/MM/YYYY format correctly', () {
      final d = AppDateUtils.parseDate('09/11/2026');
      expect(d, equals(DateTime(2026, 11, 9)));
    });

    test('Validates leap year edge cases', () {
      // 2024 is leap year: Feb 29 is valid
      expect(AppDateUtils.parseDate('2024/02/29'), equals(DateTime(2024, 2, 29)));

      // 2023 is not leap year: Feb 29 is invalid
      expect(AppDateUtils.parseDate('2023/02/29'), isNull);

      // 2000 is leap century: Feb 29 is valid
      expect(AppDateUtils.parseDate('2000/02/29'), equals(DateTime(2000, 2, 29)));

      // 1900 is not leap century: Feb 29 is invalid
      expect(AppDateUtils.parseDate('1900/02/29'), isNull);
    });

    test('Rejects invalid calendar month and day edge cases', () {
      // Month 13
      expect(AppDateUtils.parseDate('2026/13/01'), isNull);
      // Month 0
      expect(AppDateUtils.parseDate('2026/00/01'), isNull);
      // Day 0
      expect(AppDateUtils.parseDate('2026/05/00'), isNull);
      // April 31 (April has only 30 days)
      expect(AppDateUtils.parseDate('2026/04/31'), isNull);
      // June 31 (June has only 30 days)
      expect(AppDateUtils.parseDate('2026/06/31'), isNull);
      // Sept 31 (Sept has only 30 days)
      expect(AppDateUtils.parseDate('2026/09/31'), isNull);
      // Nov 31 (Nov has only 30 days)
      expect(AppDateUtils.parseDate('2026/11/31'), isNull);
      // Year out of bounds
      expect(AppDateUtils.parseDate('1899/01/01'), isNull);
      expect(AppDateUtils.parseDate('2101/01/01'), isNull);
    });

    test('validateDate returns null on valid and Arabic error on invalid', () {
      final l10n = AppLocalizations('ar');

      expect(AppDateUtils.validateDate('2026/11/09', l10n: l10n), isNull);
      expect(
        AppDateUtils.validateDate('2026/02/30', l10n: l10n),
        equals(l10n.invalidDate),
      );
      expect(
        AppDateUtils.validateDate('not-a-date', l10n: l10n),
        equals(l10n.invalidDate),
      );

      // Range check
      final min = DateTime(2026, 1, 1);
      final max = DateTime(2026, 12, 31);
      expect(
        AppDateUtils.validateDate('2025/12/31', l10n: l10n, firstDate: min),
        equals(l10n.dateOutOfRange),
      );
      expect(
        AppDateUtils.validateDate('2027/01/01', l10n: l10n, lastDate: max),
        equals(l10n.dateOutOfRange),
      );
    });
  });

  group('DateTextInputFormatter typing behavior', () {
    const formatter = DateTextInputFormatter();

    test('Auto-inserts slashes as user types YYYYMMDD', () {
      var val = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '2026'),
      );
      expect(val.text, equals('2026/'));

      val = formatter.formatEditUpdate(
        const TextEditingValue(text: '2026/'),
        const TextEditingValue(text: '2026/11'),
      );
      expect(val.text, equals('2026/11/'));

      val = formatter.formatEditUpdate(
        const TextEditingValue(text: '2026/11/'),
        const TextEditingValue(text: '2026/11/09'),
      );
      expect(val.text, equals('2026/11/09'));
    });

    test('Normalizes Arabic digits while typing', () {
      final val = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '٢٠٢٦'),
      );
      expect(val.text, equals('2026/'));
    });

    test('Does not get stuck when backspacing slashes', () {
      // User is at '2026/' and presses backspace
      final val = formatter.formatEditUpdate(
        const TextEditingValue(text: '2026/'),
        const TextEditingValue(text: '2026'),
      );
      expect(val.text, equals('2026'));
    });
  });

  group('DateRangeFilter presets and range invariance', () {
    test('Today preset encompasses start and end of day', () {
      final filter = DateRangeFilter.today();
      expect(filter.preset, equals(DateRangePreset.today));
      expect(filter.from.hour, equals(0));
      expect(filter.to.hour, equals(23));
    });

    test('Yesterday preset targets the previous day', () {
      final filter = DateRangeFilter.yesterday();
      expect(filter.preset, equals(DateRangePreset.yesterday));
      final now = DateTime.now();
      expect(filter.to.isBefore(now), isTrue);
    });

    test('This week preset starts at start of week', () {
      final filter = DateRangeFilter.thisWeek();
      expect(filter.preset, equals(DateRangePreset.thisWeek));
      expect(filter.from.isBefore(filter.to), isTrue);
    });

    test('This year preset starts at Jan 1', () {
      final filter = DateRangeFilter.thisYear();
      expect(filter.preset, equals(DateRangePreset.thisYear));
      expect(filter.from.month, equals(1));
      expect(filter.from.day, equals(1));
    });

    test('Custom range auto-corrects if from > to', () {
      final d1 = DateTime(2026, 11, 20);
      final d2 = DateTime(2026, 11, 5);
      final filter = DateRangeFilter.custom(d1, d2);
      expect(filter.from.isBefore(filter.to), isTrue);
      expect(filter.from.day, equals(5));
      expect(filter.to.day, equals(20));
    });

    test('label formats with Western digits', () {
      final l10n = AppLocalizations('ar');
      final filter = DateRangeFilter.custom(
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 9),
      );
      expect(filter.label(l10n), equals('2026/11/01 – 2026/11/09'));
    });
  });

  group('ReportDateFilter Widget', () {
    testWidgets('Renders all required quick chips and From/To display', (
      tester,
    ) async {
      DateRangeFilter current = DateRangeFilter.today();

      await tester.pumpWidget(
        LanguageProvider(
          langCode: 'ar',
          onChangeLanguage: (_) async {},
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (ctx, setState) {
                  return ReportDateFilter(
                    range: current,
                    onChanged: (newRange) {
                      setState(() => current = newRange);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');

      // Verify all required presets chips are present
      expect(find.text(l10n.today), findsOneWidget);
      expect(find.text(l10n.yesterday), findsOneWidget);
      expect(find.text(l10n.thisWeek), findsOneWidget);
      expect(find.text(l10n.thisMonth), findsOneWidget);
      expect(find.text(l10n.lastMonth), findsOneWidget);
      expect(find.text(l10n.thisYear), findsOneWidget);
      expect(find.text(l10n.customRange), findsOneWidget);

      // Verify From / To range display bar exists and shows Western digits
      expect(find.text('${l10n.fromDate}: '), findsOneWidget);
      expect(find.text('${l10n.toDate}: '), findsOneWidget);
      expect(find.text(AppDateUtils.formatDate(current.from)), findsWidgets);

      // Tapping 'Yesterday' chip updates range
      await tester.tap(find.text(l10n.yesterday));
      await tester.pumpAndSettle();
      expect(current.preset, equals(DateRangePreset.yesterday));

      // Tapping 'This Year' chip updates range
      await tester.tap(find.text(l10n.thisYear));
      await tester.pumpAndSettle();
      expect(current.preset, equals(DateRangePreset.thisYear));
    });
  });

  group('AppDateInputField Widget', () {
    testWidgets('Inputs date and validates with Western digits', (
      tester,
    ) async {
      DateTime? changedDate;

      await tester.pumpWidget(
        LanguageProvider(
          langCode: 'ar',
          onChangeLanguage: (_) async {},
          child: MaterialApp(
            home: Scaffold(
              body: Form(
                child: AppDateInputField(
                  initialDate: DateTime(2026, 11, 9),
                  onDateChanged: (d) => changedDate = d,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Field displays formatted date with Western digits
      expect(find.text('2026/11/09'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);

      // Enter Arabic-Indic digits
      await tester.enterText(find.byType(TextFormField), '٢٠٢٦/١٢/٢٥');
      await tester.pumpAndSettle();

      // Text field normalizes and parses correctly
      expect(changedDate, equals(DateTime(2026, 12, 25)));
    });
  });
}
