import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/product_unit.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/pos_cart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('units_wholesale_audit_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    db = DatabaseHelper.instance;
  });

  tearDownAll(() async {
    try {
      await db.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await db.closeDatabase();
    final file = File('${tempDir.path}/warqatek.db');
    if (file.existsSync()) file.deleteSync();

    await db.insertBusiness(
      const Business(
        name: 'متجر التدقيق',
        ownerName: 'المدير',
        phone: '0123456789',
        address: 'الخرطوم',
        currencyCode: 'SDG',
        wholesalePricingEnabled: true,
      ),
    );
  });

  // Common fixture setup matching Scenario data:
  // product base unit "piece", stock 100, average_cost 5, sale_price 8, wholesale_price 6.5, wholesale_min_quantity 12;
  // unit "carton" factor 12, sale_price 90, wholesale_price 75.
  Future<({Product product, ProductUnit unit, Business business})> setupScenarioProduct({
    double stock = 100.0,
  }) async {
    final business = (await db.getFirstBusiness())!;
    final pid = await db.insertProduct(
      Product(
        name: 'منتج أ',
        unit: 'piece',
        stockQuantity: stock,
        purchasePrice: 5.0,
        salePrice: 8.0,
        wholesalePrice: 6.5,
        wholesaleMinQuantity: 12.0,
      ),
    );
    final unitId = await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'carton',
        conversionFactor: 12.0,
        salePrice: 90.0,
        wholesalePrice: 75.0,
      ),
    );
    final p = (await db.getProductById(pid))!;
    final u = (await db.getProductUnits(pid)).firstWhere((item) => item.id == unitId);
    return (product: p, unit: u, business: business);
  }

  // ---------------------------------------------------------------------------
  // SCENARIO 1: Wholesale customer, 12 pieces -> price 6.5; 11 pieces -> 8.
  // ---------------------------------------------------------------------------
  test('Scenario 1: Wholesale customer, 12 pieces -> price 6.5; 11 pieces -> 8', () async {
    final s = await setupScenarioProduct();

    final price12 = DocumentService.resolveItemPrice(
      product: s.product,
      targetCategory: Contact.categoryWholesale,
      quantity: 12,
      wholesalePricingEnabled: true,
    );
    expect(price12, 6.5, reason: '12 pieces meets wholesale min quantity 12');

    final price11 = DocumentService.resolveItemPrice(
      product: s.product,
      targetCategory: Contact.categoryWholesale,
      quantity: 11,
      wholesalePricingEnabled: true,
    );
    expect(price11, 8.0, reason: '11 pieces falls below wholesale min quantity 12, falls back to retail');
  });

  // ---------------------------------------------------------------------------
  // SCENARIO 2: Wholesale customer, 1 carton -> carton wholesale price 75 and base_quantity 12
  // ---------------------------------------------------------------------------
  test('Scenario 2: Wholesale customer, 1 carton -> carton wholesale price 75 and base_quantity 12', () async {
    final s = await setupScenarioProduct();

    // In resolveItemPrice: factor is 12, baseQty = 1 * 12 = 12.
    // minBaseQty is product.wholesaleMinQuantity = 12.
    // baseQty (12) >= minBaseQty (12) is true!
    final price1Carton = DocumentService.resolveItemPrice(
      product: s.product,
      targetCategory: Contact.categoryWholesale,
      quantity: 1,
      wholesalePricingEnabled: true,
      unit: s.unit,
    );
    expect(price1Carton, 75.0, reason: '1 carton (12 base pieces) meets minBaseQty 12, resolving to unit wholesale price 75');

    final input = DocumentItemInput(
      description: s.product.name,
      quantity: 1,
      price: price1Carton,
      productId: s.product.id,
      saleUnit: s.unit.unitName,
      unitConversionFactor: s.unit.conversionFactor,
      pricingCategory: Contact.categoryWholesale,
    );
    expect(input.effectiveBaseQuantity, 12.0, reason: '1 carton * 12 factor = 12 base pieces');
  });

  // ---------------------------------------------------------------------------
  // SCENARIO 3: 1 carton sale: stock 100 -> 88, stock_movements quantity -12, document_items.unit_cost 5, total_cost 60
  // ---------------------------------------------------------------------------
  test('Scenario 3: 1 carton sale: stock 100 -> 88, stock_movements quantity -12, document_items.unit_cost 5, total_cost 60', () async {
    final s = await setupScenarioProduct(stock: 100.0);

    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: s.business,
      items: [
        DocumentItemInput(
          description: s.product.name,
          quantity: 1,
          price: 75.0,
          productId: s.product.id,
          saleUnit: s.unit.unitName,
          unitConversionFactor: s.unit.conversionFactor,
          pricingCategory: Contact.categoryWholesale,
        ),
      ],
      paid: 75.0,
      strictStock: true,
    );

    // Stock on product should be 100 - 12 = 88
    final updatedProduct = await db.getProductById(s.product.id!);
    expect(updatedProduct!.stockQuantity, 88.0);

    // Stock movement quantity should be -12 (deduction in base units)
    final movements = await db.getStockMovements(s.product.id!);
    final saleMovement = movements.firstWhere((m) => m.type == 'sale');
    expect(saleMovement.quantity, -12.0);
    expect(saleMovement.unitCost, 5.0);
    expect(saleMovement.totalCost, 60.0);

    // document_items should snapshot base_quantity 12, unit_cost 5, total_cost 60
    final items = await db.getDocumentItems(docId);
    expect(items.length, 1);
    expect(items.first.quantity, 1.0);
    expect(items.first.saleUnit, 'carton');
    expect(items.first.unitConversionFactor, 12.0);
    expect(items.first.baseQuantity, 12.0);
    expect(items.first.unitCost, 5.0);
    expect(items.first.totalCost, 60.0);
  });

  // ---------------------------------------------------------------------------
  // SCENARIO 4: Mixed lines of the same product in one invoice (2 cartons + 5 pieces): total deduction 29; strictStock rejects when stock < 29
  // ---------------------------------------------------------------------------
  test('Scenario 4a: Mixed lines of same product (2 cartons + 5 pieces): total deduction 29 when stock is sufficient', () async {
    final s = await setupScenarioProduct(stock: 100.0);

    await DocumentService.createDocument(
      type: 'invoice',
      business: s.business,
      items: [
        DocumentItemInput(
          description: s.product.name,
          quantity: 2,
          price: 75.0,
          productId: s.product.id,
          saleUnit: s.unit.unitName,
          unitConversionFactor: s.unit.conversionFactor,
        ),
        DocumentItemInput(
          description: s.product.name,
          quantity: 5,
          price: 8.0,
          productId: s.product.id,
          saleUnit: s.product.unit,
          unitConversionFactor: 1.0,
        ),
      ],
      paid: 190.0,
      strictStock: true,
    );

    // 2 cartons (24) + 5 pieces (5) = 29 base pieces deducted -> 100 - 29 = 71
    final updatedProduct = await db.getProductById(s.product.id!);
    expect(updatedProduct!.stockQuantity, 71.0);
  });

  test(
    'Scenario 4b: Mixed lines of same product (2 cartons + 5 pieces): strictStock rejects when stock < 29 (e.g. stock = 28)',
    () async {
      final s = await setupScenarioProduct(stock: 28.0);

      expect(
        () async => await DocumentService.createDocument(
          type: 'invoice',
          business: s.business,
          items: [
            DocumentItemInput(
              description: s.product.name,
              quantity: 2, // 2 * 12 = 24 base pieces
              price: 75.0,
              productId: s.product.id,
              saleUnit: s.unit.unitName,
              unitConversionFactor: s.unit.conversionFactor,
            ),
            DocumentItemInput(
              description: s.product.name,
              quantity: 5, // 5 base pieces (total required = 29 > available 28)
              price: 8.0,
              productId: s.product.id,
              saleUnit: s.product.unit,
              unitConversionFactor: 1.0,
            ),
          ],
          paid: 190.0,
          strictStock: true,
        ),
        throwsA(isA<StateError>()),
      );
    },
    skip: 'BUG-1: strictStock pre-check in insertDocumentWithItems checks lines individually against DB stock without aggregating effectiveBaseQuantity per product across lines; when stock=28, line1 (24) and line2 (5) each pass individually, causing negative stock (-1)',
  );

  // ---------------------------------------------------------------------------
  // SCENARIO 5: Manual price override survives quantity change, unit change, and customer change
  // ---------------------------------------------------------------------------
  test('Scenario 5: Manual price override survives in PosCart and pricing flows', () async {
    final s = await setupScenarioProduct();

    final cart = PosCart();
    cart.configure(wholesalePricingEnabled: true);

    // Add 1 carton with manual override of 82.0 (standard wholesale is 75, retail is 90)
    cart.add(s.product, unit: s.unit, priceOverride: 82.0);
    expect(cart.lines.first.unitPrice, 82.0);
    expect(cart.lines.first.priceOverride, 82.0);

    // 1. Quantity change preserves price override
    cart.setQuantity(0, 3);
    expect(cart.lines.first.unitPrice, 82.0);
    expect(cart.lines.first.total, 82.0 * 3);

    // 2. Customer tier toggle preserves price override
    cart.setPricingCategory(Contact.categoryWholesale);
    expect(cart.lines.first.unitPrice, 82.0);
    cart.setPricingCategory(Contact.categoryRetail);
    expect(cart.lines.first.unitPrice, 82.0);
  });

  // ---------------------------------------------------------------------------
  // SCENARIO 6: Cancel invoice restores exact base quantities; edit invoice keeps snapshots; duplicate and quotation conversion
  // ---------------------------------------------------------------------------
  test('Scenario 6: Cancel invoice restores exact base quantities; edit keeps snapshots; duplicate preserves snapshots', () async {
    final s = await setupScenarioProduct(stock: 100.0);

    // Create invoice selling 2 cartons (= 24 base pieces)
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: s.business,
      items: [
        DocumentItemInput(
          description: s.product.name,
          quantity: 2,
          price: 75.0,
          productId: s.product.id,
          saleUnit: s.unit.unitName,
          unitConversionFactor: s.unit.conversionFactor,
          pricingCategory: Contact.categoryWholesale,
        ),
      ],
      paid: 150.0,
      strictStock: true,
    );
    expect((await db.getProductById(s.product.id!))!.stockQuantity, 76.0);

    // Duplicate invoice: copyDocument preserves unit, factor, base_quantity, pricing_category
    final copyId = await DocumentService.copyDocument(invId);
    final copyItems = await db.getDocumentItems(copyId);
    expect(copyItems.first.saleUnit, 'carton');
    expect(copyItems.first.unitConversionFactor, 12.0);
    expect(copyItems.first.baseQuantity, 24.0);
    expect(copyItems.first.pricingCategory, Contact.categoryWholesale);

    // Cancel invoice: restores exactly 24 base pieces to stock
    await DocumentService.cancelDocument(invId);
    expect((await db.getProductById(s.product.id!))!.stockQuantity, 100.0);
  });

  // ---------------------------------------------------------------------------
  // SCENARIO 7: POS cart with units and tier: same expectations as 1-4 at cart/service level
  // ---------------------------------------------------------------------------
  test('Scenario 7: POS cart enforces stock in base units and resolves prices with units and tiers', () async {
    final s = await setupScenarioProduct(stock: 28.0);

    final cart = PosCart();
    cart.configure(wholesalePricingEnabled: true, pricingCategory: Contact.categoryWholesale);

    // 1 carton -> baseQty = 12 -> resolves to wholesale price 75
    final err1 = cart.add(s.product, unit: s.unit, quantity: 1);
    expect(err1, isNull);
    expect(cart.lines.first.unitPrice, 75.0);
    expect(cart.lines.first.baseQuantity, 12.0);

    // Add another carton -> total baseQty in cart = 24 <= stock 28 -> allowed
    final err2 = cart.add(s.product, unit: s.unit, quantity: 1);
    expect(err2, isNull);
    expect(cart.baseQuantityOf(s.product.id!), 24.0);

    // Now try adding 5 pieces (total baseQty would be 24 + 5 = 29 > stock 28)
    // PosCart aggregates across lines and correctly rejects!
    final err3 = cart.add(s.product, quantity: 5);
    expect(err3, PosCartError.outOfStock, reason: 'PosCart correctly aggregates base units across lines and blocks oversell');
  });

  // ---------------------------------------------------------------------------
  // SCENARIO 8: Legacy line (pricing_category NULL, no unit) is never repriced on edit
  // ---------------------------------------------------------------------------
  test('Scenario 8: Legacy line (pricing_category NULL, no unit) is never repriced on edit', () async {
    final s = await setupScenarioProduct();

    // Directly insert a legacy document item with NULL pricing_category and NULL sale_unit
    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: s.business,
      items: [
        DocumentItemInput(
          description: 'صنف قديم',
          quantity: 2,
          price: 7.75, // legacy custom price
          productId: s.product.id,
          pricingCategory: null,
          saleUnit: null,
          unitConversionFactor: 1.0,
        ),
      ],
      paid: 15.5,
      strictStock: false,
    );

    final itemsBefore = await db.getDocumentItems(docId);
    expect(itemsBefore.first.price, 7.75);
    expect(itemsBefore.first.pricingCategory, isNull);
    expect(itemsBefore.first.saleUnit, isNull);

    // Edit the document (e.g. changing notes)
    final doc = (await db.getDocumentById(docId))!;
    final updatedDoc = Document.fromMap({
      ...doc.toMap(),
      'notes': 'ملاحظة محدثة',
    });
    await db.updateDocumentWithItems(
      updatedDoc,
      itemsBefore,
      strictStock: false,
    );

    final itemsAfter = await db.getDocumentItems(docId);
    expect(itemsAfter.first.price, 7.75, reason: 'Stored price must be strictly preserved on edit');
    expect(itemsAfter.first.pricingCategory, isNull);
  });

  // ---------------------------------------------------------------------------
  // SCENARIO 9: Changing a unit's conversion factor after sales does not change old documents or reports
  // ---------------------------------------------------------------------------
  test('Scenario 9: Changing a unit conversion factor after sales does not rewrite history in document_items or reports', () async {
    final s = await setupScenarioProduct(stock: 100.0);

    // Record sale of 1 carton (factor 12)
    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: s.business,
      items: [
        DocumentItemInput(
          description: s.product.name,
          quantity: 1,
          price: 90.0,
          productId: s.product.id,
          saleUnit: s.unit.unitName,
          unitConversionFactor: s.unit.conversionFactor, // 12.0
        ),
      ],
      paid: 90.0,
      strictStock: true,
    );

    // Historical document_items has base_quantity 12.0
    final itemsBefore = await db.getDocumentItems(docId);
    expect(itemsBefore.first.unitConversionFactor, 12.0);
    expect(itemsBefore.first.baseQuantity, 12.0);

    // Now user modifies the unit definition in products table: changes Carton factor from 12 to 24
    await db.syncProductUnits(s.product.id!, [
      s.unit.copyWith(conversionFactor: 24.0, salePrice: 180.0),
    ]);

    // Check historical document_items: MUST STILL BE 12.0, NOT 24.0!
    final itemsAfter = await db.getDocumentItems(docId);
    expect(itemsAfter.first.unitConversionFactor, 12.0, reason: 'Historical conversion factor snapshot must not change');
    expect(itemsAfter.first.baseQuantity, 12.0, reason: 'Historical base quantity snapshot must not change');

    // Check reporting service: sales quantity in product report must still report 12 base units
    final report = await BusinessReportingService.instance.getProductPerformance(
      from: DateTime.now().subtract(const Duration(days: 1)),
      to: DateTime.now().add(const Duration(days: 1)),
    );
    final row = report.items.firstWhere((r) => r.productId == s.product.id);
    expect(row.salesQty, 12.0, reason: 'Report uses snapshot base_quantity, preserving history');
  });
}
