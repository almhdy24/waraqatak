// Real SQLite (ffi) integration test for inventory data integrity (Batch 1).
// Covers Free-user stock clamping, product deletion with movements,
// deleted-document cleanup, purchase cancellation safety, and transaction rollback.
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/pos_cart.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Business business;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('inventory_integrity_db_test');
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

  // 1. Free invoice exceeding available stock does not silently create a negative stock balance
  test('1. Free invoice exceeding available stock clamps stock deduction and prevents negative stock', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج مجاني 1',
      salePrice: 100,
      stockQuantity: 3,
    );

    // Free user (strictStock: false) creates an invoice for 5 units (available: 3)
    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج مجاني 1', quantity: 5, price: 100, productId: pid),
      ],
      strictStock: false,
    );

    final product = (await db.getProductById(pid))!;
    expect(product.stockQuantity, 0.0, reason: 'Stock should clamp at 0 and not go negative (-2)');

    final movements = (await db.getStockMovements(pid))
        .where((m) => m.referenceDocumentId == docId)
        .toList();
    expect(movements, hasLength(1));
    expect(movements.first.quantity, -3.0, reason: 'Movement should record only the 3 deducted units');
  });

  // 2. Quick Sale follows a consistent, intentional stock policy
  test('2. Quick Sale follows consistent stock policy and prevents exceeding stock', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج سريع 2',
      salePrice: 200,
      stockQuantity: 2,
    );
    final product = (await db.getProductById(pid))!;

    final cart = PosCart();
    expect(cart.add(product, quantity: 2), isNull);
    expect(cart.add(product, quantity: 1), PosCartError.outOfStock);

    // Submitting quick sale invoice with strictStock = true rejects out of stock
    await expectLater(
      DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(description: 'منتج سريع 2', quantity: 5, price: 200, productId: pid),
        ],
        payNowMethod: 'cash',
        strictStock: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  // 3. Deleting a product with an opening movement succeeds when no document references it
  test('3. Deleting a product with opening movement succeeds when unreferenced', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج للحذف 3',
      salePrice: 150,
      stockQuantity: 10, // Creates opening stock movement
    );

    final movementsBefore = await db.getStockMovements(pid);
    expect(movementsBefore, isNotEmpty);

    // Deleting should delete both the movement and the product atomically
    final deleted = await db.deleteProduct(pid);
    expect(deleted, 1);
    expect(await db.getProductById(pid), isNull);
    expect(await db.getStockMovements(pid), isEmpty);
  });

  // 4. Deleting a product referenced by a historical document remains protected
  test('4. Deleting a product referenced by a document throws StateError', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج محمي 4',
      salePrice: 300,
      stockQuantity: 10,
    );

    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج محمي 4', quantity: 1, price: 300, productId: pid),
      ],
      strictStock: false,
    );

    expect(
      () => db.deleteProduct(pid),
      throwsA(isA<StateError>()),
      reason: 'Should prevent deleting products referenced in document_items',
    );
    expect(await db.getProductById(pid), isNotNull);
  });

  // 5. Deleting a stock-affecting document leaves stock balances and movements consistent
  test('5. Deleting a stock-affecting document restores stock and removes movements', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج مستند 5',
      salePrice: 50,
      stockQuantity: 10,
    );

    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج مستند 5', quantity: 4, price: 50, productId: pid),
      ],
      strictStock: true,
    );

    expect((await db.getProductById(pid))!.stockQuantity, 6);

    await db.deleteDocument(docId);

    // Stock must be restored to 10
    expect((await db.getProductById(pid))!.stockQuantity, 10);
    // Movements belonging to docId must be removed, leaving opening movement
    final movements = await db.getStockMovements(pid);
    expect(movements.where((m) => m.referenceDocumentId == docId), isEmpty);
  });

  // 6. Cancelling a purchase whose stock has already been consumed is rejected safely without partial changes
  test('6. Cancelling purchase with consumed stock is rejected safely', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج مشتريات 6',
      salePrice: 100,
      stockQuantity: 0,
    );

    // 1. Purchase 10 units
    final purchaseId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج مشتريات 6', quantity: 10, price: 80, productId: pid),
      ],
    );
    expect((await db.getProductById(pid))!.stockQuantity, 10);

    // 2. Sell 8 units (leaving 2 units in stock)
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج مشتريات 6', quantity: 8, price: 100, productId: pid),
      ],
      strictStock: true,
    );
    expect((await db.getProductById(pid))!.stockQuantity, 2);

    // 3. Attempt to cancel purchase of 10 units when only 2 remain -> must be rejected
    await expectLater(
      DocumentService.cancelDocument(purchaseId),
      throwsA(isA<StateError>()),
    );

    // Verify stock remains untouched at 2, and purchase is NOT cancelled
    expect((await db.getProductById(pid))!.stockQuantity, 2);
    final purchaseDoc = (await db.getDocumentById(purchaseId))!;
    expect(purchaseDoc.status, isNot(DocumentStatus.cancelled));
  });

  // 7. Transaction rollback preserves data consistency when a relevant operation fails
  test('7. Transaction rollback preserves data consistency on failure', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج تراجع 7',
      salePrice: 50,
      stockQuantity: 2,
    );

    final docsBefore = (await db.getAllDocuments()).length;

    // Strict stock invoice exceeding 2 units rolls back
    await expectLater(
      DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(description: 'منتج تراجع 7', quantity: 5, price: 50, productId: pid),
        ],
        strictStock: true,
      ),
      throwsA(isA<StateError>()),
    );

    expect((await db.getAllDocuments()).length, docsBefore);
    expect((await db.getProductById(pid))!.stockQuantity, 2);
  });

  // 8. Updating product metadata preserves existing stock balance
  test('8. Metadata edit does not overwrite existing stock balance', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج تعديل بيانات 8',
      salePrice: 100,
      stockQuantity: 15.5,
      unit: 'حبة',
    );

    final original = (await db.getProductById(pid))!;
    expect(original.stockQuantity, 15.5);

    // Attempt to update product with a modified stockQuantity
    final updatedData = original.copyWith(
      name: 'منتج تعديل بيانات 8 (محدث)',
      salePrice: 125,
      stockQuantity: 999.0, // Should be ignored by updateProduct
      unit: 'كرتونة',
    );
    await db.updateProduct(updatedData);

    final reloaded = (await db.getProductById(pid))!;
    expect(reloaded.name, 'منتج تعديل بيانات 8 (محدث)');
    expect(reloaded.salePrice, 125.0);
    expect(reloaded.unit, 'كرتونة');
    expect(reloaded.stockQuantity, 15.5, reason: 'stock_quantity must not be changed via updateProduct');
  });

  // 9. Creating a new product initializes opening stock and records initial movement
  test('9. New product opening stock is initialized and recorded in movements', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج رصيد افتتاحي 9',
      salePrice: 75,
      stockQuantity: 20.25,
      unit: 'كجم',
    );

    final product = (await db.getProductById(pid))!;
    expect(product.stockQuantity, 20.25);

    final movements = await db.getStockMovements(pid);
    expect(movements, hasLength(1));
    expect(movements.first.type, StockMovement.typeOpening);
    expect(movements.first.quantity, 20.25);
  });

  // 10. Converting a product with active stock to a service is rejected
  test('10. Converting product with active stock to service throws StateError', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج مخزون 10',
      salePrice: 50,
      stockQuantity: 8,
    );

    final product = (await db.getProductById(pid))!;
    expect(product.isProduct, true);
    expect(product.stockQuantity, 8.0);

    // Attempting to convert to service must throw StateError
    final serviceData = product.copyWith(type: Product.typeService);
    await expectLater(
      () => db.updateProduct(serviceData),
      throwsA(isA<StateError>()),
    );

    // Verify product type remains unchanged
    final reloaded = (await db.getProductById(pid))!;
    expect(reloaded.type, Product.typeProduct);
    expect(reloaded.stockQuantity, 8.0);
  });

  // 11. Management search returns more than 10 products when matched
  test('11. Management search does not artificially truncate at 10 results', () async {
    final db = DatabaseHelper.instance;
    for (int i = 1; i <= 15; i++) {
      await ProductService.createProduct(
        name: 'بحث اختبار الدفعة الثانية $i',
        salePrice: 10.0 + i,
        stockQuantity: 1,
      );
    }

    // searchProducts (management) without limit returns all 15
    final managementResults = await db.searchProducts('بحث اختبار الدفعة الثانية');
    expect(managementResults.length, greaterThanOrEqualTo(15));

    // searchActiveProducts defaults to limit: 10
    final limitedResults = await db.searchActiveProducts('بحث اختبار الدفعة الثانية');
    expect(limitedResults.length, 10);
  });

  // 12. Editing a purchase document reverses previous stock and applies new stock atomically
  test('12. Editing purchase document updates items and stock atomically', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج تعديل مشتريات 12',
      salePrice: 100,
      stockQuantity: 0,
    );

    // Initial purchase of 10 units
    final purchaseId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج تعديل مشتريات 12', quantity: 10, price: 70, productId: pid),
      ],
    );
    expect((await db.getProductById(pid))!.stockQuantity, 10.0);

    // Edit purchase: change quantity to 15 units at 75 price
    await DocumentService.updateDocument(
      documentId: purchaseId,
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج تعديل مشتريات 12 (محدث)', quantity: 15, price: 75, productId: pid),
      ],
    );

    final reloadedProduct = (await db.getProductById(pid))!;
    expect(reloadedProduct.stockQuantity, 15.0, reason: 'Stock should reflect new purchase quantity 15');

    final updatedItems = await db.getDocumentItems(purchaseId);
    expect(updatedItems, hasLength(1));
    expect(updatedItems.first.quantity, 15.0);
    expect(updatedItems.first.price, 75.0);
    expect(updatedItems.first.description, 'منتج تعديل مشتريات 12 (محدث)');
  });

  // 13. Editing a purchase document with consumed stock is rejected cleanly with StateError
  test('13. Editing purchase document with consumed stock is rejected safely', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج استهلاك مشتريات 13',
      salePrice: 150,
      stockQuantity: 0,
    );

    // 1. Purchase 10 units
    final purchaseId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج استهلاك مشتريات 13', quantity: 10, price: 80, productId: pid),
      ],
    );
    expect((await db.getProductById(pid))!.stockQuantity, 10.0);

    // 2. Sell 8 units (leaving 2 units in stock)
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج استهلاك مشتريات 13', quantity: 8, price: 150, productId: pid),
      ],
      strictStock: true,
    );
    expect((await db.getProductById(pid))!.stockQuantity, 2.0);

    // 3. Attempt to edit purchase down to 5 units:
    // Requires reducing 5 units from stock, but only 2 units remain on hand!
    await expectLater(
      DocumentService.updateDocument(
        documentId: purchaseId,
        type: 'purchase',
        business: business,
        items: [
          DocumentItemInput(description: 'منتج استهلاك مشتريات 13', quantity: 5, price: 80, productId: pid),
        ],
      ),
      throwsA(isA<StateError>()),
    );

    // Verify stock remains untouched at 2, and purchase items are not corrupted
    expect((await db.getProductById(pid))!.stockQuantity, 2.0);
    final itemsAfterReject = await db.getDocumentItems(purchaseId);
    expect(itemsAfterReject.first.quantity, 10.0);
  });

  // 14. Deleting an edited purchase document safely reverses only the net stock
  test('14. Deleting an edited purchase reverses net stock accurately', () async {
    final db = DatabaseHelper.instance;
    final pid = await ProductService.createProduct(
      name: 'منتج حذف مشتريات معدلة 14',
      salePrice: 200,
      stockQuantity: 0,
    );

    // 1. Purchase 10 units
    final purchaseId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج حذف مشتريات معدلة 14', quantity: 10, price: 100, productId: pid),
      ],
    );
    expect((await db.getProductById(pid))!.stockQuantity, 10.0);

    // 2. Edit purchase to 14 units
    await DocumentService.updateDocument(
      documentId: purchaseId,
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(description: 'منتج حذف مشتريات معدلة 14', quantity: 14, price: 100, productId: pid),
      ],
    );
    expect((await db.getProductById(pid))!.stockQuantity, 14.0);

    // 3. Delete the purchase document
    await db.deleteDocument(purchaseId);

    // Stock should be completely restored to 0, not negative or double-decremented
    expect((await db.getProductById(pid))!.stockQuantity, 0.0);
    expect(await db.getDocumentById(purchaseId), isNull);
    final movements = await db.getStockMovements(pid);
    expect(movements.where((m) => m.referenceDocumentId == purchaseId), isEmpty);
  });
}


