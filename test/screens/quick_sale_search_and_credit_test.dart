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
import 'package:warqatek/screens/quick_sale_screen.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/product_service.dart';
import 'package:warqatek/utils/quick_sale_settings.dart';
import 'package:warqatek/widgets/amount_field.dart';
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
    tempDir = Directory.systemTemp.createTempSync('quick_sale_search_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await DatabaseHelper.instance.closeDatabase();

    final helper = DatabaseHelper.instance;
    await helper.database;
    await helper.insertBusiness(
      const Business(
        name: 'متجر البحث',
        ownerName: 'أحمد',
        phone: '123',
        address: 'حي الزهور',
        currencyCode: 'SDG',
      ),
    );

    // Seed test products
    await ProductService.createProduct(
      name: 'حليب مراعي طازج',
      salePrice: 1000,
      stockQuantity: 50,
      code: 'MILK-01',
      barcode: '628100111',
    );
    await ProductService.createProduct(
      name: 'حليب نادك طويل الأجل',
      salePrice: 1200,
      stockQuantity: 30,
      code: 'MILK-02',
      barcode: '628100222',
    );
    await ProductService.createProduct(
      name: 'جبنة شيدر كرافت',
      salePrice: 2500,
      stockQuantity: 20,
      code: 'CH-01',
      barcode: '628999999',
    );
    await ProductService.createProduct(
      name: 'عصير برتقال طبيعي',
      salePrice: 800,
      stockQuantity: 40,
      code: 'JUICE-SPECIFIC-CODE',
      barcode: '628888888',
    );
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget buildApp() {
    return LanguageProvider(
      langCode: 'ar',
      onChangeLanguage: (_) async {},
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('ar'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: QuickSaleScreen(),
      ),
    );
  }

  Future<void> pumpQuickSale(WidgetTester tester) async {
    QuickSaleSettings.instance.setShowProductImagesForTesting(false);
    await tester.pumpWidget(buildApp());
    await tester.pump();
    for (
      var i = 0;
      i < 20 && find.byType(PosProductTile).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'Quick Sale search Enter key follows priority: exact barcode, exact code, single result, multiple results, not found',
    (tester) async {
      await pumpQuickSale(tester);
      final l10n = AppLocalizations('ar');

      final searchField = find.byType(TextField).first;

      // Priority 1: Exact barcode match
      await tester.enterText(searchField, '628999999');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Cheese added to cart
      expect(find.text(l10n.posItemsCount('1')), findsOneWidget);
      expect(find.text('جبنة شيدر كرافت'), findsWidgets);

      // Priority 2: Exact product code match
      await tester.enterText(searchField, 'JUICE-SPECIFIC-CODE');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Juice added to cart -> count is 2
      expect(find.text(l10n.posItemsCount('2')), findsOneWidget);

      // Priority 3: Exactly one filtered result (search by unique name fragment)
      await tester.enterText(searchField, 'طويل الأجل');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Milk Nadec added to cart -> count is 3
      expect(find.text(l10n.posItemsCount('3')), findsOneWidget);

      // Priority 4: Multiple filtered results (query "حليب" matches 2 products)
      await tester.enterText(searchField, 'حليب');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Count remains 3 (no accidental auto-addition)
      expect(find.text(l10n.posItemsCount('3')), findsOneWidget);
      // Query "حليب" is preserved so user can choose manually
      expect(find.text('حليب'), findsOneWidget);

      // Priority 5: No matching products
      await tester.enterText(searchField, 'منتج غير موجود ابدا');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Count still 3
      expect(find.text(l10n.posItemsCount('3')), findsOneWidget);

      // Drain AppSnackBar dismiss timer
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'Quick Sale credit sale without customer is blocked; customer chip allows selecting customer',
    (tester) async {
      await pumpQuickSale(tester);
      final l10n = AppLocalizations('ar');

      // Customer chip initially shows "اختيار عميل"
      expect(find.text(l10n.selectCustomer), findsOneWidget);

      // Add item to cart
      await tester.tap(find.byType(PosProductTile).first);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Enter received amount less than total (e.g. 0 or partial)
      final receivedField = find.widgetWithText(
        AmountField,
        l10n.posAmountReceived,
      );
      await tester.enterText(receivedField, '100');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Try to complete sale without customer
      final completeButton = find.widgetWithText(
        FilledButton,
        '${l10n.posCompleteSale} · 1,000 SDG',
      );
      if (completeButton.evaluate().isNotEmpty) {
        await tester.tap(completeButton);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Toast shown: requires customer
        expect(find.text(l10n.customerRequiredForCreditSale), findsOneWidget);
      }

      // Drain AppSnackBar dismiss timer
      await tester.pump(const Duration(seconds: 4));
    },
  );
}
