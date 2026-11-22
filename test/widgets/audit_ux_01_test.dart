import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/screens/access/pin_lock_screen.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/access/pin_keypad.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_ux_01_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    AuthService.useCompute = false;
    AuthService.testingIterations = 50;
    SessionManager.enableInactivityTimer = false;
  });

  tearDownAll(() async {
    SessionManager.enableInactivityTimer = true;
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseHelper.instance.closeDatabase();
    final dir = Directory.systemTemp.createTempSync('ux01_run_');
    await databaseFactory.setDatabasesPath(dir.path);
    final db = await DatabaseHelper.instance.database;

    // Ensure the default owner user has a PIN set so keypad and PIN dots are rendered
    await db.update(
      'users',
      {
        'pin_hash': 'testpinhash',
        'pin_salt': 'testpinsalt',
        'is_active': 1,
      },
      where: 'is_owner = 1',
    );
  });

  testWidgets('UX-01 Regression: PinLockScreen must not overflow in landscape/compact viewport (< 550dp)', (tester) async {
    // Landscape viewport: 800 width, 380 height (typical mobile landscape)
    tester.view.physicalSize = const Size(800, 380);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('ar'), Locale('en')],
        locale: Locale('ar'),
        home: PinLockScreen(),
      ),
    );

    // Pump and allow SQLite FFI background thread to return results
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    // Verify keypad is rendered
    expect(find.byType(PinKeypad), findsOneWidget, reason: 'PinKeypad should be rendered');

    // UX-01 BUG: PinLockScreen wraps the user selector, PIN dots, and PinKeypad (324dp)
    // in an unscrollable Column with `const Spacer()`. In landscape orientation or any
    // viewport with height < 550dp, the layout violently overflows vertically on the bottom,
    // cutting off digits 0, confirmation, and backspace buttons.
    // In Flutter tests, RenderFlex overflow reports a FlutterError to tester.takeException().
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: 'UX-01: PinLockScreen must be scrollable and not trigger RenderFlex overflow in landscape/compact height (< 550dp)',
    );
  });
}
