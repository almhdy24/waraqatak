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
import 'package:warqatek/widgets/pos_product_tile.dart';
import 'package:warqatek/widgets/product_image_thumbnail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SessionManager.instance.setMultiUserEnabledForTesting(false);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('pos_layout_image_test_');
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
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('QuickSaleSettings - independent layout and image preferences', () {
    test('defaults and setters persist independently', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = QuickSaleSettings.instance;
      await settings.load();

      expect(settings.showProductImages, isTrue);
      expect(settings.isGridLayout, isTrue);

      await settings.setShowProductImages(false);
      expect(settings.showProductImages, isFalse);
      expect(settings.isGridLayout, isTrue); // unchanged

      await settings.setIsGridLayout(false);
      expect(settings.showProductImages, isFalse);
      expect(settings.isGridLayout, isFalse);

      await settings.setShowProductImages(true);
      expect(settings.showProductImages, isTrue);
      expect(settings.isGridLayout, isFalse); // still false
    });
  });

  group('Quick POS - layout and image visibility decoupling', () {
    testWidgets(
      'Image visibility does not alter Grid/List layout and truly hides thumbnails in both',
      (tester) async {
        QuickSaleSettings.instance.setShowProductImagesForTesting(true);
        QuickSaleSettings.instance.setIsGridLayoutForTesting(true);

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
        await tester.pump();
        for (var i = 0;
            i < 20 && find.byType(PosProductTile).evaluate().isEmpty;
            i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }

        // 1. Initial State: GridView + showProductImages: true
        expect(find.byType(GridView), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
        expect(find.byType(ProductImageThumbnail), findsWidgets);
        final tileInitial = tester.widget<PosProductTile>(
          find.byType(PosProductTile).first,
        );
        expect(tileInitial.showImage, isTrue);

        // 2. Hide images from PopupMenu
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations('ar');
        expect(find.text(l10n.posHideProductImages), findsOneWidget);
        await tester.tap(find.text(l10n.posHideProductImages));
        await tester.pumpAndSettle();

        // Verification: Layout remains GridView, but images are hidden!
        expect(QuickSaleSettings.instance.showProductImages, isFalse);
        expect(QuickSaleSettings.instance.isGridLayout, isTrue); // Not switched to List!
        expect(find.byType(GridView), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
        expect(find.byType(ProductImageThumbnail), findsNothing); // Actual thumbnails hidden!

        // 3. Switch layout to List view from PopupMenu
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text(l10n.posListView), findsOneWidget);
        await tester.tap(find.text(l10n.posListView));
        await tester.pumpAndSettle();

        // Verification: Layout is now ListView, and thumbnails REMAIN HIDDEN!
        expect(QuickSaleSettings.instance.isGridLayout, isFalse);
        expect(QuickSaleSettings.instance.showProductImages, isFalse);
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(GridView), findsNothing);
        expect(find.byType(ProductImageThumbnail), findsNothing); // No thumbnails in list!

        // 4. Turn images ON while in List view
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text(l10n.posShowProductImages), findsOneWidget);
        await tester.tap(find.text(l10n.posShowProductImages));
        await tester.pumpAndSettle();

        // Verification: Layout remains ListView, and thumbnails appear!
        expect(QuickSaleSettings.instance.isGridLayout, isFalse); // Stays List!
        expect(QuickSaleSettings.instance.showProductImages, isTrue);
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(GridView), findsNothing);
        expect(find.byType(ProductImageThumbnail), findsWidgets); // 42dp thumbnails now visible!
      },
    );
  });
}
