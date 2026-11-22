import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/screens/document_detail_screen.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/app_snackbar.dart';

class _NoOpHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _NoOpHttpClient();
}

class _NoOpHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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
    tempDir = Directory.systemTemp.createTempSync('audit_ux_07_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    SessionManager.enableInactivityTimer = false;
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  late int testDocId;

  setUp(() async {
    await DatabaseHelper.instance.closeDatabase();
    final dir = Directory.systemTemp.createTempSync('ux07_run_');
    await databaseFactory.setDatabasesPath(dir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'Test Biz',
        currencyCode: 'SDG',
        phone: '0123456789',
        address: 'Khartoum',
        ownerName: 'Test Owner',
      ),
    );

    final rawDb = await db.database;
    final ownerMap = (await rawDb.query('users', where: 'is_owner = 1', limit: 1)).first;
    final owner = AppUser.fromMap(ownerMap);
    SessionManager.instance.setSession(
      owner,
      PermissionRegistry.all.map((p) => p.key).toSet(),
    );

    testDocId = await db.insertDocumentWithItems(
      Document(
        documentNumber: 'INV-001',
        date: DateTime.now(),
        type: 'invoice',
        status: DocumentStatus.issued,
        subtotal: 1000.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 1000.0,
        paid: 0.0,
        remaining: 1000.0,
        currencyCode: 'SDG',
      ),
      const [],
    );
  });

  testWidgets(
    'UX-07 Regression: Record payment sheet must have double-submit lock preventing duplicate records',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      addTearDown(() => AppSnackBar.resetForTest());
      final db = DatabaseHelper.instance;
      final docId = testDocId;

      await tester.pumpWidget(
        LanguageProvider(
          langCode: 'ar',
          onChangeLanguage: (_) async {},
          child: MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar'), Locale('en')],
            locale: const Locale('ar'),
            home: DocumentDetailScreen(documentId: docId),
          ),
        ),
      );

      final l10n = AppLocalizations('ar');

      // Wait until DocumentDetailScreen finishes loading and renders the record payment FAB
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        if (find.text(l10n.recordPayment).evaluate().isNotEmpty) {
          break;
        }
      }

      // Allow FAB entrance animation to complete
      await tester.pump(const Duration(milliseconds: 600));

      // Open the record payment bottom sheet
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Fill payment amount
      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '200');
      await tester.pump();

      // Find the submit button inside the bottom sheet
      final submitPaymentBtn = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, l10n.recordPayment),
      );
      expect(submitPaymentBtn, findsOneWidget);

      // Verify that rapid double tap doesn't create duplicate payments
      await tester.tap(submitPaymentBtn);
      await tester.tap(submitPaymentBtn, warnIfMissed: false);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      }

      final payments = await tester.runAsync(() => db.getDocumentPayments(docId));
      expect(
        payments!.length,
        equals(1),
        reason: 'Double-tap on payment submit must record exactly one payment',
      );

      // Drain any AppSnackBar timers before test tear down
      await tester.pump(const Duration(seconds: 6));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
