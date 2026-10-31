import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/theme.dart';
import 'package:warqatek/widgets/app_amount_text.dart';
import 'package:warqatek/widgets/app_icons.dart';

Widget _buildDirectionalTestHarness({
  required Widget child,
  String langCode = 'ar',
  double textScale = 1.0,
}) {
  return LanguageProvider(
    langCode: langCode,
    onChangeLanguage: (_) async {},
    child: MaterialApp(
      locale: Locale(langCode),
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: const Size(360, 640),
        ),
        child: Directionality(
          textDirection: langCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  group('RTL and Directionality Tests', () {
    testWidgets('AppIcons directional chevrons resolve correctly per locale', (tester) async {
      await tester.pumpWidget(
        _buildDirectionalTestHarness(
          langCode: 'ar',
          child: Builder(
            builder: (ctx) {
              expect(AppIcons.isRtl(ctx), isTrue);
              expect(AppIcons.chevronForward(ctx), Icons.chevron_left_rounded);
              expect(AppIcons.chevronBack(ctx), Icons.chevron_right_rounded);
              expect(AppIcons.arrowForward(ctx), Icons.arrow_back_rounded);
              expect(AppIcons.arrowBack(ctx), Icons.arrow_forward_rounded);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        _buildDirectionalTestHarness(
          langCode: 'en',
          child: Builder(
            builder: (ctx) {
              expect(AppIcons.isRtl(ctx), isFalse);
              expect(AppIcons.chevronForward(ctx), Icons.chevron_right_rounded);
              expect(AppIcons.chevronBack(ctx), Icons.chevron_left_rounded);
              expect(AppIcons.arrowForward(ctx), Icons.arrow_forward_rounded);
              expect(AppIcons.arrowBack(ctx), Icons.arrow_back_rounded);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('AppAmountText renders in RTL and LTR without throwing exceptions', (tester) async {
      for (final lang in ['ar', 'en']) {
        for (final scale in [1.0, 1.3, 2.0]) {
          await tester.pumpWidget(
            _buildDirectionalTestHarness(
              langCode: lang,
              textScale: scale,
              child: const AppAmountText(
                amount: 1250000.75,
                currencySymbol: 'SDG',
                isDebit: false,
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
