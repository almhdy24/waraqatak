import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/exchange_rate.dart';
import 'package:warqatek/widgets/reference_pricing_widgets.dart';

Widget _buildTestApp(Widget child, {String langCode = 'en'}) {
  return LanguageProvider(
    langCode: langCode,
    onChangeLanguage: (_) async {},
    child: MaterialApp(
      locale: Locale(langCode),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('PricingSelection.reconcile W2', () {
    test('all truth-table branches', () {
      // 1. selected is null -> null, reverted: false
      final r1 = PricingSelection.reconcile(
        selected: null,
        storedCurrency: 'USD',
        activeCodes: {'USD'},
        allCodes: {'USD'},
      );
      expect(r1.code, isNull);
      expect(r1.reverted, isFalse);

      // 2. stored archived currency kept -> stored, reverted: false
      final r2 = PricingSelection.reconcile(
        selected: 'USD',
        storedCurrency: 'USD',
        activeCodes: {},
        allCodes: {'USD'},
      );
      expect(r2.code, 'USD');
      expect(r2.reverted, isFalse);

      // 3. active selection kept -> selected, reverted: false
      final r3 = PricingSelection.reconcile(
        selected: 'USD',
        storedCurrency: null,
        activeCodes: {'USD'},
        allCodes: {'USD'},
      );
      expect(r3.code, 'USD');
      expect(r3.reverted, isFalse);

      // 4. selected archived -> reverted to stored (which exists in allCodes)
      final r4 = PricingSelection.reconcile(
        selected: 'EUR',
        storedCurrency: 'USD',
        activeCodes: {'USD'},
        allCodes: {'USD', 'EUR'},
      );
      expect(r4.code, 'USD');
      expect(r4.reverted, isTrue);

      // 5. selected archived, stored null -> reverted to null
      final r5 = PricingSelection.reconcile(
        selected: 'EUR',
        storedCurrency: null,
        activeCodes: {'USD'},
        allCodes: {'USD', 'EUR'},
      );
      expect(r5.code, isNull);
      expect(r5.reverted, isTrue);

      // 6. selected archived, stored deleted (not in allCodes) -> reverted to null
      final r6 = PricingSelection.reconcile(
        selected: 'EUR',
        storedCurrency: 'GBP',
        activeCodes: {'USD'},
        allCodes: {'USD', 'EUR'},
      );
      expect(r6.code, isNull);
      expect(r6.reverted, isTrue);
    });
  });

  group('PricingCurrencySelector W1', () {
    testWidgets('renders base currency and notifies on change', (tester) async {
      String? selectedCurrency = 'INITIAL';
      final rates = [
        ExchangeRate(
          code: 'USD',
          nameAr: 'دولار أمريكي',
          nameEn: 'US Dollar',
          symbol: '\$',
          rate: 530.5,
          isActive: true,
          isCustom: false,
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_buildTestApp(
        PricingCurrencySelector(
          baseCurrencyCode: 'YER',
          baseSymbol: 'ر.ي',
          options: rates,
          value: null,
          onChanged: (val) {
            selectedCurrency = val;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Displays base currency label
      expect(find.text('YER (ر.ي)'), findsOneWidget);

      // Tap dropdown to open menu
      await tester.tap(find.text('YER (ر.ي)'));
      await tester.pumpAndSettle();

      // Tap USD option
      await tester.tap(find.text('دولار أمريكي (USD)').last);
      await tester.pumpAndSettle();

      expect(selectedCurrency, 'USD');
    });

    testWidgets('selecting base currency returns null', (tester) async {
      String? selectedCurrency = 'USD';
      final rates = [
        ExchangeRate(
          code: 'USD',
          nameAr: 'دولار أمريكي',
          symbol: '\$',
          rate: 530.5,
          isActive: true,
          isCustom: false,
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_buildTestApp(
        PricingCurrencySelector(
          baseCurrencyCode: 'YER',
          baseSymbol: 'ر.ي',
          options: rates,
          value: 'USD',
          onChanged: (val) {
            selectedCurrency = val;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Open menu
      await tester.tap(find.text('دولار أمريكي (USD)'));
      await tester.pumpAndSettle();

      // Select base currency
      await tester.tap(find.text('YER (ر.ي)').last);
      await tester.pumpAndSettle();

      expect(selectedCurrency, isNull);
    });
  });

  group('ReferencePriceField W2', () {
    testWidgets('renders suffixText and live helper reflects typing', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_buildTestApp(
        Form(
          child: ReferencePriceField(
            controller: ctrl,
            currencyCode: 'USD',
            rate: 530.0,
            rounding: 0,
            baseDecimals: 2,
            baseSymbol: 'YER',
            label: 'Unit Price',
            requiredField: true,
            helperWhenEmpty: 'Current base: 1000',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Helper when empty
      expect(find.text('Current base: 1000'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);

      // Type 10
      await tester.enterText(find.byType(TextFormField), '10');
      await tester.pump();

      // Live helper = 5300.0 YER
      expect(find.textContaining('5300.0 YER'), findsOneWidget);
      expect(find.text('Current base: 1000'), findsNothing);
    });

    testWidgets('validation rejects invalid reference prices', (tester) async {
      final ctrl = TextEditingController();
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(_buildTestApp(
        Form(
          key: formKey,
          child: ReferencePriceField(
            controller: ctrl,
            currencyCode: 'USD',
            rate: 530.0,
            rounding: 0,
            baseDecimals: 2,
            baseSymbol: 'YER',
            label: 'Unit Price',
            requiredField: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Empty field validation
      expect(formKey.currentState!.validate(), isFalse);

      // > 4 decimals
      ctrl.text = '10.12345';
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);

      // Negative
      ctrl.text = '-5';
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);

      // Non-numeric
      ctrl.text = 'abc';
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);

      // Valid
      ctrl.text = '10.5';
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}
