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

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_acc_12_test');
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
        name: 'ACC-12 Test Business',
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

  test('ACC-12 Regression: Sale reduction must restore stock at original sale snapshot cost, not current average cost', () async {
    final rawDb = await db.database;

    // 1. Initial product with unit cost = 10.0 SDG, stock = 10 units
    final pId = await db.insertProduct(
      Product(
        name: 'Item Snapshot',
        salePrice: 100.0,
        purchasePrice: 10.0,
        averageCost: 10.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 10.0,
      ),
    );

    // 2. Issue invoice for 5 units (snapshot cost was 10.0 SDG)
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-001',
      date: DateTime(2026, 3, 1),
      subtotal: 500.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 500.0,
      paid: 500.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    final invItems = <DocumentItem>[
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'Item Snapshot',
        quantity: 5.0,
        price: 100.0,
        total: 500.0,
        baseQuantity: 5.0,
        unitCost: 10.0,
        totalCost: 50.0,
      ),
    ];
    final docId = await db.insertDocumentWithItems(inv, invItems);

    // 3. Subsequent purchase of 100 units @ 50.0 SDG arrives, shifting current average cost to ~48.0 SDG
    final pur = Document(
      type: 'purchase',
      documentNumber: 'PUR-001',
      date: DateTime(2026, 3, 5),
      subtotal: 5000.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 5000.0,
      paid: 5000.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    final purItems = <DocumentItem>[
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'Item Snapshot',
        quantity: 100.0,
        price: 50.0,
        total: 5000.0,
        baseQuantity: 100.0,
      ),
    ];
    await db.insertDocumentWithItems(pur, purItems);

    final prodAfterPurchase = await db.getProductById(pId);
    expect(prodAfterPurchase!.averageCost, greaterThan(40.0));

    // 4. Merchant edits INV-001 to reduce quantity from 5 to 3 (partial return of 2 units)
    final updatedDoc = (await db.getDocumentById(docId))!.copyWith(
      subtotal: 300.0,
      total: 300.0,
      remaining: 0.0,
      paid: 300.0,
    );
    final updatedItems = <DocumentItem>[
      DocumentItem(
        documentId: docId,
        productId: pId,
        description: 'Item Snapshot',
        quantity: 3.0,
        price: 100.0,
        total: 300.0,
        baseQuantity: 3.0,
      ),
    ];
    await db.updateDocumentWithItems(updatedDoc, updatedItems);

    // 5. Inspect cancellation movement in stock_movements
    final movements = await rawDb.query(
      'stock_movements',
      where: "reference_document_id = ? AND provenance = 'sale_reversal'",
      whereArgs: [docId],
    );
    expect(movements, isNotEmpty);
    final reversalMove = movements.first;
    final restoredUnitCost = (reversalMove['unit_cost'] as num?)?.toDouble();

    // ACC-12 BUG: In DatabaseHelper._applyDocumentEditStockDeltas (line 4614),
    // when restoring stock from a sales edit quantity reduction, it uses `avgCost`
    // (the product's current average cost in `products` table, here ~48.0 SDG) instead of
    // reading `oldItem['unit_cost']` (the original sale snapshot cost, 10.0 SDG).
    expect(
      restoredUnitCost,
      equals(10.0),
      reason: 'ACC-12: Sale reduction stock reversal must use snapshot unit cost (10.0), but used current average cost ($restoredUnitCost)',
    );
  });
}
