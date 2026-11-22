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
    tempDir = Directory.systemTemp.createTempSync('audit_acc_02_test');
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
        name: 'ACC-02 Test Business',
        ownerName: 'Test Owner',
        phone: '0123456789',
        address: 'Riyadh',
        currencyCode: 'SDG',
        taxRate: 0.15,
        taxesEnabled: true,
        pricesIncludeTax: true,
      ),
    );
  });

  test('ACC-02 Regression: Tax-inclusive purchases must record net unit cost in stock ledger', () async {
    final rawDb = await db.database;

    // 1. Initial product with zero stock and unknown cost
    final pId = await db.insertProduct(
      Product(
        name: 'Taxed Product',
        salePrice: 200.0,
        purchasePrice: 115.0,
        stockQuantity: 0.0,
      ),
    );

    // 2. Record tax-inclusive purchase: 10 units @ 115 SDG gross (Subtotal 1150, Tax 150, Net 1000)
    final purchaseDoc = Document(
      type: 'purchase',
      documentNumber: 'PUR-001',
      date: DateTime(2026, 3, 1),
      subtotal: 1000.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 150.0,
      total: 1150.0,
      paid: 1150.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    final purchaseItems = <DocumentItem>[
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'Taxed Product',
        quantity: 10.0,
        price: 115.0,
        taxRate: 0.15,
        total: 1150.0,
        baseQuantity: 10.0,
      ),
    ];
    await db.insertDocumentWithItems(purchaseDoc, purchaseItems);

    // 3. Inspect product average cost
    final productAfterPurchase = await db.getProductById(pId);
    expect(productAfterPurchase, isNotNull);

    // ACC-02 BUG: DatabaseHelper stores gross unit price (115.0) as average_cost instead of net price (100.0).
    // In GL, Inventory (1140) was debited 1000.0 and VAT Input (1150) was debited 150.0.
    // Stock ledger should reflect net cost of 100.0 per unit.
    expect(
      productAfterPurchase!.averageCost,
      equals(100.0),
      reason: 'ACC-02: Product average cost should be net of recoverable tax (100.0 SDG), but is gross (115.0 SDG)',
    );

    // 4. Sell all 10 units
    final saleDoc = Document(
      type: 'invoice',
      documentNumber: 'INV-001',
      date: DateTime(2026, 3, 5),
      subtotal: 2000.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 2000.0,
      paid: 2000.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    final saleItems = <DocumentItem>[
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'Taxed Product',
        quantity: 10.0,
        price: 200.0,
        total: 2000.0,
        baseQuantity: 10.0,
      ),
    ];
    await db.insertDocumentWithItems(saleDoc, saleItems);

    // 5. Account 1140 (Merchandise Inventory) must not become negative
    final invLines = await rawDb.query(
      'journal_lines',
      where: 'account_code = ?',
      whereArgs: [Accounts.inventory.code],
    );
    int invBalanceMinor = 0;
    for (final line in invLines) {
      invBalanceMinor += (line['debit_minor'] as int?) ?? 0;
      invBalanceMinor -= (line['credit_minor'] as int?) ?? 0;
    }
    expect(
      invBalanceMinor,
      greaterThanOrEqualTo(0),
      reason: 'ACC-02: Inventory GL Account 1140 balance must not become negative (-150 SDG) after selling all stock',
    );
  });
}
