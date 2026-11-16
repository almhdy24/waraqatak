import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/core/feature_gate.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/digital_seal.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/screens/pdf_customize_screen.dart';
import 'package:warqatek/services/feature_access.dart';
import 'package:warqatek/services/pdf/pdf_document_builder.dart';
import 'package:warqatek/utils/pdf_settings.dart';
import 'package:warqatek/utils/print_settings.dart';
import 'package:warqatek/widgets/pro_upgrade_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('digital_seals_pro_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await DatabaseHelper.instance.closeDatabase();
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    FeatureGate.resetForTesting();
  });

  tearDown(() {
    FeatureGate.resetForTesting();
  });

  final sampleBusiness = const Business(
    id: 1,
    name: 'شركة الاختبار',
    ownerName: 'محمد',
    phone: '0123456789',
    address: 'الخرطوم',
    currencyCode: 'SDG',
  );

  final sampleDoc = Document(
    id: 1,
    type: 'invoice',
    documentNumber: 'INV-100',
    date: DateTime(2026, 1, 1),
    subtotal: 1000,
    discount: 0,
    taxRate: 0,
    taxAmount: 0,
    total: 1000,
    paid: 1000,
    remaining: 0,
    currencyCode: 'SDG',
  );

  final sampleItems = [
    const DocumentItem(
      documentId: 1,
      description: 'بند اختبار',
      quantity: 1,
      price: 1000,
      total: 1000,
    ),
  ];

  Widget buildApp({
    required Widget child,
    String lang = 'ar',
    ThemeMode themeMode = ThemeMode.light,
    double textScale = 1.0,
    Size size = const Size(360, 800),
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: LanguageProvider(
        langCode: lang,
        onChangeLanguage: (_) async {},
        child: MaterialApp(
          locale: Locale(lang),
          supportedLocales: const [Locale('ar'), Locale('en')],
          themeMode: themeMode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: child,
        ),
      ),
    );
  }

  group('Digital Seals Pro Entitlement & Logic Enforcement', () {
    test('FeatureGate correctly recognizes digitalSeals as a Pro feature', () {
      expect(FeatureAccess.isPro(Feature.digitalSeals), isTrue);

      FeatureGate.setEntitlement(null);
      expect(FeatureGate.isAvailable(Feature.digitalSeals), isFalse);

      FeatureGate.setEntitlement(const EntitlementState(
        status: EntitlementStatus.trialExpired,
        deviceId: 'd1',
      ));
      expect(FeatureGate.isAvailable(Feature.digitalSeals), isFalse);

      FeatureGate.setEntitlement(const EntitlementState(
        status: EntitlementStatus.licenseExpired,
        deviceId: 'd1',
      ));
      expect(FeatureGate.isAvailable(Feature.digitalSeals), isFalse);

      FeatureGate.setEntitlement(const EntitlementState(
        status: EntitlementStatus.licenseRevoked,
        deviceId: 'd1',
      ));
      expect(FeatureGate.isAvailable(Feature.digitalSeals), isFalse);

      FeatureGate.setEntitlement(const EntitlementState(
        status: EntitlementStatus.trialActive,
        deviceId: 'd1',
        trialDaysRemaining: 7,
      ));
      expect(FeatureGate.isAvailable(Feature.digitalSeals), isTrue);

      FeatureGate.setEntitlement(const EntitlementState(
        status: EntitlementStatus.licensed,
        deviceId: 'd1',
      ));
      expect(FeatureGate.isAvailable(Feature.digitalSeals), isTrue);
    });

    test('PdfDocumentBuilder ignores digital seals for Free users', () async {
      FeatureGate.setOverrideForTesting(false);

      const stampConfig = DigitalSealConfig(
        type: SealType.stamp,
        isEnabled: true,
        assetId: 'stamp_1',
      );
      const sigConfig = DigitalSealConfig(
        type: SealType.signature,
        isEnabled: true,
        assetId: 'sig_1',
      );

      final bytes = await PdfDocumentBuilder.build(
        doc: sampleDoc,
        business: sampleBusiness,
        items: sampleItems,
        l10n: AppLocalizations('ar'),
        paperSize: PaperSize.a4,
        style: const PdfStyleSettings(),
        activeSealsPreview: (stampConfig, sigConfig),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('PdfDocumentBuilder allows digital seals for Pro users', () async {
      FeatureGate.setOverrideForTesting(true);

      const stampConfig = DigitalSealConfig(
        type: SealType.stamp,
        isEnabled: true,
        assetId: 'stamp_1',
      );
      const sigConfig = DigitalSealConfig(
        type: SealType.signature,
        isEnabled: true,
        assetId: 'sig_1',
      );

      final bytes = await PdfDocumentBuilder.build(
        doc: sampleDoc,
        business: sampleBusiness,
        items: sampleItems,
        l10n: AppLocalizations('ar'),
        paperSize: PaperSize.a4,
        style: const PdfStyleSettings(),
        activeSealsPreview: (stampConfig, sigConfig),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('PdfCustomizeScreen Pro Gating UI', () {
    testWidgets('Free users see PRO badge on Stamp and Signature cards at 360dp with textScale 1.3',
        (tester) async {
      FeatureGate.setOverrideForTesting(false);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildApp(
        child: const PdfCustomizeScreen(),
        lang: 'ar',
        textScale: 1.3,
        size: const Size(360, 800),
      ));

      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      final l10n = AppLocalizations('ar');
      final stampCardFinder = find.widgetWithText(Card, l10n.pdfSealStamp);
      await tester.ensureVisible(stampCardFinder);
      await tester.pumpAndSettle();

      // ProBadge should be present on the stamp card
      expect(
        find.descendant(of: stampCardFinder, matching: find.byType(ProBadge)),
        findsOneWidget,
      );

      // Tapping the switch triggers ProUpgradeSheet for Free users
      final switchGestureFinder = find.descendant(
        of: stampCardFinder,
        matching: find.byType(GestureDetector),
      );
      await tester.tap(switchGestureFinder.first);
      await tester.pumpAndSettle();

      expect(find.byType(ProUpgradeSheet), findsOneWidget);

      // Dismiss the upgrade sheet
      final cancelBtn = find.text(l10n.cancel);
      await tester.ensureVisible(cancelBtn);
      await tester.pumpAndSettle();
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ProUpgradeSheet), findsNothing);

      // Scroll down to reveal the signature card and verify its ProBadge
      final sigCardFinder = find.widgetWithText(Card, l10n.pdfSealSignature);
      await tester.ensureVisible(sigCardFinder);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: sigCardFinder, matching: find.byType(ProBadge)),
        findsOneWidget,
      );
    });

    testWidgets('Free users in English and Dark Theme see PRO badge and tapping upload triggers ProUpgradeSheet',
        (tester) async {
      FeatureGate.setOverrideForTesting(false);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildApp(
        child: const PdfCustomizeScreen(),
        lang: 'en',
        themeMode: ThemeMode.dark,
        textScale: 1.3,
        size: const Size(360, 800),
      ));

      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      final l10n = AppLocalizations('en');
      final uploadSealBtns = find.text(l10n.pdfUploadSeal);
      await tester.ensureVisible(uploadSealBtns.first);
      await tester.pumpAndSettle();

      expect(find.byType(ProBadge), findsAtLeastNWidgets(1));
      expect(uploadSealBtns, findsAtLeastNWidgets(1));

      await tester.tap(uploadSealBtns.first);
      await tester.pumpAndSettle();

      expect(find.byType(ProUpgradeSheet), findsOneWidget);

      final cancelBtnEn = find.text(l10n.cancel);
      await tester.ensureVisible(cancelBtnEn);
      await tester.pumpAndSettle();
      await tester.tap(cancelBtnEn);
      await tester.pumpAndSettle();

      // Scroll to verify the signature card also has upload button and ProBadge
      final sigCardFinder = find.widgetWithText(Card, l10n.pdfSealSignature);
      await tester.ensureVisible(sigCardFinder);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: sigCardFinder, matching: find.byType(ProBadge)),
        findsOneWidget,
      );
    });

    testWidgets('Pro users see no PRO badge on seals and tapping switch does not show ProUpgradeSheet',
        (tester) async {
      FeatureGate.setOverrideForTesting(true);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildApp(
        child: const PdfCustomizeScreen(),
        lang: 'ar',
        size: const Size(360, 800),
      ));

      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      // No ProBadge on seal cards for Pro users
      expect(find.byType(ProBadge), findsNothing);
      expect(find.byType(ProUpgradeSheet), findsNothing);
    });
  });
}
