import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/screens/pdf_customize_screen.dart';
import 'package:warqatek/services/pdf/pdf_document_builder.dart';
import 'package:warqatek/utils/pdf_settings.dart';
import 'package:warqatek/utils/print_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('pdf_customize_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await DatabaseHelper.instance.closeDatabase();
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
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

  group('PdfStyleSettings printed stamp & signature independence', () {
    test('effectiveShowStampBox defaults to showSignature when null', () {
      const s1 = PdfStyleSettings(showSignature: true);
      expect(s1.effectiveShowStampBox, isTrue);

      const s2 = PdfStyleSettings(showSignature: false);
      expect(s2.effectiveShowStampBox, isFalse);
    });

    test('effectiveShowStampBox respects explicit showPrintedStamp override', () {
      const s1 = PdfStyleSettings(showSignature: true, showPrintedStamp: false);
      expect(s1.showSignature, isTrue);
      expect(s1.effectiveShowStampBox, isFalse);

      const s2 = PdfStyleSettings(showSignature: false, showPrintedStamp: true);
      expect(s2.showSignature, isFalse);
      expect(s2.effectiveShowStampBox, isTrue);
    });

    test('round-trips independent showSignature and showPrintedStamp through JSON', () {
      const s = PdfStyleSettings(
        showSignature: true,
        showPrintedStamp: false,
      );
      final json = s.toJson();
      expect(json['showSignature'], isTrue);
      expect(json['showPrintedStamp'], isFalse);

      final restored = PdfStyleSettings.fromJson(json);
      expect(restored.showSignature, isTrue);
      expect(restored.showPrintedStamp, isFalse);
      expect(restored.effectiveShowStampBox, isFalse);
      expect(restored, s);
    });
  });

  group('PdfDocumentBuilder independent signature and stamp rendering', () {
    test('renders signature only without error', () async {
      final l10n = AppLocalizations('ar');
      final bytes = await PdfDocumentBuilder.build(
        doc: sampleDoc,
        business: sampleBusiness,
        items: sampleItems,
        l10n: l10n,
        paperSize: PaperSize.a4,
        style: const PdfStyleSettings(
          showSignature: true,
          showPrintedStamp: false,
        ),
      );
      expect(bytes, isNotEmpty);
    });

    test('renders stamp box only without error', () async {
      final l10n = AppLocalizations('ar');
      final bytes = await PdfDocumentBuilder.build(
        doc: sampleDoc,
        business: sampleBusiness,
        items: sampleItems,
        l10n: l10n,
        paperSize: PaperSize.a4,
        style: const PdfStyleSettings(
          showSignature: false,
          showPrintedStamp: true,
        ),
      );
      expect(bytes, isNotEmpty);
    });

    test('renders both or neither without error', () async {
      final l10n = AppLocalizations('ar');
      final bytesBoth = await PdfDocumentBuilder.build(
        doc: sampleDoc,
        business: sampleBusiness,
        items: sampleItems,
        l10n: l10n,
        paperSize: PaperSize.a4,
        style: const PdfStyleSettings(
          showSignature: true,
          showPrintedStamp: true,
        ),
      );
      expect(bytesBoth, isNotEmpty);

      final bytesNeither = await PdfDocumentBuilder.build(
        doc: sampleDoc,
        business: sampleBusiness,
        items: sampleItems,
        l10n: l10n,
        paperSize: PaperSize.a4,
        style: const PdfStyleSettings(
          showSignature: false,
          showPrintedStamp: false,
        ),
      );
      expect(bytesNeither, isNotEmpty);
    });
  });

  group('PdfCustomizeScreen UI clear separation of digital and paper controls', () {
    Widget buildScreen(Widget child) {
      return LanguageProvider(
        langCode: 'ar',
        onChangeLanguage: (_) async {},
        child: MaterialApp(
          locale: const Locale('ar'),
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

    testWidgets('shows distinct digital and paper sections with independent controls',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final l10n = AppLocalizations('ar');
      await tester.pumpWidget(buildScreen(const PdfCustomizeScreen()));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify Digital Seals section header
      expect(find.text(l10n.pdfDigitalSealsHeader), findsOneWidget);
      expect(find.text(l10n.pdfSealStamp), findsOneWidget);
      expect(find.text(l10n.pdfSealSignature), findsOneWidget);
      expect(find.text(l10n.pdfDigitalStampDesc), findsOneWidget);
      expect(find.text(l10n.pdfDigitalSignatureDesc), findsOneWidget);

      // Scroll down to Paper Placeholders section
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pump();

      // Verify Paper Placeholders section header
      expect(find.text(l10n.pdfPaperStampSignatureSection), findsOneWidget);
      expect(find.text(l10n.pdfShowSignatureLine), findsOneWidget);
      expect(find.text(l10n.pdfShowSignatureLineDesc), findsOneWidget);
      expect(find.text(l10n.pdfShowStampBox), findsOneWidget);
      expect(find.text(l10n.pdfShowStampBoxDesc), findsOneWidget);

      // Verify generic fields section does NOT contain conflicting signature toggle
      expect(find.text(l10n.pdfShowSignature), findsNothing);
    });
  });
}
