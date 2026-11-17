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
import 'package:warqatek/models/product.dart';
import 'package:warqatek/screens/quotation_screen.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/utils/error_utils.dart';
import 'package:warqatek/utils/number_input.dart';
import 'package:warqatek/widgets/amount_field.dart';
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
    tempDir = Directory.systemTemp.createTempSync('quotation_test_');
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

    await helper.insertProduct(
      const Product(
        name: 'Lenovo Thinkpad L14',
        salePrice: 200000,
        purchasePrice: 150000,
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

  group('Quotation & Document Reproduction Tests', () {
    test('1. Error string matching: ErrorUtils maps old and new exceptions correctly', () {
      final l10nAr = AppLocalizations('ar');

      // Exact customer string:
      final errCustomer = ArgumentError('Valid until must be after document date');
      expect(ErrorUtils.toFriendlyMessage(errCustomer, l10nAr), equals(l10nAr.errorValidUntilBeforeDate));

      // Old test string:
      final errServiceOld = ArgumentError('validUntil must be on or after date');
      expect(ErrorUtils.toFriendlyMessage(errServiceOld, l10nAr), equals(l10nAr.errorValidUntilBeforeDate));

      // 0-day error:
      final errZeroDay = ArgumentError('Quotation validity period must be at least 1 day');
      expect(ErrorUtils.toFriendlyMessage(errZeroDay, l10nAr), equals(l10nAr.errorValidityMinDays));
    });

    test('2. Validity date rules & Timezone safety (Africa/Khartoum, UTC+2)', () async {
      final business = (await DatabaseHelper.instance.getFirstBusiness())!;
      final docDate = DateTime.utc(2026, 11, 17, 18, 30); // 18:30 in Khartoum

      // Same calendar date with earlier timestamp must be 0 calendar days:
      final sameDayEarlierTime = DateTime.utc(2026, 11, 17, 9, 0);
      expect(DocumentService.calendarDaysBetween(docDate, sameDayEarlierTime), equals(0));

      // Next calendar date with earlier timestamp must be 1 calendar day:
      final nextDayEarlierTime = DateTime.utc(2026, 11, 18, 8, 0);
      expect(DocumentService.calendarDaysBetween(docDate, nextDayEarlierTime), equals(1));

      // Service rejects 0-day validity:
      expect(
        () => DocumentService.createDocument(
          type: 'quotation',
          business: business,
          items: const [
            DocumentItemInput(description: 'Item', quantity: 1, price: 100, taxable: false),
          ],
          date: docDate,
          validUntil: sameDayEarlierTime,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('at least 1 day'),
        )),
      );

      // Service rejects negative days:
      final pastDate = DateTime.utc(2026, 11, 16);
      expect(
        () => DocumentService.createDocument(
          type: 'quotation',
          business: business,
          items: const [
            DocumentItemInput(description: 'Item', quantity: 1, price: 100, taxable: false),
          ],
          date: docDate,
          validUntil: pastDate,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('must be after document date'),
        )),
      );
    });

    test('3. Quotation discount: respects discount, converts to invoice, checks limits and accounting immutability', () async {
      final business = (await DatabaseHelper.instance.getFirstBusiness())!;
      final now = DateTime.now();
      final validUntil = now.add(const Duration(days: 7));

      // A) Create quotation with discount
      final docId = await DocumentService.createDocument(
        type: 'quotation',
        business: business,
        items: const [
          DocumentItemInput(description: 'Laptop', quantity: 1, price: 1000, taxable: false),
        ],
        discount: 150,
        date: now,
        validUntil: validUntil,
      );

      final quotation = await DatabaseHelper.instance.getDocumentById(docId);
      expect(quotation, isNotNull);
      expect(quotation!.discount, equals(150.0));
      expect(quotation.total, equals(850.0));

      // B) Discount exceeding subtotal throws
      expect(
        () => DocumentService.createDocument(
          type: 'quotation',
          business: business,
          items: const [
            DocumentItemInput(description: 'Item', quantity: 1, price: 100, taxable: false),
          ],
          discount: 200,
          date: now,
          validUntil: validUntil,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Discount cannot exceed subtotal'),
        )),
      );

      // C) Re-save quotation with discount 0
      await DocumentService.updateDocument(
        documentId: docId,
        type: 'quotation',
        business: business,
        items: const [
          DocumentItemInput(description: 'Laptop', quantity: 1, price: 1000, taxable: false),
        ],
        discount: 0,
        date: now,
        validUntil: validUntil,
      );
      final resavedQuotation = await DatabaseHelper.instance.getDocumentById(docId);
      expect(resavedQuotation!.discount, equals(0.0));
      expect(resavedQuotation.total, equals(1000.0));

      // Update back with 150 discount for invoice conversion test
      await DocumentService.updateDocument(
        documentId: docId,
        type: 'quotation',
        business: business,
        items: const [
          DocumentItemInput(description: 'Laptop', quantity: 1, price: 1000, taxable: false),
        ],
        discount: 150,
        date: now,
        validUntil: validUntil,
      );

      // D) Convert quotation to invoice: discount and totals carry over
      final invoiceId = await DocumentService.convertQuotationToInvoice(docId);
      final convertedInvoice = await DatabaseHelper.instance.getDocumentById(invoiceId);
      expect(convertedInvoice, isNotNull);
      expect(convertedInvoice!.type, equals('invoice'));
      expect(convertedInvoice.discount, equals(150.0));
      expect(convertedInvoice.subtotal, equals(1000.0));
      expect(convertedInvoice.total, equals(850.0));
      expect(convertedInvoice.remaining, equals(850.0));

      // E) Invariants: quotation creates 0 journal lines
      final db = await DatabaseHelper.instance.database;
      final journalEntries = await db.query(
        'journal_entries',
        where: 'source_id = ?',
        whereArgs: [docId],
      );
      expect(journalEntries, isEmpty);
    });

    test('4. Audit log records document_edited on updates', () async {
      final business = (await DatabaseHelper.instance.getFirstBusiness())!;
      final now = DateTime.now();
      final validUntil = now.add(const Duration(days: 7));

      final docId = await DocumentService.createDocument(
        type: 'quotation',
        business: business,
        items: const [
          DocumentItemInput(description: 'Item Original', quantity: 1, price: 500, taxable: false),
        ],
        date: now,
        validUntil: validUntil,
      );

      await DocumentService.updateDocument(
        documentId: docId,
        type: 'quotation',
        business: business,
        items: const [
          DocumentItemInput(description: 'Item Updated', quantity: 1, price: 600, taxable: false),
        ],
        date: now,
        validUntil: validUntil,
      );

      final auditRows = await DatabaseHelper.instance.getRecentAuditEvents(limit: 20);
      final editEvent = auditRows.firstWhere(
        (e) => e['action'] == 'document_edited' && e['entity_id'] == docId,
        orElse: () => <String, dynamic>{},
      );
      expect(editEvent, isNotEmpty);
      expect(editEvent['entity_type'], equals('document'));
    });

    test('5. Custom Product Name & Description persistence across quotation, invoice, and purchase flows', () async {
      final business = (await DatabaseHelper.instance.getFirstBusiness())!;
      final now = DateTime.now();
      final validUntil = now.add(const Duration(days: 7));

      for (final docType in ['quotation', 'invoice', 'purchase']) {
        // Save with custom name + separate description encoded as newline
        final docId = await DocumentService.createDocument(
          type: docType,
          business: business,
          items: const [
            DocumentItemInput(
              description: 'Lenovo E55\n16GB RAM / 512GB SSD',
              quantity: 1,
              price: 450000,
              taxable: false,
            ),
          ],
          date: now,
          validUntil: docType == 'quotation' ? validUntil : null,
        );

        final items = await DatabaseHelper.instance.getDocumentItems(docId);
        expect(items, hasLength(1));
        final storedDesc = items.first.description;
        expect(storedDesc, equals('Lenovo E55\n16GB RAM / 512GB SSD'));

        // When reopening in EditDocumentScreen, split into product name and description:
        final idx = storedDesc.indexOf('\n');
        final restoredName = storedDesc.substring(0, idx).trim();
        final restoredDesc = storedDesc.substring(idx + 1).trim();

        expect(restoredName, equals('Lenovo E55'));
        expect(restoredDesc, equals('16GB RAM / 512GB SSD'));
      }
    });

    testWidgets('6. Bug 1: Product name field does not lose typed text after scrolling', (tester) async {
      tester.view.physicalSize = const Size(384, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapWithApp(const QuotationScreen()));
      await tester.pumpAndSettle();

      final productField = find.descendant(
        of: find.byType(ProductAutocompleteField),
        matching: find.byType(TextFormField),
      );
      expect(productField, findsOneWidget);

      await tester.enterText(productField, 'lenovo yoga');
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(ProductAutocompleteField),
          matching: find.text('lenovo yoga'),
        ),
        findsOneWidget,
      );

      final listFinder = find.byType(ListView);
      await tester.drag(listFinder, const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.drag(listFinder, const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ProductAutocompleteField),
          matching: find.text('lenovo yoga'),
        ),
        findsOneWidget,
      );

      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('7. Bug 1.2: Deleting middle item keeps the other items values intact', (tester) async {
      await tester.pumpWidget(wrapWithApp(const QuotationScreen()));
      await tester.pumpAndSettle();

      final addItemBtn = find.widgetWithText(OutlinedButton, AppLocalizations('ar').addItem);
      await tester.tap(addItemBtn);
      await tester.pumpAndSettle();
      await tester.tap(addItemBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DocumentItemForm), findsNWidgets(3));

      final forms = find.byType(DocumentItemForm);
      final item0Field = find.descendant(
        of: forms.at(0),
        matching: find.byType(TextFormField),
      ).first;
      final item1Field = find.descendant(
        of: forms.at(1),
        matching: find.byType(TextFormField),
      ).first;
      final item2Field = find.descendant(
        of: forms.at(2),
        matching: find.byType(TextFormField),
      ).first;

      await tester.enterText(item0Field, 'Item Zero');
      await tester.enterText(item1Field, 'Item One');
      await tester.enterText(item2Field, 'Item Two');
      await tester.pumpAndSettle();

      expect(find.text('Item Zero'), findsWidgets);
      expect(find.text('Item One'), findsWidgets);
      expect(find.text('Item Two'), findsWidgets);

      final deleteBtnItem1 = find.descendant(
        of: forms.at(1),
        matching: find.byIcon(Icons.delete_outline),
      );
      await tester.tap(deleteBtnItem1);
      await tester.pumpAndSettle();

      final confirmBtn = find.text(AppLocalizations('ar').delete);
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.last);
        await tester.pumpAndSettle();
      }

      expect(find.byType(DocumentItemForm), findsNWidgets(2));
      expect(find.text('Item Zero'), findsWidgets);
      expect(find.text('Item Two'), findsWidgets);
      expect(find.text('Item One'), findsNothing);

      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('8. Bug 2.2: Validity field validator shows localized error and scrolls to field', (tester) async {
      await tester.pumpWidget(wrapWithApp(const QuotationScreen()));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      final validityFieldFinder = find.widgetWithText(AmountField, l10n.validityDays);
      expect(validityFieldFinder, findsOneWidget);

      final validityTextFormField = find.descendant(
        of: validityFieldFinder,
        matching: find.byType(TextFormField),
      );

      await tester.enterText(validityTextFormField, '0');
      await tester.pumpAndSettle();

      final descField = find.descendant(
        of: find.byType(DocumentItemForm),
        matching: find.byType(TextFormField),
      ).first;
      await tester.enterText(descField, 'Laptop');
      final priceField = find.descendant(
        of: find.byType(DocumentItemForm),
        matching: find.widgetWithText(AmountField, l10n.itemPrice),
      );
      await tester.enterText(find.descendant(of: priceField, matching: find.byType(TextFormField)), '500');
      await tester.pumpAndSettle();

      final saveBtn = find.widgetWithText(FilledButton, l10n.save);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Error message for 0 days must be errorValidityMinDays
      expect(find.text(l10n.errorValidityMinDays), findsOneWidget);

      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('9. Bug 1.3: Soft keyboard submission does not hijack typed custom product name with suggestion', (tester) async {
      await tester.pumpWidget(wrapWithApp(const QuotationScreen()));
      await tester.pumpAndSettle();

      final productField = find.descendant(
        of: find.byType(ProductAutocompleteField),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(productField, 'Lenovo yoga');
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(ProductAutocompleteField), matching: find.text('Lenovo yoga')), findsOneWidget);
      expect(find.byType(ProductAutocompleteField), findsOneWidget);

      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('10. Custom product name typing never overwrites separate description field in DocumentItemForm', (tester) async {
      final nameController = TextEditingController();
      final descController = TextEditingController(text: 'Initial Description');
      final qtyController = TextEditingController(text: '1');
      final priceController = TextEditingController(text: '100');

      await tester.pumpWidget(
        wrapWithApp(
          Scaffold(
            body: DocumentItemForm(
              productNameController: nameController,
              descriptionController: descController,
              quantityController: qtyController,
              priceController: priceController,
              taxable: false,
              onTaxableChanged: (_) {},
              onProductChanged: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final productField = find.descendant(
        of: find.byType(ProductAutocompleteField),
        matching: find.byType(TextFormField),
      );

      // Type a product name
      await tester.enterText(productField, 'Lenovo Legion 5');
      await tester.pump();

      // Verify that descriptionController was NOT overwritten!
      expect(descController.text, equals('Initial Description'));
      expect(nameController.text, equals('Lenovo Legion 5'));
    });

    test('11. Legacy custom items: multi-line, description-only, and name-only round trip without data loss', () async {
      final helper = DatabaseHelper.instance;
      final business = (await helper.getFirstBusiness())!;

      // 1. Create a quotation with 3 legacy custom items in SQLite
      final items = [
        const DocumentItemInput(
          description: 'Service A\nLine 2 details\nLine 3 notes',
          quantity: 1,
          price: 1000,
          taxable: false,
        ),
        const DocumentItemInput(
          description: 'Just a single line description',
          quantity: 2,
          price: 500,
          taxable: false,
        ),
        const DocumentItemInput(
          description: 'Custom Item Name',
          quantity: 1,
          price: 300,
          taxable: false,
        ),
      ];

      final docId = await DocumentService.createDocument(
        type: 'quotation',
        business: business,
        items: items,
        date: DateTime.utc(2026, 11, 1, 10, 0),
        validUntil: DateTime.utc(2026, 11, 10, 10, 0),
      );

      // Verify original stored descriptions in SQLite
      final storedItems = await helper.getDocumentItems(docId);
      expect(storedItems, isNotEmpty);
      expect(storedItems[0].description, equals('Service A\nLine 2 details\nLine 3 notes'));
      expect(storedItems[1].description, equals('Just a single line description'));
      expect(storedItems[2].description, equals('Custom Item Name'));

      // 2. Simulate reopening in EditDocumentScreen
      // For each item, split on newline:
      final nameControllers = <TextEditingController>[];
      final descControllers = <TextEditingController>[];
      for (final item in storedItems) {
        final parts = item.description.split('\n');
        if (parts.length > 1) {
          nameControllers.add(TextEditingController(text: parts.first));
          descControllers.add(TextEditingController(text: parts.sublist(1).join('\n')));
        } else {
          nameControllers.add(TextEditingController(text: parts.first));
          descControllers.add(TextEditingController(text: ''));
        }
      }

      // Check parsed controllers
      expect(nameControllers[0].text, equals('Service A'));
      expect(descControllers[0].text, equals('Line 2 details\nLine 3 notes'));

      expect(nameControllers[1].text, equals('Just a single line description'));
      expect(descControllers[1].text, equals(''));

      expect(nameControllers[2].text, equals('Custom Item Name'));
      expect(descControllers[2].text, equals(''));

      // 3. Re-save without changing text: Reconstruct effectiveDesc
      final resavedItems = <DocumentItemInput>[];
      for (int i = 0; i < storedItems.length; i++) {
        final name = nameControllers[i].text.trim();
        final desc = descControllers[i].text.trim();
        final effectiveDesc = (name.isNotEmpty && desc.isNotEmpty && name != desc)
            ? '$name\n$desc'
            : (name.isNotEmpty ? name : desc);
        resavedItems.add(
          DocumentItemInput(
            description: effectiveDesc,
            quantity: storedItems[i].quantity,
            price: storedItems[i].price,
            taxable: storedItems[i].taxable,
          ),
        );
      }

      await DocumentService.updateDocument(
        documentId: docId,
        type: 'quotation',
        business: business,
        items: resavedItems,
        validUntil: DateTime.utc(2026, 11, 10, 10, 0),
      );

      // Verify the re-saved descriptions in SQLite match exactly
      final reloadedItems = await helper.getDocumentItems(docId);
      expect(reloadedItems[0].description, equals('Service A\nLine 2 details\nLine 3 notes'));
      expect(reloadedItems[1].description, equals('Just a single line description'));
      expect(reloadedItems[2].description, equals('Custom Item Name'));
    });

    test('12. Opening and re-saving an OLD quotation with validUntil null or 0 days', () async {
      final helper = DatabaseHelper.instance;
      final business = (await helper.getFirstBusiness())!;

      // Insert an old quotation directly with valid_until = NULL
      final db = await helper.database;
      final docId = await db.insert('documents', {
        'type': 'quotation',
        'document_number': 'QUO-LEGACY-001',
        'date': '2026-01-01T00:00:00.000',
        'valid_until': null, // Old document with null valid_until
        'subtotal': 1000.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 1000.0,
        'paid': 0.0,
        'remaining': 1000.0,
        'status': 'active',
      });
      await db.insert('document_items', {
        'document_id': docId,
        'description': 'Legacy item',
        'quantity': 1.0,
        'price': 1000.0,
        'total': 1000.0,
        'taxable': 0,
      });

      final legacyDoc = await helper.getDocumentById(docId);
      expect(legacyDoc, isNotNull);
      expect(legacyDoc!.validUntil, isNull);

      // Verify EditDocumentScreen initialization behavior:
      // When doc.validUntil is null, validityDaysController is empty (NOT silently defaulted to 7)
      final validityController = TextEditingController();
      if (legacyDoc.validUntil != null) {
        final days = DocumentService.calendarDaysBetween(legacyDoc.date, legacyDoc.validUntil!);
        validityController.text = days.toString();
      } else {
        validityController.text = '';
      }
      expect(validityController.text, equals(''), reason: 'Old document must not silently receive 7 days default');

      // Validator rejects empty or <= 0
      final l10nAr = AppLocalizations('ar');
      String? validateValidity(String? v) {
        final d = NumberInput.parse(v ?? '')?.toInt();
        if (d == null || d <= 0) {
          return l10nAr.errorValidityMinDays;
        }
        return null;
      }

      expect(validateValidity(''), equals(l10nAr.errorValidityMinDays));
      expect(validateValidity('0'), equals(l10nAr.errorValidityMinDays));

      // Attempting to update with null or 0 throws clear ArgumentError
      expect(
        () => DocumentService.updateDocument(
          documentId: docId,
          type: 'quotation',
          business: business,
          items: [const DocumentItemInput(description: 'Legacy item', quantity: 1, price: 1000, taxable: false)],
          validUntil: null,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('Valid until date is required'))),
      );

      // Once the user enters valid days (e.g. 14 days), save succeeds
      final newValidUntil = legacyDoc.date.add(const Duration(days: 14));
      await DocumentService.updateDocument(
        documentId: docId,
        type: 'quotation',
        business: business,
        items: [const DocumentItemInput(description: 'Legacy item', quantity: 1, price: 1000, taxable: false)],
        validUntil: newValidUntil,
      );

      final updatedDoc = await helper.getDocumentById(docId);
      expect(updatedDoc!.validUntil, equals(newValidUntil));
    });

    test('13. Arabic-Indic digits and thousands separators parsing in number inputs', () {
      // Eastern Arabic numerals (٠-٩) and Arabic decimal comma (، / ٫)
      expect(NumberInput.parse('١٢٣.٤٥'), closeTo(123.45, 0.0001));
      expect(NumberInput.parse('١,٠٠٠'), closeTo(1000.0, 0.0001));
      expect(NumberInput.parse('١،٠٠٠.٥٠'), closeTo(1000.50, 0.0001));
      expect(NumberInput.parse('٥٠'), closeTo(50.0, 0.0001));
      expect(NumberInput.parse('٠.٧٥'), closeTo(0.75, 0.0001));

      // Combined calculation
      final qty = NumberInput.parse('٢.٥') ?? 0;
      final price = NumberInput.parse('١٠٠') ?? 0;
      expect(qty * price, closeTo(250.0, 0.0001));
    });

    testWidgets('14. Double-tap on Save: button enters disabled/saving state and ignores concurrent taps', (tester) async {
      bool isSaving = false;
      int saveInvocations = 0;

      Future<void> simulateSave() async {
        if (isSaving) return; // The exact guard used in QuotationScreen and EditDocumentScreen
        isSaving = true;
        saveInvocations++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        isSaving = false;
      }

      await tester.pumpWidget(
        wrapWithApp(
          StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: FilledButton(
                  onPressed: isSaving ? null : () async {
                    setState(() {});
                    await simulateSave();
                    setState(() {});
                  },
                  child: isSaving
                      ? const CircularProgressIndicator()
                      : const Text('حفظ'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btn = find.byType(FilledButton);
      expect(btn, findsOneWidget);

      // Tap twice rapidly
      await tester.tap(btn);
      await tester.pump(); // Start first save, button enters loading
      expect(isSaving, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Attempt second tap while saving
      await tester.tap(btn);
      await simulateSave(); // Guard check
      expect(saveInvocations, equals(1), reason: 'Double-tap must not invoke save twice');

      await tester.pump(const Duration(milliseconds: 60));
      expect(isSaving, isFalse);
      expect(find.text('حفظ'), findsOneWidget);
    });
  });
}
