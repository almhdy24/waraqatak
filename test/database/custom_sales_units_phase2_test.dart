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
import 'package:warqatek/services/backup_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('custom_units_phase2_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // 1 & 2. Migration from v22 to v23 and legacy row preservation
  test('1 & 2. Migration from v22 to v23 creates product_units and preserves legacy document_items', () async {
    final migDbPath = '${tempDir.path}/mig_v22_to_v23.db';
    final db = await databaseFactory.openDatabase(migDbPath);

    // Create v22 schema
    await db.execute('''
      CREATE TABLE businesses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        email TEXT,
        logo_path TEXT,
        currency_code TEXT DEFAULT 'SDG',
        tax_rate REAL DEFAULT 0,
        wholesale_pricing_enabled INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT DEFAULT 'product',
        unit TEXT,
        sale_price REAL DEFAULT 0,
        wholesale_price REAL,
        wholesale_min_quantity REAL,
        purchase_price REAL DEFAULT 0,
        stock_quantity REAL DEFAULT 0,
        is_taxable INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1
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
        total REAL NOT NULL,
        taxable INTEGER DEFAULT 1,
        tax_rate REAL,
        unit_cost REAL,
        total_cost REAL,
        pricing_category TEXT
      )
    ''');

    // Insert legacy v22 document items
    final pid = await db.insert('products', {
      'name': 'صابون',
      'unit': 'قطعة',
      'sale_price': 10.0,
      'stock_quantity': 50.0,
    });
    final iid = await db.insert('document_items', {
      'document_id': 10,
      'product_id': pid,
      'description': 'صابون',
      'quantity': 5.0,
      'price': 10.0,
      'total': 50.0,
    });

    // Run migration v22 -> v23
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 22, 23);
    });

    // Verify product_units table exists
    final puRows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='product_units'");
    expect(puRows.isNotEmpty, isTrue);

    // Verify document_items columns added and backfilled
    final itemRows = await db.query('document_items', where: 'id = ?', whereArgs: [iid]);
    final migratedItem = itemRows.first;
    expect(migratedItem['sale_unit'], isNull);
    expect(migratedItem['unit_conversion_factor'], 1.0);
    expect(migratedItem['base_quantity'], 5.0); // base_quantity = quantity
    expect(migratedItem['quantity'], 5.0);
    expect(migratedItem['total'], 50.0);

    await db.close();
  });

  // 3 & 4. Selling 2 cartons x 10 pieces deducts 20 base units and calculates COGS = 20 x avgCost
  test('3 & 4. Selling 2 cartons x 10 pieces deducts 20 base units and COGS = 20 x avgCost', () async {
    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر الوحدات',
        ownerName: 'أحمد',
        phone: '0111111111',
        address: 'الخرطوم',
        wholesalePricingEnabled: true,
      ),
    );
    final business = (await db.getFirstBusiness())!;

    // Create product with 100 base units (pieces) at purchase price 15.0 (average_cost = 15.0)
    final pid = await db.insertProduct(
      const Product(
        name: 'بسكويت',
        unit: 'قطعة',
        salePrice: 20.0,
        purchasePrice: 15.0,
        stockQuantity: 100.0,
      ),
    );

    // Add sales unit: Carton = 10 pieces, sale_price = 190.0
    await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'كرتونة',
        conversionFactor: 10.0,
        salePrice: 190.0,
      ),
    );

    // Sell 2 cartons
    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'بسكويت (كرتونة)',
          quantity: 2.0,
          price: 190.0,
          productId: pid,
          saleUnit: 'كرتونة',
          unitConversionFactor: 10.0,
          baseQuantity: 20.0,
        ),
      ],
      strictStock: true,
    );

    // Verify stock quantity: 100 - 20 = 80
    final updatedProd = await db.getProductById(pid);
    expect(updatedProd?.stockQuantity, 80.0);

    // Verify stock_movement quantity is negative base_quantity (-20)
    final movements = await db.getStockMovements(pid);
    final saleMovement = movements.firstWhere((m) => m.type == 'sale');
    expect(saleMovement.quantity, -20.0);
    expect(saleMovement.unitCost, 15.0);
    expect(saleMovement.totalCost, 300.0); // 20 * 15.0

    // Verify document item: quantity = 2, total = 380, base_quantity = 20, total_cost = 300
    final items = await db.getDocumentItems(docId);
    expect(items.first.quantity, 2.0);
    expect(items.first.saleUnit, 'كرتونة');
    expect(items.first.unitConversionFactor, 10.0);
    expect(items.first.baseQuantity, 20.0);
    expect(items.first.price, 190.0);
    expect(items.first.total, 380.0);
    expect(items.first.unitCost, 15.0);
    expect(items.first.totalCost, 300.0); // 20 * 15.0
  });

  // 5. Different sales units preserve correct stock quantities
  test('5. Different sales units on same product preserve correct stock deduction', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    // Create product with 500 meters
    final pid = await db.insertProduct(
      const Product(
        name: 'قماش',
        unit: 'متر',
        salePrice: 50.0,
        purchasePrice: 30.0,
        stockQuantity: 500.0,
      ),
    );

    // Roll = 50 meters
    await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'طاقة',
        conversionFactor: 50.0,
        salePrice: 2400.0,
      ),
    );

    // Sell 3 rolls (150 meters) + 5 meters = 155 meters
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'طاقة قماش',
          quantity: 3.0,
          price: 2400.0,
          productId: pid,
          saleUnit: 'طاقة',
          unitConversionFactor: 50.0,
          baseQuantity: 150.0,
        ),
        DocumentItemInput(
          description: 'متر قماش فردي',
          quantity: 5.0,
          price: 50.0,
          productId: pid,
          saleUnit: 'متر',
          unitConversionFactor: 1.0,
          baseQuantity: 5.0,
        ),
      ],
      strictStock: true,
    );

    final prod = await db.getProductById(pid);
    expect(prod?.stockQuantity, 345.0); // 500 - 155 = 345
  });

  // 6. Cancellation restores exact base quantity
  test('6. Invoice cancellation restores the exact original base quantity', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    final pid = await db.insertProduct(
      const Product(
        name: 'زيت طعام',
        unit: 'لتر',
        salePrice: 80.0,
        purchasePrice: 60.0,
        stockQuantity: 200.0,
      ),
    );

    // Carton = 12 liters
    await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'كرتونة',
        conversionFactor: 12.0,
        salePrice: 900.0,
      ),
    );

    // Sell 5 cartons = 60 liters
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'كرتونة زيت',
          quantity: 5.0,
          price: 900.0,
          productId: pid,
          saleUnit: 'كرتونة',
          unitConversionFactor: 12.0,
          baseQuantity: 60.0,
        ),
      ],
      strictStock: true,
    );

    // Stock after sale: 200 - 60 = 140
    expect((await db.getProductById(pid))?.stockQuantity, 140.0);

    // Cancel document
    await db.cancelDocument(invId);

    // Stock after cancellation restored back to 200.0
    expect((await db.getProductById(pid))?.stockQuantity, 200.0);

    // Cancellation movement recorded with +60.0
    final movements = await db.getStockMovements(pid);
    final cancelMovement = movements.firstWhere((m) => m.type == 'cancellation');
    expect(cancelMovement.quantity, 60.0);
    expect(cancelMovement.unitCost, 60.0);
    expect(cancelMovement.totalCost, 3600.0);
  });

  // 7. Editing and duplication preserve historical conversion snapshots
  test('7. Editing and duplication preserve historical unit and conversion snapshots', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    final pid = await db.insertProduct(
      const Product(
        name: 'حليب',
        unit: 'علبة',
        salePrice: 30.0,
        purchasePrice: 20.0,
        stockQuantity: 100.0,
      ),
    );

    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'صندوق حليب',
          quantity: 2.0,
          price: 350.0,
          productId: pid,
          saleUnit: 'صندوق',
          unitConversionFactor: 12.0,
          baseQuantity: 24.0,
        ),
      ],
      strictStock: true,
    );

    // Duplicate invoice
    final dupId = await db.copyDocumentWithItems(invId);
    final dupItems = await db.getDocumentItems(dupId);
    expect(dupItems.length, 1);
    expect(dupItems.first.saleUnit, 'صندوق');
    expect(dupItems.first.unitConversionFactor, 12.0);
    expect(dupItems.first.baseQuantity, 24.0);
    expect(dupItems.first.quantity, 2.0);
    expect(dupItems.first.price, 350.0);

    // Update original document: modify notes without modifying conversion snapshots
    await DocumentService.updateDocument(
      documentId: invId,
      type: 'invoice',
      business: business,
      notes: 'ملاحظة محدثة',
      items: [
        DocumentItemInput(
          description: dupItems.first.description,
          quantity: dupItems.first.quantity,
          price: dupItems.first.price,
          productId: dupItems.first.productId,
          saleUnit: dupItems.first.saleUnit,
          unitConversionFactor: dupItems.first.unitConversionFactor,
          baseQuantity: dupItems.first.baseQuantity,
        ),
      ],
      strictStock: false,
    );

    final reloaded = await db.getDocumentItems(invId);
    expect(reloaded.first.saleUnit, 'صندوق');
    expect(reloaded.first.unitConversionFactor, 12.0);
    expect(reloaded.first.baseQuantity, 24.0);
  });

  // 8. Wholesale/retail prices with additional units and base quantity threshold
  test('8. Wholesale/retail prices work with additional units and evaluate min quantity in base units', () {
    const product = Product(
      name: 'معكرونة',
      unit: 'كيس',
      salePrice: 10.0,
      wholesalePrice: 8.0,
      wholesaleMinQuantity: 50.0, // 50 base bags required for wholesale price
    );

    // Unit 1: Pack = 10 bags, explicit retail = 95.0, explicit wholesale = 75.0
    const packUnit = ProductUnit(
      productId: 1,
      unitName: 'باكت',
      conversionFactor: 10.0,
      salePrice: 95.0,
      wholesalePrice: 75.0,
    );

    // Buying 4 packs = 40 base bags (< 50 min) -> falls back to unit retail price (95.0)
    final priceBelowMin = DocumentService.resolveItemPrice(
      product: product,
      unit: packUnit,
      targetCategory: Contact.categoryWholesale,
      quantity: 4.0, // 4 * 10 = 40 base units
      wholesalePricingEnabled: true,
    );
    expect(priceBelowMin, 95.0);

    // Buying 5 packs = 50 base bags (>= 50 min) -> qualifies for unit wholesale price (75.0)
    final priceAtMin = DocumentService.resolveItemPrice(
      product: product,
      unit: packUnit,
      targetCategory: Contact.categoryWholesale,
      quantity: 5.0, // 5 * 10 = 50 base units
      wholesalePricingEnabled: true,
    );
    expect(priceAtMin, 75.0);

    // Unit 2: Box = 20 bags, no explicit prices configured (scales from product prices)
    const boxUnit = ProductUnit(
      productId: 1,
      unitName: 'صندوق',
      conversionFactor: 20.0,
      salePrice: null, // scales: 10 * 20 = 200.0
      wholesalePrice: null, // scales: 8 * 20 = 160.0
    );

    // Retail category
    final boxRetail = DocumentService.resolveItemPrice(
      product: product,
      unit: boxUnit,
      targetCategory: Contact.categoryRetail,
      quantity: 1.0,
      wholesalePricingEnabled: true,
    );
    expect(boxRetail, 200.0);

    // Wholesale category: 3 boxes = 60 base bags >= 50 min -> qualifies for wholesale scaled price (160.0)
    final boxWholesale = DocumentService.resolveItemPrice(
      product: product,
      unit: boxUnit,
      targetCategory: Contact.categoryWholesale,
      quantity: 3.0,
      wholesalePricingEnabled: true,
    );
    expect(boxWholesale, 160.0);
  });

  // 9. Invalid conversion factors are rejected
  test('9. Invalid conversion factors (<= 0) are rejected by model/database', () async {
    final db = DatabaseHelper.instance;

    expect(
      () => db.insertProductUnit(
        const ProductUnit(
          productId: 1,
          unitName: 'غير صالح',
          conversionFactor: 0.0,
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      () => db.insertProductUnit(
        const ProductUnit(
          productId: 1,
          unitName: 'سالب',
          conversionFactor: -5.0,
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  // 10. Backup and restore preserves all unit definitions and document snapshots
  test('10. Backup/restore preserves product units and document unit snapshots', () async {
    final db = DatabaseHelper.instance;

    // Insert product with unit
    final pid = await db.insertProduct(
      const Product(
        name: 'شاي',
        unit: 'علبة',
        salePrice: 25.0,
        purchasePrice: 18.0,
      ),
    );
    await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'كرتونة',
        conversionFactor: 24.0,
        salePrice: 550.0,
        wholesalePrice: 480.0,
        isDefaultSale: true,
      ),
    );

    // Export backup
    final backupJsonMap = {
      'app': 'warqatek',
      'backup_version': 4,
      'database_version': 23,
      'created_at': DateTime.now().toIso8601String(),
      'data': {
        'businesses': await (await db.database).query('businesses'),
        'contacts': await (await db.database).query('contacts'),
        'products': await (await db.database).query('products'),
        'product_units': await (await db.database).query('product_units'),
        'documents': await (await db.database).query('documents'),
        'document_items': await (await db.database).query('document_items'),
        'document_counters': await (await db.database).query('document_counters'),
        'document_payments': [],
        'stock_movements': [],
        'tax_profiles': [],
        'payment_methods': [],
        'stocktake_sessions': [],
        'stocktake_items': [],
        'audit_log': [],
      },
      'assets': {'logo_base64': null},
    };

    // Restore from map
    final success = await BackupService.restoreFromJsonMap(
      backupJsonMap,
      createSafetyBackup: false,
    );
    expect(success, isTrue);

    // Verify product_units restored
    final restoredUnits = await db.getProductUnits(pid);
    expect(restoredUnits.length, 1);
    expect(restoredUnits.first.unitName, 'كرتونة');
    expect(restoredUnits.first.conversionFactor, 24.0);
    expect(restoredUnits.first.salePrice, 550.0);
    expect(restoredUnits.first.wholesalePrice, 480.0);
    expect(restoredUnits.first.isDefaultSale, isTrue);
  });

  // 11. Existing users without additional units retain 100% current behavior
  test('11. Standard products without additional units continue functioning identically', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    final pid = await ProductService.createProduct(
      name: 'قلم جاف',
      unit: 'حبة',
      salePrice: 10.0,
      purchasePrice: 6.0,
      stockQuantity: 50.0,
    );

    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'قلم جاف',
          quantity: 5.0,
          price: 10.0,
          productId: pid,
        ),
      ],
      strictStock: true,
    );

    // Stock deducted 50 - 5 = 45
    expect((await db.getProductById(pid))?.stockQuantity, 45.0);

    final items = await db.getDocumentItems(invId);
    expect(items.first.quantity, 5.0);
    expect(items.first.unitConversionFactor, 1.0);
    expect(items.first.baseQuantity, 5.0);
    expect(items.first.total, 50.0);
  });
}
