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

  setUp(() {
    AppSnackBar.resetForTest();
  });

  tearDown(() {
    AppSnackBar.resetForTest();
  });

  group('AppSnackBar Semantic Durations', () {
    testWidgets('Success notification defaults to 2 seconds', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Saved successfully',
              severity: AppSnackBarSeverity.success,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Saved successfully'), findsOneWidget);

      // At 1.8s from trigger (1.5s after entrance): must be visible
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('Saved successfully'), findsOneWidget);

      // At 2.5s (another 700ms): must be gone
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Saved successfully'), findsNothing);
    });

    testWidgets('Informational / default notification defaults to 2.5 seconds', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(context, 'Notice info'),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Notice info'), findsOneWidget);

      // At 2.2s: must be visible
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.text('Notice info'), findsOneWidget);

      // At 3.0s: must be gone
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.text('Notice info'), findsNothing);
    });

    testWidgets('Warning notification defaults to 3.5 seconds', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Stock is low',
              severity: AppSnackBarSeverity.warning,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Stock is low'), findsOneWidget);

      // At 3.2s: must be visible
      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text('Stock is low'), findsOneWidget);

      // At 4.0s: must be gone
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.text('Stock is low'), findsNothing);
    });

    testWidgets('Recoverable error notification defaults to 4 seconds', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Network glitch',
              severity: AppSnackBarSeverity.error,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Network glitch'), findsOneWidget);

      // At 3.7s: must be visible
      await tester.pump(const Duration(milliseconds: 3400));
      expect(find.text('Network glitch'), findsOneWidget);

      // At 4.5s: must be gone
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.text('Network glitch'), findsNothing);
    });

    testWidgets('Time-limited destructive action (Undo) defaults to 5 seconds', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Item deleted',
              actionLabel: 'Undo',
              actionExpires: true,
              onAction: () {},
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Item deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // At 4.7s: must be visible
      await tester.pump(const Duration(milliseconds: 4400));
      expect(find.text('Item deleted'), findsOneWidget);

      // At 5.6s: must be gone
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text('Item deleted'), findsNothing);
    });

    testWidgets('Critical error persists until manually dismissed via close icon', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Database corruption detected',
              severity: AppSnackBarSeverity.critical,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Database corruption detected'), findsOneWidget);
      // Close icon is present
      expect(find.byType(IconButton), findsOneWidget);

      // Advance 15 seconds: still visible
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Database corruption detected'), findsOneWidget);

      // Tap close icon
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.text('Database corruption detected'), findsNothing);
    });

    testWidgets('Explicit duration override is respected', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Custom duration message',
              severity: AppSnackBarSeverity.success,
              duration: const Duration(seconds: 6),
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Custom duration message'), findsOneWidget);

      // At 5.5s: still visible despite being success severity
      await tester.pump(const Duration(milliseconds: 5200));
      expect(find.text('Custom duration message'), findsOneWidget);

      // At 6.5s: gone
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(find.text('Custom duration message'), findsNothing);
    });
  });

  group('AppSnackBar Countdown Indicator Rules', () {
    testWidgets('Circular countdown appears ONLY when actionExpires is true', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Message with expiring action',
              actionLabel: 'Undo',
              actionExpires: true,
              onAction: () {},
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('Non-expiring actions (e.g. Open, View, Retry) do NOT show countdown', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Document ready',
              actionLabel: 'Open',
              actionExpires: false,
              onAction: () {},
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Document ready'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('Ordinary notifications without action do NOT show countdown', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(context, 'Just a notice'),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });

  group('AppSnackBar Decoupled Expiration & Action Execution', () {
    testWidgets('Action tap fires callback exactly once and cancels onActionExpired', (tester) async {
      var undoCount = 0;
      var expiredCount = 0;

      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Item deleted',
              actionLabel: 'Undo',
              actionExpires: true,
              onAction: () => undoCount++,
              onActionExpired: () => expiredCount++,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Item deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(undoCount, 0);
      expect(expiredCount, 0);

      // Tap action button
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(undoCount, 1);
      expect(find.text('Item deleted'), findsNothing);

      // Advance past the 5-second deadline: onActionExpired must NOT fire
      await tester.pump(const Duration(seconds: 6));
      expect(expiredCount, 0);
    });

    testWidgets('Action expiration timer fires onActionExpired when deadline elapses without action', (tester) async {
      var undoCount = 0;
      var expiredCount = 0;

      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Item deleted',
              actionLabel: 'Undo',
              actionExpires: true,
              onAction: () => undoCount++,
              onActionExpired: () => expiredCount++,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(expiredCount, 0);

      // Advance to 4.9s: not expired yet
      await tester.pump(const Duration(milliseconds: 4600));
      expect(expiredCount, 0);

      // Advance to 5.2s: expired!
      await tester.pump(const Duration(milliseconds: 500));
      expect(expiredCount, 1);
      expect(undoCount, 0);

      await tester.pumpAndSettle();
    });

    testWidgets('showUndo convenience method behaves identically to expiring action', (tester) async {
      var undoCount = 0;

      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.showUndo(
              context,
              'Category removed',
              actionLabel: 'Undo',
              onUndo: () => undoCount++,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Category removed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undoCount, 1);
    });
  });

  group('AppSnackBar Lifecycle & Resource Cleanup', () {
    testWidgets('Clears previous snackbar and timers immediately upon showing a new one', (tester) async {
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
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('AppSnackBar.hide immediately dismisses and cleans up', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () => AppSnackBar.show(context, 'Temporary note'),
                child: const Text('Show'),
              ),
              ElevatedButton(
                onPressed: () => AppSnackBar.hide(context),
                child: const Text('Hide'),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Temporary note'), findsOneWidget);

      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(find.text('Temporary note'), findsNothing);
    });
  });

  group('AppSnackBar Accessibility & Typography', () {
    testWidgets('accessibleNavigation extends duration to 10 seconds for interactive actions', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          accessibleNavigation: true,
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Accessible action',
              actionLabel: 'Undo',
              actionExpires: true,
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
                  actionExpires: true,
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
