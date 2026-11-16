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
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/screens/purchase_screen.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/amount_field.dart';
import 'package:warqatek/widgets/contact_autocomplete_field.dart';
import 'package:warqatek/widgets/document_item_form.dart';
import 'package:warqatek/widgets/product_autocomplete_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SessionManager.instance.setMultiUserEnabledForTesting(false);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('purchase_focus_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await DatabaseHelper.instance.closeDatabase();

    final helper = DatabaseHelper.instance;
    await helper.database;
    await helper.insertBusiness(
      const Business(
        name: 'مؤسسة الاختبار',
        ownerName: 'أحمد',
        phone: '123',
        address: 'الخرطوم',
        currencyCode: 'SDG',
      ),
    );

    await helper.insertContact(
      const Contact(name: 'مورد الأمل', phone: '0911', type: 'supplier'),
    );
    await helper.insertContact(
      const Contact(name: 'مورد البركة', phone: '0922', type: 'supplier'),
    );

    await helper.insertProduct(
      const Product(
        name: 'منتج تجريبي ممتاز',
        salePrice: 100,
        purchasePrice: 70,
      ),
    );
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.closeDatabase();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget createWidget() {
    return LanguageProvider(
      langCode: 'ar',
      onChangeLanguage: (_) async {},
      child: const MaterialApp(
        locale: Locale('ar'),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('ar'), Locale('en')],
        home: PurchaseScreen(),
      ),
    );
  }

  testWidgets(
    'Reproduction: selecting a product does not steal focus back to supplier or reopen supplier autocomplete',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // 1. Enter/select a supplier
      final supplierFinder = find.descendant(
        of: find.byType(ContactAutocompleteField),
        matching: find.byType(TextFormField),
      );
      expect(supplierFinder, findsOneWidget);

      await tester.tap(supplierFinder);
      await tester.enterText(supplierFinder, 'الأمل');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Tap the supplier suggestion
      final supplierOption = find.text('مورد الأمل').last;
      expect(supplierOption, findsOneWidget);
      await tester.tap(supplierOption);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      // 2. Add a product using the product autocomplete field
      final productFinder = find.descendant(
        of: find.byType(ProductAutocompleteField),
        matching: find.byType(TextFormField),
      );
      expect(productFinder, findsOneWidget);

      await tester.tap(productFinder);
      await tester.enterText(productFinder, 'تجريبي');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap the product suggestion
      final productOption = find.text('منتج تجريبي ممتاز').last;
      expect(productOption, findsOneWidget);
      await tester.tap(productOption);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      // 3. Verify focus is NOT on supplier, and supplier suggestions are NOT showing
      final supplierEditableText = tester.widget<EditableText>(
        find.descendant(
          of: supplierFinder,
          matching: find.byType(EditableText),
        ),
      );
      expect(
        supplierEditableText.focusNode.hasFocus,
        isFalse,
        reason: 'Focus unexpectedly jumped back to supplier field!',
      );

      // Verify supplier suggestions overlay is NOT open
      expect(
        find.text('مورد الأمل'),
        findsOneWidget, // Only in the text field itself
      );

      // 4. Verify focus moved to the next logical purchase order field (Quantity AmountField)
      final quantityFinder = find.descendant(
        of: find.byType(DocumentItemForm),
        matching: find.byType(AmountField),
      ).first;
      expect(quantityFinder, findsOneWidget);

      final quantityEditableText = tester.widget<EditableText>(
        find.descendant(
          of: quantityFinder,
          matching: find.byType(EditableText),
        ),
      );
      expect(
        quantityEditableText.focusNode.hasFocus,
        isTrue,
        reason: 'Focus should logically move to item quantity field!',
      );

      // 5. Test typing a new supplier query explicitly opens suggestions
      await tester.tap(supplierFinder);
      await tester.enterText(supplierFinder, 'البركة');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // New supplier suggestion should appear
      expect(find.text('مورد البركة'), findsWidgets);
    },
  );
}
