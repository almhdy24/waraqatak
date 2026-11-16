import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/core/theme_mode_scope.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/screens/settings_screen.dart';
import 'package:warqatek/theme.dart';

Future<void> loadTestFonts() async {
  final tajawal = FontLoader('Tajawal')
    ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
  await tajawal.load();
}

Widget _buildSettingsTestHarness({
  required ThemeMode mode,
  double textScale = 1.3,
  double screenWidth = 360.0,
}) {
  return LanguageProvider(
    langCode: 'ar',
    onChangeLanguage: (_) async {},
    child: ThemeModeScope(
      themeMode: mode,
      onChangeThemeMode: (_) async {},
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(screenWidth, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: SettingsScreen(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    await loadTestFonts();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('settings_screen_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'Settings screen Quick Sale layout title renders horizontally at 360dp with text scale 1.3 in ${mode.name} mode',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildSettingsTestHarness(mode: mode));
        await tester.pumpAndSettle();

        // Find the title text
        final titleFinder = find.text('طريقة عرض المنتجات في البيع السريع');
        await tester.scrollUntilVisible(titleFinder, 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();

        expect(titleFinder, findsOneWidget);

        // Find the SegmentedButtons
        final segmentedButtons = find.byType(SegmentedButton<bool>);
        expect(segmentedButtons, findsOneWidget);

        // Ensure title is rendered horizontally with ample width (not squished vertically)
        final titleSize = tester.getSize(titleFinder);
        final titleTopLeft = tester.getTopLeft(titleFinder);

        // In 360dp viewport with margins, title width should be >= 200dp
        expect(titleSize.width, greaterThan(200.0));

        // With Tajawal font loaded, check how many lines were rendered
        final renderParagraph = tester.renderObject<RenderParagraph>(titleFinder);
        final textPainter = TextPainter(
          text: renderParagraph.text,
          textDirection: TextDirection.rtl,
          textScaler: const TextScaler.linear(1.3),
        )..layout(maxWidth: titleSize.width);
        final lineMetrics = textPainter.computeLineMetrics();
        expect(lineMetrics.length, inInclusiveRange(1, 2));

        // Ensure SegmentedButton is located below the title (not beside it in the same Row)
        final buttonTopLeft = tester.getTopLeft(segmentedButtons);
        expect(buttonTopLeft.dy, greaterThan(titleTopLeft.dy + titleSize.height));

        // SegmentedButton should take full card width (~296dp inside the card padding)
        final buttonSize = tester.getSize(segmentedButtons);
        expect(buttonSize.width, greaterThan(280.0));

        // Check the segment labels: "عرض كشبكة" and "عرض كقائمة"
        expect(find.text('عرض كشبكة'), findsOneWidget);
        expect(find.text('عرض كقائمة'), findsOneWidget);

        // Ensure no exception / overflow
        expect(tester.takeException(), isNull);
      },
    );
  }
}
