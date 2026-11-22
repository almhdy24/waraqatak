import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;
  late Business business;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_acc_11_test');
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

    business = const Business(
      name: 'ACC-11 Test Business',
      ownerName: 'Test Owner',
      phone: '0123456789',
      address: 'Khartoum',
      currencyCode: 'SDG',
      taxRate: 15.0, // 15% business default tax rate
      taxesEnabled: true,
      pricesIncludeTax: false,
    );
    final bId = await db.insertBusiness(business);
    business = business.copyWith(id: bId);
  });

  test('ACC-11 Regression: Multi-rate tax invoice must not display single fallback tax rate (15%) as document tax rate', () async {
    // 1. Create an invoice with mixed tax rates:
    // Item 1: Standard taxed @ 15% (taxRate: 15.0)
    // Item 2: Zero-rated / exempt @ 0% (taxRate: 0.0)
    final items = [
      DocumentItemInput(
        description: 'Taxable Goods',
        quantity: 1.0,
        price: 100.0,
        taxRate: 15.0,
      ),
      DocumentItemInput(
        description: 'Exempt Services',
        quantity: 1.0,
        price: 100.0,
        taxRate: 0.0,
      ),
    ];

    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: items,
      payNowMethod: 'cash',
    );

    final doc = await db.getDocumentById(docId);
    expect(doc, isNotNull);

    // Subtotal: 200, Tax Amount: 15 (only from Item 1)
    expect(doc!.subtotal, equals(200.0));
    expect(doc.taxAmount, equals(15.0));

    // ACC-11 BUG: DocumentService.createDocument lines 202 and 226 unconditionally assign
    // `taxRate = effectiveTaxRate;` (15.0 / 15%) regardless of whether items have heterogeneous
    // rates. When displayed on PDF or UI totals, it claims "Tax (15%): 15.00 SDG", which falsely
    // implies 15% was levied on the 200.00 subtotal (which would be 30 SDG, not 15 SDG).
    // For mixed-rate documents, doc.taxRate should not be the uniform 15% rate.
    expect(
      doc.taxRate,
      isNot(equals(15.0)),
      reason: 'ACC-11: Multi-rate document must not display single fallback rate (15%) when items have heterogeneous rates',
    );
  });
}
