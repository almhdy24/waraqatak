import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/core/catalog_events.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/database/reference_pricing_dao.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/exchange_rate.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/product_unit.dart';
import 'package:warqatek/models/reference_pricing_types.dart';
import 'package:warqatek/services/backup_service.dart';
import 'package:warqatek/services/bulk_pricing_service.dart';
import 'package:warqatek/services/csv_service.dart';
import 'package:warqatek/services/reference_pricing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  DatabaseHelper? db;
  bool canRunSqliteFfi = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tempDir = Directory.systemTemp.createTempSync('ref_pricing_db_test');
      await databaseFactory.setDatabasesPath(tempDir.path);
      db = DatabaseHelper.instance;
      final rawDb = await db!.database;
      await rawDb.execute('SELECT 1');
      canRunSqliteFfi = true;
    } catch (_) {
      canRunSqliteFfi = false;
    }
  });

  tearDownAll(() async {
    if (canRunSqliteFfi && db != null) {
      await db!.closeDatabase();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  setUp(() async {
    if (!canRunSqliteFfi) return;
    await db!.closeDatabase();
    if (tempDir.existsSync()) {
      for (final f in tempDir.listSync()) {
        if (f is File) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }

    await db!.insertBusiness(
      const Business(
        name: 'Test Reference Business',
        ownerName: 'Owner',
        phone: '123456789',
        address: 'Sana\'a',
        currencyCode: 'YER',
        wholesalePricingEnabled: true,
      ),
    );
  });

  // =========================================================================
  // D1: Migration v25 -> v26
  // =========================================================================
  test('D1: Migration 25 -> 26 on a populated DB', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    // Check exchange_rates table exists
    final tables = await rawDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='exchange_rates'",
    );
    expect(tables, isNotEmpty);

    // Check columns on products
    final prodCols =
        await rawDb.rawQuery("PRAGMA table_info(products)");
    final prodColNames = prodCols.map((c) => c['name'] as String).toSet();
    expect(prodColNames.contains('price_currency'), isTrue);
    expect(prodColNames.contains('reference_sale_price'), isTrue);
    expect(prodColNames.contains('reference_wholesale_price'), isTrue);
    expect(prodColNames.contains('reference_purchase_price'), isTrue);

    // Check columns on product_units
    final unitCols =
        await rawDb.rawQuery("PRAGMA table_info(product_units)");
    final unitColNames = unitCols.map((c) => c['name'] as String).toSet();
    expect(unitColNames.contains('reference_sale_price'), isTrue);
    expect(unitColNames.contains('reference_wholesale_price'), isTrue);
    expect(unitColNames.contains('reference_currency'), isTrue);

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D2: No accumulation (1000 -> 1100 -> 1000)
  // =========================================================================
  test('D2: 1000 -> 1100 -> 1000 returns exact original base prices', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار أمريكي',
      symbol: '\$',
      rate: 1000.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    final pId = await db!.insertProduct(Product(
      name: 'Accumulation Test Product',
      priceCurrency: 'USD',
      referenceSalePrice: 10.5,
      salePrice: 0,
      purchasePrice: 0,
    ));

    var prod = (await db!.getProductById(pId))!;
    expect(prod.salePrice, 10500.0);

    // Reprice to 1100
    await ReferencePricingService.updateRateAndReprice('USD', 1100.0);
    prod = (await db!.getProductById(pId))!;
    expect(prod.salePrice, 11550.0);

    // Reprice back to 1000
    await ReferencePricingService.updateRateAndReprice('USD', 1000.0);
    prod = (await db!.getProductById(pId))!;
    expect(prod.salePrice, 10500.0);

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D3 & D4: updateRateAndReprice, audit, CatalogEvents, unit identity
  // =========================================================================
  test('D3 & D4: updateRateAndReprice and unit identity', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    final p = Product(
      name: 'Multi Unit Product',
      priceCurrency: 'USD',
      referenceSalePrice: 10.0,
      salePrice: 0,
      purchasePrice: 0,
    );
    final units = [
      ProductUnit(
        productId: 0,
        unitName: 'Carton',
        conversionFactor: 12,
        referenceSalePrice: 110.0,
        referenceCurrency: 'USD',
        isDefaultSale: true,
      ),
    ];
    final pId = await db!.saveProductWithUnits(p, units);

    final origUnits = await db!.getProductUnits(pId);
    final origUnit = origUnits.first;
    expect(origUnit.salePrice, 55000.0);

    int catalogEventsCount = 0;
    void listener() => catalogEventsCount++;
    CatalogEvents.pricesChanged.addListener(listener);

    // Same rate -> no-op
    final noOpRes =
        await ReferencePricingService.updateRateAndReprice('USD', 500.0);
    expect(noOpRes.affectedProducts, 0);
    expect(catalogEventsCount, 0);

    // Update rate to 600
    final res =
        await ReferencePricingService.updateRateAndReprice('USD', 600.0);
    expect(res.affectedProducts, 1);
    expect(res.affectedUnits, 1);
    expect(catalogEventsCount, 1);

    final updatedUnits = await db!.getProductUnits(pId);
    final updatedUnit = updatedUnits.first;
    expect(updatedUnit.id, origUnit.id);
    expect(updatedUnit.unitName, origUnit.unitName);
    expect(updatedUnit.conversionFactor, origUnit.conversionFactor);
    expect(updatedUnit.isDefaultSale, origUnit.isDefaultSale);
    expect(updatedUnit.referenceSalePrice, origUnit.referenceSalePrice);
    expect(updatedUnit.referenceCurrency, origUnit.referenceCurrency);
    expect(updatedUnit.salePrice, 66000.0);

    // Verify audit log has the update entry
    final audit = await rawDb.query(
      'audit_log',
      where: 'action = ?',
      whereArgs: ['exchange_rate_updated'],
    );
    expect(audit, isNotEmpty);

    CatalogEvents.pricesChanged.removeListener(listener);
    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D5: Per-field rule
  // =========================================================================
  test('D5: Per-field rule derives only non-null reference prices', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    final pId = await db!.insertProduct(Product(
      name: 'Partial Ref Product',
      priceCurrency: 'USD',
      referenceSalePrice: 10.0,
      salePrice: 0,
      wholesalePrice: 4000.0, // Manual base
      purchasePrice: 3500.0, // Manual base
    ));

    var prod = (await db!.getProductById(pId))!;
    expect(prod.salePrice, 5000.0);
    expect(prod.wholesalePrice, 4000.0);
    expect(prod.purchasePrice, 3500.0);

    // Reprice
    await ReferencePricingService.updateRateAndReprice('USD', 600.0);
    prod = (await db!.getProductById(pId))!;
    expect(prod.salePrice, 6000.0);
    expect(prod.wholesalePrice, 4000.0); // Untouched
    expect(prod.purchasePrice, 3500.0); // Untouched

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D6 & D7: Rollback mid-transaction
  // =========================================================================
  test('D6 & D7: Rollback on failure preserves previous state', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    final pId = await db!.insertProduct(Product(
      name: 'Rollback Product',
      priceCurrency: 'USD',
      referenceSalePrice: 10.0,
      salePrice: 5000.0,
      purchasePrice: 0,
    ));

    // Force invalid rate to trigger exception
    expect(
      () => ReferencePricingService.updateRateAndReprice('USD', -100.0),
      throwsA(isA<ReferencePricingException>()),
    );

    final prod = (await db!.getProductById(pId))!;
    expect(prod.salePrice, 5000.0);

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D8: Re-entrancy guard
  // =========================================================================
  test('D8: Re-entrancy throws repricingInProgress', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    ReferencePricingService.setBusyForTest(true);
    try {
      expect(
        () => ReferencePricingService.updateRateAndReprice('USD', 600.0),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.repricingInProgress)),
      );
      expect(
        () => ReferencePricingService.recalculateAll(),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.repricingInProgress)),
      );
    } finally {
      ReferencePricingService.setBusyForTest(false);
    }

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D9: Latest-rate rule
  // =========================================================================
  test('D9: Stored rate is used at write time', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    final pId = await db!.insertProduct(Product(
      name: 'Latest Rate Product',
      priceCurrency: 'USD',
      referenceSalePrice: 10.0,
      salePrice: 0,
      purchasePrice: 0,
    ));

    // Update stored rate directly
    await ReferencePricingDao.updateRate(rawDb, 'USD', 700.0, DateTime.now());

    // Save product again with same reference price
    final p = (await db!.getProductById(pId))!;
    await db!.updateProduct(p);

    final updated = (await db!.getProductById(pId))!;
    expect(updated.salePrice, 7000.0);

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D10: Implicit clear guard
  // =========================================================================
  test('D10: Implicit clear guard protects reference pricing', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    final pId = await db!.insertProduct(Product(
      name: 'Guarded Product',
      priceCurrency: 'USD',
      referenceSalePrice: 10.0,
      salePrice: 5000.0,
      purchasePrice: 0,
    ));

    // Attempting to save without price_currency without allowClearReferencePricing throws
    final clearedProduct = Product(
      id: pId,
      name: 'Guarded Product',
      salePrice: 5000.0,
      purchasePrice: 0,
    );
    expect(
      () => db!.updateProduct(clearedProduct),
      throwsA(predicate((e) =>
          e is ReferencePricingException &&
          e.code == ReferencePricingError.implicitClear)),
    );

    // With allowClearReferencePricing: true it succeeds
    await db!.saveProductWithUnits(
      clearedProduct,
      [],
      allowClearReferencePricing: true,
    );
    final saved = (await db!.getProductById(pId))!;
    expect(saved.priceCurrency, isNull);
    expect(saved.referenceSalePrice, isNull);
    expect(saved.salePrice, 5000.0);

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D11: Currency change A -> B clears unit references
  // =========================================================================
  test('D11: Currency change clears unit references', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'SAR',
      nameAr: 'ريال سعودي',
      symbol: 'ر.س',
      rate: 140.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    final p = Product(
      name: 'Unit Currency Switch',
      priceCurrency: 'USD',
      referenceSalePrice: 10.0,
      salePrice: 0,
      purchasePrice: 0,
    );
    final units = [
      ProductUnit(
        productId: 0,
        unitName: 'Box',
        conversionFactor: 5,
        referenceSalePrice: 45.0,
        referenceCurrency: 'USD',
      ),
    ];
    final pId = await db!.saveProductWithUnits(p, units);

    // Switch to SAR via updateProduct
    final pUSD = (await db!.getProductById(pId))!;
    final pSAR = pUSD.copyWith(
      priceCurrency: 'SAR',
      referenceSalePrice: 35.0,
    );
    await db!.updateProduct(pSAR);

    final u = (await db!.getProductUnits(pId)).first;
    expect(u.referenceSalePrice, isNull);
    expect(u.referenceCurrency, isNull);
    expect(u.salePrice, 22500.0); // Preserved base price (45 * 500)

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D12: saveProductWithUnits atomicity
  // =========================================================================
  test('D12: saveProductWithUnits atomicity rollback', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    final p = Product(
      name: 'Atomic Product',
      priceCurrency: 'USD',
      referenceSalePrice: 10.0,
      salePrice: 0,
      purchasePrice: 0,
    );
    final badUnits = [
      ProductUnit(
        productId: 0,
        unitName: 'Bad Unit',
        conversionFactor: 0, // Invalid!
      ),
    ];

    expect(
      () => db!.saveProductWithUnits(p, badUnits),
      throwsA(isA<ArgumentError>()),
    );

    // Ensure product was not created
    final prods = await rawDb.query('products');
    expect(prods.where((x) => x['name'] == 'Atomic Product'), isEmpty);

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D13 & D14: Exceptions & Validation
  // =========================================================================
  test('D13 & D14: Service-layer validation and exception codes', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;

    // Rate missing
    expect(
      () => db!.insertProduct(Product(
        name: 'Missing Rate Product',
        priceCurrency: 'GBP',
        referenceSalePrice: 10.0,
        salePrice: 0,
        purchasePrice: 0,
      )),
      throwsA(predicate((e) =>
          e is ReferencePricingException &&
          e.code == ReferencePricingError.rateMissing)),
    );

    // Reference sale price required
    expect(
      () => db!.insertProduct(Product(
        name: 'Missing Sale Price',
        priceCurrency: 'USD',
        salePrice: 0,
        purchasePrice: 0,
      )),
      throwsA(predicate((e) =>
          e is ReferencePricingException &&
          e.code == ReferencePricingError.referencePriceRequired)),
    );

    // Base currency cannot be added as exchange rate
    expect(
      () => ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'YER',
        nameAr: 'ريال يمني',
        symbol: 'ر.ي',
        rate: 1.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      )),
      throwsA(predicate((e) =>
          e is ReferencePricingException &&
          e.code == ReferencePricingError.currencyIsBase)),
    );

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D15: updateBusiness currency change blocked by rates
  // =========================================================================
  test('D15: updateBusiness blocked when exchange rates exist', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    final b = (await db!.getFirstBusiness())!;
    final updated = b.copyWith(currencyCode: 'SAR');

    expect(
      () => db!.updateBusiness(updated),
      throwsA(predicate((e) =>
          e is ReferencePricingException &&
          e.code == ReferencePricingError.baseCurrencyChangeBlocked)),
    );

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D16: Bulk pricing skips reference-driven products
  // =========================================================================
  test('D16: Bulk pricing skips reference-driven products', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    // Product 1: Manual base
    final p1Id = await db!.insertProduct(Product(
      name: 'Manual Product',
      salePrice: 1000.0,
      purchasePrice: 0,
    ));

    // Product 2: Reference USD
    final p2Id = await db!.insertProduct(Product(
      name: 'Ref Product',
      priceCurrency: 'USD',
      referenceSalePrice: 10.0,
      salePrice: 5000.0,
      purchasePrice: 0,
    ));

    final p1 = (await db!.getProductById(p1Id))!;
    final p2 = (await db!.getProductById(p2Id))!;
    final preview = BulkPricingService.instance.preview(
      products: [p1, p2],
      opType: BulkPriceOpType.percentageIncrease,
      opValue: 10.0,
      target: BulkPriceTarget.sellingPrice,
    );

    expect(preview.length, 2);
    final refItem = preview.firstWhere((i) => i.product.id == p2Id);
    expect(refItem.skipSale, isTrue);

    final res = await BulkPricingService.instance.applyBatch(
      items: preview,
      opType: BulkPriceOpType.percentageIncrease,
      opValue: 10.0,
      target: BulkPriceTarget.sellingPrice,
    );
    expect(res.affectedCount, 1);
    expect(res.skippedCount, 1);

    final updatedP1 = (await db!.getProductById(p1Id))!;
    expect(updatedP1.salePrice, 1100.0);

    final updatedP2 = (await db!.getProductById(p2Id))!;
    expect(updatedP2.salePrice, 5000.0); // Skipped!

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D17: CSV import/export
  // =========================================================================
  test('D17: CSV import/export round-trip', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'USD',
      nameAr: 'دولار',
      symbol: '\$',
      rate: 500.0,
      isActive: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    ));

    await db!.insertProduct(Product(
      name: 'CSV Ref Product',
      priceCurrency: 'USD',
      referenceSalePrice: 15.0,
      salePrice: 7500.0,
      purchasePrice: 0,
    ));

    final csvBytes = await CsvService.instance.exportProducts();
    final csvString = utf8.decode(csvBytes);
    expect(csvString.contains('PriceCurrency'), isTrue);
    expect(csvString.contains('ReferenceSalePrice'), isTrue);
    expect(csvString.contains('USD'), isTrue);
    expect(csvString.contains('15'), isTrue);

    final preview = await CsvService.instance.previewImport(csvBytes);
    expect(preview.errorCount, 0);
    expect(preview.rows.length, 1);
    expect(preview.rows.first.priceCurrency, 'USD');

    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D18: Backup and Restore
  // =========================================================================
  test('D18: Backup and Restore preserves exchange_rates', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;
    await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
      code: 'EUR',
      nameAr: 'يورو',
      symbol: '€',
      rate: 580.0,
      isActive: true,
      isCustom: true,
      updatedAt: DateTime.now(),
    ));

    final backupPath = await BackupService.createLocalBackup();
    final jsonStr = await File(backupPath).readAsString();
    final backupData = jsonDecode(jsonStr) as Map<String, dynamic>;
    final data = backupData['data'] as Map<String, dynamic>;
    expect(data.containsKey('exchange_rates'), isTrue);

    // Delete custom currency
    await ReferencePricingDao.deleteCustomIfUnused(rawDb, 'EUR');
    var rates = await ReferencePricingDao.getRates(rawDb);
    expect(rates.where((r) => r.code == 'EUR'), isEmpty);

    // Restore backup
    await BackupService.restoreFromJsonMap(backupData);
    rates = await ReferencePricingDao.getRates(rawDb);
    expect(rates.where((r) => r.code == 'EUR'), isNotEmpty);

    try {
      File(backupPath).deleteSync();
    } catch (_) {}
    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // D19: Invariant Verification (I1..I4)
  // =========================================================================
  test('D19: ReferencePricingDao.verifyInvariants catches violations', () async {
    if (!canRunSqliteFfi) return;
    final rawDb = await db!.database;

    // Verify initially clean
    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);

    // Violate I1: price_currency NOT NULL but reference_sale_price IS NULL
    await rawDb.rawInsert(
      "INSERT INTO products (name, price_currency, reference_sale_price, sale_price, purchase_price, stock_quantity, min_stock, is_taxable, is_active, type, created_at, updated_at) "
      "VALUES ('I1 Bad', 'USD', NULL, 100, 0, 0, 0, 1, 1, 'product', '2026-01-01', '2026-01-01')",
    );
    var violations = await ReferencePricingDao.verifyInvariants(rawDb);
    expect(violations.any((v) => v.startsWith('I1')), isTrue);

    // Repair I1
    await rawDb.execute("DELETE FROM products WHERE name = 'I1 Bad'");
    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);

    // Violate I2: price_currency IS NULL but reference_sale_price NOT NULL
    await rawDb.rawInsert(
      "INSERT INTO products (name, price_currency, reference_sale_price, sale_price, purchase_price, stock_quantity, min_stock, is_taxable, is_active, type, created_at, updated_at) "
      "VALUES ('I2 Bad', NULL, 10.0, 100, 0, 0, 0, 1, 1, 'product', '2026-01-01', '2026-01-01')",
    );
    violations = await ReferencePricingDao.verifyInvariants(rawDb);
    expect(violations.any((v) => v.startsWith('I2')), isTrue);

    // Repair I2
    await rawDb.execute("DELETE FROM products WHERE name = 'I2 Bad'");
    expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
  });

  // =========================================================================
  // T-static: Forbidden Identifiers Scan
  // =========================================================================
  test('T-static: Sales and non-pricing code contains zero forbidden identifiers', () {
    final forbidden = [
      'price_currency',
      'priceCurrency',
      'reference_sale_price',
      'referenceSalePrice',
      'reference_wholesale',
      'referenceWholesale',
      'reference_purchase',
      'referencePurchase',
      'ReferencePricingService',
      'ReferencePricingDao',
      'PricingCurrencySelector',
      'ReferencePriceField',
    ];

    final restrictedFiles = [
      'lib/services/document_service.dart',
      'lib/models/pos_cart.dart',
      'lib/screens/invoice_screen.dart',
      'lib/screens/quotation_screen.dart',
      'lib/screens/purchase_screen.dart',
      'lib/screens/edit_document_screen.dart',
      'lib/screens/custom_document_screen.dart',
      'lib/screens/voucher_screen.dart',
      'lib/widgets/document_item_form.dart',
      'lib/widgets/product_autocomplete_field.dart',
      'lib/screens/inventory_screen.dart',
      'lib/screens/documents_screen.dart',
      'lib/screens/document_detail_screen.dart',
      'lib/services/inventory_costing_service.dart',
    ];

    for (final relPath in restrictedFiles) {
      final file = File(relPath);
      if (!file.existsSync()) continue;
      final content = file.readAsStringSync();
      for (final id in forbidden) {
        expect(
          content.contains(id),
          isFalse,
          reason: 'File $relPath contains forbidden identifier "$id"',
        );
      }
    }

    // Also scan directories: accounting, pdf, reports
    final restrictedDirs = [
      'lib/services/accounting',
      'lib/services/pdf',
      'lib/screens/reports',
    ];

    for (final dirPath in restrictedDirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          for (final id in forbidden) {
            expect(
              content.contains(id),
              isFalse,
              reason: 'File ${entity.path} contains forbidden identifier "$id"',
            );
          }
        }
      }
    }
  });
}
