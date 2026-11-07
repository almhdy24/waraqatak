import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/core/constants/app_constants.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/services/feature_access.dart';
import 'package:warqatek/widgets/activation_key_input_widget.dart';

void main() {
  group('License & Subscription Redesign Invariants', () {
    test(
      'WhatsApp URI is clean with no query parameters or prefilled text',
      () {
        final uri = Uri.parse(AppConstants.whatsappUrl);
        expect(uri.scheme, 'https');
        expect(uri.host, 'wa.me');
        expect(uri.path, '/249993452125');
        expect(
          uri.hasQuery,
          isFalse,
          reason: 'WhatsApp intent must have no ?text= or prefilled message',
        );
        expect(uri.queryParameters, isEmpty);
      },
    );

    test('Exact Arabic copy in AppLocalizations matches specification', () {
      final l10n = AppLocalizations('ar');

      // Title & What is key
      expect(l10n.licenseScreenRedesignTitle, 'تفعيل ورقتك Pro');
      expect(l10n.whatIsLicenseKeyTitle, 'ما هو مفتاح التفعيل؟');
      expect(
        l10n.whatIsLicenseKeyBody,
        'مفتاح التفعيل رمز خاص بك تحصل عليه بعد الاشتراك، تدخله في التطبيق لتفتح مميزات ورقتك Pro على جهازك.',
      );

      // Trial states
      expect(
        l10n.trialActiveStatusWithDays(7),
        'عندك تجربة مجانية لمدة 14 يوماً لكامل مميزات ورقتك Pro. متبقي 7 يوم.',
      );
      expect(
        l10n.trialExpiredStatusMessage,
        'انتهت التجربة المجانية. للاستمرار في استخدام مميزات Pro، احصل على مفتاح التفعيل عبر واتساب.',
      );

      // Steps
      expect(l10n.howToGetKeyTitle, 'كيف أحصل على المفتاح؟');
      expect(l10n.howToGetKeyStep1, 'اضغط على زر "تواصل عبر واتساب" بالأسفل.');
      expect(
        l10n.howToGetKeyStep2('المهدي عبدالله'),
        'ستفتح محادثة مع المهدي عبدالله.',
      );
      expect(
        l10n.howToGetKeyStep3,
        'اكتب له واسأله عن الاشتراك والباقات المتاحة.',
      );
      expect(
        l10n.howToGetKeyStep4,
        'بعد إتمام الاشتراك يرسل لك مفتاح التفعيل.',
      );
      expect(
        l10n.howToGetKeyStep5,
        'ارجع للتطبيق وأدخل المفتاح في الخانة أدناه.',
      );

      // Notice & button
      expect(
        l10n.whatsappOfficialNotice,
        'واتساب هو الطريقة الرسمية الوحيدة للاشتراك والحصول على المفتاح. لا تدفع لأي جهة أخرى.',
      );
      expect(
        l10n.contactWhatsAppForActivationButton,
        'تواصل عبر واتساب للحصول على المفتاح',
      );
      expect(l10n.whatsappNotInstalled, 'واتساب غير مثبت على جهازك');

      // Free vs Pro intro and headers
      expect(
        l10n.freeVsProIntroText,
        'تحميل ورقتك مجاني. تجربة Pro كاملة 14 يوماً بدون دفع، وبعدها تحتاج مفتاح تفعيل.',
      );
      expect(l10n.freeTierHeader, 'المجاني');
      expect(l10n.proTierHeader, 'Pro (مع المفتاح)');

      // Activation section
      expect(l10n.alreadyHaveKeyTitle, 'عندك مفتاح؟');
      expect(l10n.enterKeyHintText, 'الصق المفتاح هنا ثم اضغط "تفعيل".');
      expect(
        l10n.activationSuccessDone,
        'تم التفعيل بنجاح، مميزات Pro صارت متاحة لك.',
      );
      expect(
        l10n.activationFailureGuidance,
        'تعذّر التفعيل. تأكد أن المفتاح منسوخ كاملاً بدون مسافات وأن الإنترنت شغال. إذا استمرت المشكلة، تواصل معنا عبر واتساب.',
      );
    });

    test('Real entitlements match FeatureAccess single source of truth', () {
      expect(FeatureAccess.freeFeatures.length, 9);
      expect(FeatureAccess.proFeatures.length, 7);

      // Free features
      expect(FeatureAccess.freeFeatures.contains(Feature.invoices), isTrue);
      expect(FeatureAccess.freeFeatures.contains(Feature.quotations), isTrue);
      expect(FeatureAccess.freeFeatures.contains(Feature.vouchers), isTrue);
      expect(
        FeatureAccess.freeFeatures.contains(Feature.customDocuments),
        isTrue,
      );
      expect(FeatureAccess.freeFeatures.contains(Feature.customers), isTrue);
      expect(FeatureAccess.freeFeatures.contains(Feature.products), isTrue);
      expect(FeatureAccess.freeFeatures.contains(Feature.barcode), isTrue);
      expect(FeatureAccess.freeFeatures.contains(Feature.basicReports), isTrue);
      expect(
        FeatureAccess.freeFeatures.contains(Feature.backupRestore),
        isTrue,
      );

      // Pro features
      expect(FeatureAccess.proFeatures.contains(Feature.purchases), isTrue);
      expect(FeatureAccess.proFeatures.contains(Feature.inventory), isTrue);
      expect(
        FeatureAccess.proFeatures.contains(Feature.advancedReports),
        isTrue,
      );
      expect(FeatureAccess.proFeatures.contains(Feature.stocktake), isTrue);
      expect(
        FeatureAccess.proFeatures.contains(Feature.bulkPriceUpdate),
        isTrue,
      );
      expect(
        FeatureAccess.proFeatures.contains(Feature.csvImportExport),
        isTrue,
      );
      expect(
        FeatureAccess.proFeatures.contains(Feature.inventoryAudit),
        isTrue,
      );
    });

    test(
      'Entitlement state subscription check matches trial and licensed states',
      () {
        const activeTrial = EntitlementState(
          status: EntitlementStatus.trialActive,
          deviceId: 'test-device',
          trialDaysRemaining: 10,
        );
        expect(activeTrial.isSubscriptionActive, isTrue);

        const expiredTrial = EntitlementState(
          status: EntitlementStatus.trialExpired,
          deviceId: 'test-device',
        );
        expect(expiredTrial.isSubscriptionActive, isFalse);

        const licensed = EntitlementState(
          status: EntitlementStatus.licensed,
          deviceId: 'test-device',
        );
        expect(licensed.isSubscriptionActive, isTrue);

        const revoked = EntitlementState(
          status: EntitlementStatus.licenseRevoked,
          deviceId: 'test-device',
        );
        expect(revoked.isSubscriptionActive, isFalse);
      },
    );

    testWidgets(
      'ActivationKeyInputWidget renders at 360dp with 1.5x font scale without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar'), Locale('en')],
            home: LanguageProvider(
              langCode: 'ar',
              onChangeLanguage: (_) async {},
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 800),
                  textScaler: TextScaler.linear(1.5),
                ),
                child: const Scaffold(
                  body: Directionality(
                    textDirection: TextDirection.rtl,
                    child: SingleChildScrollView(
                      child: ActivationKeyInputWidget(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('عندك مفتاح؟'), findsOneWidget);
        expect(find.text('تفعيل'), findsOneWidget);
      },
    );
  });
}
