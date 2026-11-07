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

  group('AppSnackBar Action Expiration Independence & Terminal States', () {
    testWidgets('Showing another SnackBar never silently cancels an unresolved action expiration', (tester) async {
      var expired1 = 0;
      var expired2 = 0;

      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () => AppSnackBar.show(
                  context,
                  'First deletion',
                  actionLabel: 'Undo',
                  actionExpires: true,
                  onAction: () {},
                  onActionExpired: () => expired1++,
                ),
                child: const Text('Delete 1'),
              ),
              ElevatedButton(
                onPressed: () => AppSnackBar.show(
                  context,
                  'Second deletion',
                  actionLabel: 'Undo',
                  actionExpires: true,
                  onAction: () {},
                  onActionExpired: () => expired2++,
                ),
                child: const Text('Delete 2'),
              ),
            ],
          ),
        ),
      );

      // Trigger first deletion SnackBar (5s deadline)
      await tester.tap(find.text('Delete 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First deletion'), findsOneWidget);
      expect(expired1, 0);

      // 1.0s later, trigger second deletion SnackBar (visually replaces First deletion)
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.tap(find.text('Delete 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First deletion'), findsNothing);
      expect(find.text('Second deletion'), findsOneWidget);
      expect(expired1, 0);
      expect(expired2, 0);

      // Advance to 5.2s from t=0 (4.2s from Delete 1 trigger):
      // Delete 1's 5s deadline completes!
      await tester.pump(const Duration(milliseconds: 4000));
      expect(expired1, 1, reason: 'Delete 1 must reach terminal expired state despite visual replacement');
      expect(expired2, 0, reason: 'Delete 2 deadline has not elapsed yet');

      // Advance another 1.2s: Delete 2's deadline completes!
      await tester.pump(const Duration(milliseconds: 1200));
      expect(expired1, 1);
      expect(expired2, 1, reason: 'Delete 2 must also reach terminal expired state');

      await tester.pumpAndSettle();
    });

    testWidgets('Swipe dismissal does NOT abort pending business action expiration', (tester) async {
      var expiredCount = 0;

      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Swipeable deletion',
              actionLabel: 'Undo',
              actionExpires: true,
              onAction: () {},
              onActionExpired: () => expiredCount++,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Swipeable deletion'), findsOneWidget);
      expect(expiredCount, 0);

      // Fling the floating SnackBar down to dismiss it visually
      await tester.fling(find.text('Swipeable deletion'), const Offset(0, 500), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Visual SnackBar is gone immediately
      expect(find.text('Swipeable deletion'), findsNothing);
      expect(expiredCount, 0);

      // Advance past 5s: the action expiration timer still reaches terminal expired state
      await tester.pump(const Duration(seconds: 5));
      expect(expiredCount, 1);
    });

    testWidgets('AppSnackBar.hide() does NOT abort pending business action expiration', (tester) async {
      var expiredCount = 0;

      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () => AppSnackBar.show(
                  context,
                  'Dismissible notice',
                  actionLabel: 'Undo',
                  actionExpires: true,
                  onAction: () {},
                  onActionExpired: () => expiredCount++,
                ),
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Dismissible notice'), findsOneWidget);

      // Programmatically hide the SnackBar at 1s
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      expect(find.text('Dismissible notice'), findsNothing);
      expect(expiredCount, 0);

      // At 5.2s: onActionExpired still fires
      await tester.pump(const Duration(milliseconds: 4300));
      expect(expiredCount, 1);
    });

    testWidgets('Navigation pop does NOT abort pending business action expiration', (tester) async {
      var expiredCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (subContext) => Scaffold(
                        body: Center(
                          child: ElevatedButton(
                            onPressed: () {
                              AppSnackBar.show(
                                subContext,
                                'Screen deletion',
                                actionLabel: 'Undo',
                                actionExpires: true,
                                onAction: () {},
                                onActionExpired: () => expiredCount++,
                              );
                              Navigator.pop(subContext);
                            },
                            child: const Text('Delete & Pop'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Page'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Page'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete & Pop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Screen is popped back to root
      expect(find.text('Open Page'), findsOneWidget);
      expect(expiredCount, 0);

      // Advance past 5s: action expiration reaches terminal expired state
      await tester.pump(const Duration(seconds: 6));
      expect(expiredCount, 1);
    });

    testWidgets('Every pending action reaches exactly one terminal state (executed xor expired)', (tester) async {
      var undoCount = 0;
      var expiredCount = 0;

      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Single terminal test',
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

      // Tap Undo before expiration
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(undoCount, 1);
      expect(expiredCount, 0);

      // Advance past deadline: expiredCount must stay 0
      await tester.pump(const Duration(seconds: 10));
      expect(undoCount, 1);
      expect(expiredCount, 0);
    });

    testWidgets('flushPendingActions immediately transitions pending actions to expired', (tester) async {
      var expiredCount = 0;

      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Pending item',
              actionLabel: 'Undo',
              actionExpires: true,
              onAction: () {},
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

      // Force flush
      AppSnackBar.flushPendingActions();
      expect(expiredCount, 1);

      // Advancing past deadline doesn't fire again
      await tester.pump(const Duration(seconds: 6));
      expect(expiredCount, 1);
    });
  });

  group('AppSnackBar Flutter Persistence Verification', () {
    testWidgets('Timed notifications configure persist: false', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Timed notice',
              severity: AppSnackBarSeverity.info,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.persist, isFalse, reason: 'Timed notification must configure persist: false');

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('Critical notifications configure persist: true', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Critical system failure',
              severity: AppSnackBarSeverity.critical,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.persist, isTrue, reason: 'Critical notification must configure persist: true');

      // Clean up
      AppSnackBar.resetForTest();
      await tester.pumpAndSettle();
    });
  });

  group('AppSnackBar Accessibility & Typography', () {
    testWidgets('accessibleNavigation extends duration to 10 seconds for interactive actions', (tester) async {
      var actionCount = 0;
      await tester.pumpWidget(
        buildTestHost(
          accessibleNavigation: true,
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Accessible action',
              actionLabel: 'Undo',
              actionExpires: true,
              onAction: () => actionCount++,
            ),
            child: const Text('Show'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Accessible action'), findsOneWidget);

      // At 9.0s: still visible and interactive
      await tester.pump(const Duration(milliseconds: 8900));
      expect(find.text('Accessible action'), findsOneWidget);

      // Tap action button at 9.0s
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(actionCount, 1);
      expect(find.text('Accessible action'), findsNothing);
    });

    testWidgets('Circular countdown wraps in ExcludeSemantics for screen reader clarity', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.show(
              context,
              'Screen reader test',
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

      // Find CircularProgressIndicator's parent ExcludeSemantics
      final excludeSemanticsFinder = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(ExcludeSemantics),
      );
      expect(excludeSemanticsFinder, findsOneWidget);

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
                  actionExpires: true,
                  onAction: () {},
                ),
                child: const Text('Trigger'),
              ),
            ),
          );

          await tester.tap(find.text('Trigger'));
          await tester.pumpAndSettle();

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
