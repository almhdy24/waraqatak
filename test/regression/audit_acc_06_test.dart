import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_acc_06_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    db = DatabaseHelper.instance;
  });

  tearDownAll(() async {
    await db.closeDatabase();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await db.closeDatabase();
    if (tempDir.existsSync()) {
      for (final f in tempDir.listSync()) {
        if (f is File) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }

    await db.insertBusiness(
      const Business(
        name: 'ACC-06 Test Business',
        ownerName: 'Test Owner',
        phone: '0123456789',
        address: 'Kassala',
        currencyCode: 'SDG',
        taxRate: 0.0,
        taxesEnabled: false,
        pricesIncludeTax: false,
      ),
    );
  });

  test('ACC-06 Regression: Deleting allocated voucher must throw StateError with guidance rather than crashing with raw SQLite FK exception', () async {
    final rawDb = await db.database;

    // 1. Create invoice for 300 SDG
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-300',
      date: DateTime(2026, 3, 1),
      subtotal: 300.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 300.0,
      paid: 0.0,
      remaining: 300.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    final invItems = <DocumentItem>[
      const DocumentItem(
        documentId: 0,
        description: 'Service item',
        quantity: 1.0,
        price: 300.0,
        total: 300.0,
      ),
    ];
    final invId = await db.insertDocumentWithItems(inv, invItems);

    // 2. Record payment with linked receipt voucher
    await db.recordPaymentWithReceipt(
      documentId: invId,
      amount: 300.0,
      paymentMethod: 'cash',
      notes: 'Paid in full',
    );

    // Find the receipt document id
    final payRows = await rawDb.query(
      'document_payments',
      where: 'document_id = ? AND receipt_document_id IS NOT NULL',
      whereArgs: [invId],
    );
    expect(payRows, isNotEmpty);
    final receiptDocId = payRows.first['receipt_document_id'] as int;

    // ACC-06: Pre-delete allocation check for vouchers.
    // Must explicitly detect active allocations and throw StateError with
    // guidance to cancel the document instead of crashing with SQLite FK constraint.
    expect(
      () => db.deleteDocument(receiptDocId),
      throwsA(
        isA<StateError>().having(
          (e) => e.message.toLowerCase(),
          'message',
          anyOf(contains('recorded payment history'), contains('allocated voucher')),
        ),
      ),
      reason: 'ACC-06: Attempting to delete an allocated receipt must throw StateError with explicit cancellation guidance',
    );
  });
}
