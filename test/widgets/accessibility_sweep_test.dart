import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/theme.dart';
import 'package:warqatek/widgets/app_metric_card.dart';
import 'package:warqatek/widgets/app_search_bar.dart';
import 'package:warqatek/widgets/status_badge.dart';

Widget _wrapWithTheme({
  required Widget child,
  double textScale = 1.0,
  String lang = 'ar',
  ThemeMode mode = ThemeMode.light,
}) {
  return LanguageProvider(
    langCode: lang,
    onChangeLanguage: (_) async {},
    child: MaterialApp(
      locale: Locale(lang),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: const Size(360, 640),
        ),
        child: Directionality(
          textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
}

void main() {
  group('Accessibility & Touch Target Sweep', () {
    testWidgets('ElevatedButton minimum size >= 48dp', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Action'),
          ),
        ),
      );
      final size = tester.getSize(find.byType(ElevatedButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('FilledButton minimum size >= 48dp', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          child: FilledButton(
            onPressed: () {},
            child: const Text('Action'),
          ),
        ),
      );
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('OutlinedButton minimum size >= 48dp', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          child: OutlinedButton(
            onPressed: () {},
            child: const Text('Action'),
          ),
        ),
      );
      final size = tester.getSize(find.byType(OutlinedButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('TextButton minimum size >= 48dp', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          child: TextButton(
            onPressed: () {},
            child: const Text('Action'),
          ),
        ),
      );
      final size = tester.getSize(find.byType(TextButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('IconButton theme minimum size >= 48dp', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          child: IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {},
          ),
        ),
      );
      final size = tester.getSize(find.byType(IconButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('AppSearchBar has localized clear button and no overflow', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          textScale: 1.5,
          child: AppSearchBar(
            hintText: 'بحث...',
            initialValue: 'sample query',
            onChanged: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final clearBtn = find.byType(IconButton);
      expect(clearBtn, findsOneWidget);
    });

    testWidgets('AppMetricCard with large text scale 1.8 renders without overflow', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          textScale: 1.8,
          child: const AppMetricCard(
            title: 'إجمالي المبيعات السنوية المتوقعة',
            value: '1,250,450.75 ر.س',
            icon: Icons.trending_up,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('StatusBadge with icon renders at 2.0x scale without error', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          textScale: 2.0,
          child: const StatusBadge(
            status: 'paid',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
