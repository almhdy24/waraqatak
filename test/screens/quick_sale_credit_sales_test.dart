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
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/screens/quick_sale_screen.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/product_service.dart';
import 'package:warqatek/widgets/contact_autocomplete_field.dart';
import 'package:warqatek/widgets/pos_product_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SessionManager.instance.setMultiUserEnabledForTesting(false);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('quick_sale_credit_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await DatabaseHelper.instance.closeDatabase();

    final helper = DatabaseHelper.instance;
    await helper.database;
    await helper.insertBusiness(
      const Business(
        name: 'متجر الاختبار',
        ownerName: 'أحمد',
        phone: '123',
        address: 'حي الزهور',
        currencyCode: 'SDG',
      ),
    );

    await ProductService.createProduct(
      name: 'منتج تجريبي 1',
      salePrice: 100,
      stockQuantity: 50,
    );

    final contactId = await helper.insertContact(
      const Contact(
        name: 'عميل الحساب',
        phone: '0912345678',
        type: 'customer',
      ),
    );

    // Insert prior open invoice with debt
    final db = await helper.database;
    await db.insert(
      'documents',
      Document(
        id: 10,
        type: 'invoice',
        documentNumber: 'INV-PREV-01',
        date: DateTime.now().subtract(const Duration(days: 3)),
        contactId: contactId,
        subtotal: 300.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 300.0,
        paid: 100.0,
        remaining: 200.0,
        status: 'unpaid',
        currencyCode: 'SDG',
      ).toMap(),
    );
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget buildApp(Widget child) {
    return LanguageProvider(
      langCode: 'ar',
      onChangeLanguage: (_) async {},
      child: MaterialApp(
        locale: const Locale('ar'),
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

  testWidgets(
    'Quick Sale: credit sale modes, previous debt and remaining balance presentation',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final l10n = AppLocalizations('ar');

      await tester.pumpWidget(buildApp(const QuickSaleScreen()));
      await tester.pump();
      for (var i = 0;
          i < 20 && find.byType(PosProductTile).evaluate().isEmpty;
          i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      // Add item to cart
      final productTile = find.byType(PosProductTile).first;
      expect(productTile, findsOneWidget);
      await tester.tap(productTile);
      await tester.pumpAndSettle();

      // Verify grand total displays
      expect(find.text(l10n.grandTotal), findsWidgets);

      // Verify SegmentedButton for payment modes is present
      expect(find.text(l10n.posPayCashFull), findsOneWidget);
      expect(find.text(l10n.posPayCredit), findsOneWidget);
      expect(find.text(l10n.posPayPartial), findsOneWidget);

      // Select customer with debt
      final selectCustomerChip = find.text(l10n.selectCustomer);
      await tester.tap(selectCustomerChip);
      await tester.pumpAndSettle();

      final contactInput = find.descendant(
        of: find.byType(ContactAutocompleteField),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(contactInput, 'عميل الحساب');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      final contactOption = find.descendant(
        of: find.byType(ListView),
        matching: find.text('عميل الحساب'),
      );
      expect(contactOption, findsOneWidget);
      await tester.tap(contactOption);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      // Customer previous debt badge appears
      expect(find.textContaining(l10n.posCustomerDebt), findsOneWidget);

      // Switch to Full Credit
      await tester.tap(find.text(l10n.posPayCredit));
      await tester.pumpAndSettle();

      // Verify button text updates to complete credit sale
      expect(find.textContaining(l10n.posCompleteCreditSale), findsOneWidget);
      // Verify Remaining summary row is displayed
      expect(find.text(l10n.remaining), findsOneWidget);
      expect(find.text(l10n.unpaidStatus), findsOneWidget);

      // Switch to Partial Payment
      await tester.tap(find.text(l10n.posPayPartial));
      await tester.pumpAndSettle();

      // Button updates to partial sale
      expect(find.textContaining(l10n.posCompletePartialSale), findsOneWidget);
      expect(find.text(l10n.partialStatus), findsOneWidget);
      expect(find.text(l10n.paid), findsOneWidget);

      // Complete the partial sale
      final completeButton = find.byType(FilledButton).last;
      final btnWidget = tester.widget<FilledButton>(completeButton);
      expect(btnWidget.onPressed, isNotNull, reason: 'Complete button should be enabled');
      await tester.tap(completeButton);
      await tester.pump();

      // Wait for async document creation to finish
      for (var i = 0; i < 20 && find.byType(AlertDialog).evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Sale completed dialog displays remaining on account
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining(l10n.posRemainingOnAccount), findsOneWidget);

      // Dismiss dialog cleanly
      await tester.tap(find.text(l10n.posNewSale));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      // Elapse Sqflite 10s lock-check timer in fakeAsync
      await tester.pump(const Duration(seconds: 11));
    },
  );
}
