import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/widgets/amount_field.dart';
import 'package:warqatek/widgets/discount_input_field.dart';

void main() {
  Widget buildHost({
    required Widget child,
    String locale = 'ar',
  }) {
    return LanguageProvider(
      langCode: locale,
      onChangeLanguage: (_) async {},
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  group('DiscountInputField - Amount (مبلغ) behavior', () {
    testWidgets('allows entering pure numeric amount and reports exact currency discount',
        (tester) async {
      double latestDiscount = 0.0;
      await tester.pumpWidget(
        buildHost(
          child: DiscountInputField(
            subtotal: 1000,
            currencySymbol: 'SDG',
            decimalDigits: 2,
            initialType: DiscountType.amount,
            onDiscountChanged: (d) => latestDiscount = d,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      // Segmented control shows مبلغ as selected
      expect(find.text(l10n.discountTypeAmount), findsOneWidget);
      expect(find.text(l10n.discountTypePercentage), findsOneWidget);

      // Enter 150
      final input = find.byType(AmountField);
      await tester.enterText(input, '150');
      await tester.pump();

      expect(latestDiscount, 150.0);
      // Suffix indicates SDG
      expect(find.text('SDG'), findsOneWidget);
      // Helper calculation shows equivalent percentage (= 15%)
      expect(find.text('= 15%'), findsOneWidget);
    });

    testWidgets('validates when fixed amount exceeds subtotal', (tester) async {
      await tester.pumpWidget(
        buildHost(
          child: Form(
            autovalidateMode: AutovalidateMode.always,
            child: DiscountInputField(
              subtotal: 500,
              currencySymbol: 'SDG',
              initialType: DiscountType.amount,
              onDiscountChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      final input = find.byType(AmountField);
      await tester.enterText(input, '600');
      await tester.pump();

      expect(find.text(l10n.discountAmountExceedsSubtotal), findsOneWidget);
    });
  });

  group('DiscountInputField - Percentage (نسبة) behavior', () {
    testWidgets('allows entering numeric percentage without % symbol and calculates discount',
        (tester) async {
      double latestDiscount = 0.0;
      await tester.pumpWidget(
        buildHost(
          child: DiscountInputField(
            subtotal: 800,
            currencySymbol: 'SDG',
            decimalDigits: 2,
            initialType: DiscountType.percentage,
            onDiscountChanged: (d) => latestDiscount = d,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 25 (pure number, no % symbol needed)
      final input = find.byType(AmountField);
      await tester.enterText(input, '25');
      await tester.pump();

      // 25% of 800 = 200 SDG
      expect(latestDiscount, 200.0);
      // Suffix displays %
      expect(find.text('%'), findsOneWidget);
      // Helper displays = 200 SDG
      expect(find.textContaining('200'), findsOneWidget);
    });

    testWidgets('validates percentage cannot exceed 100%', (tester) async {
      await tester.pumpWidget(
        buildHost(
          child: Form(
            autovalidateMode: AutovalidateMode.always,
            child: DiscountInputField(
              subtotal: 500,
              initialType: DiscountType.percentage,
              onDiscountChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      final input = find.byType(AmountField);
      await tester.enterText(input, '120');
      await tester.pump();

      expect(find.text(l10n.discountPercentExceedsMax), findsOneWidget);
    });
  });

  group('DiscountInputField - Switching between types', () {
    testWidgets('switches from amount to percentage with accurate value conversion',
        (tester) async {
      double latestDiscount = 0.0;
      DiscountType? latestType;

      await tester.pumpWidget(
        buildHost(
          child: DiscountInputField(
            subtotal: 1000,
            currencySymbol: 'SDG',
            decimalDigits: 2,
            initialType: DiscountType.amount,
            onDiscountChanged: (d) => latestDiscount = d,
            onTypeChanged: (t) => latestType = t,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      final input = find.byType(AmountField);
      await tester.enterText(input, '200');
      await tester.pump();
      expect(latestDiscount, 200.0);

      // Switch to نسبة
      await tester.tap(find.text(l10n.discountTypePercentage));
      await tester.pumpAndSettle();

      expect(latestType, DiscountType.percentage);
      // Input text converted to 20 (percent of 1000)
      final formField = tester.widget<TextFormField>(
        find.descendant(of: input, matching: find.byType(TextFormField)),
      );
      expect(formField.controller?.text, '20');
      expect(latestDiscount, 200.0);
    });

    testWidgets('switches from percentage to amount with accurate value conversion',
        (tester) async {
      double latestDiscount = 0.0;

      await tester.pumpWidget(
        buildHost(
          child: DiscountInputField(
            subtotal: 500,
            currencySymbol: 'SDG',
            decimalDigits: 2,
            initialType: DiscountType.percentage,
            onDiscountChanged: (d) => latestDiscount = d,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      final input = find.byType(AmountField);
      await tester.enterText(input, '10');
      await tester.pump();
      // 10% on 500 = 50
      expect(latestDiscount, 50.0);

      // Switch to مبلغ
      await tester.tap(find.text(l10n.discountTypeAmount));
      await tester.pumpAndSettle();

      final formField = tester.widget<TextFormField>(
        find.descendant(of: input, matching: find.byType(TextFormField)),
      );
      expect(formField.controller?.text, '50');
      expect(latestDiscount, 50.0);
    });
  });

  group('DiscountInputField - Subtotal updates & Dropdown selector', () {
    testWidgets('percentage discount auto-recalculates when parent subtotal changes',
        (tester) async {
      double latestDiscount = 0.0;
      double currentSubtotal = 100;
      late void Function(void Function()) setSubtotal;

      await tester.pumpWidget(
        buildHost(
          child: StatefulBuilder(
            builder: (ctx, setState) {
              setSubtotal = setState;
              return DiscountInputField(
                subtotal: currentSubtotal,
                initialType: DiscountType.percentage,
                onDiscountChanged: (d) => latestDiscount = d,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(AmountField);
      await tester.enterText(input, '10');
      await tester.pump();
      expect(latestDiscount, 10.0);

      // Re-pump with higher subtotal (200) via state update
      setSubtotal(() => currentSubtotal = 200);
      await tester.pump();

      // 10% on 200 = 20
      expect(latestDiscount, 20.0);
    });

    testWidgets('dropdown selector mode renders and switches correctly',
        (tester) async {
      double latestDiscount = 0.0;
      await tester.pumpWidget(
        buildHost(
          child: DiscountInputField(
            subtotal: 1000,
            selectorType: DiscountSelectorType.dropdown,
            initialType: DiscountType.amount,
            onDiscountChanged: (d) => latestDiscount = d,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dropdown button is present
      expect(find.byType(DropdownButton<DiscountType>), findsOneWidget);

      final input = find.byType(AmountField);
      await tester.enterText(input, '300');
      await tester.pump();
      expect(latestDiscount, 300.0);
    });
  });
}
