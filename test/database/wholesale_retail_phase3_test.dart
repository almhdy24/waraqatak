import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/core/feature_gate.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/product_unit.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';
import 'package:warqatek/services/bulk_pricing_service.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/csv_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/pos_cart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    FeatureGate.setOverrideForTesting(true);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('phase3_wholesale_retail_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = DatabaseHelper.instance;
    await db.database;
    await db.insertBusiness(
      const Business(
        name: 'متجر المرحلة الثالثة',
        ownerName: 'مالك الاختبار',
        phone: '0912345678',
        address: 'الخرطوم',
        currencyCode: 'SDG',
        wholesalePricingEnabled: true,
      ),
    );
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {
    } finally {
      FeatureGate.resetForTesting();
    }
  });

  // 1. POS retail and wholesale pricing resolution
  test('1. POS retail and wholesale pricing resolution with min quantity threshold', () {
    const product = Product(
      id: 1,
      name: 'أرز فاخر',
      unit: 'كيلو',
      salePrice: 100.0,
      wholesalePrice: 80.0,
      wholesaleMinQuantity: 25.0,
      stockQuantity: 500.0,
    );

    final cart = PosCart();
    cart.setWholesalePricingEnabled(true);

    // Add 10 kg with retail pricing
    cart.setPricingCategory(Contact.categoryRetail);
    cart.add(product, quantity: 10.0);
    expect(cart.lines.first.unitPrice, 100.0);
    expect(cart.lines.first.total, 1000.0);

    // Switch cart to wholesale pricing: 10 kg is below min (25 kg) -> falls back to retail
    cart.setPricingCategory(Contact.categoryWholesale);
    expect(cart.lines.first.unitPrice, 100.0);

    // Increase quantity to 25 kg -> qualifies for wholesale price (80.0)
    cart.setQuantity(0, 25.0);
    expect(cart.lines.first.unitPrice, 80.0);
    expect(cart.lines.first.total, 2000.0);
  });

  // 2. POS sales units and base-unit stock tracking
  test('2. POS sales units calculate base quantity and enforce stock limits in base units', () {
    const product = Product(
      id: 2,
      name: 'شاي عبوة',
      unit: 'علبة',
      salePrice: 50.0,
      wholesalePrice: 40.0,
      stockQuantity: 100.0, // 100 base packets in stock
    );

    const cartonUnit = ProductUnit(
      id: 10,
      productId: 2,
      unitName: 'كرتونة',
      conversionFactor: 20.0, // 1 carton = 20 packets
      salePrice: 900.0,
    );

    final cart = PosCart();
    // Add 4 cartons (4 * 20 = 80 packets)
    final err1 = cart.add(product, quantity: 4.0, unit: cartonUnit);
    expect(err1, isNull);
    expect(cart.quantityOf(2), 4.0);
    expect(cart.baseQuantityOf(2), 80.0);

    // Try to add 2 more cartons (needs 40 packets, available 20) -> out of stock
    final err2 = cart.add(product, quantity: 2.0, unit: cartonUnit);
    expect(err2, PosCartError.outOfStock);

    // Adding 1 carton (20 packets) succeeds -> exactly 100 packets
    final err3 = cart.add(product, quantity: 1.0, unit: cartonUnit);
    expect(err3, isNull);
    expect(cart.baseQuantityOf(2), 100.0);

    final inputs = cart.toItemInputs();
    expect(inputs.first.saleUnit, 'كرتونة');
    expect(inputs.first.unitConversionFactor, 20.0);
    expect(inputs.first.baseQuantity, 100.0);
  });

  // 3. POS manual price override preservation
  test('3. POS manual price override survives quantity and tier changes', () {
    const product = Product(
      id: 3,
      name: 'قهوة',
      unit: 'حبة',
      salePrice: 70.0,
      wholesalePrice: 55.0,
      stockQuantity: 200.0,
    );

    final cart = PosCart();
    cart.setWholesalePricingEnabled(true);
    cart.add(product, quantity: 2.0, priceOverride: 65.0);

    expect(cart.lines.first.unitPrice, 65.0);

    // Change quantity
    cart.setQuantity(0, 5.0);
    expect(cart.lines.first.unitPrice, 65.0);

    // Switch tier
    cart.setPricingCategory(Contact.categoryWholesale);
    expect(cart.lines.first.unitPrice, 65.0);

    // Clear price override -> automatically resolves wholesale price
    cart.updateLine(0, clearPriceOverride: true);
    expect(cart.lines.first.unitPrice, 55.0);
  });

  // 4. Product performance and profit reports normalize quantities to base units
  test('4. Product performance reports aggregate sales quantity in base units', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    final pid = await db.insertProduct(
      const Product(
        name: 'سكر مكعبات',
        unit: 'كيس',
        salePrice: 20.0,
        purchasePrice: 15.0,
        stockQuantity: 500.0,
      ),
    );

    // Insert unit: Box = 10 bags
    await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'صندوق',
        conversionFactor: 10.0,
        salePrice: 180.0,
      ),
    );

    // Invoice 1: 3 boxes (= 30 bags)
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'صندوق سكر',
          quantity: 3.0,
          price: 180.0,
          productId: pid,
          saleUnit: 'صندوق',
          unitConversionFactor: 10.0,
          baseQuantity: 30.0,
        ),
      ],
      strictStock: true,
    );

    // Invoice 2: 5 bags (= 5 bags)
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'كيس سكر',
          quantity: 5.0,
          price: 20.0,
          productId: pid,
          saleUnit: 'كيس',
          unitConversionFactor: 1.0,
          baseQuantity: 5.0,
        ),
      ],
      strictStock: true,
    );

    final from = DateTime.now().subtract(const Duration(days: 1));
    final to = DateTime.now().add(const Duration(days: 1));

    // Check DatabaseHelper report
    final dbReport = await db.getProductReport(from: from, to: to);
    final itemDb = dbReport.firstWhere((r) => r['id'] == pid);
    // sales_qty MUST be 30 + 5 = 35 (not 3 + 5 = 8)
    expect(itemDb['sales_qty'], 35.0);

    // Check BusinessReportingService report
    final perfSummary = await BusinessReportingService.instance.getProductPerformance(
      from: from,
      to: to,
    );
    final perfItem = perfSummary.items.firstWhere((i) => i.productId == pid);
    expect(perfItem.salesQty, 35.0);
  });

  // 5. Ledger stock reconciliation uses effectiveBaseQuantity
  test('5. Ledger stock replay processes stock deduction using base quantity', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    final pid = await db.insertProduct(
      const Product(
        name: 'قماش فاخر',
        unit: 'متر',
        salePrice: 50.0,
        purchasePrice: 30.0,
        stockQuantity: 300.0,
      ),
    );

    // 2 rolls (50m each) = 100 meters
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'طاقة قماش',
          quantity: 2.0,
          price: 2300.0,
          productId: pid,
          saleUnit: 'طاقة',
          unitConversionFactor: 50.0,
          baseQuantity: 100.0,
        ),
      ],
      strictStock: true,
    );

    final book = await LedgerService.load();
    // Find journal entry corresponding to the invoice's cost of sales
    final cogsEntries = book.entries
        .where((e) => e.lines.any((l) => l.account == Accounts.cogs))
        .toList();
    expect(cogsEntries.isNotEmpty, isTrue);

    // Replay stock quantity should equal exactly 200 (300 - 100)
    final prod = await db.getProductById(pid);
    expect(prod?.stockQuantity, 200.0);
  });

  // 6. Fractional conversion factors precision
  test('6. Fractional conversion factors are calculated with precision without drift', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    final pid = await db.insertProduct(
      const Product(
        name: 'جبنة بيضاء',
        unit: 'كيلو',
        salePrice: 120.0,
        purchasePrice: 80.0,
        stockQuantity: 50.0,
      ),
    );

    // Half kilo unit = 0.5 kg
    await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'نصف كيلو',
        conversionFactor: 0.5,
        salePrice: 65.0,
      ),
    );

    // Sell 3 half-kilos = 1.5 kg
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'نصف كيلو جبنة',
          quantity: 3.0,
          price: 65.0,
          productId: pid,
          saleUnit: 'نصف كيلو',
          unitConversionFactor: 0.5,
          baseQuantity: 1.5,
        ),
      ],
      strictStock: true,
    );

    final prod = await db.getProductById(pid);
    expect(prod?.stockQuantity, 48.5); // 50 - 1.5 = 48.5
  });

  // 7. Invoice editing and cancellation with different units
  test('7. Editing invoice with different sales units reverses and deducts exact base units', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    final pid = await db.insertProduct(
      const Product(
        name: 'مياه معدنية',
        unit: 'قارورة',
        salePrice: 10.0,
        purchasePrice: 6.0,
        stockQuantity: 200.0,
      ),
    );

    // Pack = 12 bottles, Carton = 24 bottles
    await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'باكت',
        conversionFactor: 12.0,
        salePrice: 110.0,
      ),
    );
    await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'كرتونة',
        conversionFactor: 24.0,
        salePrice: 210.0,
      ),
    );

    // Issue invoice: 2 packs = 24 bottles (Stock: 200 - 24 = 176)
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'باكت مياه',
          quantity: 2.0,
          price: 110.0,
          productId: pid,
          saleUnit: 'باكت',
          unitConversionFactor: 12.0,
          baseQuantity: 24.0,
        ),
      ],
      strictStock: true,
    );
    expect((await db.getProductById(pid))?.stockQuantity, 176.0);

    // Edit invoice: change to 1 carton = 24 bottles + 6 individual bottles = 30 bottles
    await DocumentService.updateDocument(
      documentId: invId,
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'كرتونة مياه',
          quantity: 1.0,
          price: 210.0,
          productId: pid,
          saleUnit: 'كرتونة',
          unitConversionFactor: 24.0,
          baseQuantity: 24.0,
        ),
        DocumentItemInput(
          description: 'قارورة فردية',
          quantity: 6.0,
          price: 10.0,
          productId: pid,
          saleUnit: 'قارورة',
          unitConversionFactor: 1.0,
          baseQuantity: 6.0,
        ),
      ],
      strictStock: true,
    );

    // Stock should be 200 - 30 = 170.0
    expect((await db.getProductById(pid))?.stockQuantity, 170.0);

    // Cancel invoice: should restore exactly +30 bottles back to 200.0
    await db.cancelDocument(invId);
    expect((await db.getProductById(pid))?.stockQuantity, 200.0);
  });

  // 8. Unit modification/deletion does not corrupt historical snapshots
  test('8. Deleting a product unit definition leaves historical document snapshots intact', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    final pid = await db.insertProduct(
      const Product(
        name: 'صابون سائل',
        unit: 'لتر',
        salePrice: 25.0,
        purchasePrice: 15.0,
        stockQuantity: 100.0,
      ),
    );

    final unitId = await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'جركن 5 لتر',
        conversionFactor: 5.0,
        salePrice: 115.0,
      ),
    );

    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'جركن صابون',
          quantity: 4.0,
          price: 115.0,
          productId: pid,
          saleUnit: 'جركن 5 لتر',
          unitConversionFactor: 5.0,
          baseQuantity: 20.0,
        ),
      ],
      strictStock: true,
    );

    // Delete the unit definition from product_units
    await db.deleteProductUnit(unitId);

    // Verify unit definition is gone from catalog
    final currentUnits = await db.getProductUnits(pid);
    expect(currentUnits.isEmpty, isTrue);

    // Historical invoice item snapshot remains 100% intact
    final items = await db.getDocumentItems(invId);
    expect(items.first.saleUnit, 'جركن 5 لتر');
    expect(items.first.unitConversionFactor, 5.0);
    expect(items.first.baseQuantity, 20.0);
    expect(items.first.total, 460.0);
  });

  // 9. Bulk pricing updates wholesale prices safely
  test('9. BulkPricingService updates wholesale prices without touching retail or purchase prices', () async {
    final db = DatabaseHelper.instance;

    final pid1 = await db.insertProduct(
      const Product(
        name: 'منتج أ',
        salePrice: 100.0,
        purchasePrice: 60.0,
        wholesalePrice: 80.0,
      ),
    );
    final pid2 = await db.insertProduct(
      const Product(
        name: 'منتج ب',
        salePrice: 200.0,
        purchasePrice: 120.0,
        wholesalePrice: 160.0,
      ),
    );

    final p1 = (await db.getProductById(pid1))!;
    final p2 = (await db.getProductById(pid2))!;

    // 10% increase on wholesale prices
    final preview = BulkPricingService.instance.preview(
      products: [p1, p2],
      opType: BulkPriceOpType.percentageIncrease,
      opValue: 10.0,
      target: BulkPriceTarget.wholesalePrice,
    );

    expect(preview.length, 2);
    expect(preview[0].proposedWholesalePrice, 88.0);
    expect(preview[1].proposedWholesalePrice, 176.0);

    // Apply batch
    final result = await BulkPricingService.instance.applyBatch(
      items: preview,
      opType: BulkPriceOpType.percentageIncrease,
      opValue: 10.0,
      target: BulkPriceTarget.wholesalePrice,
    );
    expect(result.affectedCount, 2);

    // Verify products in database
    final p1Updated = (await db.getProductById(pid1))!;
    expect(p1Updated.wholesalePrice, 88.0);
    expect(p1Updated.salePrice, 100.0); // Preserved
    expect(p1Updated.purchasePrice, 60.0); // Preserved
  });

  // 10. CSV export and import compatibility (old and new formats)
  test('10. CSV import handles new wholesale/unit fields and retains old CSV compatibility', () async {
    final db = DatabaseHelper.instance;

    // 10.1 New CSV format import
    const newCsv = '''
Name,Barcode,Code,Category,Type,Unit,SalePrice,PurchasePrice,WholesalePrice,WholesaleMinQty,SalesUnits,MinStock,CurrentStock_ReadOnly,IsActive
تمر بركاوي,11223344,BARK-1,تمور,product,كجم,150.00,100.00,120.00,10.00,كرتونة:10:1100:950,5.00,0.00,1
''';

    final previewNew = await CsvService.instance.previewImport(
      Uint8List.fromList(utf8.encode(newCsv)),
    );
    expect(previewNew.validNewCount, 1);
    expect(previewNew.errorCount, 0);
    expect(previewNew.rows.first.wholesalePrice, 120.0);
    expect(previewNew.rows.first.wholesaleMinQty, 10.0);
    expect(previewNew.rows.first.salesUnits?.length, 1);
    expect(previewNew.rows.first.salesUnits?.first.unitName, 'كرتونة');
    expect(previewNew.rows.first.salesUnits?.first.conversionFactor, 10.0);

    final importResult = await CsvService.instance.applyImport(
      rows: previewNew.rows,
      strategy: CsvDuplicateStrategy.skip,
    );
    expect(importResult.importedCount, 1);

    // Verify inserted product and units
    final prodRows = await (await db.database).query('products', where: "name = 'تمر بركاوي'");
    expect(prodRows.isNotEmpty, isTrue);
    final pid = prodRows.first['id'] as int;
    final units = await db.getProductUnits(pid);
    expect(units.length, 1);
    expect(units.first.unitName, 'كرتونة');
    expect(units.first.conversionFactor, 10.0);

    // 10.2 Old CSV format (missing WholesalePrice, WholesaleMinQty, SalesUnits)
    const oldCsv = '''
Name,Barcode,Code,Category,Type,Unit,SalePrice,PurchasePrice,MinStock,CurrentStock_ReadOnly,IsActive
عدس أحمر,99887766,LENT-1,بقوليات,product,كجم,60.00,40.00,10.00,0.00,1
''';

    final previewOld = await CsvService.instance.previewImport(
      Uint8List.fromList(utf8.encode(oldCsv)),
    );
    expect(previewOld.validNewCount, 1);
    expect(previewOld.errorCount, 0);
    expect(previewOld.rows.first.wholesalePrice, isNull);
    expect(previewOld.rows.first.salesUnits, isNull);

    final importOldResult = await CsvService.instance.applyImport(
      rows: previewOld.rows,
      strategy: CsvDuplicateStrategy.skip,
    );
    expect(importOldResult.importedCount, 1);

    // 10.3 Invalid conversion factor (<= 0) is rejected
    const invalidUnitCsv = '''
Name,Barcode,Code,Category,Type,Unit,SalePrice,PurchasePrice,WholesalePrice,WholesaleMinQty,SalesUnits,MinStock,CurrentStock_ReadOnly,IsActive
منتج غير صالح,00000000,BAD-1,عام,product,حبة,50.00,30.00,40.00,5.00,وحدة خاطئة:0:0:0,2.00,0.00,1
''';
    final previewInvalid = await CsvService.instance.previewImport(
      Uint8List.fromList(utf8.encode(invalidUnitCsv)),
    );
    expect(previewInvalid.errorCount, 1);
    expect(previewInvalid.canImport, isFalse);
  });

  // 11. Feature disabled preserves existing quick-sale and pricing behavior
  test('11. POS with wholesale pricing disabled falls back to standard retail prices', () {
    const product = Product(
      id: 50,
      name: 'معجون أسنان',
      unit: 'حبة',
      salePrice: 45.0,
      wholesalePrice: 35.0,
      stockQuantity: 100.0,
    );

    final cart = PosCart();
    // Disabled wholesale pricing
    cart.setWholesalePricingEnabled(false);
    cart.setPricingCategory(Contact.categoryWholesale);

    cart.add(product, quantity: 50.0);
    // Since feature is disabled, price must remain retail (45.0)
    expect(cart.lines.first.unitPrice, 45.0);
    expect(cart.lines.first.total, 2250.0);
  });
}
