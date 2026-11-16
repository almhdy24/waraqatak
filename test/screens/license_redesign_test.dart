import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/core/constants/app_constants.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/screens/license_screen.dart';
import 'package:warqatek/services/feature_access.dart';
import 'package:warqatek/services/license_service.dart';
import 'package:warqatek/widgets/activation_key_input_widget.dart';

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
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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
      'wq_device_id': 'test_mock_device_id_12345',
      'wq_device_model_cache': 'Test Model Android',
    });
  });

  group('License Screen & Compliance Invariants', () {
    test(
      '1. WhatsApp URI is clean with no query parameters or prefilled text',
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

    test('2. Exact compliance-safe copy in AppLocalizations', () {
      final l10n = AppLocalizations('ar');

      expect(l10n.licenseScreenRedesignTitle, 'تفعيل ورقتك Pro');
      expect(
        l10n.trialActiveStatusWithDays(7),
        'لديك تجربة مجانية لمدة 14 يوماً لجميع مميزات ورقتك Pro. المتبقي: 7 يوم.',
      );
      expect(l10n.whatsappNotInstalled, 'واتساب غير مثبت على جهازك');
      expect(l10n.alreadyHaveKeyTitle, 'لديك مفتاح تفعيل؟');
      expect(
        l10n.activationSuccessDone,
        'تم التفعيل بنجاح. أصبحت مميزات Pro متاحة لك.',
      );
      expect(l10n.supportCardTitle, 'الدعم والمساعدة');
      expect(l10n.contactEmailAction, 'البريد الإلكتروني');
      expect(l10n.whatsappSupportAction, 'واتساب');
    });

    test('3. Scanning license and activation l10n keys for forbidden words', () {
      final ar = AppLocalizations('ar');
      final en = AppLocalizations('en');

      // Forbidden terms: price, buy, purchase, order, subscription, "get a key", discount, external payment links
      final forbiddenRegex = RegExp(
        r'price|buy|purchase|order|subscription|get a key|discount|اشتر|اشتراك شهري|سعر|باقات|احصل على المفتاح|خصم|ادفع',
        caseSensitive: false,
      );

      final stringsToCheck = [
        ar.activationKeyHelperText,
        en.activationKeyHelperText,
        ar.supportCardTitle,
        en.supportCardTitle,
        ar.supportCardSubtitle,
        en.supportCardSubtitle,
        ar.contactEmailAction,
        en.contactEmailAction,
        ar.whatsappSupportAction,
        en.whatsappSupportAction,
        ar.helpAndSupport,
        en.helpAndSupport,
        ar.licenseDetailsTitle,
        en.licenseDetailsTitle,
        ar.licenseDetailsSubtitle,
        en.licenseDetailsSubtitle,
        ar.trialExpiredStatusMessage,
        en.trialExpiredStatusMessage,
      ];

      for (final str in stringsToCheck) {
        expect(
          forbiddenRegex.hasMatch(str),
          isFalse,
          reason: 'String "$str" contains forbidden sales/steering term',
        );
      }
    });

    test('4. Real entitlements match FeatureAccess single source of truth', () {
      expect(FeatureAccess.freeFeatures.length, 9);
      expect(FeatureAccess.proFeatures.length, 11);

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
      expect(
        FeatureAccess.proFeatures.contains(Feature.multiUser),
        isTrue,
      );
      expect(
        FeatureAccess.proFeatures.contains(Feature.referenceCurrency),
        isTrue,
      );
      expect(
        FeatureAccess.proFeatures.contains(Feature.wholesalePricing),
        isTrue,
      );
      expect(
        FeatureAccess.proFeatures.contains(Feature.digitalSeals),
        isTrue,
      );
    });

    test(
      '5. Entitlement state subscription check matches trial and licensed states',
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
      '6. Licensed state: shows status card, collapsed details, remove key; hides key input',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        FlutterSecureStorage.setMockInitialValues({
          'wq_device_id': 'test_mock_device_id_12345',
          'wq_device_model_cache': 'Test Model Android',
          'wq_license_key': 'TEST-LICENSE-KEY',
          'wq_license_status': 'active',
          'wq_license_type': 'perpetual',
        });
        await LicenseService.instance.checkEntitlement(force: true);

        await tester.pumpWidget(_buildTestHost(child: const LicenseScreen()));
        await tester.pump();
        await tester.pumpAndSettle();

        final l10n = AppLocalizations('ar');
        // Status card is shown
        expect(find.text(l10n.licenseStatusLabel), findsOneWidget);
        expect(find.text(l10n.activatedStatus), findsOneWidget);

        // Key input is NOT shown
        expect(find.byType(ActivationKeyInputWidget), findsNothing);

        // Collapsed details tile is present
        expect(find.text(l10n.licenseDetailsTitle), findsOneWidget);

        // Remove key button is present
        expect(find.text(l10n.removeKeyFromDevice), findsOneWidget);
      },
    );

    testWidgets(
      '7. TrialActive state: shows days banner, key input card, support card, collapsed Free-vs-Pro, collapsed details',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now().toIso8601String();
        FlutterSecureStorage.setMockInitialValues({
          'wq_device_id': 'test_mock_device_id_12345',
          'wq_device_model_cache': 'Test Model Android',
          'wq_trial_start': now,
        });
        await LicenseService.instance.checkEntitlement(force: true);

        await tester.pumpWidget(_buildTestHost(child: const LicenseScreen()));
        await tester.pump();
        await tester.pumpAndSettle();

        final l10n = AppLocalizations('ar');
        // Days banner shown
        expect(find.text(l10n.trialActiveStatusWithDays(14)), findsOneWidget);

        // Key input is present
        expect(find.byType(ActivationKeyInputWidget), findsOneWidget);

        // Support card is present
        expect(find.text(l10n.supportCardTitle), findsOneWidget);
        expect(find.text(l10n.contactEmailAction), findsOneWidget);
        expect(find.text(l10n.whatsappSupportAction), findsOneWidget);

        // Collapsed Free vs Pro is present
        expect(find.text(l10n.freeVsProComparisonTitle), findsOneWidget);

        // Collapsed details is present
        expect(find.text(l10n.licenseDetailsTitle), findsOneWidget);
      },
    );

    testWidgets(
      '8. TrialExpired state: shows expired banner, key input card FIRST, support card, collapsed details',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final past = DateTime.now()
            .subtract(const Duration(days: 20))
            .toIso8601String();
        FlutterSecureStorage.setMockInitialValues({
          'wq_device_id': 'test_mock_device_id_12345',
          'wq_device_model_cache': 'Test Model Android',
          'wq_trial_start': past,
        });
        await LicenseService.instance.checkEntitlement(force: true);

        await tester.pumpWidget(_buildTestHost(child: const LicenseScreen()));
        await tester.pump();
        await tester.pumpAndSettle();

        final l10n = AppLocalizations('ar');
        // Expired banner shown
        expect(find.text(l10n.trialExpiredStatusMessage), findsOneWidget);

        // Key input is present
        expect(find.byType(ActivationKeyInputWidget), findsOneWidget);

        // Support card is present
        expect(find.text(l10n.supportCardTitle), findsOneWidget);

        // Details is present
        expect(find.text(l10n.licenseDetailsTitle), findsOneWidget);
      },
    );
  });
}
