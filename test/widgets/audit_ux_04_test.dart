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
import 'package:warqatek/models/product.dart';
import 'package:warqatek/screens/bulk_pricing_screen.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/license_service.dart';
import 'package:warqatek/widgets/app_snackbar.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
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
    AuditService.instance.setTestingDeviceId('test_mock_device_id_12345');
    tempDir = Directory.systemTemp.createTempSync('audit_ux_04_test');
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
    final dir = Directory.systemTemp.createTempSync('ux04_run_');
    await databaseFactory.setDatabasesPath(dir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'Bulk Pricing Biz',
        currencyCode: 'SDG',
        phone: '0123456789',
        address: 'Khartoum',
        ownerName: 'Test Owner',
      ),
    );

    // Insert Product 1: standard local currency item (will be updated)
    await db.insertProduct(
      const Product(
        name: 'Local Product',
        salePrice: 100.0,
        purchasePrice: 80.0,
        stockQuantity: 10.0,
      ),
    );

    // Insert Product 2: reference-currency driven product (has price_currency set -> skipped in batch)
    final p2Id = await db.insertProduct(
      const Product(
        name: 'Ref Currency Product',
        salePrice: 200.0,
        purchasePrice: 150.0,
        stockQuantity: 5.0,
      ),
    );
    final rawDb = await db.database;
    await rawDb.update('products', {'price_currency': 'USD'}, where: 'id = ?', whereArgs: [p2Id]);
  });

  testWidgets('UX-04 Regression: Bulk pricing Undo button must not be overwritten by skipped notification snackbar', (tester) async {
    addTearDown(() => AppSnackBar.resetForTest());
    final l10n = AppLocalizations('ar');

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('ar'), Locale('en')],
        locale: Locale('ar'),
        home: BulkPricingScreen(),
      ),
    );

    // Allow database load and entitlement check to finish
    for (int i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify products loaded
    expect(find.text('Local Product'), findsOneWidget);
    expect(find.text('Ref Currency Product'), findsOneWidget);

    // Tap "Select All" checkbox
    final selectAllCheckbox = find.byType(Checkbox).first;
    await tester.tap(selectAllCheckbox);
    await tester.pump();

    // Tap "Apply Changes" button in bottom bar
    final applyBottomButton = find.widgetWithIcon(FilledButton, Icons.check);
    expect(applyBottomButton, findsOneWidget);
    await tester.tap(applyBottomButton);
    await tester.pumpAndSettle();

    // Tap "تطبيق التغييرات" inside confirm dialog
    final confirmButton = find.widgetWithText(FilledButton, l10n.applyChanges);
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);

    // Pump and allow SQLite FFI background operations to settle
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      if (find.byType(SnackBar).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(
      find.text(l10n.undo),
      findsOneWidget,
      reason: 'UX-04: Undo action button must remain visible when items are skipped, but was cleared by immediate snackbar overwrite',
    );

    // Let the snackbar timer finish to avoid pending timer exception
    await tester.pump(const Duration(seconds: 6));
  });
}
