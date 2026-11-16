import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/screens/exchange_rates_screen.dart';
import 'package:warqatek/services/feature_access.dart';
import 'package:warqatek/widgets/pro_upgrade_sheet.dart';
import 'package:warqatek/core/feature_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProUpgradeSheet standardization & UX', () {
    testWidgets('ProUpgradeSheet displays localized feature labels for all Pro features', (tester) async {
      for (final lang in ['ar', 'en']) {
        final l10n = AppLocalizations(lang);
        for (final feature in FeatureAccess.proFeatures) {
          await tester.pumpWidget(
            LanguageProvider(
              langCode: lang,
              onChangeLanguage: (_) async {},
              child: MaterialApp(
                locale: Locale(lang),
                supportedLocales: const [Locale('ar'), Locale('en')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  body: ProUpgradeSheet(feature: feature),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Header must display proFeatureTitle
          expect(find.text(l10n.proFeatureTitle), findsOneWidget);

          // Activation action button must display enterActivationKeyAction
          expect(find.text(l10n.enterActivationKeyAction), findsOneWidget);

          // Cancel button must display cancel
          expect(find.text(l10n.cancel), findsOneWidget);

          // Feature-specific subtitle must not be empty or fall back to proFeatureTitle
          if (feature == Feature.multiUser) {
            expect(find.text(l10n.usersAndPermissions), findsOneWidget);
          } else if (feature == Feature.wholesalePricing) {
            expect(find.text(l10n.wholesalePricing), findsOneWidget);
          } else if (feature == Feature.referenceCurrency) {
            expect(find.text(l10n.exchangeRates), findsAtLeastNWidgets(1));
          }
        }
      }
    });

    testWidgets('ProUpgradeSheet returns false when cancel is pressed', (tester) async {
      bool? result;

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
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await ProUpgradeSheet.show(
                      context,
                      feature: Feature.inventory,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('en');
      expect(find.text(l10n.cancel), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('ExchangeRatesScreen Pro Gate Presentation', () {
    tearDown(() {
      FeatureGate.resetForTesting();
    });

    testWidgets('Displays standardized lock screen and action button when locked', (tester) async {
      FeatureGate.setOverrideForTesting(false);

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
            home: ExchangeRatesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      // Must not display "Pro Feature" as button text
      // Must display enterActivationKeyAction on the button
      expect(find.widgetWithText(FilledButton, l10n.enterActivationKeyAction), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_outlined), findsOneWidget);
    });
  });

  group('UX & Localization Parity', () {
    test('All new and updated Pro keys have full Arabic and English parity', () {
      final l10nAr = AppLocalizations('ar');
      final l10nEn = AppLocalizations('en');

      final keys = <String, (String, String)>{
        'posGridView': (l10nAr.posGridView, l10nEn.posGridView),
        'posListView': (l10nAr.posListView, l10nEn.posListView),
        'posLayoutSettingTitle': (l10nAr.posLayoutSettingTitle, l10nEn.posLayoutSettingTitle),
        'enterActivationKeyAction': (l10nAr.enterActivationKeyAction, l10nEn.enterActivationKeyAction),
        'stocktakeHistoryTitle': (l10nAr.stocktakeHistoryTitle, l10nEn.stocktakeHistoryTitle),
      };

      final arabicRegex = RegExp(r'[\u0600-\u06FF]');
      final englishRegex = RegExp(r'[a-zA-Z]');

      for (final entry in keys.entries) {
        final key = entry.key;
        final ar = entry.value.$1;
        final en = entry.value.$2;

        expect(ar.trim().isNotEmpty, isTrue, reason: '$key Arabic is empty');
        expect(en.trim().isNotEmpty, isTrue, reason: '$key English is empty');
        expect(arabicRegex.hasMatch(ar), isTrue, reason: '$key Arabic lacks Arabic script');
        expect(englishRegex.hasMatch(en), isTrue, reason: '$key English lacks Latin script');
      }
    });
  });
}
