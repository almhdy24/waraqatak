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
import 'package:warqatek/screens/voucher_screen.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/utils/number_input.dart';
import 'package:warqatek/widgets/amount_field.dart';
import 'package:warqatek/widgets/contact_autocomplete_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Business business;
  late Contact customerWithDebt;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SessionManager.instance.setMultiUserEnabledForTesting(false);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('voucher_shortcut_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await DatabaseHelper.instance.closeDatabase();

    final helper = DatabaseHelper.instance;
    await helper.database;
    await helper.insertBusiness(
      const Business(
        name: 'مؤسسة السندات',
        ownerName: 'أحمد',
        phone: '123',
        address: 'الخرطوم',
        currencyCode: 'SDG',
      ),
    );
    business = (await helper.getFirstBusiness())!;

    // Create a customer with outstanding balance
    final c1Id = await helper.insertContact(
      const Contact(name: 'عميل آجل', phone: '0111', type: 'customer'),
    );
    customerWithDebt = (await helper.getContactById(c1Id))!;

    // Create an unpaid invoice for 3,500 SDG
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        const DocumentItemInput(
          description: 'بضاعة آجلة',
          quantity: 1,
          price: 3500,
          taxable: false,
        ),
      ],
      paid: 0,
      contact: customerWithDebt,
    );

    // Create a customer with 0 debt
    await helper.insertContact(
      const Contact(name: 'عميل مسدد', phone: '0222', type: 'customer'),
    );
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget buildApp(Widget child) {
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

  testWidgets(
    'Voucher screen: pay full balance shortcut displays and clicking fills amount',
    (tester) async {
      final l10n = AppLocalizations('ar');

      await tester.pumpWidget(
        buildApp(const VoucherScreen(type: VoucherType.paymentReceipt)),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Before selecting a contact, pay full balance shortcut should not exist
      expect(
        find.widgetWithText(TextButton, l10n.voucherPayFullBalance),
        findsNothing,
      );

      // Select contact with debt via Autocomplete field
      final contactInput = find.descendant(
        of: find.byType(ContactAutocompleteField),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(contactInput, 'عميل آجل');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();

      // Tap on the autocomplete option
      await tester.tap(find.text('عميل آجل').last);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Now verify pay full balance shortcut button exists
      final payFullButton = find.widgetWithText(
        TextButton,
        l10n.voucherPayFullBalance,
      );
      expect(payFullButton, findsOneWidget);

      // Tap the shortcut button to populate the amount field
      await tester.tap(payFullButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify amount controller is populated with 3,500
      final amountField = find.byType(AmountField);
      expect(amountField, findsOneWidget);
      expect(find.text(NumberInput.formatForInput(3500)), findsOneWidget);

      // Switch to customer with 0 debt
      await tester.enterText(contactInput, 'عميل مسدد');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();

      // Tap on the autocomplete option
      await tester.tap(find.text('عميل مسدد').last);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Customer has 0 debt -> shortcut button should not be shown
      expect(
        find.widgetWithText(TextButton, l10n.voucherPayFullBalance),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Voucher screen: overpayment is prevented and shortcut auto-resolves excess',
    (tester) async {
      final l10n = AppLocalizations('ar');

      await tester.pumpWidget(
        buildApp(const VoucherScreen(type: VoucherType.paymentReceipt)),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Select contact with debt (3,500)
      final contactInput = find.descendant(
        of: find.byType(ContactAutocompleteField),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(contactInput, 'عميل آجل');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('عميل آجل').last);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Enter an overpayment amount: 5,000 (exceeds 3,500)
      final amountInput = find.descendant(
        of: find.byType(AmountField),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(amountInput, '5000');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Attempt save -> form validation rejects overpayment
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      final saveButton = find.widgetWithText(FilledButton, l10n.save);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('المبلغ أكبر من المستحق'),
        findsOneWidget,
      );

      // Now scroll back up and tap the full balance shortcut to fix the amount
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      final payFullButton = find.widgetWithText(
        TextButton,
        l10n.voucherPayFullBalance,
      );
      expect(payFullButton, findsOneWidget);
      await tester.tap(payFullButton);
      await tester.pumpAndSettle();

      // Amount is now 3,500 and overpayment error is resolved
      expect(find.text(NumberInput.formatForInput(3500)), findsOneWidget);
      expect(
        find.textContaining('المبلغ أكبر من المستحق'),
        findsNothing,
      );
    },
  );
}
