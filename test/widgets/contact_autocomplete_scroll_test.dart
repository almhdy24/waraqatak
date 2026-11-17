import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/screens/edit_document_screen.dart';
import 'package:warqatek/screens/invoice_screen.dart';
import 'package:warqatek/screens/purchase_screen.dart';
import 'package:warqatek/screens/quotation_screen.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/widgets/app_loading_view.dart';
import 'package:warqatek/widgets/contact_autocomplete_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SessionManager.instance.setMultiUserEnabledForTesting(false);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('contact_scroll_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await DatabaseHelper.instance.closeDatabase();

    final helper = DatabaseHelper.instance;
    await helper.database;
    await helper.insertBusiness(
      const Business(
        name: 'مؤسسة تجريبية',
        ownerName: 'المدير',
        phone: '0123456789',
        address: 'الخرطوم',
        currencyCode: 'SDG',
      ),
    );
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.closeDatabase();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget wrapWithApp(Widget child) {
    return LanguageProvider(
      langCode: 'ar',
      onChangeLanguage: (_) async {},
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        home: child,
      ),
    );
  }

  group('Contact Name Scroll Retention Tests', () {
    testWidgets(
      '1. ContactAutocompleteField keeps typed text intact after scrolling down and back up',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = TextEditingController();
        addTearDown(() => controller.dispose());

        await tester.pumpWidget(
          wrapWithApp(
            Scaffold(
              body: ListView(
                children: [
                  ContactAutocompleteField(
                    controller: controller,
                    label: 'العميل',
                    type: 'customer',
                    onContactChanged: (_) {},
                  ),
                  for (int i = 0; i < 20; i++)
                    Container(
                      height: 80,
                      color: i.isEven ? Colors.grey[200] : Colors.white,
                      child: Text('Spacer $i'),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textFieldFinder = find.descendant(
          of: find.byType(ContactAutocompleteField),
          matching: find.byType(TextFormField),
        );
        expect(textFieldFinder, findsOneWidget);

        await tester.enterText(textFieldFinder, 'شركة النور المتميزة');
        await tester.pump();
        expect(controller.text, equals('شركة النور المتميزة'));
        expect(find.text('شركة النور المتميزة'), findsOneWidget);

        // Scroll down
        final listFinder = find.byType(ListView);
        await tester.drag(listFinder, const Offset(0, -900));
        await tester.pumpAndSettle();

        // Scroll back up
        await tester.drag(listFinder, const Offset(0, 900));
        await tester.pumpAndSettle();

        expect(controller.text, equals('شركة النور المتميزة'));
        expect(find.text('شركة النور المتميزة'), findsOneWidget);

        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(seconds: 11));
      },
    );

    testWidgets(
      '2. QuotationScreen: Customer name is NOT wiped out when scrolling down and up',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const QuotationScreen()));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pumpAndSettle();

        final customerField = find.descendant(
          of: find.byType(ContactAutocompleteField),
          matching: find.byType(TextFormField),
        );
        expect(customerField, findsOneWidget);

        // Enter customer name
        await tester.enterText(customerField, 'مؤسسة التجارة العالمية');
        await tester.pump();
        expect(find.text('مؤسسة التجارة العالمية'), findsOneWidget);

        // Scroll down
        final listFinder = find.byType(ListView);
        await tester.drag(listFinder, const Offset(0, -600));
        await tester.pumpAndSettle();

        // Scroll back up
        await tester.drag(listFinder, const Offset(0, 600));
        await tester.pumpAndSettle();

        // Customer name must still be present!
        expect(find.text('مؤسسة التجارة العالمية'), findsOneWidget);

        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(seconds: 11));
      },
    );

    testWidgets(
      '3. InvoiceScreen: Customer name is NOT wiped out when scrolling down and up',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const InvoiceScreen()));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pumpAndSettle();

        final customerField = find.descendant(
          of: find.byType(ContactAutocompleteField),
          matching: find.byType(TextFormField),
        );
        expect(customerField, findsOneWidget);

        await tester.enterText(customerField, 'مستشفى الأمل التخصصي');
        await tester.pump();
        expect(find.text('مستشفى الأمل التخصصي'), findsOneWidget);

        final listFinder = find.byType(ListView);
        await tester.drag(listFinder, const Offset(0, -600));
        await tester.pumpAndSettle();

        await tester.drag(listFinder, const Offset(0, 600));
        await tester.pumpAndSettle();

        expect(find.text('مستشفى الأمل التخصصي'), findsOneWidget);

        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(seconds: 11));
      },
    );

    testWidgets(
      '4. PurchaseScreen: Supplier name is NOT wiped out when scrolling down and up',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const PurchaseScreen()));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pumpAndSettle();

        final supplierField = find.descendant(
          of: find.byType(ContactAutocompleteField),
          matching: find.byType(TextFormField),
        );
        expect(supplierField, findsOneWidget);

        await tester.enterText(supplierField, 'شركة التوريدات العالمية');
        await tester.pump();
        expect(find.text('شركة التوريدات العالمية'), findsOneWidget);

        final listFinder = find.byType(ListView);
        await tester.drag(listFinder, const Offset(0, -600));
        await tester.pumpAndSettle();

        await tester.drag(listFinder, const Offset(0, 600));
        await tester.pumpAndSettle();

        expect(find.text('شركة التوريدات العالمية'), findsOneWidget);

        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(seconds: 11));
      },
    );

    testWidgets(
      '5. EditDocumentScreen: Existing recipient name is displayed and kept intact on scroll',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        late int docId;
        await tester.runAsync(() async {
          final business = (await DatabaseHelper.instance.getFirstBusiness())!;
          docId = await DocumentService.createDocument(
            type: 'quotation',
            business: business,
            recipientName: 'العميل الأصلي محفوظ',
            validUntil: DateTime.now().add(const Duration(days: 7)),
            items: [
              const DocumentItemInput(
                description: 'خدمة تجريبية',
                quantity: 1,
                price: 1000,
                taxable: false,
              ),
            ],
          );
        });

        await tester.pumpWidget(wrapWithApp(EditDocumentScreen(documentId: docId)));
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          if (find.byType(AppLoadingView).evaluate().isEmpty) break;
        }
        await tester.pump();

        // Expect the customer name to be displayed
        expect(find.text('العميل الأصلي محفوظ'), findsOneWidget);

        // Scroll down
        final scrollFinder = find.byType(Scrollable).first;
        await tester.drag(scrollFinder, const Offset(0, -600));
        await tester.pumpAndSettle();

        // Scroll back up
        await tester.drag(scrollFinder, const Offset(0, 600));
        await tester.pumpAndSettle();

        // Still present!
        expect(find.text('العميل الأصلي محفوظ'), findsOneWidget);

        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(seconds: 11));
      },
    );
  });
}
