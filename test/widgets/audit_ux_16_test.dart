import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/screens/edit_document_screen.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/app_snackbar.dart';

Widget _buildTestHost({
  required Widget child,
  Locale locale = const Locale('ar'),
}) {
  return LanguageProvider(
    langCode: locale.languageCode,
    onChangeLanguage: (_) async {},
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late int testDocId;

  setUpAll(() {
    SessionManager.enableInactivityTimer = false;
  });

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('ux16_run_');
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
    'UX-16 Regression: Recipient phone field in EditDocumentScreen must have keyboardType TextInputType.phone',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      addTearDown(() => AppSnackBar.resetForTest());

      await tester.pumpWidget(
        _buildTestHost(
          child: EditDocumentScreen(documentId: testDocId),
        ),
      );

      final l10n = AppLocalizations('ar');

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        if (find.widgetWithText(TextFormField, l10n.phone).evaluate().isNotEmpty) break;
      }

      final phoneFieldFinder = find.widgetWithText(TextFormField, l10n.phone);
      expect(phoneFieldFinder, findsOneWidget);

      final textFieldFinder = find.descendant(
        of: phoneFieldFinder,
        matching: find.byType(TextField),
      );
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.keyboardType, equals(TextInputType.phone),
          reason: 'Recipient phone field must use TextInputType.phone to prompt numeric keyboard');
    },
  );
}
