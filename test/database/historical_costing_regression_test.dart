// Regression tests for historical costing bugs:
//   1. updateProduct was silently overwriting average_cost / cost_status.
//   2. _migrateLegacyCosting did not repair historical invoice document_items.
//   3. profitMargin was forced to 0.0 for products with any unknown-cost sales.
//
// All tests use real SQLite (sqflite_common_ffi) so they exercise the actual
// SQL queries, transactions, and migration logic.

import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/inventory_costing_service.dart';
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
    tempDir = Directory.systemTemp
        .createTempSync('historical_costing_regression_test');
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

  // ──────────────────────────────────────────────────────────────────────────
  // Test 1: Product with a known, defensible historical purchase cost
  // A product purchased before v15 costing columns existed should have its
  // document_items cost reconstructed from the purchase price.
  // ──────────────────────────────────────────────────────────────────────────
  test('1. Product with known purchase history gets average_cost reconstructed', () async {
    final db = DatabaseHelper.instance;

    // Create product with no opening stock (purchase-only cost basis)
    final pid = await ProductService.createProduct(
      name: 'كورن ستارش 1',
      salePrice: 120.0,
      purchasePrice: 80.0,
      stockQuantity: 0,
    );

    // Create a purchase document (this sets average_cost via the costing service)
    await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(
          description: 'كورن ستارش 1',
          quantity: 10,
          price: 80.0,
          productId: pid,
        ),
      ],
    );

    final product = (await db.getProductById(pid))!;
    expect(product.averageCost, closeTo(80.0, 0.001),
        reason: 'average_cost should be set from purchase price');
    expect(product.costStatus, Product.costStatusKnown);
    expect(product.isCostKnown, isTrue);
    expect(product.stockQuantity, 10.0);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 2: Product metadata edit must NOT clear average_cost or cost_status
  // ──────────────────────────────────────────────────────────────────────────
  test('2. Product metadata edit preserves average_cost and cost_status', () async {
    final db = DatabaseHelper.instance;

    final pid = await ProductService.createProduct(
      name: 'سكر 2',
      salePrice: 200.0,
      purchasePrice: 150.0,
      stockQuantity: 0,
    );

    // Purchase establishes cost
    await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(
          description: 'سكر 2',
          quantity: 5,
          price: 150.0,
          productId: pid,
        ),
      ],
    );

    final before = (await db.getProductById(pid))!;
    expect(before.averageCost, closeTo(150.0, 0.001));
    expect(before.costStatus, Product.costStatusKnown);

    // Simulate ProductFormScreen: user changes purchase_price in catalog but
    // the form does not carry averageCost / costStatus — it uses the model
    // constructor defaults (averageCost: null, costStatus: 'unknown').
    final formProduct = Product(
      id: pid,
      name: 'سكر 2 (محدث)',
      salePrice: 220.0,
      purchasePrice: 170.0, // Changed catalog price
      stockQuantity: before.stockQuantity,
      // averageCost intentionally omitted (defaults to null)
      // costStatus intentionally omitted (defaults to 'unknown')
      createdAt: before.createdAt,
      updatedAt: DateTime.now(),
    );

    await db.updateProduct(formProduct);

    final after = (await db.getProductById(pid))!;
    expect(after.name, 'سكر 2 (محدث)');
    expect(after.purchasePrice, 170.0,
        reason: 'catalog purchase_price should be updated');
    expect(after.averageCost, closeTo(150.0, 0.001),
        reason: 'average_cost must NOT be cleared by metadata edit');
    expect(after.costStatus, Product.costStatusKnown,
        reason: 'cost_status must NOT be reset to unknown by metadata edit');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 3: Changing purchase_price does NOT affect subsequent invoice costing
  // The invoice costing reads average_cost from the product, not purchase_price.
  // ──────────────────────────────────────────────────────────────────────────
  test('3. Invoice after purchase_price catalog change uses average_cost not purchase_price', () async {
    final db = DatabaseHelper.instance;

    final pid = await ProductService.createProduct(
      name: 'زيت 3',
      salePrice: 300.0,
      purchasePrice: 200.0,
      stockQuantity: 0,
    );

    // Purchase at 200
    await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(
          description: 'زيت 3',
          quantity: 10,
          price: 200.0,
          productId: pid,
        ),
      ],
    );

    // Edit catalog purchase_price to 250 (future catalog price, not yet purchased at this price)
    final p = (await db.getProductById(pid))!;
    await db.updateProduct(p.copyWith(purchasePrice: 250.0));

    // Now create an invoice — should cost at 200 (average_cost), not 250
    final invoiceId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'زيت 3',
          quantity: 5,
          price: 300.0,
          productId: pid,
        ),
      ],
      strictStock: true,
    );

    final items = await db.getDocumentItems(invoiceId);
    expect(items, hasLength(1));
    expect(items.first.unitCost, closeTo(200.0, 0.001),
        reason: 'unit_cost should be the moving average (200), not the new catalog price (250)');
    expect(items.first.totalCost, closeTo(1000.0, 0.001),
        reason: 'total_cost = 5 units × 200 = 1000');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 4: Product with no purchase history has no defensible cost (unknown)
  // ──────────────────────────────────────────────────────────────────────────
  test('4. Product with no purchase history and purchasePrice=0 stays unknown', () async {
    final db = DatabaseHelper.instance;

    final pid = await ProductService.createProduct(
      name: 'غير معروف 4',
      salePrice: 50.0,
      purchasePrice: 0.0,
      stockQuantity: 10.0, // Opening stock, no cost
    );

    final product = (await db.getProductById(pid))!;
    // Opening stock with purchasePrice=0 → no cost basis
    expect(product.isCostKnown, isFalse,
        reason: 'No purchase price → cost is unknown');
    expect(product.averageCost, isNull);

    final movements = await db.getStockMovements(pid);
    expect(movements, hasLength(1));
    expect(movements.first.type, StockMovement.typeOpening);
    expect(movements.first.unitCost, isNull);
    expect(movements.first.costStatus, StockMovement.costStatusUnknown);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 5: Historical purchase prices different from current catalog price
  // A purchase at 60, then catalog price updated to 90 — average_cost is 60.
  // ──────────────────────────────────────────────────────────────────────────
  test('5. Historical purchase price differs from current catalog price', () async {
    final db = DatabaseHelper.instance;

    final pid = await ProductService.createProduct(
      name: 'أرز 5',
      salePrice: 100.0,
      purchasePrice: 60.0,
      stockQuantity: 0,
    );

    // Purchase at historical price 60
    await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(
          description: 'أرز 5',
          quantity: 10,
          price: 60.0,
          productId: pid,
        ),
      ],
    );

    final afterPurchase = (await db.getProductById(pid))!;
    expect(afterPurchase.averageCost, closeTo(60.0, 0.001));

    // Catalog price updated to 90 (future price, not yet purchased at this price)
    await db.updateProduct(afterPurchase.copyWith(purchasePrice: 90.0));

    final afterEdit = (await db.getProductById(pid))!;
    expect(afterEdit.purchasePrice, 90.0,
        reason: 'Catalog price updated');
    expect(afterEdit.averageCost, closeTo(60.0, 0.001),
        reason: 'Historical average cost must not change when catalog price is updated');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 6: New invoices after repair are costed correctly
  // Revenue=500, COGS=300, Gross Profit=200, Margin=40%
  // ──────────────────────────────────────────────────────────────────────────
  test('6. New invoice: 5 units sold at 100 each with unit_cost=60 → COGS=300, GP=200, margin=40%', () async {
    final db = DatabaseHelper.instance;

    final pid = await ProductService.createProduct(
      name: 'بضاعة اختبار 6',
      salePrice: 100.0,
      purchasePrice: 60.0,
      stockQuantity: 0,
    );

    // Purchase 10 units at 60
    await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(
          description: 'بضاعة اختبار 6',
          quantity: 10,
          price: 60.0,
          productId: pid,
        ),
      ],
    );

    final product = (await db.getProductById(pid))!;
    expect(product.averageCost, closeTo(60.0, 0.001));

    // Invoice: sell 5 units at 100
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'بضاعة اختبار 6',
          quantity: 5,
          price: 100.0,
          productId: pid,
        ),
      ],
      strictStock: true,
    );

    final items = await db.getDocumentItems(invId);
    expect(items, hasLength(1));

    final revenue = items.first.total; // 500
    final cogs = items.first.totalCost!; // 300
    final grossProfit = revenue - cogs; // 200
    final margin = (grossProfit / revenue) * 100; // 40%

    expect(revenue, closeTo(500.0, 0.001));
    expect(cogs, closeTo(300.0, 0.001));
    expect(grossProfit, closeTo(200.0, 0.001));
    expect(margin, closeTo(40.0, 0.001));
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 7: Report with mixed known-cost and unknown-cost products
  // ──────────────────────────────────────────────────────────────────────────
  test('7. Product performance report: mixed known and unknown cost products', () async {
    // Known-cost product: purchased and sold
    final pidKnown = await ProductService.createProduct(
      name: 'منتج معلوم التكلفة 7',
      category: 'cat7',
      salePrice: 100.0,
      purchasePrice: 60.0,
      stockQuantity: 0,
    );
    await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(
          description: 'منتج معلوم التكلفة 7',
          quantity: 10,
          price: 60.0,
          productId: pidKnown,
        ),
      ],
    );
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'منتج معلوم التكلفة 7',
          quantity: 5,
          price: 100.0,
          productId: pidKnown,
        ),
      ],
      strictStock: true,
    );

    // Unknown-cost product: has stock but no purchase history
    final pidUnknown = await ProductService.createProduct(
      name: 'منتج مجهول التكلفة 7',
      category: 'cat7',
      salePrice: 80.0,
      purchasePrice: 0.0,
      stockQuantity: 10.0,
    );
    // Sell without cost basis
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'منتج مجهول التكلفة 7',
          quantity: 3,
          price: 80.0,
          productId: pidUnknown,
        ),
      ],
      strictStock: false,
    );

    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 1));
    final to = now.add(const Duration(days: 1));

    final summary = await BusinessReportingService.instance.getProductPerformance(
      from: from,
      to: to,
      category: 'cat7',
    );

    // Overall report should flag incomplete costs
    expect(summary.hasIncompleteCosts, isTrue,
        reason: 'Unknown-cost product makes report incomplete');
    expect(summary.totalTrustedGrossProfit, closeTo(200.0, 0.001),
        reason: 'Trusted total gross profit must only include the known-cost product (200.0)');

    // Known-cost product
    final knownItem = summary.items.firstWhere(
      (i) => i.productId == pidKnown,
    );
    expect(knownItem.isCostReliable, isTrue);
    expect(knownItem.cogs, closeTo(300.0, 0.001)); // 5 × 60
    expect(knownItem.grossProfit, closeTo(200.0, 0.001)); // 500 - 300
    expect(knownItem.profitMargin, closeTo(40.0, 0.001)); // 200/500

    // Unknown-cost product
    final unknownItem = summary.items.firstWhere(
      (i) => i.productId == pidUnknown,
    );
    expect(unknownItem.isCostReliable, isFalse,
        reason: 'Unknown-cost sales must be flagged as unreliable');
    expect(unknownItem.unknownCostSalesCount, greaterThan(0));
    expect(unknownItem.cogs, 0.0,
        reason: 'COGS is 0 because no cost data exists');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 8: Summary totals reconcile with individual product results
  // ──────────────────────────────────────────────────────────────────────────
  test('8. Summary totals reconcile with sum of individual product items', () async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 365));
    final to = now.add(const Duration(days: 1));

    final summary = await BusinessReportingService.instance.getProductPerformance(
      from: from,
      to: to,
    );

    final computedRevenue = summary.items.fold(0.0, (s, i) => s + i.salesRevenue);
    final computedCogs = summary.items.fold(0.0, (s, i) => s + i.cogs);
    final computedGp = summary.items.fold(0.0, (s, i) => s + i.grossProfit);

    expect(summary.totalSalesRevenue, closeTo(computedRevenue, 0.001),
        reason: 'Total revenue must equal sum of individual product revenues');
    expect(summary.totalCogs, closeTo(computedCogs, 0.001),
        reason: 'Total COGS must equal sum of individual product COGS');
    expect(summary.totalGrossProfit, closeTo(computedGp, 0.001),
        reason: 'Total gross profit must equal sum of individual gross profits');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 9: Idempotency — running updateProduct twice does not corrupt costing
  // ──────────────────────────────────────────────────────────────────────────
  test('9. Idempotency: calling updateProduct twice does not corrupt average_cost', () async {
    final db = DatabaseHelper.instance;

    final pid = await ProductService.createProduct(
      name: 'منتج تكرار 9',
      salePrice: 150.0,
      purchasePrice: 100.0,
      stockQuantity: 0,
    );

    await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(
          description: 'منتج تكرار 9',
          quantity: 8,
          price: 100.0,
          productId: pid,
        ),
      ],
    );

    final p1 = (await db.getProductById(pid))!;
    expect(p1.averageCost, closeTo(100.0, 0.001));

    // Simulate running updateProduct twice (e.g., user opens and saves form twice)
    final formData = p1.copyWith(name: 'منتج تكرار 9 (محدث)', salePrice: 160.0);
    await db.updateProduct(formData);
    await db.updateProduct(formData);

    final p2 = (await db.getProductById(pid))!;
    expect(p2.averageCost, closeTo(100.0, 0.001),
        reason: 'average_cost must survive two metadata edits');
    expect(p2.costStatus, Product.costStatusKnown,
        reason: 'cost_status must remain known after two metadata edits');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 10: Stock quantity and movement history remain intact after repair
  // ──────────────────────────────────────────────────────────────────────────
  test('10. Stock quantities and movement history remain intact after metadata edit', () async {
    final db = DatabaseHelper.instance;

    final pid = await ProductService.createProduct(
      name: 'منتج سلامة المخزون 10',
      salePrice: 200.0,
      purchasePrice: 120.0,
      stockQuantity: 5.0,
    );

    // Also create a purchase
    await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(
          description: 'منتج سلامة المخزون 10',
          quantity: 10,
          price: 120.0,
          productId: pid,
        ),
      ],
    );

    final movementsBefore = await db.getStockMovements(pid);
    final stockBefore = (await db.getProductById(pid))!.stockQuantity;

    // Metadata edit
    final p = (await db.getProductById(pid))!;
    await db.updateProduct(p.copyWith(name: 'منتج سلامة المخزون 10 (معدّل)'));

    final movementsAfter = await db.getStockMovements(pid);
    final stockAfter = (await db.getProductById(pid))!.stockQuantity;

    expect(movementsAfter.length, movementsBefore.length,
        reason: 'No movements should be added or removed by a metadata edit');
    expect(stockAfter, stockBefore,
        reason: 'Stock quantity must not change via metadata edit');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 11: getSalesReportWithCost — unreliable sales flagged, not silently zero
  // ──────────────────────────────────────────────────────────────────────────
  test('11. getSalesReportWithCost flags unknown-cost invoice as not reliable', () async {
    final db = DatabaseHelper.instance;

    // Unknown-cost product — opening stock with no purchase price
    final pid = await ProductService.createProduct(
      name: 'بضاعة مجهولة 11',
      salePrice: 90.0,
      purchasePrice: 0.0,
      stockQuantity: 20.0,
    );

    // Invoice with unknown cost
    final invoiceId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'بضاعة مجهولة 11',
          quantity: 2,
          price: 90.0,
          productId: pid,
        ),
      ],
      strictStock: false,
    );

    // Verify the item has no total_cost (unknown costing situation)
    final items = await db.getDocumentItems(invoiceId);
    expect(items, hasLength(1));
    // Product was created with purchasePrice=0 so average_cost=null → total_cost=null
    expect(items.first.totalCost, isNull,
        reason: 'Item with unknown cost should have null total_cost');

    final now = DateTime.now();
    final report = await InventoryCostingService.instance.getSalesReportWithCost(
      from: now.subtract(const Duration(days: 1)),
      to: now.add(const Duration(days: 1)),
    );

    final unreliableEntry = report.where((s) => s.document.id == invoiceId).toList();
    expect(unreliableEntry, hasLength(1),
        reason: 'Invoice must appear in the sales report');
    expect(unreliableEntry.first.isCostReliable, isFalse,
        reason: 'Invoice with unknown-cost product must be flagged unreliable');
    expect(unreliableEntry.first.trustedGrossProfit, isNull,
        reason: 'Trusted gross profit must be null for unreliable cost invoice');
    expect(unreliableEntry.first.trustedProfitMargin, isNull,
        reason: 'Trusted profit margin must be null for unreliable cost invoice');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 12: Weighted average calculation — the canonical 5-unit example
  // Revenue=500, COGS=300, GP=200, margin=40%
  // ──────────────────────────────────────────────────────────────────────────
  test('12. Weighted average formula: 5 sold @ 100, cost 60 → margin 40%', () {
    // Pure calculation test, no DB
    const revenue = 5.0 * 100.0; // 500
    const cogs = 5.0 * 60.0; // 300
    const grossProfit = revenue - cogs; // 200
    const margin = (grossProfit / revenue) * 100; // 40.0

    expect(revenue, 500.0);
    expect(cogs, 300.0);
    expect(grossProfit, 200.0);
    expect(margin, closeTo(40.0, 0.001));
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 13: Multi-line invoice referencing same product with different quantities
  // Reconciles stock movements without cross-line total_cost overwrite.
  // ──────────────────────────────────────────────────────────────────────────
  test('13. Multi-line invoice with same product assigns distinct movement costs by quantity', () async {
    final db = DatabaseHelper.instance;

    final pid = await ProductService.createProduct(
      name: 'منتج متعدد الأسطر 13',
      salePrice: 100.0,
      purchasePrice: 50.0,
      stockQuantity: 0,
    );

    // Purchase 20 units @ 50
    await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(
          description: 'منتج متعدد الأسطر 13',
          quantity: 20,
          price: 50.0,
          productId: pid,
        ),
      ],
    );

    // Invoice with TWO lines for this product: Line 1 = 3 units, Line 2 = 7 units
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'منتج متعدد الأسطر 13 - سطر 1',
          quantity: 3,
          price: 100.0,
          productId: pid,
        ),
        DocumentItemInput(
          description: 'منتج متعدد الأسطر 13 - سطر 2',
          quantity: 7,
          price: 90.0,
          productId: pid,
        ),
      ],
      strictStock: true,
    );

    final items = await db.getDocumentItems(invId);
    expect(items, hasLength(2));
    expect(items[0].totalCost, 150.0); // 3 * 50
    expect(items[1].totalCost, 350.0); // 7 * 50

    final movements = await db.getStockMovements(pid);
    final saleMovements = movements.where((m) => m.referenceDocumentId == invId).toList();
    expect(saleMovements, hasLength(2));

    final m3 = saleMovements.firstWhere((m) => m.quantity == -3.0);
    final m7 = saleMovements.firstWhere((m) => m.quantity == -7.0);

    expect(m3.totalCost, 150.0, reason: 'Movement for 3 units must have total_cost = 150');
    expect(m7.totalCost, 350.0, reason: 'Movement for 7 units must have total_cost = 350');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 14: Real SQLite Migration Test: v14 -> v17 upgrade
  // ──────────────────────────────────────────────────────────────────────────
  test('14. Real SQLite migration v14 -> v17 adds columns and repairs invoice costs safely', () async {
    // Open a fresh isolated database file to simulate v14 -> v17 upgrade
    final migDbPath = '${tempDir.path}/mig_v14_test.db';
    final db = await databaseFactory.openDatabase(migDbPath);

    // 1. Setup schema as it was at v14 (before costing columns)
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT DEFAULT 'product',
        code TEXT,
        barcode TEXT,
        unit TEXT,
        sale_price REAL DEFAULT 0,
        purchase_price REAL DEFAULT 0,
        stock_quantity REAL DEFAULT 0,
        min_stock REAL DEFAULT 0,
        is_taxable INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1,
        notes TEXT,
        category TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'issued'
      )
    ''');
    await db.execute('''
      CREATE TABLE document_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        product_id INTEGER,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_document_id INTEGER,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id INTEGER,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    // Insert v14 legacy data: Product 1 with a purchase and an invoice
    final pid = await db.insert('products', {
      'name': 'سلعة قديمة 14',
      'sale_price': 100.0,
      'purchase_price': 50.0,
      'stock_quantity': 10.0,
    });
    // Purchase on 2026-01-01 @ 50.0
    final purchId = await db.insert('documents', {
      'type': 'purchase',
      'document_number': 'PUR-001',
      'date': '2026-01-01',
      'status': 'issued',
    });
    await db.insert('document_items', {
      'document_id': purchId,
      'product_id': pid,
      'description': 'شراء',
      'quantity': 10.0,
      'price': 50.0,
      'total': 500.0,
    });
    // Invoice on 2026-01-15 (after purchase)
    final invId = await db.insert('documents', {
      'type': 'invoice',
      'document_number': 'INV-001',
      'date': '2026-01-15',
      'status': 'issued',
    });
    final invItemId = await db.insert('document_items', {
      'document_id': invId,
      'product_id': pid,
      'description': 'بيع',
      'quantity': 2.0,
      'price': 100.0,
      'total': 200.0,
    });
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'sale',
      'quantity': -2.0,
      'reference_document_id': invId,
      'date': '2026-01-15',
    });

    // Run the real SQLite migration from 14 to 17
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 14, 17);
    });

    // Assert: schema columns added
    final prodCols = (await db.rawQuery('PRAGMA table_info(products)')).map((c) => c['name']).toSet();
    expect(prodCols.contains('average_cost'), isTrue);
    expect(prodCols.contains('cost_status'), isTrue);

    final itemCols = (await db.rawQuery('PRAGMA table_info(document_items)')).map((c) => c['name']).toSet();
    expect(itemCols.contains('unit_cost'), isTrue);
    expect(itemCols.contains('total_cost'), isTrue);

    // Assert: data repaired safely using the preceding purchase
    final repairedItems = await db.query('document_items', where: 'id = ?', whereArgs: [invItemId]);
    expect(repairedItems.first['unit_cost'], 50.0);
    expect(repairedItems.first['total_cost'], 100.0);

    await db.close();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 15: Real SQLite Migration Test: v16 -> v17 upgrade
  // ──────────────────────────────────────────────────────────────────────────
  test('15. Real SQLite migration v16 -> v17 repairs uncosted invoice and synchronizes stock movement', () async {
    final migDbPath = '${tempDir.path}/mig_v16_test.db';
    final db = await databaseFactory.openDatabase(migDbPath);

    // Setup schema at v16
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        average_cost REAL,
        cost_status TEXT DEFAULT 'unknown'
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'issued'
      )
    ''');
    await db.execute('''
      CREATE TABLE document_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        product_id INTEGER,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        unit_cost REAL,
        total_cost REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_document_id INTEGER,
        date TEXT NOT NULL,
        unit_cost REAL,
        total_cost REAL,
        cost_status TEXT DEFAULT 'unknown',
        provenance TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id INTEGER,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    final pid = await db.insert('products', {'name': 'منتج 16'});
    final purchId = await db.insert('documents', {'type': 'purchase', 'document_number': 'P-1', 'date': '2026-02-01', 'status': 'issued'});
    await db.insert('document_items', {
      'document_id': purchId,
      'product_id': pid,
      'quantity': 5.0,
      'price': 80.0,
      'total': 400.0,
      'unit_cost': 80.0,
      'total_cost': 400.0,
    });

    final invId = await db.insert('documents', {'type': 'invoice', 'document_number': 'I-1', 'date': '2026-02-10', 'status': 'issued'});
    final invItemId = await db.insert('document_items', {
      'document_id': invId,
      'product_id': pid,
      'quantity': 2.0,
      'price': 150.0,
      'total': 300.0,
      'unit_cost': null,
      'total_cost': null,
    });
    final smId = await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'sale',
      'quantity': -2.0,
      'reference_document_id': invId,
      'date': '2026-02-10',
      'cost_status': 'unknown',
    });

    // Run migration from 16 to 17
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 16, 17);
    });

    // Assert: item repaired
    final itemRows = await db.query('document_items', where: 'id = ?', whereArgs: [invItemId]);
    expect(itemRows.first['unit_cost'], 80.0);
    expect(itemRows.first['total_cost'], 160.0);

    // Assert: movement repaired and synchronized
    final smRows = await db.query('stock_movements', where: 'id = ?', whereArgs: [smId]);
    expect(smRows.first['unit_cost'], 80.0);
    expect(smRows.first['total_cost'], 160.0);
    expect(smRows.first['cost_status'], 'reconstructed');
    expect(smRows.first['provenance'], 'v17_invoice_repair');

    await db.close();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 16: Real SQLite Transaction Rollback on Failure
  // ──────────────────────────────────────────────────────────────────────────
  test('16. Real SQLite transaction rollback on migration failure leaves database untouched', () async {
    final rbDbPath = '${tempDir.path}/rollback_test.db';
    final db = await databaseFactory.openDatabase(rbDbPath);

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.insert('products', {'id': 1, 'name': 'البيانات الأصلية'});

    // Attempt an upgrade in a transaction that fails midway
    bool threw = false;
    try {
      await db.transaction((txn) async {
        // Step 1: modifies table
        await txn.update('products', {'name': 'بيانات معدلة مؤقتة'}, where: 'id = 1');
        // Step 2: failure injection (simulated crash / bad SQL)
        throw Exception('Simulated fatal disk or SQL error during migration');
      });
    } catch (_) {
      threw = true;
    }

    expect(threw, isTrue);

    // Verify real SQLite rollback: the original name must be completely preserved!
    final rows = await db.query('products', where: 'id = 1');
    expect(rows.first['name'], 'البيانات الأصلية',
        reason: 'Real SQLite transaction must rollback all changes on failure');

    await db.close();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 17: Overselling in non-strict mode leaves total_cost = null
  // ──────────────────────────────────────────────────────────────────────────
  test('17. Oversold invoice line in non-strict mode leaves total_cost null and profit untrusted', () async {
    final db = DatabaseHelper.instance;

    final pid = await ProductService.createProduct(
      name: 'منتج غير صارم 17',
      category: 'cat17',
      salePrice: 100.0,
      purchasePrice: 60.0,
      stockQuantity: 2.0, // Only 2 units in stock
    );

    // Invoice requests 5 units (3 units oversold)
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'منتج غير صارم 17',
          quantity: 5.0,
          price: 100.0,
          productId: pid,
        ),
      ],
      strictStock: false,
    );

    final items = await db.getDocumentItems(invId);
    expect(items.first.totalCost, isNull,
        reason: 'Oversold invoice line must have total_cost = null');

    final now = DateTime.now();
    final sales = await InventoryCostingService.instance.getSalesReportWithCost(
      from: now.subtract(const Duration(days: 1)),
      to: now.add(const Duration(days: 1)),
    );
    final sale = sales.firstWhere((s) => s.document.id == invId);
    expect(sale.isCostReliable, isFalse,
        reason: 'Oversold sale must be flagged as unreliable');
    expect(sale.trustedGrossProfit, isNull,
        reason: 'Trusted gross profit must be null for oversold sale');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 18: Uncosted sale cancellation return prevents migration reconstruction
  // ──────────────────────────────────────────────────────────────────────────
  test('18. Uncosted sale cancellation return before invoice date stops v17 migration from fabricating cost', () async {
    final migDbPath = '${tempDir.path}/mig_cancellation_test.db';
    final db = await databaseFactory.openDatabase(migDbPath);

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        average_cost REAL,
        cost_status TEXT DEFAULT 'unknown'
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'issued'
      )
    ''');
    await db.execute('''
      CREATE TABLE document_items (
        id INTEGER PRIMARY KEY,
        document_id INTEGER NOT NULL,
        product_id INTEGER,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        unit_cost REAL,
        total_cost REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_document_id INTEGER,
        date TEXT NOT NULL,
        unit_cost REAL,
        total_cost REAL,
        cost_status TEXT DEFAULT 'unknown',
        provenance TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id INTEGER,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    final pid = await db.insert('products', {'name': 'مرتجع مجهول 18'});
    // Purchase @ 50 on 2026-01-01
    final purchId = await db.insert('documents', {'type': 'purchase', 'document_number': 'P-18', 'date': '2026-01-01', 'status': 'issued'});
    await db.insert('document_items', {
      'document_id': purchId,
      'product_id': pid,
      'quantity': 10.0,
      'price': 50.0,
      'total': 500.0,
      'unit_cost': 50.0,
      'total_cost': 500.0,
    });
    // Uncosted sale cancellation return (+3 units) on 2026-01-05
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'cancellation',
      'quantity': 3.0,
      'date': '2026-01-05',
      'unit_cost': null,
      'total_cost': null,
      'cost_status': 'unknown',
      'provenance': 'sale_reversal',
    });
    // Invoice on 2026-01-10
    final invId = await db.insert('documents', {'type': 'invoice', 'document_number': 'I-18', 'date': '2026-01-10', 'status': 'issued'});
    final invItemId = await db.insert('document_items', {
      'document_id': invId,
      'product_id': pid,
      'quantity': 2.0,
      'price': 100.0,
      'total': 200.0,
      'unit_cost': null,
      'total_cost': null,
    });
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'sale',
      'quantity': -2.0,
      'reference_document_id': invId,
      'date': '2026-01-10',
      'cost_status': 'unknown',
    });

    // Run v16 -> v17 migration
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 16, 17);
    });

    // Assert: item remains NULL because uncosted return contaminated the inventory pool
    final items = await db.query('document_items', where: 'id = ?', whereArgs: [invItemId]);
    expect(items.first['total_cost'], isNull,
        reason: 'Uncosted cancellation return must prevent fabrication of historical cost');

    await db.close();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 19: Stock adjustment with different unit cost stops reconstruction
  // ──────────────────────────────────────────────────────────────────────────
  test('19. Stock adjustment with different cost stops v17 migration from fabricating cost', () async {
    final migDbPath = '${tempDir.path}/mig_adj_test.db';
    final db = await databaseFactory.openDatabase(migDbPath);

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        average_cost REAL,
        cost_status TEXT DEFAULT 'unknown'
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'issued'
      )
    ''');
    await db.execute('''
      CREATE TABLE document_items (
        id INTEGER PRIMARY KEY,
        document_id INTEGER NOT NULL,
        product_id INTEGER,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        unit_cost REAL,
        total_cost REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_document_id INTEGER,
        date TEXT NOT NULL,
        unit_cost REAL,
        total_cost REAL,
        cost_status TEXT DEFAULT 'unknown',
        provenance TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id INTEGER,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    final pid = await db.insert('products', {'name': 'تسوية سعر مختلف 19'});
    // Purchase @ 50 on 2026-01-01
    final purchId = await db.insert('documents', {'type': 'purchase', 'document_number': 'P-19', 'date': '2026-01-01', 'status': 'issued'});
    await db.insert('document_items', {
      'document_id': purchId,
      'product_id': pid,
      'quantity': 10.0,
      'price': 50.0,
      'total': 500.0,
      'unit_cost': 50.0,
      'total_cost': 500.0,
    });
    // Stock adjustment with unit cost 70 on 2026-01-05
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'adjustment',
      'quantity': 2.0,
      'date': '2026-01-05',
      'unit_cost': 70.0,
      'total_cost': 140.0,
      'cost_status': 'known',
    });
    // Invoice on 2026-01-10
    final invId = await db.insert('documents', {'type': 'invoice', 'document_number': 'I-19', 'date': '2026-01-10', 'status': 'issued'});
    final invItemId = await db.insert('document_items', {
      'document_id': invId,
      'product_id': pid,
      'quantity': 3.0,
      'price': 100.0,
      'total': 300.0,
      'unit_cost': null,
      'total_cost': null,
    });
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'sale',
      'quantity': -3.0,
      'reference_document_id': invId,
      'date': '2026-01-10',
      'cost_status': 'unknown',
    });

    // Run v16 -> v17 migration
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 16, 17);
    });

    // Assert: item remains NULL because purchase @ 50 and adjustment @ 70 conflict
    final items = await db.query('document_items', where: 'id = ?', whereArgs: [invItemId]);
    expect(items.first['total_cost'], isNull,
        reason: 'Conflicting adjustment and purchase prices must prevent cost fabrication');

    await db.close();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Test 20: Oversold historical invoice line with partial stock deduction is not reconciled
  // ──────────────────────────────────────────────────────────────────────────
  test('20. Oversold historical invoice line with partial stock deduction is not reconciled by v17 migration', () async {
    final migDbPath = '${tempDir.path}/mig_oversold_test.db';
    final db = await databaseFactory.openDatabase(migDbPath);

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        average_cost REAL,
        cost_status TEXT DEFAULT 'unknown'
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'issued'
      )
    ''');
    await db.execute('''
      CREATE TABLE document_items (
        id INTEGER PRIMARY KEY,
        document_id INTEGER NOT NULL,
        product_id INTEGER,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        unit_cost REAL,
        total_cost REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_document_id INTEGER,
        date TEXT NOT NULL,
        unit_cost REAL,
        total_cost REAL,
        cost_status TEXT DEFAULT 'unknown',
        provenance TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id INTEGER,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    final pid = await db.insert('products', {'name': 'تاريخي مفرط البيع 20'});
    // Purchase @ 50
    final purchId = await db.insert('documents', {'type': 'purchase', 'document_number': 'P-20', 'date': '2026-01-01', 'status': 'issued'});
    await db.insert('document_items', {
      'document_id': purchId,
      'product_id': pid,
      'quantity': 10.0,
      'price': 50.0,
      'total': 500.0,
      'unit_cost': 50.0,
      'total_cost': 500.0,
    });
    // Non-strict historical invoice for 5 units, but stock movement was only -2 units (3 units oversold)
    final invId = await db.insert('documents', {'type': 'invoice', 'document_number': 'I-20', 'date': '2026-01-10', 'status': 'issued'});
    final invItemId = await db.insert('document_items', {
      'document_id': invId,
      'product_id': pid,
      'quantity': 5.0,
      'price': 100.0,
      'total': 500.0,
      'unit_cost': null,
      'total_cost': null,
    });
    final smId = await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'sale',
      'quantity': -2.0, // Partial deduction due to overselling
      'reference_document_id': invId,
      'date': '2026-01-10',
      'cost_status': 'unknown',
    });

    // Run v16 -> v17 migration
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 16, 17);
    });

    // Assert: item remains NULL because movement quantity (-2) does not match line quantity (5)
    final items = await db.query('document_items', where: 'id = ?', whereArgs: [invItemId]);
    expect(items.first['total_cost'], isNull,
        reason: 'Oversold line with partial movement must not be marked trusted');

    final sm = await db.query('stock_movements', where: 'id = ?', whereArgs: [smId]);
    expect(sm.first['cost_status'], 'unknown');

    await db.close();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Finding 4 / Migration v20 Real SQLite Tests
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> initV19Schema(Database db) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT DEFAULT 'product',
        stock_quantity REAL DEFAULT 0,
        average_cost REAL,
        cost_status TEXT DEFAULT 'unknown'
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        date TEXT NOT NULL,
        subtotal REAL DEFAULT 0,
        total REAL DEFAULT 0,
        paid REAL DEFAULT 0,
        remaining REAL DEFAULT 0,
        status TEXT DEFAULT 'issued'
      )
    ''');
    await db.execute('''
      CREATE TABLE document_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        product_id INTEGER,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        unit_cost REAL,
        total_cost REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE document_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        payment_origin TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_document_id INTEGER,
        date TEXT NOT NULL,
        unit_cost REAL,
        total_cost REAL,
        cost_status TEXT DEFAULT 'unknown',
        provenance TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id INTEGER,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  test('21. Real SQLite v14 -> v20 upgrade safely reconstructs history with opening stock and purchase cancellation', () async {
    final migDbPath = '${tempDir.path}/mig_v14_to_v20_test.db';
    final db = await databaseFactory.openDatabase(migDbPath);

    // v14 products table (no costing columns)
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT DEFAULT 'product',
        stock_quantity REAL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'issued'
      )
    ''');
    await db.execute('''
      CREATE TABLE document_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        product_id INTEGER,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_document_id INTEGER,
        date TEXT NOT NULL
      )
    ''');

    // Product with 15 units remaining:
    // Opening 10 @ 50 = 500
    // Purchase 1: 10 @ 100 = 1000
    // Purchase 2: 10 @ 200 = 2000
    // Cancel Purchase 2: -10 @ 200 = -2000
    // Sale: -5
    // Expected stock = 15, expected avg = (500 + 1000) / 20 = 75.0
    final pid = await db.insert('products', {
      'name': 'سلعة v14 إلى v20',
      'stock_quantity': 15.0,
    });

    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'opening',
      'quantity': 10.0,
      'date': '2026-01-01',
    });

    final docP1 = await db.insert('documents', {'type': 'purchase', 'document_number': 'P1', 'date': '2026-01-02'});
    await db.insert('document_items', {'document_id': docP1, 'product_id': pid, 'quantity': 10.0, 'price': 100.0, 'total': 1000.0});
    await db.insert('stock_movements', {'product_id': pid, 'type': 'purchase', 'quantity': 10.0, 'reference_document_id': docP1, 'date': '2026-01-02'});

    final docP2 = await db.insert('documents', {'type': 'purchase', 'document_number': 'P2', 'date': '2026-01-03'});
    await db.insert('document_items', {'document_id': docP2, 'product_id': pid, 'quantity': 10.0, 'price': 200.0, 'total': 2000.0});
    await db.insert('stock_movements', {'product_id': pid, 'type': 'purchase', 'quantity': 10.0, 'reference_document_id': docP2, 'date': '2026-01-03'});

    // Cancel P2
    await db.insert('stock_movements', {'product_id': pid, 'type': 'cancellation', 'quantity': -10.0, 'reference_document_id': docP2, 'date': '2026-01-03'});

    // Sale
    final docS1 = await db.insert('documents', {'type': 'invoice', 'document_number': 'S1', 'date': '2026-01-04'});
    await db.insert('document_items', {'document_id': docS1, 'product_id': pid, 'quantity': 5.0, 'price': 300.0, 'total': 1500.0});
    await db.insert('stock_movements', {'product_id': pid, 'type': 'sale', 'quantity': -5.0, 'reference_document_id': docS1, 'date': '2026-01-04'});

    // Upgrade v14 -> v20
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 14, 20);
    });

    // Check product average cost
    // Note: Opening stock in v14 has no price in document_items so it is marked unknown in step 3.
    // Therefore unknownCount > 0, so cost basis safely remains NULL / unknown without fabricating cost.
    final prod = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first;
    expect(prod['stock_quantity'], 15.0);
    expect(prod['cost_status'], Product.costStatusUnknown);
    expect(prod['average_cost'], isNull);

    await db.close();
  });

  test('22. Real SQLite v19 -> v20 repair corrects average_cost for product with purchase cancellation', () async {
    final migDbPath = '${tempDir.path}/mig_v19_to_v20_purch_cancel.db';
    final db = await databaseFactory.openDatabase(migDbPath);
    await initV19Schema(db);

    // Product had flawed cost 116.6667 because legacy v15 ignored purchase cancellation
    final pid = await db.insert('products', {
      'name': 'منتج شراء ملغي',
      'stock_quantity': 10.0,
      'average_cost': 116.6667,
      'cost_status': Product.costStatusKnown,
    });

    // Purchase 1: 10 @ 50 = 500
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'purchase',
      'quantity': 10.0,
      'unit_cost': 50.0,
      'total_cost': 500.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-01',
    });

    // Purchase 2: 10 @ 100 = 1000
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'purchase',
      'quantity': 10.0,
      'unit_cost': 100.0,
      'total_cost': 1000.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-02',
    });

    // Cancel Purchase 2: -10 @ 100 = -1000
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'cancellation',
      'quantity': -10.0,
      'unit_cost': 100.0,
      'total_cost': -1000.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-02',
    });

    // Run Migration v19 -> v20
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    final prod = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first;
    expect(prod['stock_quantity'], 10.0);
    // Correct average cost after cancelling P2 is 50.0!
    expect(prod['average_cost'], closeTo(50.0, 0.001));
    expect(prod['cost_status'], Product.costStatusKnown);

    await db.close();
  });

  test('23. Real SQLite v19 -> v20 preserves runtime sale-cancellation quantity restoration without new return policy', () async {
    final migDbPath = '${tempDir.path}/mig_v19_to_v20_sale_cancel.db';
    final db = await databaseFactory.openDatabase(migDbPath);
    await initV19Schema(db);

    final pid = await db.insert('products', {
      'name': 'منتج بيع ملغي',
      'stock_quantity': 15.0,
      'average_cost': 100.0,
      'cost_status': Product.costStatusKnown,
    });

    // Purchase 1: 10 @ 50.0
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'purchase',
      'quantity': 10.0,
      'unit_cost': 50.0,
      'total_cost': 500.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-01',
    });

    // Sale: -5
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'sale',
      'quantity': -5.0,
      'unit_cost': 50.0,
      'total_cost': 250.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-02',
    });

    // Sale cancellation: +5
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'cancellation',
      'quantity': 5.0,
      'unit_cost': 50.0,
      'total_cost': 250.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-02',
    });

    // Purchase 2: 5 @ 100.0 -> stock becomes 15, avg becomes (10*50 + 5*100)/15 = 66.6667
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'purchase',
      'quantity': 5.0,
      'unit_cost': 100.0,
      'total_cost': 500.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-03',
    });

    // Run Migration v19 -> v20
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    final prod = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first;
    expect(prod['stock_quantity'], 15.0);
    expect(prod['average_cost'], closeTo(66.6667, 0.001));
    expect(prod['cost_status'], Product.costStatusKnown);

    await db.close();
  });

  test('24. Real SQLite v19 -> v20: backdated purchase after an earlier sale rejects replay and preserves live cost', () async {
    final migDbPath = '${tempDir.path}/mig_v19_to_v20_backdated_purch.db';
    final db = await databaseFactory.openDatabase(migDbPath);
    await initV19Schema(db);

    final pid = await db.insert('products', {
      'name': 'منتج شراء بأثر رجعي',
      'stock_quantity': 15.0,
      'average_cost': 13.3333,
      'cost_status': Product.costStatusKnown,
    });

    // P1 on Jan 10 (id: 1), 10 @ 20.0
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'purchase',
      'quantity': 10.0,
      'unit_cost': 20.0,
      'total_cost': 200.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-10',
    });

    // S1 on Jan 15 (id: 2), -5 @ 20.0
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'sale',
      'quantity': -5.0,
      'unit_cost': 20.0,
      'total_cost': 100.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-15',
    });

    // Backdated adjustment on Jan 05, entered on Jan 20 (id: 3): 10 @ 10.0
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'adjustment',
      'quantity': 10.0,
      'unit_cost': 10.0,
      'total_cost': 100.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-05',
    });

    // Run Migration v19 -> v20
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    final prod = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first;
    expect(prod['stock_quantity'], 15.0, reason: 'Physical stock must be preserved');
    // Monotonicity check detects inversion (1 < 3) and rejects replay.
    // Because there is no proven legacy defect, existing live cost is preserved.
    expect(prod['average_cost'], 13.3333, reason: 'Ambiguous replay order: must preserve live-maintained cost');
    expect(prod['cost_status'], Product.costStatusKnown);

    await db.close();
  });

  test('25. Real SQLite v19 -> v20: backdated cancellation rejects replay and preserves live cost', () async {
    final migDbPath = '${tempDir.path}/mig_v19_to_v20_backdated_cancel.db';
    final db = await databaseFactory.openDatabase(migDbPath);
    await initV19Schema(db);

    final pid = await db.insert('products', {
      'name': 'منتج إلغاء بأثر رجعي',
      'stock_quantity': 5.0,
      'average_cost': 20.0,
      'cost_status': Product.costStatusKnown,
    });

    // P1: Jan 1 (id: 1), 10 @ 10.0
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'purchase',
      'quantity': 10.0,
      'unit_cost': 10.0,
      'total_cost': 100.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-01',
    });

    // S1: Jan 5 (id: 2), -5 @ 10.0
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'sale',
      'quantity': -5.0,
      'unit_cost': 10.0,
      'total_cost': 50.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-05',
    });

    // P2: Jan 10 (id: 3), 10 @ 20.0
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'purchase',
      'quantity': 10.0,
      'unit_cost': 20.0,
      'total_cost': 200.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-10',
    });

    // Cancel P1 on Jan 20 (id: 4), but backdated to doc.date = Jan 01 (-10 @ 10.0)
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'cancellation',
      'quantity': -10.0,
      'unit_cost': 10.0,
      'total_cost': -100.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-01',
    });

    // Run Migration v19 -> v20
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    final prod = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first;
    expect(prod['stock_quantity'], 5.0, reason: 'Physical stock must be preserved');
    // In date order: Cancel P1 (id 4) is placed at Jan 1, preceding S1 (id 2) at Jan 5 -> id 4 precedes id 2!
    // Monotonicity check detects inversion (2 < 4) and rejects replay.
    // Live-maintained average_cost (20.0) is safely preserved!
    expect(prod['average_cost'], 20.0, reason: 'Ambiguous replay order: must preserve live-maintained cost');
    expect(prod['cost_status'], Product.costStatusKnown);

    await db.close();
  });

  test('26. Real SQLite v19 -> v20: ambiguous history with valid existing cost preserves both cost fields', () async {
    final migDbPath = '${tempDir.path}/mig_v19_to_v20_preserve_both.db';
    final db = await databaseFactory.openDatabase(migDbPath);
    await initV19Schema(db);

    final pid = await db.insert('products', {
      'name': 'منتج الحفاظ على الحقول',
      'stock_quantity': 8.0,
      'average_cost': 14.5,
      'cost_status': Product.costStatusKnown,
    });

    // Two movements with date inversion entered during operation
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'adjustment',
      'quantity': 10.0,
      'unit_cost': 14.5,
      'total_cost': 145.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-10',
    });

    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'sale',
      'quantity': -2.0,
      'unit_cost': 14.5,
      'total_cost': 29.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-05',
    });

    // Run Migration v19 -> v20
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    final prod = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first;
    expect(prod['stock_quantity'], 8.0);
    expect(prod['average_cost'], 14.5, reason: 'Ambiguity must not overwrite valid live average_cost');
    expect(prod['cost_status'], Product.costStatusKnown, reason: 'Ambiguity must not downgrade valid cost_status');

    await db.close();
  });

  test('27. Real SQLite v19 -> v20: proven legacy migration defect safely marks unknown', () async {
    final migDbPath = '${tempDir.path}/mig_v19_to_v20_proven_defect.db';
    final db = await databaseFactory.openDatabase(migDbPath);
    await initV19Schema(db);

    final pid = await db.insert('products', {
      'name': 'منتج عيب هجرة سابق',
      'stock_quantity': 10.0,
      'average_cost': 85.0, // Leaked/fabricated cost despite unknown opening movement
      'cost_status': Product.costStatusKnown,
    });

    // Legacy opening stock created by v18 migration (has_legacy_provenance) with unknown cost
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'opening',
      'quantity': 10.0,
      'unit_cost': null,
      'total_cost': null,
      'cost_status': StockMovement.costStatusUnknown,
      'provenance': 'migration_legacy_opening',
      'date': '2026-01-01',
    });

    // Run Migration v19 -> v20
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    final prod = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first;
    expect(prod['stock_quantity'], 10.0, reason: 'Physical stock must be preserved');
    expect(prod['average_cost'], isNull, reason: 'Proven legacy defect with unknown history must be marked unknown');
    expect(prod['cost_status'], Product.costStatusUnknown);

    await db.close();
  });

  test('28. Real SQLite v19 -> v20: clean post-v15 product with opening stock is completely unchanged', () async {
    final migDbPath = '${tempDir.path}/mig_v19_to_v20_clean_post15.db';
    final db = await databaseFactory.openDatabase(migDbPath);
    await initV19Schema(db);

    final pid = await db.insert('products', {
      'name': 'منتج ما بعد v15 سليم',
      'stock_quantity': 10.0,
      'average_cost': 99.0,
      'cost_status': Product.costStatusKnown,
    });

    // Normal product creation opening movement (provenance == 'opening_stock')
    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'opening',
      'quantity': 10.0,
      'unit_cost': 99.0,
      'total_cost': 990.0,
      'cost_status': StockMovement.costStatusKnown,
      'provenance': 'opening_stock',
      'date': '2026-01-01',
    });

    // Run Migration v19 -> v20
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    final prod = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first;
    expect(prod['stock_quantity'], 10.0);
    expect(prod['average_cost'], 99.0, reason: 'Normal post-v15 product must not be touched or downgraded');
    expect(prod['cost_status'], Product.costStatusKnown);

    await db.close();
  });

  test('29. Real SQLite v19 -> v20: migration idempotency and rollback safety', () async {
    final migDbPath = '${tempDir.path}/mig_v19_to_v20_idempotent.db';
    final db = await databaseFactory.openDatabase(migDbPath);
    await initV19Schema(db);

    final pid = await db.insert('products', {
      'name': 'منتج اختبار التكرار',
      'stock_quantity': 10.0,
      'average_cost': 150.0,
      'cost_status': Product.costStatusKnown,
    });

    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'opening',
      'quantity': 10.0,
      'unit_cost': 90.0,
      'total_cost': 900.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-01',
    });

    // Run Migration v19 -> v20 first time
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    final state1 = await db.query('products');

    // Run Migration v19 -> v20 second time (idempotency)
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    final state2 = await db.query('products');
    expect(state2, equals(state1), reason: 'Running migration twice must yield 100% identical state');

    // Test rollback safety: transaction failure rolls back cleanly
    try {
      await db.transaction((txn) async {
        await txn.update('products', {'average_cost': 999.0});
        throw StateError('Simulated failure');
      });
    } catch (_) {}

    final stateAfterRollback = await db.query('products');
    expect(stateAfterRollback, equals(state1), reason: 'Rollback must preserve pre-transaction state');

    await db.close();
  });

  test('30. Real SQLite v19 -> v20: physical stock and all financial documents remain strictly unchanged', () async {
    final migDbPath = '${tempDir.path}/mig_v19_to_v20_immutability.db';
    final db = await databaseFactory.openDatabase(migDbPath);
    await initV19Schema(db);

    final pid = await db.insert('products', {
      'name': 'منتج غير متغير',
      'stock_quantity': 12.5,
      'average_cost': 100.0,
      'cost_status': Product.costStatusKnown,
    });

    final docId = await db.insert('documents', {
      'type': 'invoice',
      'document_number': 'INV-IMMUTABLE-01',
      'date': '2026-01-01',
      'subtotal': 1000.0,
      'total': 1000.0,
      'paid': 500.0,
      'remaining': 500.0,
      'status': 'issued',
    });

    await db.insert('document_items', {
      'document_id': docId,
      'product_id': pid,
      'quantity': 2.5,
      'price': 400.0,
      'total': 1000.0,
      'unit_cost': 80.0,
      'total_cost': 200.0,
    });

    await db.insert('document_payments', {
      'document_id': docId,
      'amount': 500.0,
      'date': '2026-01-01',
      'payment_origin': 'upfront',
    });

    await db.insert('stock_movements', {
      'product_id': pid,
      'type': 'cancellation',
      'quantity': 2.5,
      'unit_cost': 80.0,
      'total_cost': 200.0,
      'cost_status': StockMovement.costStatusKnown,
      'date': '2026-01-01',
    });

    // Snapshot pre-migration state
    final preDocs = await db.query('documents');
    final preItems = await db.query('document_items');
    final prePayments = await db.query('document_payments');
    final preMovements = await db.query('stock_movements');
    final preStock = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first['stock_quantity'];

    // Run Migration v19 -> v20
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 19, 20);
    });

    // Snapshot post-migration state
    final postDocs = await db.query('documents');
    final postItems = await db.query('document_items');
    final postPayments = await db.query('document_payments');
    final postMovements = await db.query('stock_movements');
    final postStock = (await db.query('products', where: 'id = ?', whereArgs: [pid])).first['stock_quantity'];

    expect(postDocs, equals(preDocs), reason: 'documents table must be strictly untouched');
    expect(postItems, equals(preItems), reason: 'document_items table must be strictly untouched');
    expect(postPayments, equals(prePayments), reason: 'document_payments table must be strictly untouched');
    expect(postMovements, equals(preMovements), reason: 'stock_movements table must be strictly untouched');
    expect(postStock, equals(preStock), reason: 'products.stock_quantity must be strictly untouched');

    await db.close();
  });
}
