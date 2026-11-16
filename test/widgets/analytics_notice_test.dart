import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/analytics/analytics_service.dart';
import 'package:warqatek/widgets/analytics_notice_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({VoidCallback? onOpenSettings, String lang = 'ar'}) {
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
      AnalyticsService.instance.resetForTesting();
    });

    testWidgets('shows notice in Arabic and pressing Agree sets diagnosticsConsent=true', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('analytics_first_run_notice_shown'), isNull);

      await tester.pumpWidget(buildTestApp(lang: 'ar'));
      await tester.tap(find.text('CHECK_NOTICE'));
      await tester.pumpAndSettle();

      // Notice dialog is displayed with new Arabic title & body
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('ساعدنا في تحسين ورقتك'), findsOneWidget);
      expect(find.textContaining('نجمع بيانات تشغيلية مجهولة'), findsOneWidget);
      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      expect(find.text('موافق'), findsOneWidget);
      expect(find.text('ليس الآن'), findsOneWidget);

      // Flag is now persisted
      expect(prefs.getBool('analytics_first_run_notice_shown'), isTrue);

      // Tap Agree ("موافق")
      await tester.tap(find.text('موافق'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(prefs.getBool(AnalyticsService.kDiagnosticsConsentKey), isTrue);
      expect(AnalyticsService.instance.isDiagnosticsConsentGranted, isTrue);
    });

    testWidgets('shows notice in English and pressing Not now sets diagnosticsConsent=false', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('analytics_first_run_notice_shown'), isNull);

      await tester.pumpWidget(buildTestApp(lang: 'en'));
      await tester.tap(find.text('CHECK_NOTICE'));
      await tester.pumpAndSettle();

      // Notice dialog is displayed with new English title & body
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Help us improve'), findsOneWidget);
      expect(find.textContaining('We collect anonymous usage data'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Agree'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      // Tap Not now ("Not now")
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(prefs.getBool(AnalyticsService.kDiagnosticsConsentKey), isFalse);
      expect(AnalyticsService.instance.isDiagnosticsConsentGranted, isFalse);
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
      expect(prefs.getBool('analytics_first_run_notice_shown'), isNull);

      SessionManager.instance.setMultiUserEnabledForTesting(false);
    });
  });
}
