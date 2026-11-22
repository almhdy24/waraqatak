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
import 'package:warqatek/services/accounting/ledger.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_acc_04_test');
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
        name: 'ACC-04 Test Business',
        ownerName: 'Test Owner',
        phone: '0123456789',
        address: 'Omdurman',
        currencyCode: 'SDG',
        taxRate: 0.0,
        taxesEnabled: false,
        pricesIncludeTax: false,
      ),
    );
  });

  test('ACC-04 Regression: Zero-total invoices must record COGS and credit Inventory in journal', () async {
    final rawDb = await db.database;

    // 1. Setup product with known average cost
    final pId = await db.insertProduct(
      Product(
        name: 'Promo Item',
        salePrice: 100.0,
        purchasePrice: 40.0,
        averageCost: 40.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 10.0,
      ),
    );

    // 2. Issue invoice with 100% discount (doc.total = 0.0 SDG)
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-FREE-01',
      date: DateTime(2026, 3, 10),
      subtotal: 200.0,
      discount: 200.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 0.0,
      paid: 0.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    final invItems = <DocumentItem>[
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'Promo Item',
        quantity: 2.0,
        price: 100.0,
        total: 200.0,
        baseQuantity: 2.0,
        unitCost: 40.0,
        totalCost: 80.0,
      ),
    ];
    await db.insertDocumentWithItems(inv, invItems);

    // 3. Verify physical stock was deducted (10 - 2 = 8)
    final prod = await db.getProductById(pId);
    expect(prod?.stockQuantity, equals(8.0));

    // 4. Inspect journal_entries and journal_lines for COGS
    final cogsEntries = await rawDb.query(
      'journal_entries',
      where: 'entry_no LIKE ?',
      whereArgs: ['%JE-COGS%'],
    );
    final cogsLines = await rawDb.query(
      'journal_lines',
      where: 'account_code = ?',
      whereArgs: [Accounts.cogs.code],
    );

    // ACC-04 BUG: In PostingService._postInvoice, `if (totalMinor <= 0) return;`
    // prevents the COGS loop from ever running when total is zero.
    expect(
      cogsEntries,
      isNotEmpty,
      reason: 'ACC-04: Zero-total invoice for stocked item with known cost must generate JE-COGS journal entry',
    );
    expect(
      cogsLines,
      isNotEmpty,
      reason: 'ACC-04: Account 5100 (COGS) must be debited for inventory relieved on zero-total invoice',
    );
  });
}
