import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/screens/home_screen.dart';
import 'package:warqatek/services/license_service.dart';

class _NoOpHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _NoOpHttpClient();
}

class _NoOpHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('Url') || name.contains('get') || name.contains('post') || name.contains('open')) {
      return Future<HttpClientRequest>.error(const SocketException('offline'));
    }
    return null;
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    HttpOverrides.global = _NoOpHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'wq_device_id': 'test_mock_device_id_12345',
      'wq_device_model_cache': 'Test Model Android',
      'wq_license_key': 'TEST-LICENSE-KEY',
      'wq_license_status': 'active',
      'wq_license_type': 'perpetual',
    });
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_ux_05_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await LicenseService.instance.checkEntitlement(force: true);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseHelper.instance.closeDatabase();
    final dir = Directory.systemTemp.createTempSync('ux05_run_');
    await databaseFactory.setDatabasesPath(dir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'Home Biz',
        currencyCode: 'SDG',
        phone: '0123456789',
        address: 'Khartoum',
        ownerName: 'Test Owner',
      ),
    );
  });

  testWidgets('UX-05 Regression: Quick action buttons must not trigger RenderFlex overflow under 1.4x font scaling', (tester) async {
    // Viewport width 360 (standard Android budget phone)
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        locale: const Locale('ar'),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 720),
            textScaler: TextScaler.linear(1.8),
          ),
          child: const HomeScreen(),
        ),
      ),
    );

    // Allow database queries to finish and UI to rebuild
    for (int i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(FilledButton), findsWidgets, reason: 'Quick action buttons should be rendered');

    // UX-05 BUG: home_screen.dart:409:
    //   SizedBox(
    //     height: 52,
    //     child: Row(
    //       children: [
    //         Expanded(child: FilledButton.icon(... label: Text(l10n.posQuickSale, style: TextStyle(fontSize: 16)))),
    //         ...
    //       ],
    //     ),
    //   )
    // At font scale 1.4x, the button text (22.4pt) and icon cannot fit inside the rigid 52dp box,
    // causing: A RenderFlex overflowed by ... pixels on the bottom.
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: 'UX-05: Quick action buttons must adapt dynamically to accessibility text scale (1.4x) without vertical RenderFlex overflow',
    );
  });
}
