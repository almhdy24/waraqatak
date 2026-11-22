import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/journal_backfill_service.dart';
import 'package:warqatek/services/accounting/ledger.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_acc_01_test');
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
        name: 'ACC-01 Test Business',
        ownerName: 'Test Owner',
        phone: '0123456789',
        address: 'Khartoum',
        currencyCode: 'SDG',
        taxRate: 0.0,
        taxesEnabled: false,
        pricesIncludeTax: false,
      ),
    );
  });

  test('ACC-01 Regression: Invoice edit must not duplicate payment posting in journal', () async {
    final rawDb = await db.database;

    // 1. Setup product
    final pId = await db.insertProduct(
      Product(
        name: 'Item A',
        salePrice: 1000.0,
        purchasePrice: 600.0,
        averageCost: 600.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 100.0,
      ),
    );

    // 2. Day 1: Create Invoice for 1,000 SDG (paid = 0)
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-001',
      date: DateTime(2026, 3, 1),
      subtotal: 1000.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 1000.0,
      paid: 0.0,
      remaining: 1000.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    final invItems = <DocumentItem>[
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'Item A',
        quantity: 1.0,
        price: 1000.0,
        total: 1000.0,
        baseQuantity: 1.0,
      ),
    ];
    final docId = await db.insertDocumentWithItems(inv, invItems);

    // 3. Day 10: Customer pays 400 SDG via receipt voucher allocated to INV-001
    await db.recordPaymentWithReceipt(
      documentId: docId,
      amount: 400.0,
      paymentMethod: 'cash',
      notes: 'First installment',
    );

    // 4. Day 15: Edit invoice to add an item, increasing total from 1,000 to 1,200 SDG (paid remains 400)
    final docBeforeEdit = await db.getDocumentById(docId);
    expect(docBeforeEdit, isNotNull);
    expect(docBeforeEdit!.paid, equals(400.0));

    final updatedDoc = docBeforeEdit.copyWith(
      subtotal: 1200.0,
      total: 1200.0,
      remaining: 800.0,
    );
    final updatedItems = <DocumentItem>[
      DocumentItem(
        documentId: docId,
        productId: pId,
        description: 'Item A',
        quantity: 1.2,
        price: 1000.0,
        total: 1200.0,
        baseQuantity: 1.2,
      ),
    ];
    await db.updateDocumentWithItems(updatedDoc, updatedItems);

    // 5. Inspect journal_lines for Account 1110 (Cash)
    // Only 400 SDG was ever paid into cash.
    // Total debit to Cash (1110) should be 40,000 minor units (400 SDG).
    final cashLines = await rawDb.query(
      'journal_lines',
      where: 'account_code = ?',
      whereArgs: [Accounts.cash.code],
    );

    int totalCashDebitMinor = 0;
    for (final line in cashLines) {
      totalCashDebitMinor += (line['debit_minor'] as int?) ?? 0;
    }

    // ACC-01 BUG: In updateDocumentWithItems, reverseDocument reverses JE-INV but leaves JE-REC intact.
    // Then postDocumentIssued sees doc.paid = 400 > 0 and posts a duplicate JE-PAY for 400!
    // Total cash debit becomes 80,000 minor units instead of 40,000 minor units.
    expect(
      totalCashDebitMinor,
      equals(40000),
      reason: 'ACC-01: Cash debit in journal must equal exactly 400 SDG (40000 minor units), but was double-counted on edit',
    );

    await JournalBackfillService.verifyParity(executor: rawDb);
  });
}
