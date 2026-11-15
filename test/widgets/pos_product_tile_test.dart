import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/widgets/pos_product_tile.dart';

void main() {
  group('posTileExtent pure function', () {
    test('computes correct extents across scales with clamping at 1.0 and 1.4', () {
      // showImage: false -> 116.0 * clamp(scale, 1.0, 1.4)
      expect(posTileExtent(showImage: false, textScale: 0.8), closeTo(116.0, 0.001));
      expect(posTileExtent(showImage: false, textScale: 1.0), closeTo(116.0, 0.001));
      expect(posTileExtent(showImage: false, textScale: 1.2), closeTo(139.2, 0.001));
      expect(posTileExtent(showImage: false, textScale: 1.4), closeTo(162.4, 0.001));
      expect(posTileExtent(showImage: false, textScale: 2.0), closeTo(162.4, 0.001));

      // showImage: true -> (116.0 * clamp(scale, 1.0, 1.4)) + 64.0
      expect(posTileExtent(showImage: true, textScale: 0.8), closeTo(180.0, 0.001));
      expect(posTileExtent(showImage: true, textScale: 1.0), closeTo(180.0, 0.001));
      expect(posTileExtent(showImage: true, textScale: 1.2), closeTo(203.2, 0.001));
      expect(posTileExtent(showImage: true, textScale: 1.4), closeTo(226.4, 0.001));
      expect(posTileExtent(showImage: true, textScale: 2.0), closeTo(226.4, 0.001));
    });
  });

  group('PosProductTile layout overflow resistance', () {
    const longArabicName =
        'منتج تجريبي طويل جداً جداً مع تفاصيل إضافية للاختبار والتأكد من عدم وجود تجاوزات';
    const longEnglishName =
        'Super Extra Long Product Name For Layout Overflow Testing And Verification';

    final locales = [
      const Locale('ar'),
      const Locale('en'),
    ];
    final scales = [1.0, 1.2, 1.4];

    for (final locale in locales) {
      for (final scale in scales) {
        for (final showImage in [false, true]) {
          testWidgets(
            'renders 0 RenderFlex overflows with ${locale.languageCode} text, scale $scale, showImage=$showImage',
            (tester) async {
              final product = Product(
                id: 1,
                name: locale.languageCode == 'ar' ? longArabicName : longEnglishName,
                salePrice: 1250000.75,
                stockQuantity: 42.0,
              );

              final height = posTileExtent(showImage: showImage, textScale: scale);
              const width = 170.0; // typical column width in POS grid

              await tester.pumpWidget(
                LanguageProvider(
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
                    home: Scaffold(
                      body: MediaQuery(
                        data: MediaQueryData(
                          textScaler: TextScaler.linear(scale),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: PosProductTile(
                              product: product,
                              cartQuantity: 5,
                              showImage: showImage,
                              onTap: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );

              await tester.pumpAndSettle();

              // Verify no overflow exception occurred
              expect(tester.takeException(), isNull);
              expect(find.byType(PosProductTile), findsOneWidget);
            },
          );
        }
      }
    }
  });

  group('PosProductTile interactions and state', () {
    testWidgets('fires onTap when not blocked and ignores when blocked', (tester) async {
      int taps = 0;
      final product = Product(
        id: 1,
        name: 'Item',
        salePrice: 10.0,
      );

      await tester.pumpWidget(
        LanguageProvider(
          langCode: 'en',
          onChangeLanguage: (_) async {},
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: PosProductTile(
                product: product,
                cartQuantity: 0,
                showImage: false,
                isBlocked: false,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PosProductTile));
      expect(taps, 1);

      // Now blocked
      await tester.pumpWidget(
        LanguageProvider(
          langCode: 'en',
          onChangeLanguage: (_) async {},
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: PosProductTile(
                product: product,
                cartQuantity: 0,
                showImage: false,
                isBlocked: true,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PosProductTile));
      expect(taps, 1); // Not incremented
    });

    testWidgets('displays cart count badge when cartQuantity > 0', (tester) async {
      final product = Product(
        id: 2,
        name: 'Coffee',
        salePrice: 5.0,
      );

      await tester.pumpWidget(
        LanguageProvider(
          langCode: 'en',
          onChangeLanguage: (_) async {},
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: PosProductTile(
                product: product,
                cartQuantity: 3,
                showImage: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('colors stock text with warning color when 0 < stockQuantity <= minStock in both tile modes', (tester) async {
      final lowStockProduct = Product(
        id: 3,
        name: 'Sugar',
        salePrice: 2.0,
        stockQuantity: 4.0,
        minStock: 5.0,
      );

      for (final showImage in [false, true]) {
        await tester.pumpWidget(
          LanguageProvider(
            langCode: 'en',
            onChangeLanguage: (_) async {},
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                body: PosProductTile(
                  product: lowStockProduct,
                  cartQuantity: 0,
                  showImage: showImage,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final stockTextWidget = tester.widget<Text>(find.text('In stock: 4'));
        expect(stockTextWidget.style?.color, equals(const Color(0xFFD97706)));
      }
    });
  });
}
