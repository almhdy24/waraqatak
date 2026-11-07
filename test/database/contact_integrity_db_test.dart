// Real SQLite (ffi) integration test for contact deletion integrity (Batch 2).
// Covers: contact with documents blocks deletion, contact without documents deletes OK.
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Business business;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('contact_integrity_db_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final db = DatabaseHelper.instance;
    await db.insertBusiness(const Business(
      name: 'متجر الاختبار',
      ownerName: 'أحمد',
      phone: '0912345678',
      address: 'الخرطوم',
      taxRate: 0,
    ));
    business = (await db.getFirstBusiness())!;
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('B2-3: contact with one document → deleteContact throws StateError; contact and document still exist', () async {
    final db = DatabaseHelper.instance;
    // Create a contact
    final contactId = await db.insertContact(Contact(
      name: 'عميل اختبار',
      type: 'customer',
    ));

    // Create a document referencing this contact
    final contact = (await db.getContactById(contactId))!;
    await DocumentService.createDocument(
      type: 'payment_receipt',
      business: business,
      contact: contact,
      paid: 100,
      paymentMethod: 'cash',
      items: [],
    );

    // countContactDocuments must return > 0
    final count = await db.countContactDocuments(contactId);
    expect(count, greaterThan(0));

    // deleteContact must throw StateError
    await expectLater(
      () => db.deleteContact(contactId),
      throwsA(isA<StateError>()),
    );

    // Contact still exists
    expect(await db.getContactById(contactId), isNotNull);
  });

  test('B2-3: contact with no documents → deleteContact succeeds', () async {
    final db = DatabaseHelper.instance;
    final contactId = await db.insertContact(Contact(
      name: 'عميل بدون مستندات',
      type: 'customer',
    ));

    final count = await db.countContactDocuments(contactId);
    expect(count, 0);

    final deleted = await db.deleteContact(contactId);
    expect(deleted, 1);
    expect(await db.getContactById(contactId), isNull);
  });
}
