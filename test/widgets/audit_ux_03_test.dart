import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/screens/payment_methods_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_ux_03_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseHelper.instance.closeDatabase();
    final dir = Directory.systemTemp.createTempSync('ux03_run_');
    await databaseFactory.setDatabasesPath(dir.path);
    await DatabaseHelper.instance.database;
  });

  testWidgets('UX-03 Regression: Custom payment method dialog must not access disposed controllers', (tester) async {
    await tester.pumpWidget(
      LanguageProvider(
        langCode: 'ar',
        onChangeLanguage: (_) async {},
        child: const MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ar'), Locale('en')],
          locale: Locale('ar'),
          home: PaymentMethodsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Find and tap the FloatingActionButton to add a custom payment method
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Find TextField for Arabic name and enter text
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.first, 'طريقة دفع مخصصة');
    await tester.pump();

    // Tap the Save button inside AlertDialog
    final saveButton = find.widgetWithText(FilledButton, 'حفظ');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    // In UX-03 defect: accessing arCtrl.text after arCtrl.dispose() causes:
    // FlutterError: A TextEditingController was used after being disposed.
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: 'UX-03: Accessing controller text after dispose throws FlutterError',
    );
  });
}
