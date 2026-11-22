import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/core/feature_gate.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/screens/exchange_rates_screen.dart';
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

  setUpAll(() {
    SessionManager.enableInactivityTimer = false;
  });

  tearDownAll(() {
    FeatureGate.resetForTesting();
  });

  setUp(() async {
    FeatureGate.setOverrideForTesting(true);
    final dir = Directory.systemTemp.createTempSync('ux08_run_');
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

    final owner = AppUser(
      id: '1',
      workspaceId: 'default',
      username: 'owner',
      displayName: 'Owner User',
      roleId: 'owner',
      isOwner: true,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    SessionManager.instance.setSession(
      owner,
      PermissionRegistry.all.map((p) => p.key).toSet(),
    );
  });

  testWidgets(
    'UX-08 Regression: Custom currency sheet displays localized helper, proper labels, and accurate validation error messages',
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
          child: const ExchangeRatesScreen(),
        ),
      );

      final l10n = AppLocalizations('ar');

      // Wait for screen to load
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        if (find.byType(FloatingActionButton).evaluate().isNotEmpty) break;
      }

      // Allow FAB entrance animation to complete
      await tester.pump(const Duration(milliseconds: 600));

      // Open Add Currency bottom sheet
      final addFab = find.byType(FloatingActionButton);
      expect(addFab, findsOneWidget);
      await tester.tap(addFab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(BottomSheet), findsOneWidget);

      // Verify built-in validation error when no built-in currency selected
      final saveBtn = find.widgetWithText(FilledButton, l10n.save);
      expect(saveBtn, findsOneWidget);

      // Fill a valid rate first
      final rateField = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(TextFormField, l10n.exchangeRate),
      );
      expect(rateField, findsOneWidget);
      await tester.enterText(rateField, '500');
      await tester.pump();

      // Tap Save without selecting built-in currency
      await tester.tap(saveBtn);
      await tester.pump();

      // Must show selectCurrencyFirst, NOT refErrInvalidPrice
      expect(find.text(l10n.selectCurrencyFirst), findsOneWidget);
      expect(find.text(l10n.refErrInvalidPrice), findsNothing);

      // Advance past snackbar
      await tester.pump(const Duration(seconds: 4));

      // Switch to Custom Currency mode
      final customSwitchBtn = find.widgetWithText(TextButton, l10n.customCurrency);
      expect(customSwitchBtn, findsOneWidget);
      await tester.tap(customSwitchBtn);
      await tester.pump();

      // Verify that helperText is localized (l10n.currencyCodeHelper) and not hardcoded English
      expect(find.text(l10n.currencyCodeHelper), findsOneWidget);
      expect(find.text('e.g. USD, EUR (2-5 letters)'), findsNothing);

      // Verify that the Arabic name label is currencyNameArField, not methodLabelAr
      expect(find.text(l10n.currencyNameArField), findsOneWidget);
      expect(find.text(l10n.methodLabelAr), findsNothing);

      // Test invalid currency code (e.g. 1 letter)
      final codeField = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(TextFormField, l10n.currencyCode),
      );
      expect(codeField, findsOneWidget);
      await tester.enterText(codeField, 'Q');
      await tester.pump();

      await tester.tap(saveBtn);
      await tester.pump();

      // Must show currencyCodeInvalid, NOT refErrInvalidPrice
      expect(find.text(l10n.currencyCodeInvalid), findsOneWidget);
      expect(find.text(l10n.refErrInvalidPrice), findsNothing);

      // Advance past snackbar
      await tester.pump(const Duration(seconds: 4));

      // Enter valid code but empty name/symbol
      await tester.enterText(codeField, 'QAR');
      await tester.pump();

      await tester.tap(saveBtn);
      await tester.pump();

      // Must show currencyFieldsRequired, NOT refErrInvalidPrice
      expect(find.text(l10n.currencyFieldsRequired), findsOneWidget);
      expect(find.text(l10n.refErrInvalidPrice), findsNothing);

      // Drain remaining timers
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
