import 'dart:io';
import 'dart:math';
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
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;
  late Business business;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('units_invariants_test');
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
        name: 'متجر الحتميات',
        ownerName: 'المدير',
        phone: '0123456789',
        address: 'الخرطوم',
        currencyCode: 'SDG',
        wholesalePricingEnabled: true,
      ),
    );
    business = (await db.getFirstBusiness())!;
  });

  test('P1: Seeded randomized invariant tests (INV-1..INV-9)', () async {
    final rand = Random(42);

    for (int iter = 0; iter < 60; iter++) {
      // 1. Create a randomized product with custom unit
      final initialStock = (rand.nextInt(40) + 10).toDouble(); // 10..50
      final avgCost = (rand.nextInt(10) + 5).toDouble(); // 5..15
      final salePrice = avgCost + 5.0;
      final wholesalePrice = avgCost + 2.0;
      final factor = (rand.nextInt(10) + 2).toDouble(); // 2..12

      final pid = await db.insertProduct(
        Product(
          name: 'منتج $iter',
          unit: 'قطعة',
          stockQuantity: initialStock,
          purchasePrice: avgCost,
          salePrice: salePrice,
          wholesalePrice: wholesalePrice,
          wholesaleMinQuantity: 5.0,
        ),
      );

      final unitId = await db.insertProductUnit(
        ProductUnit(
          productId: pid,
          unitName: 'صندوق $iter',
          conversionFactor: factor,
          salePrice: salePrice * factor,
          wholesalePrice: wholesalePrice * factor,
        ),
      );
      final product = (await db.getProductById(pid))!;
      final unit = (await db.getProductUnits(pid)).firstWhere((u) => u.id == unitId);

      // Random lines: mix of custom units and base units
      final unitLinesCount = rand.nextInt(3) + 1; // 1..3 lines
      final pieceLinesCount = rand.nextInt(3) + 1; // 1..3 lines

      double totalRequiredBase = 0.0;
      final items = <DocumentItemInput>[];

      for (int i = 0; i < unitLinesCount; i++) {
        final q = (rand.nextInt(4) + 1).toDouble(); // 1..4 units
        totalRequiredBase += q * factor;
        items.add(
          DocumentItemInput(
            description: '${product.name} صندوق',
            quantity: q,
            price: unit.salePrice!,
            productId: pid,
            saleUnit: unit.unitName,
            unitConversionFactor: factor,
            pricingCategory: Contact.categoryRetail,
          ),
        );
      }

      for (int i = 0; i < pieceLinesCount; i++) {
        final q = (rand.nextInt(5) + 1).toDouble(); // 1..5 pieces
        totalRequiredBase += q;
        items.add(
          DocumentItemInput(
            description: '${product.name} قطعة',
            quantity: q,
            price: salePrice,
            productId: pid,
            saleUnit: product.unit,
            unitConversionFactor: 1.0,
            pricingCategory: Contact.categoryRetail,
          ),
        );
      }

      // --- INVARIANT 1: Strict mode acceptance & non-negative stock ---
      final strictStock = rand.nextBool();
      if (strictStock) {
        if (totalRequiredBase > initialStock) {
          // MUST be rejected
          expect(
            () async => await DocumentService.createDocument(
              type: 'invoice',
              business: business,
              items: items,
              strictStock: true,
            ),
            throwsA(isA<StateError>()),
            reason: 'Strict sale requiring $totalRequiredBase on stock $initialStock must be rejected',
          );
          final currentP = (await db.getProductById(pid))!;
          expect(currentP.stockQuantity, initialStock);
          expect(currentP.stockQuantity >= 0, true, reason: 'INV-1: stock must never be negative');
          continue; // product untampered, move to next iteration
        }
      }

      // If accepted (or non-strict):
      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: items,
        strictStock: strictStock,
      );

      final postSaleProduct = (await db.getProductById(pid))!;

      // --- INVARIANT 2: In non-strict mode stock never goes negative ---
      expect(postSaleProduct.stockQuantity >= 0, true, reason: 'INV-2: non-strict stock never goes negative');

      if (strictStock || totalRequiredBase <= initialStock) {
        // --- INVARIANT 3: final stock = initial - sum(base quantities) for fully backed accepted sales ---
        expect(
          postSaleProduct.stockQuantity,
          closeTo(initialStock - totalRequiredBase, 0.0001),
          reason: 'INV-3: exact base quantity deduction',
        );

        // --- INVARIANT 4: sum of stock_movements per document = -sum(base quantities) ---
        final movements = await db.getStockMovements(pid);
        final saleMovs = movements.where((m) => m.referenceDocumentId == docId && m.type == StockMovement.typeSale);
        final totalMoved = saleMovs.fold<double>(0.0, (sum, m) => sum + m.quantity);
        expect(
          totalMoved,
          closeTo(-totalRequiredBase, 0.0001),
          reason: 'INV-4: movement quantity must match total base required',
        );

        // --- INVARIANT 5: item total_cost = base_quantity x average_cost when fully backed ---
        final savedItems = await db.getDocumentItems(docId);
        for (final it in savedItems) {
          if (it.totalCost != null) {
            expect(
              it.totalCost!,
              closeTo(it.effectiveBaseQuantity * avgCost, 0.0001),
              reason: 'INV-5: total_cost equals base_quantity * avgCost',
            );
          }
        }

        // --- INVARIANT 6: cancel restores exact base quantities ---
        await db.cancelDocument(docId);
        final postCancelProduct = (await db.getProductById(pid))!;
        expect(
          postCancelProduct.stockQuantity,
          closeTo(initialStock, 0.0001),
          reason: 'INV-6: cancellation restores exact base quantities',
        );

        // --- INVARIANT 7: edit then cancel returns to initial stock ---
        final doc2Id = await DocumentService.createDocument(
          type: 'invoice',
          business: business,
          items: items.take(1).toList(),
          strictStock: true,
        );
        // update with original full items
        await DocumentService.updateDocument(
          documentId: doc2Id,
          type: 'invoice',
          business: business,
          items: items,
          strictStock: true,
        );
        await db.cancelDocument(doc2Id);
        final postEditCancelProduct = (await db.getProductById(pid))!;
        expect(
          postEditCancelProduct.stockQuantity,
          closeTo(initialStock, 0.0001),
          reason: 'INV-7: edit then cancel returns to initial stock',
        );
      }

      // --- INVARIANT 8: repricing never touches manual or legacy NULL lines ---
      final manualPrice = DocumentService.resolveLinePrice(
        product: product,
        availableUnits: [unit],
        quantity: 2.0,
        currentPrice: 99.99,
        saleUnit: unit.unitName,
        unitConversionFactor: factor,
        pricingCategory: Contact.categoryRetail,
        targetCategory: Contact.categoryWholesale,
        isManualPrice: true,
        wholesalePricingEnabled: true,
      );
      expect(manualPrice, 99.99, reason: 'INV-8: manual price override never overwritten');

      final legacyPrice = DocumentService.resolveLinePrice(
        product: product,
        availableUnits: [unit],
        quantity: 2.0,
        currentPrice: 12.34,
        saleUnit: null,
        unitConversionFactor: null,
        pricingCategory: null,
        targetCategory: Contact.categoryWholesale,
        isManualPrice: false,
        wholesalePricingEnabled: true,
      );
      expect(legacyPrice, 12.34, reason: 'INV-8: legacy NULL category never overwritten');

      // --- INVARIANT 9: reports aggregate COALESCE(base_quantity, quantity) ---
      await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(
            description: '${product.name} تقرير',
            quantity: 2.0,
            price: unit.salePrice!,
            productId: pid,
            saleUnit: unit.unitName,
            unitConversionFactor: factor,
            pricingCategory: Contact.categoryRetail,
          ),
        ],
        strictStock: false,
      );
      final perf = await BusinessReportingService.instance.getProductPerformance(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      final prodPerf = perf.items.firstWhere((p) => p.productId == pid);
      // The report must reflect base units (2.0 * factor) for this sale (plus any previous non-cancelled sale on this product)
      expect(prodPerf.salesQty >= 2.0 * factor, true, reason: 'INV-9: report must aggregate base quantities');
    }
  });
}
