import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/analytics_notice_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({VoidCallback? onOpenSettings, String lang = 'en'}) {
    return LanguageProvider(
      langCode: lang,
      onChangeLanguage: (_) async {},
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: Locale(lang),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AnalyticsNoticeDialog.checkAndShow(
                context,
                onOpenSettings: onOpenSettings,
              ),
              child: const Text('CHECK_NOTICE'),
            ),
          ),
        ),
      ),
    );
  }

  group('AnalyticsNoticeDialog tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SessionManager.instance.setMultiUserEnabledForTesting(false);
    });

    testWidgets('shows notice on first start and persists shown flag', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('analytics_first_run_notice_shown'), isNull);

      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.text('CHECK_NOTICE'));
      await tester.pumpAndSettle();

      // Notice dialog is displayed
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Usage Statistics & Error Reports'), findsOneWidget);

      // Flag is now persisted
      expect(prefs.getBool('analytics_first_run_notice_shown'), isTrue);

      // Tap OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('does not show notice if already shown previously', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'analytics_first_run_notice_shown': true,
      });

      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.text('CHECK_NOTICE'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('never shows notice while multi-user session is locked', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.lock();
      expect(SessionManager.instance.isLocked, isTrue);

      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.text('CHECK_NOTICE'));
      await tester.pumpAndSettle();

      // Dialog must NOT show
      expect(find.byType(AlertDialog), findsNothing);
      // And flag must NOT be marked shown yet (will show after unlock)
      expect(prefs.getBool('analytics_first_run_notice_shown'), isNull);

      SessionManager.instance.setMultiUserEnabledForTesting(false);
    });

    testWidgets('Settings button navigates to settings callback', (
      tester,
    ) async {
      bool settingsOpened = false;

      await tester.pumpWidget(
        buildTestApp(onOpenSettings: () => settingsOpened = true),
      );
      await tester.tap(find.text('CHECK_NOTICE'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(settingsOpened, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
