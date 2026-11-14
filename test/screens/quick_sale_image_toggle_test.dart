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
import 'package:warqatek/services/product_service.dart';
import 'package:warqatek/utils/quick_sale_settings.dart';
import 'package:warqatek/widgets/pos_product_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getDatabasesPath();
    final f = File('$dir/warqatek_free.db');
    if (f.existsSync()) f.deleteSync();

    final helper = DatabaseHelper.instance;
    db = await helper.database;
    await helper.insertBusiness(
      const Business(
        name: 'متجر الاختبار',
        ownerName: 'أحمد',
        phone: '123',
        address: 'حي الزهور',
        currencyCode: 'IQD',
      ),
    );

    await ProductService.createProduct(
      name: 'منتج تجريبي 1',
      salePrice: 1500,
      stockQuantity: 10,
    );
    await ProductService.createProduct(
      name: 'منتج تجريبي 2',
      salePrice: 2500,
      stockQuantity: 20,
    );
  });

  tearDownAll(() async {
    await db.close();
  });

  testWidgets(
    'Quick Sale image toggle flips setting, preserves cart, search text, and category',
    (tester) async {
      // Seed settings to true initially
      QuickSaleSettings.instance.setShowProductImagesForTesting(true);

      await tester.pumpWidget(
        LanguageProvider(
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
        ),
      );
      await tester.pumpAndSettle();

      // Verify toggle button icon indicates images ON
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(QuickSaleSettings.instance.showProductImages, isTrue);

      // Verify product tiles are rendered with showImage: true
      final initialTile = tester.widget<PosProductTile>(
        find.byType(PosProductTile).first,
      );
      expect(initialTile.showImage, isTrue);

      // 1. Add 1 item to cart by tapping the tile
      await tester.tap(find.byType(PosProductTile).first);
      await tester.pumpAndSettle();

      // Verify cart has 1 item
      final l10n = AppLocalizations.of(tester.element(find.byType(QuickSaleScreen)));
      expect(find.text(l10n.posItemsCount('1')), findsOneWidget);

      // 2. Type search query in search field
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'تجريبي');
      await tester.pumpAndSettle();
      expect(find.text('تجريبي'), findsOneWidget);

      // 3. Tap toggle button in AppBar
      await tester.tap(find.byIcon(Icons.image_outlined));
      await tester.pumpAndSettle();

      // Verify QuickSaleSettings.instance.showProductImages flipped to false
      expect(QuickSaleSettings.instance.showProductImages, isFalse);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);

      // Verify tile now has showImage: false
      final updatedTile = tester.widget<PosProductTile>(
        find.byType(PosProductTile).first,
      );
      expect(updatedTile.showImage, isFalse);

      // Verify cart still has 1 item (cart not cleared)
      expect(find.text(l10n.posItemsCount('1')), findsOneWidget);

      // Verify search query still present
      expect(find.text('تجريبي'), findsOneWidget);

      // 4. Tap toggle button again -> flips back to true
      await tester.tap(find.byIcon(Icons.image_not_supported_outlined));
      await tester.pumpAndSettle();

      expect(QuickSaleSettings.instance.showProductImages, isTrue);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.text(l10n.posItemsCount('1')), findsOneWidget);
      expect(find.text('تجريبي'), findsOneWidget);
    },
  );
}
