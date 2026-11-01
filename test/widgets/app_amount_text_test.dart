import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/widgets/app_amount_text.dart';
import 'package:warqatek/widgets/app_design_tokens.dart';

Widget _buildBoilerplate({
  required Widget child,
  TextDirection direction = TextDirection.rtl,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('AppAmountText Widget Tests', () {
    testWidgets('0-decimal currency formatting (e.g. integer whole pounds/piastres)', (tester) async {
      await tester.pumpWidget(
        _buildBoilerplate(
          child: const AppAmountText(
            amount: 50000.0,
            currencySymbol: 'ج.س',
            decimalDigits: 0,
          ),
        ),
      );

      // Verifies exact text tokens
      expect(find.text('50,000'), findsOneWidget);
      expect(find.text('ج.س'), findsOneWidget);

      // Verifies programmatic getters
      final widget = tester.widget<AppAmountText>(find.byType(AppAmountText));
      expect(widget.formattedAmount, '50,000');
      expect(widget.fullText, '50,000 ج.س');

      // Verifies semantics accessibility label
      expect(find.bySemanticsLabel('50,000 ج.س'), findsOneWidget);
    });

    testWidgets('2-decimal currency formatting (default precision)', (tester) async {
      await tester.pumpWidget(
        _buildBoilerplate(
          child: const AppAmountText(
            amount: 15450.50,
            currencySymbol: r'$',
          ),
        ),
      );

      expect(find.text('15,450.50'), findsOneWidget);
      expect(find.text(r'$'), findsOneWidget);

      final widget = tester.widget<AppAmountText>(find.byType(AppAmountText));
      expect(widget.formattedAmount, '15,450.50');
      expect(widget.fullText, r'15,450.50 $');
      expect(find.bySemanticsLabel(r'15,450.50 $'), findsOneWidget);
    });

    testWidgets('3-decimal currency formatting (e.g. KWD, BHD, OMR)', (tester) async {
      await tester.pumpWidget(
        _buildBoilerplate(
          child: const AppAmountText(
            amount: 12.345,
            currencySymbol: 'د.ك',
            decimalDigits: 3,
          ),
        ),
      );

      expect(find.text('12.345'), findsOneWidget);
      expect(find.text('د.ك'), findsOneWidget);

      final widget = tester.widget<AppAmountText>(find.byType(AppAmountText));
      expect(widget.formattedAmount, '12.345');
      expect(widget.fullText, '12.345 د.ك');
      expect(find.bySemanticsLabel('12.345 د.ك'), findsOneWidget);
    });

    testWidgets('RTL environment preserves LTR numerals to prevent digit flipping', (tester) async {
      await tester.pumpWidget(
        _buildBoilerplate(
          direction: TextDirection.rtl,
          child: const AppAmountText(
            amount: 98765.43,
            currencySymbol: 'ر.س',
          ),
        ),
      );

      expect(find.text('98,765.43'), findsOneWidget);
      expect(find.text('ر.س'), findsOneWidget);

      // Verify that the numeral Text widget inside AppAmountText is wrapped with Directionality(ltr)
      final ltrWrapperFinder = find.descendant(
        of: find.byType(AppAmountText),
        matching: find.byWidgetPredicate(
          (w) => w is Directionality && w.textDirection == TextDirection.ltr,
        ),
      );
      expect(ltrWrapperFinder, findsOneWidget);
    });

    testWidgets('LTR environment renders correctly', (tester) async {
      await tester.pumpWidget(
        _buildBoilerplate(
          direction: TextDirection.ltr,
          child: const AppAmountText(
            amount: 1234.56,
            currencySymbol: 'EUR',
          ),
        ),
      );

      expect(find.text('1,234.56'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      final widget = tester.widget<AppAmountText>(find.byType(AppAmountText));
      expect(widget.fullText, '1,234.56 EUR');
    });

    testWidgets('Debit mode displays negative sign and danger color', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _buildBoilerplate(
          child: Builder(
            builder: (context) {
              ctx = context;
              return const AppAmountText(
                amount: 320.0,
                currencySymbol: 'SDG',
                isDebit: true,
              );
            },
          ),
        ),
      );

      expect(find.text('-'), findsOneWidget);
      expect(find.text('320.00'), findsOneWidget);

      final widget = tester.widget<AppAmountText>(find.byType(AppAmountText));
      expect(widget.fullText, '-320.00 SDG');
      expect(find.bySemanticsLabel('-320.00 SDG'), findsOneWidget);

      // Verify danger color token
      final numTextWidget = tester.widget<Text>(find.text('320.00'));
      expect(numTextWidget.style?.color, AppDesignTokens.semanticDanger(ctx));
    });

    testWidgets('Credit mode displays positive sign and success color', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _buildBoilerplate(
          child: Builder(
            builder: (context) {
              ctx = context;
              return const AppAmountText(
                amount: 450.0,
                currencySymbol: 'SDG',
                isDebit: false,
              );
            },
          ),
        ),
      );

      expect(find.text('+'), findsOneWidget);
      expect(find.text('450.00'), findsOneWidget);

      final widget = tester.widget<AppAmountText>(find.byType(AppAmountText));
      expect(widget.fullText, '+450.00 SDG');
      expect(find.bySemanticsLabel('+450.00 SDG'), findsOneWidget);

      final numTextWidget = tester.widget<Text>(find.text('450.00'));
      expect(numTextWidget.style?.color, AppDesignTokens.semanticSuccess(ctx));
    });

    testWidgets('Negative amount without isDebit displays minus sign', (tester) async {
      await tester.pumpWidget(
        _buildBoilerplate(
          child: const AppAmountText(
            amount: -75.25,
            currencySymbol: r'$',
          ),
        ),
      );

      expect(find.text('-'), findsOneWidget);
      expect(find.text('75.25'), findsOneWidget);

      final widget = tester.widget<AppAmountText>(find.byType(AppAmountText));
      expect(widget.fullText, r'-75.25 $');
      expect(find.bySemanticsLabel(r'-75.25 $'), findsOneWidget);
    });

    testWidgets('Custom prefix and custom semanticsLabel are respected', (tester) async {
      await tester.pumpWidget(
        _buildBoilerplate(
          child: const AppAmountText(
            amount: 100.0,
            currencySymbol: 'SAR',
            prefix: '≈ ',
            semanticsLabel: 'حوالي مئة ريال',
          ),
        ),
      );

      expect(find.text('≈ '), findsOneWidget);
      expect(find.text('100.00'), findsOneWidget);
      expect(find.bySemanticsLabel('حوالي مئة ريال'), findsOneWidget);
    });

    testWidgets('Gracefully handles null and empty currency symbols without trailing space', (tester) async {
      await tester.pumpWidget(
        _buildBoilerplate(
          child: const AppAmountText(
            amount: 99.0,
            currencySymbol: null,
          ),
        ),
      );

      expect(find.text('99.00'), findsOneWidget);
      final widget = tester.widget<AppAmountText>(find.byType(AppAmountText));
      expect(widget.fullText, '99.00');
      expect(find.bySemanticsLabel('99.00'), findsOneWidget);
    });
  });
}
