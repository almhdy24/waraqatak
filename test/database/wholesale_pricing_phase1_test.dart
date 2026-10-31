import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/product.dart';
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
    tempDir = Directory.systemTemp.createTempSync('wholesale_phase1_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // 1. Migration from v21 to v22 and preservation of existing data
  test('1. Migration from v21 to v22 adds required columns and preserves existing data', () async {
    final migDbPath = '${tempDir.path}/mig_v21_to_v22.db';
    final db = await databaseFactory.openDatabase(migDbPath);

    // Create v21 schema
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
        legal_name TEXT,
        tax_id TEXT,
        tax_reg TEXT,
        commercial_reg TEXT,
        branch TEXT,
        taxes_enabled INTEGER DEFAULT 0,
        prices_include_tax INTEGER DEFAULT 0,
        default_tax_profile_id INTEGER,
        invoice_title TEXT,
        legal_footer TEXT,
        currency_locked_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        type TEXT DEFAULT 'customer',
        active INTEGER DEFAULT 1,
        legal_name TEXT,
        tax_id TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
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
        tax_profile_id INTEGER,
        average_cost REAL,
        cost_status TEXT DEFAULT 'unknown',
        created_at TEXT,
        updated_at TEXT
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
        total_cost REAL
      )
    ''');

    // Insert legacy v21 rows
    await db.insert('businesses', {
      'name': 'متجر تجريبي',
      'owner_name': 'محمد',
      'phone': '0123456789',
      'address': 'الخرطوم',
    });
    final cid = await db.insert('contacts', {'name': 'عميل قديم'});
    final pid = await db.insert('products', {
      'name': 'منتج قديم',
      'sale_price': 150.0,
      'stock_quantity': 20.0,
    });
    final iid = await db.insert('document_items', {
      'document_id': 100,
      'product_id': pid,
      'description': 'منتج قديم',
      'quantity': 2.0,
      'price': 150.0,
      'total': 300.0,
    });

    // Run Migration v21 -> v22
    await db.transaction((txn) async {
      await DatabaseHelper.instance.upgradeTablesForTest(txn, 21, 22);
    });

    // Verify businesses table has wholesale_pricing_enabled defaulting to 0
    final bRows = await db.query('businesses');
    expect(bRows.first['wholesale_pricing_enabled'], 0);

    // Verify contacts table has pricing_category defaulting to 'retail'
    final cRows = await db.query('contacts', where: 'id = ?', whereArgs: [cid]);
    expect(cRows.first['pricing_category'], 'retail');

    // Verify products table has wholesale_price and wholesale_min_quantity columns (NULL for legacy)
    final pRows = await db.query('products', where: 'id = ?', whereArgs: [pid]);
    expect(pRows.first['wholesale_price'], isNull);
    expect(pRows.first['wholesale_min_quantity'], isNull);

    // Verify document_items table has pricing_category column and legacy rows keep NULL (legacy protection)
    final itRows = await db.query('document_items', where: 'id = ?', whereArgs: [iid]);
    expect(itRows.first['pricing_category'], isNull);

    await db.close();
  });

  // 2. Fresh-install defaults and feature-disabled behavior
  test('2. Fresh-install defaults have wholesale disabled and resolve retail price', () async {
    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر جديد',
        ownerName: 'علي',
        phone: '0987654321',
        address: 'أم درمان',
        wholesalePricingEnabled: false,
      ),
    );

    final b = await db.getFirstBusiness();
    expect(b?.wholesalePricingEnabled, isFalse);

    const product = Product(
      name: 'هاتف ذكي',
      salePrice: 1000.0,
      wholesalePrice: 850.0,
      wholesaleMinQuantity: 5.0,
    );

    // When feature is disabled, resolveItemPrice always returns salePrice regardless of requested category
    final priceRetail = DocumentService.resolveItemPrice(
      product: product,
      targetCategory: Contact.categoryRetail,
      quantity: 10,
      wholesalePricingEnabled: false,
    );
    expect(priceRetail, 1000.0);

    final priceWholesale = DocumentService.resolveItemPrice(
      product: product,
      targetCategory: Contact.categoryWholesale,
      quantity: 10,
      wholesalePricingEnabled: false,
    );
    expect(priceWholesale, 1000.0);
  });

  // 3. Retail and wholesale customer defaults
  test('3. Retail and wholesale customer defaults when feature is enabled', () {
    const product = Product(
      name: 'شاحن',
      salePrice: 50.0,
      wholesalePrice: 35.0,
    );

    const retailCustomer = Contact(
      name: 'عميل تجزئة',
      pricingCategory: Contact.categoryRetail,
    );
    const wholesaleCustomer = Contact(
      name: 'عميل جملة',
      pricingCategory: Contact.categoryWholesale,
    );

    // Retail customer default
    final pRetail = DocumentService.resolveItemPrice(
      product: product,
      targetCategory: retailCustomer.pricingCategory,
      quantity: 1,
      wholesalePricingEnabled: true,
    );
    expect(pRetail, 50.0);

    // Wholesale customer default
    final pWholesale = DocumentService.resolveItemPrice(
      product: product,
      targetCategory: wholesaleCustomer.pricingCategory,
      quantity: 1,
      wholesalePricingEnabled: true,
    );
    expect(pWholesale, 35.0);
  });

  // 4. Missing wholesale price and minimum-quantity boundary cases
  test('4. Missing wholesale price and minimum-quantity boundary cases', () {
    // Case 4a: Wholesale price is missing (null) -> falls back to retail
    const prodNoWholesale = Product(
      name: 'سماعة نادرة',
      salePrice: 200.0,
      wholesalePrice: null,
    );
    final fallbackPrice = DocumentService.resolveItemPrice(
      product: prodNoWholesale,
      targetCategory: Contact.categoryWholesale,
      quantity: 10,
      wholesalePricingEnabled: true,
    );
    expect(fallbackPrice, 200.0);

    // Case 4b: Wholesale price with min quantity = 5
    const prodWithMin = Product(
      name: 'كابل بيانات',
      salePrice: 20.0,
      wholesalePrice: 12.0,
      wholesaleMinQuantity: 5.0,
    );

    // Below minimum (quantity = 4.99) -> falls back to retail price
    expect(
      DocumentService.resolveItemPrice(
        product: prodWithMin,
        targetCategory: Contact.categoryWholesale,
        quantity: 4.99,
        wholesalePricingEnabled: true,
      ),
      20.0,
    );

    // Exactly at minimum (quantity = 5.0) -> gets wholesale price
    expect(
      DocumentService.resolveItemPrice(
        product: prodWithMin,
        targetCategory: Contact.categoryWholesale,
        quantity: 5.0,
        wholesalePricingEnabled: true,
      ),
      12.0,
    );

    // Above minimum (quantity = 10.0) -> gets wholesale price
    expect(
      DocumentService.resolveItemPrice(
        product: prodWithMin,
        targetCategory: Contact.categoryWholesale,
        quantity: 10.0,
        wholesalePricingEnabled: true,
      ),
      12.0,
    );

    // Case 4c: Wholesale price with no min quantity (null) -> applies immediately for any quantity
    const prodNoMin = Product(
      name: 'محول',
      salePrice: 30.0,
      wholesalePrice: 22.0,
      wholesaleMinQuantity: null,
    );
    expect(
      DocumentService.resolveItemPrice(
        product: prodNoMin,
        targetCategory: Contact.categoryWholesale,
        quantity: 1.0,
        wholesalePricingEnabled: true,
      ),
      22.0,
    );
  });

  // 5. Manual price override surviving quantity/customer changes
  test('5. Manual price override survives quantity and customer tier changes', () async {
    const product = Product(
      name: 'دفتر حسابات',
      salePrice: 40.0,
      wholesalePrice: 25.0,
      wholesaleMinQuantity: 5.0,
    );

    // Suppose user entered manual price = 28.0
    const manualPrice = 28.0;
    bool isManualPrice = true;

    // Simulation of changing quantity or customer when isManualPrice is true:
    // The UI checks !isManualPrice before calling resolveItemPrice.
    // If isManualPrice is true, the price is not recalculated.
    double currentPrice = manualPrice;
    void onQuantityOrCustomerChanged(double newQty, String newCategory) {
      if (!isManualPrice) {
        currentPrice = DocumentService.resolveItemPrice(
          product: product,
          targetCategory: newCategory,
          quantity: newQty,
          wholesalePricingEnabled: true,
        );
      }
    }

    onQuantityOrCustomerChanged(10, Contact.categoryWholesale);
    expect(currentPrice, 28.0); // manual override preserved!

    // If manual price override is explicitly cleared (e.g. user taps Retail/Wholesale chip):
    isManualPrice = false;
    onQuantityOrCustomerChanged(10, Contact.categoryWholesale);
    expect(currentPrice, 25.0); // automatically resolved now!
  });

  // 6. Editing legacy invoices without automatic repricing
  test('6. Editing legacy invoices preserves stored prices and NULL pricing_category', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    // Create a product with updated current prices
    final pid = await ProductService.createProduct(
      name: 'سلعة تجريبية',
      salePrice: 500.0,
      wholesalePrice: 350.0,
      wholesaleMinQuantity: 5.0,
    );

    // Insert a document directly with legacy DocumentItem (pricing_category = null, price = 400.0)
    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'سلعة تجريبية',
          quantity: 2.0,
          price: 400.0, // Historical price differs from current salePrice (500)
          productId: pid,
          pricingCategory: null, // Legacy unknown category
        ),
      ],
      strictStock: false,
    );

    final loadedItems = await db.getDocumentItems(docId);
    expect(loadedItems.first.price, 400.0);
    expect(loadedItems.first.pricingCategory, isNull);

    // Update document without touching item price
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: loadedItems.first.description,
          quantity: loadedItems.first.quantity,
          price: loadedItems.first.price, // Stored historical price preserved
          taxable: loadedItems.first.taxable,
          productId: loadedItems.first.productId,
          pricingCategory: loadedItems.first.pricingCategory, // Keeps null
        ),
      ],
      strictStock: false,
    );

    final reloadedItems = await db.getDocumentItems(docId);
    expect(reloadedItems.first.price, 400.0);
    expect(reloadedItems.first.pricingCategory, isNull);
  });

  // 7. Duplicate and quotation conversion preserving available snapshots
  test('7. Quotation conversion and duplication preserve pricing_category snapshots', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    // Create a quotation with wholesale pricing snapshot
    final qId = await DocumentService.createDocument(
      type: 'quotation',
      business: business,
      date: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 14)),
      items: [
        const DocumentItemInput(
          description: 'بند جملة',
          quantity: 10.0,
          price: 80.0,
          pricingCategory: Contact.categoryWholesale,
        ),
        const DocumentItemInput(
          description: 'بند قديم',
          quantity: 1.0,
          price: 100.0,
          pricingCategory: null, // Legacy item
        ),
      ],
      strictStock: false,
    );

    // 7a. Convert quotation to draft invoice
    final invId = await DocumentService.convertQuotationToInvoice(qId);
    final invItems = await db.getDocumentItems(invId);
    expect(invItems.length, 2);
    expect(invItems[0].pricingCategory, Contact.categoryWholesale);
    expect(invItems[0].price, 80.0);
    expect(invItems[1].pricingCategory, isNull);
    expect(invItems[1].price, 100.0);

    // 7b. Duplicate invoice (copyDocumentWithItems)
    final dupId = await db.copyDocumentWithItems(invId);
    final dupItems = await db.getDocumentItems(dupId);
    expect(dupItems.length, 2);
    expect(dupItems[0].pricingCategory, Contact.categoryWholesale);
    expect(dupItems[0].price, 80.0);
    expect(dupItems[1].pricingCategory, isNull);
    expect(dupItems[1].price, 100.0);
  });

  // 8. Restoring an old backup into the new schema
  test('8. Restoring an old backup without wholesale fields succeeds using safe defaults', () async {
    final db = DatabaseHelper.instance;

    // Construct a valid v4 backup JSON from before Phase 1
    final oldBackupJson = {
      'app': 'warqatek',
      'backup_version': 4,
      'database_version': 21,
      'created_at': DateTime.now().toIso8601String(),
      'data': {
        'businesses': [
          {
            'id': 1,
            'name': 'متجر النسخة السابقة',
            'owner_name': 'خالد',
            'phone': '0911111111',
            'address': 'الخرطوم',
            'currency_code': 'SDG',
            'tax_rate': 0.0,
            'taxes_enabled': 0,
            'prices_include_tax': 0,
          }
        ],
        'contacts': [
          {
            'id': 1,
            'name': 'عميل احتياطي قديم',
            'phone': '0922222222',
            'type': 'customer',
            'active': 1,
            // Notice: 'pricing_category' is absent
          }
        ],
        'products': [
          {
            'id': 1,
            'name': 'منتج احتياطي قديم',
            'type': 'product',
            'sale_price': 120.0,
            'purchase_price': 80.0,
            'stock_quantity': 15.0,
            'min_stock': 2.0,
            'is_taxable': 1,
            'is_active': 1,
            // Notice: 'wholesale_price' and 'wholesale_min_quantity' are absent
          }
        ],
        'documents': [
          {
            'id': 1,
            'type': 'invoice',
            'document_number': 'INV-2026-0001',
            'date': DateTime.now().toIso8601String(),
            'contact_id': 1,
            'subtotal': 240.0,
            'discount': 0.0,
            'tax_rate': 0.0,
            'tax_amount': 0.0,
            'total': 240.0,
            'paid': 240.0,
            'remaining': 0.0,
            'status': 'paid',
            'currency_code': 'SDG',
          }
        ],
        'document_items': [
          {
            'id': 1,
            'document_id': 1,
            'product_id': 1,
            'description': 'منتج احتياطي قديم',
            'quantity': 2.0,
            'price': 120.0,
            'total': 240.0,
            'taxable': 1,
            // Notice: 'pricing_category' is absent
          }
        ],
        'document_counters': [
          {'type': 'invoice', 'next_number': 2}
        ],
      },
      'assets': {'logo_base64': null},
    };

    // Restore without safety backup for this isolated test
    final success = await BackupService.restoreFromJsonMap(
      oldBackupJson,
      createSafetyBackup: false,
    );
    expect(success, isTrue);

    // Verify business has wholesale_pricing_enabled defaulting to 0
    final business = await db.getFirstBusiness();
    expect(business?.name, 'متجر النسخة السابقة');
    expect(business?.wholesalePricingEnabled, isFalse);

    // Verify contact restored with default 'retail' category
    final contacts = await db.getAllContacts();
    expect(contacts.first.name, 'عميل احتياطي قديم');
    expect(contacts.first.pricingCategory, Contact.categoryRetail);

    // Verify product restored with null wholesale fields
    final products = await db.getAllProducts();
    expect(products.first.name, 'منتج احتياطي قديم');
    expect(products.first.wholesalePrice, isNull);
    expect(products.first.wholesaleMinQuantity, isNull);

    // Verify document item restored with null pricing_category (legacy preserved)
    final items = await db.getDocumentItems(1);
    expect(items.first.description, 'منتج احتياطي قديم');
    expect(items.first.price, 120.0);
    expect(items.first.pricingCategory, isNull);
  });
}
