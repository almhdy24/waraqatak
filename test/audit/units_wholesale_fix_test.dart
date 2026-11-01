import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/product_unit.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('units_wholesale_fix_test');
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

  group('BUG-1 (Critical): Multi-line stock aggregation pre-check', () {
    test('insertDocumentWithItems fails when aggregated base qty exceeds stock', () async {
      final s = await setupScenarioProduct(stock: 28.0);

      expect(
        () async => await DocumentService.createDocument(
          type: 'invoice',
          business: s.business,
          items: [
            DocumentItemInput(
              description: s.product.name,
              quantity: 2, // 2 * 12 = 24 base units
              price: 75.0,
              productId: s.product.id,
              saleUnit: s.unit.unitName,
              unitConversionFactor: s.unit.conversionFactor,
            ),
            DocumentItemInput(
              description: s.product.name,
              quantity: 5, // 5 base units (total = 29 > stock 28)
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

      // Verify stock was not touched
      final p = await db.getProductById(s.product.id!);
      expect(p!.stockQuantity, 28.0);
    });

    test('issueDocument fails when aggregated base qty exceeds stock', () async {
      final s = await setupScenarioProduct(stock: 28.0);

      // Create draft invoice (draft does not check stock or deduct)
      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: s.business,
        items: [
          DocumentItemInput(
            description: s.product.name,
            quantity: 2, // 24
            price: 75.0,
            productId: s.product.id,
            saleUnit: s.unit.unitName,
            unitConversionFactor: s.unit.conversionFactor,
          ),
          DocumentItemInput(
            description: s.product.name,
            quantity: 5, // 5 (total = 29 > stock 28)
            price: 8.0,
            productId: s.product.id,
            saleUnit: s.product.unit,
            unitConversionFactor: 1.0,
          ),
        ],
        isDraft: true,
        strictStock: true,
      );

      expect(
        () async => await db.issueDocument(docId, strictStock: true),
        throwsA(isA<StateError>()),
      );

      final p = await db.getProductById(s.product.id!);
      expect(p!.stockQuantity, 28.0);
    });

    test('updateDocumentWithItems fails when aggregated base qty exceeds stock', () async {
      final s = await setupScenarioProduct(stock: 28.0);

      // Create issued invoice with 1 piece (stock becomes 27)
      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: s.business,
        items: [
          DocumentItemInput(
            description: s.product.name,
            quantity: 1,
            price: 8.0,
            productId: s.product.id,
          ),
        ],
        strictStock: true,
      );

      // Now update the document to have 2 cartons (24) + 5 pieces (5) = 29.
      // Available stock = current (27) + reversed (1) = 28 < 29. Must throw StateError!
      expect(
        () async => await DocumentService.updateDocument(
          documentId: docId,
          type: 'invoice',
          business: s.business,
          items: [
            DocumentItemInput(
              description: s.product.name,
              quantity: 2, // 24
              price: 75.0,
              productId: s.product.id,
              saleUnit: s.unit.unitName,
              unitConversionFactor: s.unit.conversionFactor,
            ),
            DocumentItemInput(
              description: s.product.name,
              quantity: 5, // 5 (total 29 > 28)
              price: 8.0,
              productId: s.product.id,
              saleUnit: s.product.unit,
              unitConversionFactor: 1.0,
            ),
          ],
          strictStock: true,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('BUG-2 (High): resolveLinePrice single entry point', () {
    test('resolveLinePrice preserves custom sales unit on wholesale customer selection', () async {
      final s = await setupScenarioProduct();

      // Line has 1 carton (factor 12, wholesale 75.0, retail 90.0)
      final linePrice = DocumentService.resolveLinePrice(
        product: s.product,
        availableUnits: [s.unit],
        quantity: 1.0,
        saleUnit: s.unit.unitName,
        unitConversionFactor: s.unit.conversionFactor,
        pricingCategory: Contact.categoryRetail,
        targetCategory: Contact.categoryWholesale,
        isManualPrice: false,
        wholesalePricingEnabled: true,
      );

      expect(linePrice, 75.0, reason: 'Wholesale customer must get carton wholesale price 75, NOT piece 6.5 or 8');
    });

    test('resolveLinePrice preserves manual price override', () async {
      final s = await setupScenarioProduct();

      final linePrice = DocumentService.resolveLinePrice(
        product: s.product,
        availableUnits: [s.unit],
        quantity: 1.0,
        currentPrice: 82.5,
        saleUnit: s.unit.unitName,
        unitConversionFactor: s.unit.conversionFactor,
        pricingCategory: Contact.categoryRetail,
        targetCategory: Contact.categoryWholesale,
        isManualPrice: true,
        wholesalePricingEnabled: true,
      );

      expect(linePrice, 82.5, reason: 'Manual price must not be overwritten');
    });

    test('resolveLinePrice preserves legacy NULL category and conversion factor mismatch', () async {
      final s = await setupScenarioProduct();

      // Legacy NULL line
      final legacyPrice = DocumentService.resolveLinePrice(
        product: s.product,
        availableUnits: [s.unit],
        quantity: 1.0,
        currentPrice: 7.75,
        saleUnit: null,
        unitConversionFactor: null,
        pricingCategory: null,
        targetCategory: Contact.categoryWholesale,
        isManualPrice: false,
        wholesalePricingEnabled: true,
      );
      expect(legacyPrice, 7.75, reason: 'Legacy NULL category must never be repriced');

      // Conversion factor mismatch (snapshot factor 10 vs current unit factor 12)
      final mismatchPrice = DocumentService.resolveLinePrice(
        product: s.product,
        availableUnits: [s.unit],
        quantity: 1.0,
        currentPrice: 80.0,
        saleUnit: s.unit.unitName,
        unitConversionFactor: 10.0, // changed
        pricingCategory: Contact.categoryRetail,
        targetCategory: Contact.categoryWholesale,
        isManualPrice: false,
        wholesalePricingEnabled: true,
      );
      expect(mismatchPrice, 80.0, reason: 'Historical snapshot factor mismatch must preserve price');
    });
  });

  group('BUG-3 / GAP-1 (Medium): Quotation parity with custom units and tiers', () {
    test('quotation with custom units converts to invoice and issues with exact stock deduction', () async {
      final s = await setupScenarioProduct(stock: 100.0);

      // Create quotation with 2 cartons at wholesale price 75.0
      final qId = await DocumentService.createDocument(
        type: 'quotation',
        business: s.business,
        validUntil: DateTime.now().add(const Duration(days: 30)),
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
      );

      // Verify quotation does not deduct stock
      final p1 = await db.getProductById(s.product.id!);
      expect(p1!.stockQuantity, 100.0);

      // Verify quotation document_items stored snapshots
      final qItems = await db.getDocumentItems(qId);
      expect(qItems.length, 1);
      expect(qItems.first.saleUnit, 'carton');
      expect(qItems.first.unitConversionFactor, 12.0);
      expect(qItems.first.effectiveBaseQuantity, 24.0);
      expect(qItems.first.pricingCategory, Contact.categoryWholesale);

      // Convert quotation to invoice
      final invId = await db.convertQuotationToInvoice(qId);
      final invItems = await db.getDocumentItems(invId);
      expect(invItems.length, 1);
      expect(invItems.first.saleUnit, 'carton');
      expect(invItems.first.unitConversionFactor, 12.0);
      expect(invItems.first.effectiveBaseQuantity, 24.0);
      expect(invItems.first.pricingCategory, Contact.categoryWholesale);

      // Invoice is draft; stock is still 100.0
      final p2 = await db.getProductById(s.product.id!);
      expect(p2!.stockQuantity, 100.0);

      // Issue the invoice -> must deduct 24 base units (100 - 24 = 76)
      await db.issueDocument(invId, strictStock: true);
      final p3 = await db.getProductById(s.product.id!);
      expect(p3!.stockQuantity, 76.0);

      // Verify stock movements
      final movements = await db.getStockMovements(s.product.id!);
      final saleMov = movements.firstWhere((m) => m.referenceDocumentId == invId && m.type == StockMovement.typeSale);
      expect(saleMov.quantity, -24.0);
      expect(saleMov.totalCost, 24.0 * 5.0); // 120.0
    });
  });
}
