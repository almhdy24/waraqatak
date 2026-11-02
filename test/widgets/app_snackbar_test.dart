import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/widgets/app_snackbar.dart';

void main() {
  Widget buildTestHost({
    required Widget Function(BuildContext) builder,
    Locale locale = const Locale('en'),
    double textScaleFactor = 1.0,
    bool accessibleNavigation = false,
  }) {
    return LanguageProvider(
      langCode: locale.languageCode,
      onChangeLanguage: (_) async {},
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScaleFactor),
            accessibleNavigation: accessibleNavigation,
            size: const Size(800, 1200),
          ),
          child: Scaffold(
            body: Builder(builder: builder),
          ),
        ),
      ),
    );
  }

  group('AppSnackBar Widget & Lifecycle Tests', () {
    testWidgets('SnackBar without action: present at 2.9s and gone at 3.5s', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(context, 'Test message without action'),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump(); // Start show animation
      await tester.pump(const Duration(milliseconds: 300)); // Entrance animation

      expect(find.text('Test message without action'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);

      // Advance to 2.9s from trigger (2.6s remaining)
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.text('Test message without action'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);

      // Advance past 3.0s to 3.5s (another 600ms)
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Test message without action'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('SnackBar with action: present at 2.9s and gone at 3.5s', (tester) async {
      var actionCount = 0;
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Action message',
              actionLabel: 'Undo',
              onAction: () => actionCount++,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Action message'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);

      // Advance to 2.9s
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.text('Action message'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Advance to 3.5s (dismissed and settled)
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Action message'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(actionCount, 0);
    });

    testWidgets('accessibleNavigation extends duration: present at 9.9s and gone at 10.5s', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          accessibleNavigation: true,
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Accessible action',
              actionLabel: 'Undo',
              onAction: () {},
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Accessible action'), findsOneWidget);

      // At 4.9s: must still be visible
      await tester.pump(const Duration(milliseconds: 4800));
      expect(find.text('Accessible action'), findsOneWidget);

      // At 9.9s: must still be visible
      await tester.pump(const Duration(milliseconds: 5000));
      expect(find.text('Accessible action'), findsOneWidget);

      // At 10.5s: gone
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Accessible action'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Action tap fires callback exactly once and closes SnackBar immediately', (tester) async {
      var undoCount = 0;
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Item deleted',
              actionLabel: 'Undo',
              onAction: () => undoCount++,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Item deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(undoCount, 0);

      // Tap action button
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(undoCount, 1);
      expect(find.text('Item deleted'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Clears previous snackbar immediately upon showing a new one', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () => AppSnackBar.show(context, 'First SnackBar'),
                child: const Text('Show First'),
              ),
              ElevatedButton(
                onPressed: () => AppSnackBar.show(context, 'Second SnackBar'),
                child: const Text('Show Second'),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Show First'));
      await tester.pumpAndSettle();
      expect(find.text('First SnackBar'), findsOneWidget);

      await tester.tap(find.text('Show Second'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First SnackBar'), findsNothing);
      expect(find.text('Second SnackBar'), findsOneWidget);

      // Settle remaining timer for Second SnackBar
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('RTL and Text scale 1.0, 1.3, 2.0 layout check with no overflow', (tester) async {
      final scales = [1.0, 1.3, 2.0];
      final locales = [const Locale('en'), const Locale('ar')];

      for (final locale in locales) {
        for (final scale in scales) {
          await tester.pumpWidget(
            buildTestHost(
              locale: locale,
              textScaleFactor: scale,
              builder: (context) => ElevatedButton(
                onPressed: () => AppSnackBar.show(
                  context,
                  locale.languageCode == 'ar'
                      ? 'تم حذف العنصر بنجاح من الفاتورة'
                      : 'Item was successfully deleted from invoice',
                  actionLabel: locale.languageCode == 'ar' ? 'تراجع' : 'Undo',
                  onAction: () {},
                ),
                child: const Text('Trigger'),
              ),
            ),
          );

          await tester.tap(find.text('Trigger'));
          await tester.pumpAndSettle();

          // Ensure no Flutter layout overflow exceptions were caught
          expect(tester.takeException(), isNull);
          expect(find.byType(SnackBar), findsOneWidget);

          // Clean up for next iteration
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
        }
      }
    });
  });
}
