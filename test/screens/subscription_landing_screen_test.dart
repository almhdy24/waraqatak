// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:warqatek/core/constants/app_constants.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/subscription_plan.dart';
import 'package:warqatek/screens/activation_screen.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/activation_key_input_widget.dart';

class _MockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }

  @override
  Future<bool> canLaunch(String url) async => true;
}

Widget _buildTestHost({
  required Widget child,
  Locale locale = const Locale('ar'),
}) {
  return LanguageProvider(
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
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockUrlLauncher mockUrlLauncher;

  setUp(() {
    mockUrlLauncher = _MockUrlLauncher();
    UrlLauncherPlatform.instance = mockUrlLauncher;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.elmahdi.waraqatak/device'),
          (call) async {
            if (call.method == 'getDeviceModel') return 'Test Model Android';
            return null;
          },
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'wq_device_id': 'DEVICE-TEST-12345',
      'wq_device_model_cache': 'Test Model Android',
    });
    SessionManager.instance.setMultiUserEnabledForTesting(false);
  });

  group('SubscriptionPlan Model & WhatsApp Message Generation', () {
    test('Subscription plans are defined with exact requirements', () {
      final plans = SubscriptionPlan.allPlans;
      expect(plans.length, 4);

      final annual = plans.firstWhere((p) => p.id == '1_year');
      expect(annual.durationMonths, 12);
      expect(annual.priceSdg, 120000);
      expect(annual.originalPriceSdg, 180000);
      expect(annual.savingsSdg, 60000);
      expect(annual.discountPercent, 33);
      expect(annual.monthlyEquivalentSdg, 10000);
      expect(annual.isFeatured, isTrue);

      final sixMonths = plans.firstWhere((p) => p.id == '6_months');
      expect(sixMonths.durationMonths, 6);
      expect(sixMonths.priceSdg, 70000);
      expect(sixMonths.savingsSdg, 20000);
      expect(sixMonths.isFeatured, isFalse);

      final threeMonths = plans.firstWhere((p) => p.id == '3_months');
      expect(threeMonths.durationMonths, 3);
      expect(threeMonths.priceSdg, 40000);
      expect(threeMonths.savingsSdg, 5000);
      expect(threeMonths.isFeatured, isFalse);

      final oneMonth = plans.firstWhere((p) => p.id == '1_month');
      expect(oneMonth.durationMonths, 1);
      expect(oneMonth.priceSdg, 15000);
      expect(oneMonth.isFeatured, isFalse);
    });

    test('Support WhatsApp number defaults to AppConstants.whatsappNumber', () {
      expect(
        SubscriptionPlan.getSupportWhatsAppNumber(),
        AppConstants.whatsappNumber,
      );
    });

    test('WhatsApp message generation in Arabic contains all required details', () {
      final annual = SubscriptionPlan.allPlans.firstWhere((p) => p.id == '1_year');
      final msg = SubscriptionPlan.generateWhatsAppMessage(
        plan: annual,
        planTitle: 'باقة سنة كاملة',
        durationText: '1 سنة',
        deviceId: 'DEVICE-ABC-999',
        isArabic: true,
      );

      expect(msg, contains('السلام عليكم،'));
      expect(msg, contains('أود الاشتراك في باقة ورقتك برو (Waraqatak Pro):'));
      expect(msg, contains('باقة سنة كاملة (1 سنة)'));
      expect(msg, contains('120,000 ج.س'));
      expect(msg, contains('وفر 60,000 ج.س'));
      expect(msg, contains('خصم 33%'));
      expect(msg, contains('10,000 ج.س شهرياً'));
      expect(msg, contains('DEVICE-ABC-999'));
      expect(msg, contains('ورقتك | Waraqatak By Elmahdi Dev'));
      expect(msg, contains('يرجى تزويدي ببيانات الدفع ومفتاح التفعيل'));
    });

    test('WhatsApp message generation in English contains required details', () {
      final oneMonth = SubscriptionPlan.allPlans.firstWhere((p) => p.id == '1_month');
      final msg = SubscriptionPlan.generateWhatsAppMessage(
        plan: oneMonth,
        planTitle: '1 Month Plan',
        durationText: '1 Month',
        deviceId: 'DEVICE-XYZ-111',
        isArabic: false,
      );

      expect(msg, contains('Hello,'));
      expect(msg, contains('I would like to subscribe to Waraqatak Pro:'));
      expect(msg, contains('1 Month Plan (1 Month)'));
      expect(msg, contains('15,000 SDG'));
      expect(msg, contains('DEVICE-XYZ-111'));
      expect(msg, contains('Waraqatak By Elmahdi Dev'));
      expect(msg, contains('Please provide payment details'));
    });

    test('generateWhatsAppUri builds valid wa.me HTTPS Uri with encoded query', () {
      final annual = SubscriptionPlan.allPlans.firstWhere((p) => p.id == '1_year');
      final uri = SubscriptionPlan.generateWhatsAppUri(
        plan: annual,
        planTitle: 'باقة سنة كاملة',
        durationText: '1 سنة',
        deviceId: 'DEV-123',
        isArabic: true,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/${AppConstants.whatsappNumber}');
      expect(uri.queryParameters['text'], contains('120,000 ج.س'));
      expect(uri.queryParameters['text'], contains('DEV-123'));
    });
  });

  group('ActivationScreen Widget Tests', () {
    testWidgets('Renders subscription landing page elements and all 4 plans', (tester) async {
      await tester.pumpWidget(
        _buildTestHost(child: const ActivationScreen()),
      );
      await tester.pumpAndSettle();

      // Brand badge & title
      expect(find.text('ورقتك | Waraqatak By Elmahdi Dev'), findsOneWidget);
      expect(find.text('باقات اشتراك ورقتك برو'), findsAtLeastNWidgets(1));

      // Value proposition chips
      expect(find.text('فواتير وعروض أسعار وسندات غير محدودة'), findsOneWidget);
      expect(find.text('إدارة متقدمة للمخزون والتنبيهات وجرد الباركود'), findsOneWidget);
      expect(find.text('تقارير مالية وأرباح مفصلة مع تصدير وطباعة'), findsOneWidget);
      expect(find.text('تخصيص كامل للفواتير بالشعار والأختام والتوقيع'), findsOneWidget);

      // Featured annual plan elements
      expect(find.text('العرض الأفضل · الأكثر توفيراً'), findsOneWidget);
      expect(find.text('120,000'), findsOneWidget);
      expect(find.text('180,000 ج.س'), findsOneWidget); // Crossed out price
      expect(find.text('وفر 60,000 ج.س'), findsOneWidget);
      expect(find.text('خصم 33%'), findsOneWidget);
      expect(find.text('يعادل 10,000 ج.س / شهرياً فقط'), findsOneWidget);

      // Other plans
      expect(find.text('70,000'), findsOneWidget);
      expect(find.text('وفر 20,000 ج.س'), findsOneWidget);

      expect(find.text('40,000'), findsOneWidget);
      expect(find.text('وفر 5,000 ج.س'), findsOneWidget);

      expect(find.text('15,000'), findsOneWidget);

      // 4 "اشترك الآن" buttons
      expect(find.byKey(const ValueKey('subscribe_1_year')), findsOneWidget);
      expect(find.byKey(const ValueKey('subscribe_6_months')), findsOneWidget);
      expect(find.byKey(const ValueKey('subscribe_3_months')), findsOneWidget);
      expect(find.byKey(const ValueKey('subscribe_1_month')), findsOneWidget);

      // How to activate guide banner
      expect(find.text('طريقة الاشتراك والتفعيل'), findsOneWidget);

      // "لديك مفتاح تفعيل؟" section
      expect(find.text('لديك مفتاح تفعيل؟'), findsOneWidget);
      expect(find.text('DEVICE-TEST-12345'), findsOneWidget);
      expect(find.byType(ActivationKeyInputWidget), findsOneWidget);
    });

    testWidgets('Tapping Subscribe Now attempts to launch WhatsApp URL', (tester) async {
      await tester.pumpWidget(
        _buildTestHost(child: const ActivationScreen()),
      );
      await tester.pumpAndSettle();

      final subscribeButton = find.byKey(const ValueKey('subscribe_1_year'));
      expect(subscribeButton, findsOneWidget);

      await tester.ensureVisible(subscribeButton);
      await tester.tap(subscribeButton);
      await tester.pumpAndSettle();

      expect(mockUrlLauncher.launchedUrl, isNotNull);
      expect(mockUrlLauncher.launchedUrl, contains('wa.me/${AppConstants.whatsappNumber}'));
    });

    testWidgets('Copying Device ID copies to clipboard and shows snackbar', (tester) async {
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardText = (call.arguments as Map)['text'] as String?;
                return null;
              }
              return null;
            },
          );

      await tester.pumpWidget(
        _buildTestHost(child: const ActivationScreen()),
      );
      await tester.pumpAndSettle();

      final copyButton = find.byIcon(Icons.copy_rounded);
      expect(copyButton, findsOneWidget);

      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      await tester.pump();

      expect(clipboardText, 'DEVICE-TEST-12345');
      expect(find.text('تم نسخ معرف الجهاز'), findsOneWidget);

      // Advance past snackbar auto-dismiss timer
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Successful key activation displays success screen with unlocked features', (tester) async {
      await tester.pumpWidget(
        _buildTestHost(child: const ActivationScreen()),
      );
      await tester.pumpAndSettle();

      final inputWidgetFinder = find.byType(ActivationKeyInputWidget);
      expect(inputWidgetFinder, findsOneWidget);

      final widget = tester.widget<ActivationKeyInputWidget>(inputWidgetFinder);
      widget.onActivated?.call();
      await tester.pumpAndSettle();

      expect(find.text('تم التفعيل!'), findsOneWidget);
      expect(find.text('المميزات المتاحة مع Pro:'), findsOneWidget);
      expect(find.text('الدخول إلى ورقتك'), findsOneWidget);
    });
  });
}
