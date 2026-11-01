import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/theme.dart';
import 'package:warqatek/widgets/app_amount_text.dart';
import 'package:warqatek/widgets/app_confirm_dialog.dart';
import 'package:warqatek/widgets/app_error_state.dart';
import 'package:warqatek/widgets/app_icons.dart';
import 'package:warqatek/widgets/app_loading_view.dart';
import 'package:warqatek/widgets/status_badge.dart';

Widget _buildTestBoilerplate({
  required Widget child,
  String langCode = 'ar',
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.light,
}) {
  return LanguageProvider(
    langCode: langCode,
    onChangeLanguage: (_) async {},
    child: MaterialApp(
      locale: Locale(langCode),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
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
  group('AppConfirmDialog Tests', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final lang in ['ar', 'en']) {
        testWidgets('Scale $scale ($lang) renders without overflow', (tester) async {
          await tester.pumpWidget(
            _buildTestBoilerplate(
              langCode: lang,
              textScale: scale,
              child: const AppConfirmDialog(
                title: 'تأكيد الحذف',
                message: 'هل أنت متأكد من حذف هذا السجل نهائياً؟',
                isDestructive: true,
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('Touch target size for action buttons is >= 48dp', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const AppConfirmDialog(
            title: 'حذف',
            message: 'رسالة تأكيد',
            isDestructive: true,
          ),
        ),
      );
      final cancelBtnSize = tester.getSize(find.byType(TextButton));
      final confirmBtnSize = tester.getSize(find.byType(FilledButton));

      expect(cancelBtnSize.height, greaterThanOrEqualTo(48.0));
      expect(confirmBtnSize.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('AppErrorState Tests', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('Scale $scale renders without overflow', (tester) async {
        await tester.pumpWidget(
          _buildTestBoilerplate(
            textScale: scale,
            child: AppErrorState(
              message: 'فشل في الاتصال بقاعدة البيانات',
              onRetry: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Retry button touch target is >= 48dp', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: AppErrorState(
            message: 'خطأ',
            onRetry: () {},
          ),
        ),
      );
      final btnSize = tester.getSize(find.byType(FilledButton));
      expect(btnSize.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('AppLoadingView Tests', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('Scale $scale renders without overflow', (tester) async {
        await tester.pumpWidget(
          _buildTestBoilerplate(
            textScale: scale,
            child: const AppLoadingView(message: 'جاري التحميل...'),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AppStatusBadge Tests', () {
    for (final status in [
      DocumentStatus.draft,
      DocumentStatus.issued,
      DocumentStatus.partiallyPaid,
      DocumentStatus.paid,
      DocumentStatus.cancelled,
    ]) {
      testWidgets('Renders status "$status" with semantic icon and text', (tester) async {
        await tester.pumpWidget(
          _buildTestBoilerplate(
            child: AppStatusBadge(status: status),
          ),
        );
        expect(find.byType(AppStatusBadge), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders at font scale 2.0 without overflow', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          textScale: 2.0,
          child: const AppStatusBadge(status: DocumentStatus.paid),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppAmountText Tests', () {
    testWidgets('Renders amount and currency symbol properly', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const AppAmountText(
            amount: 15450.50,
            currencySymbol: 'ج.س',
          ),
        ),
      );
      expect(find.text('15,450.50'), findsOneWidget);
      expect(find.text('ج.س'), findsOneWidget);
    });

    testWidgets('Renders debit amount with negative prefix and danger color', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const AppAmountText(
            amount: 250.0,
            currencySymbol: 'SDG',
            isDebit: true,
          ),
        ),
      );
      expect(find.text('-'), findsOneWidget);
      expect(find.text('250.00'), findsOneWidget);
    });

    testWidgets('Scale 2.0 renders without overflow', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          textScale: 2.0,
          child: const AppAmountText(
            amount: 9999999.99,
            currencySymbol: 'SAR',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppIcons Directional Helper Tests', () {
    testWidgets('Returns mirrored icons in RTL vs LTR', (tester) async {
      late IconData forwardRtl;
      late IconData forwardLtr;

      await tester.pumpWidget(
        _buildTestBoilerplate(
          langCode: 'ar',
          child: Builder(builder: (ctx) {
            forwardRtl = AppIcons.chevronForward(ctx);
            return const SizedBox.shrink();
          }),
        ),
      );

      await tester.pumpWidget(
        _buildTestBoilerplate(
          langCode: 'en',
          child: Builder(builder: (ctx) {
            forwardLtr = AppIcons.chevronForward(ctx);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(forwardRtl, Icons.chevron_left_rounded);
      expect(forwardLtr, Icons.chevron_right_rounded);
    });
  });
}
