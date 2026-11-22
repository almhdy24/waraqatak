import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/screens/contact_form_screen.dart';
import 'package:warqatek/screens/customer_detail_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_ux_02_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  late Contact testContact;

  setUp(() async {
    await DatabaseHelper.instance.closeDatabase();
    final dir = Directory.systemTemp.createTempSync('ux02_run_');
    await databaseFactory.setDatabasesPath(dir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'Test Business',
        currencyCode: 'SDG',
        phone: '0123456789',
        address: 'Khartoum',
        ownerName: 'Test Owner',
      ),
    );

    final contactId = await db.insertContact(
      const Contact(
        name: 'Ahmed Test',
        phone: '0912345678',
        type: 'customer',
      ),
    );
    testContact = (await db.getContactById(contactId))!;
  });

  testWidgets('UX-02 Regression: CustomerDetailScreen must not pop prematurely when editing contact', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        locale: const Locale('ar'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerDetailScreen(contact: testContact),
                    ),
                  );
                },
                child: const Text('Open Customer'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open CustomerDetailScreen
    await tester.tap(find.text('Open Customer'));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CustomerDetailScreen), findsOneWidget);

    // Tap the edit icon button in CustomerDetailScreen appBar
    final editButton = find.byIcon(Icons.edit_outlined);
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify ContactFormScreen is now on top
    expect(find.byType(ContactFormScreen), findsOneWidget);

    // Simulate saving the contact successfully (which returns true to caller)
    Navigator.pop(tester.element(find.byType(ContactFormScreen)), true);
    // Allow ContactFormScreen pop transition (300ms)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // Allow _load and CustomerDetailScreen premature pop transition (300ms)
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // UX-02 BUG: CustomerDetailScreen._editContact contains:
    //   if (result == true && mounted) {
    //     _load();
    //     Navigator.pop(context, true); // <--- Abruptly dismisses the detail screen!
    //   }
    // Expected behavior: CustomerDetailScreen should remain mounted to display the updated profile.
    expect(
      find.byType(CustomerDetailScreen),
      findsOneWidget,
      reason: 'UX-02: CustomerDetailScreen must remain mounted after saving contact edits, but was prematurely popped',
    );
  });
}
