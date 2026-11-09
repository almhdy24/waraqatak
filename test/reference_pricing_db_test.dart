import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/core/catalog_events.dart';
import 'package:warqatek/core/feature_gate.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/database/reference_pricing_dao.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/exchange_rate.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/product_unit.dart';
import 'package:warqatek/models/reference_pricing_types.dart';
import 'package:warqatek/services/backup_encryption_service.dart';
import 'package:warqatek/services/backup_service.dart';
import 'package:warqatek/services/bulk_pricing_service.dart';
import 'package:warqatek/services/csv_service.dart';
import 'package:warqatek/services/google_drive_backup_service.dart';
import 'package:warqatek/services/reference_pricing_service.dart';

class _FakeGoogleDriveClient implements GoogleDriveClient {
  final Map<String, Uint8List> storage;
  _FakeGoogleDriveClient(this.storage);

  @override
  Future<bool> signIn() async => true;

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> isSignedIn() async => true;

  @override
  String? get currentUserEmail => 'test@example.com';

  @override
  Future<List<DriveBackupFile>> listBackups() async => [];

  @override
  Future<DriveBackupFile> uploadBackup({
    required Uint8List bytes,
    required String fileName,
  }) async {
    const id = 'drive_v25_file';
    storage[id] = bytes;
    return DriveBackupFile(
      id: id,
      name: fileName,
      sizeBytes: bytes.length,
      modifiedTime: DateTime.now(),
    );
  }

  @override
  Future<Uint8List> downloadBackup(String fileId) async {
    final bytes = storage[fileId];
    if (bytes == null) throw Exception('File not found: $fileId');
    return bytes;
  }

  @override
  Future<void> deleteBackup(String fileId) async {
    storage.remove(fileId);
  }
}

String? _detectSqliteSkip() {
  try {
    sqfliteFfiInit();
    if (Platform.isLinux) {
      final nativeAsset = File('build/native_assets/linux/libsqlite3.so');
      if (nativeAsset.existsSync()) {
        DynamicLibrary.open(nativeAsset.path);
      } else {
        DynamicLibrary.open('libsqlite3.so');
      }
    }
    return null;
  } catch (e) {
    return 'Native SQLite unavailable: $e';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sqliteSkipReason = _detectSqliteSkip();

  group('Reference Pricing Database Tests', () {
    late Directory tempDir;
    late DatabaseHelper db;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tempDir = Directory.systemTemp.createTempSync('ref_pricing_db_test');
      await databaseFactory.setDatabasesPath(tempDir.path);
      db = DatabaseHelper.instance;
    });

    tearDownAll(() async {
      FeatureGate.resetForTesting();
      await db.closeDatabase();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    setUp(() async {
      FeatureGate.setOverrideForTesting(true);
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
      final rawDb = await db.database;
      final tables = await rawDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='exchange_rates'",
      );
      expect(tables, isNotEmpty);

      final prodCols = await rawDb.rawQuery("PRAGMA table_info(products)");
      final prodColNames = prodCols.map((c) => c['name'] as String).toSet();
      expect(prodColNames.contains('price_currency'), isTrue);
      expect(prodColNames.contains('reference_sale_price'), isTrue);
      expect(prodColNames.contains('reference_wholesale_price'), isTrue);
      expect(prodColNames.contains('reference_purchase_price'), isTrue);

      final unitCols = await rawDb.rawQuery("PRAGMA table_info(product_units)");
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
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار أمريكي',
        symbol: '\$',
        rate: 1000.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      final pId = await db.insertProduct(const Product(
        name: 'Accumulation Test Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.5,
        salePrice: 0,
        purchasePrice: 0,
      ));

      var prod = (await db.getProductById(pId))!;
      expect(prod.salePrice, 10500.0);

      // Reprice to 1100
      await ReferencePricingService.updateRateAndReprice('USD', 1100.0);
      prod = (await db.getProductById(pId))!;
      expect(prod.salePrice, 11550.0);

      // Reprice back to 1000
      await ReferencePricingService.updateRateAndReprice('USD', 1000.0);
      prod = (await db.getProductById(pId))!;
      expect(prod.salePrice, 10500.0);

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D3: updateRateAndReprice base repricing, audit, CatalogEvents
    // =========================================================================
    test('D3: updateRateAndReprice reprices base prices of all products and units in currency, writes audit log, notifies CatalogEvents', () async {
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      const p = Product(
        name: 'Multi Unit Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.0,
        salePrice: 0,
        purchasePrice: 0,
      );
      final units = [
        const ProductUnit(
          productId: 0,
          unitName: 'Carton',
          conversionFactor: 12,
          referenceSalePrice: 110.0,
          referenceCurrency: 'USD',
          isDefaultSale: true,
        ),
      ];
      final pId = await db.saveProductWithUnits(p, units);

      final origUnits = await db.getProductUnits(pId);
      expect(origUnits.first.salePrice, 55000.0);

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

      final updatedUnits = await db.getProductUnits(pId);
      expect(updatedUnits.first.salePrice, 66000.0);

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
    // D4: Unit identity and conversion factors preserved
    // =========================================================================
    test('D4: Unit identity, non-reference units, and conversion factors preserved during updateRateAndReprice', () async {
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      const p = Product(
        name: 'Unit Identity Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.0,
        salePrice: 0,
        purchasePrice: 0,
      );
      final units = [
        const ProductUnit(
          productId: 0,
          unitName: 'Carton',
          conversionFactor: 12,
          referenceSalePrice: 110.0,
          referenceCurrency: 'USD',
          isDefaultSale: true,
        ),
        const ProductUnit(
          productId: 0,
          unitName: 'Fixed Base Unit',
          conversionFactor: 6,
          salePrice: 25000.0, // Manual base currency unit
          isDefaultSale: false,
        ),
      ];
      final pId = await db.saveProductWithUnits(p, units);

      final origUnits = await db.getProductUnits(pId);
      final origRefUnit = origUnits.firstWhere((u) => u.unitName == 'Carton');
      final origBaseUnit = origUnits.firstWhere((u) => u.unitName == 'Fixed Base Unit');

      // Update rate
      await ReferencePricingService.updateRateAndReprice('USD', 600.0);

      final updatedUnits = await db.getProductUnits(pId);
      final updatedRefUnit = updatedUnits.firstWhere((u) => u.unitName == 'Carton');
      final updatedBaseUnit = updatedUnits.firstWhere((u) => u.unitName == 'Fixed Base Unit');

      // Assert unit identity and metadata intact
      expect(updatedRefUnit.id, origRefUnit.id);
      expect(updatedRefUnit.conversionFactor, 12);
      expect(updatedRefUnit.salePrice, 66000.0); // Repriced: 110 * 600

      // Non-reference unit preserved untouched
      expect(updatedBaseUnit.id, origBaseUnit.id);
      expect(updatedBaseUnit.conversionFactor, 6);
      expect(updatedBaseUnit.salePrice, 25000.0); // Untouched
      expect(updatedBaseUnit.referenceCurrency, isNull);

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D5: Per-field rule
    // =========================================================================
    test('D5: Per-field rule derives only non-null reference prices', () async {
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      final pId = await db.insertProduct(const Product(
        name: 'Partial Ref Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.0,
        salePrice: 0,
        wholesalePrice: 4000.0, // Manual base
        purchasePrice: 3500.0, // Manual base
      ));

      var prod = (await db.getProductById(pId))!;
      expect(prod.salePrice, 5000.0);
      expect(prod.wholesalePrice, 4000.0);
      expect(prod.purchasePrice, 3500.0);

      // Reprice
      await ReferencePricingService.updateRateAndReprice('USD', 600.0);
      prod = (await db.getProductById(pId))!;
      expect(prod.salePrice, 6000.0);
      expect(prod.wholesalePrice, 4000.0); // Untouched
      expect(prod.purchasePrice, 3500.0); // Untouched

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D6: Rollback preserves exchange rate
    // =========================================================================
    test('D6: Rollback on rate update failure preserves previous rate', () async {
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      expect(
        () => ReferencePricingService.updateRateAndReprice('USD', -100.0),
        throwsA(isA<ReferencePricingException>()),
      );

      final rateRow = await ReferencePricingDao.getRate(rawDb, 'USD');
      expect(rateRow?.rate, 500.0);

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D7: Rollback preserves product/unit base prices
    // =========================================================================
    test('D7: Rollback on rate update failure leaves product and unit prices completely unchanged', () async {
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      final pId = await db.insertProduct(const Product(
        name: 'Rollback Base Price Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.0,
        salePrice: 5000.0,
        purchasePrice: 0,
      ));

      expect(
        () => ReferencePricingService.updateRateAndReprice('USD', -1.0),
        throwsA(isA<ReferencePricingException>()),
      );

      final prod = (await db.getProductById(pId))!;
      expect(prod.salePrice, 5000.0);

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D8: Re-entrancy guard
    // =========================================================================
    test('D8: Re-entrancy throws repricingInProgress', () async {
      final rawDb = await db.database;
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
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 530.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      final pId = await db.insertProduct(const Product(
        name: 'Stale Rate Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.0,
        salePrice: 5000.0, // Stale base
        purchasePrice: 0,
      ));

      final prod = (await db.getProductById(pId))!;
      expect(prod.salePrice, 5300.0); // 10.0 * 530.0

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D10: Implicit-clear guard
    // =========================================================================
    test('D10: Implicit clear guard protects reference pricing', () async {
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      final pId = await db.insertProduct(const Product(
        name: 'Guard Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.0,
        salePrice: 0,
        purchasePrice: 0,
      ));

      final p = (await db.getProductById(pId))!;
      final updatedP = p.copyWith(
        name: 'Guard Product Updated',
        salePrice: 5000.0,
      );

      final count = await db.updateProduct(updatedP);
      expect(count, 1);

      final reloaded = (await db.getProductById(pId))!;
      expect(reloaded.priceCurrency, 'USD');
      expect(reloaded.referenceSalePrice, 10.0);

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D11: Changing product currency clears unit references
    // =========================================================================
    test('D11: Currency change clears unit references', () async {
      final rawDb = await db.database;
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

      const p = Product(
        name: 'Currency Shift Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.0,
        salePrice: 0,
        purchasePrice: 0,
      );
      final units = [
        const ProductUnit(
          productId: 0,
          unitName: 'Carton',
          conversionFactor: 12,
          referenceSalePrice: 110.0,
          referenceCurrency: 'USD',
          isDefaultSale: true,
        ),
      ];
      final pId = await db.saveProductWithUnits(p, units);

      final pSar = (await db.getProductById(pId))!.copyWith(
        priceCurrency: 'SAR',
        referenceSalePrice: 35.0,
      );
      await db.saveProductWithUnits(pSar, units);

      final updatedUnits = await db.getProductUnits(pId);
      final u = updatedUnits.first;
      expect(u.referenceCurrency, isNull);
      expect(u.referenceSalePrice, isNull);

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D12: saveProductWithUnits atomicity
    // =========================================================================
    test('D12: saveProductWithUnits atomicity rollback', () async {
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      const p = Product(
        name: 'Atomic Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.0,
        salePrice: 0,
        purchasePrice: 0,
      );
      final badUnits = [
        const ProductUnit(
          productId: 0,
          unitName: 'Bad Unit',
          conversionFactor: 0, // Invalid conversion factor
        ),
      ];

      expect(
        () => db.saveProductWithUnits(p, badUnits),
        throwsA(isA<ArgumentError>()),
      );

      final prods = await rawDb.query('products');
      expect(prods.where((x) => x['name'] == 'Atomic Product'), isEmpty);

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D13: Service-layer validation rejects invalid inputs
    // =========================================================================
    test('D13: Service-layer validation rejects invalid rates and reference prices', () async {
      final rawDb = await db.database;

      // Rate missing
      expect(
        () => db.insertProduct(const Product(
          name: 'Missing Rate Product',
          priceCurrency: 'GBP',
          referenceSalePrice: 10.0,
          salePrice: 0,
          purchasePrice: 0,
        )),
        throwsA(isA<ReferencePricingException>()),
      );

      // Inactive currency rate
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'EUR',
        nameAr: 'يورو',
        symbol: '€',
        rate: 550.0,
        isActive: false,
        isCustom: true,
        updatedAt: DateTime.now(),
      ));
      expect(
        () => db.insertProduct(const Product(
          name: 'Inactive Rate Product',
          priceCurrency: 'EUR',
          referenceSalePrice: 10.0,
          salePrice: 0,
          purchasePrice: 0,
        )),
        throwsA(isA<ReferencePricingException>()),
      );

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D14: Exception codes verified
    // =========================================================================
    test('D14: Specific ReferencePricingError exception codes thrown for all failure modes', () async {
      final rawDb = await db.database;

      // Assert rateMissing code
      expect(
        () => db.insertProduct(const Product(
          name: 'Missing Code Product',
          priceCurrency: 'GBP',
          referenceSalePrice: 10.0,
          salePrice: 0,
          purchasePrice: 0,
        )),
        throwsA(predicate((e) =>
            e is ReferencePricingException &&
            e.code == ReferencePricingError.rateMissing)),
      );

      // Assert currencyIsBase code
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
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      final biz = (await db.getFirstBusiness())!;
      final newBiz = biz.copyWith(currencyCode: 'SAR');

      expect(
        () => db.updateBusiness(newBiz),
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
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      // Regular product
      final p1Id = await db.insertProduct(const Product(
        name: 'Manual Product',
        salePrice: 1000.0,
        purchasePrice: 800.0,
      ));

      // Reference-driven product
      final p2Id = await db.insertProduct(const Product(
        name: 'Ref Product',
        priceCurrency: 'USD',
        referenceSalePrice: 10.0,
        salePrice: 5000.0,
        purchasePrice: 0,
      ));

      final p1 = (await db.getProductById(p1Id))!;
      final p2 = (await db.getProductById(p2Id))!;
      final preview = BulkPricingService.instance.preview(
        products: [p1, p2],
        opType: BulkPriceOpType.percentageIncrease,
        opValue: 10.0,
        target: BulkPriceTarget.sellingPrice,
      );

      expect(preview.length, 2);
      final refItem = preview.firstWhere((i) => i.product.id == p2Id);
      expect(refItem.skipSale, isTrue);

      await BulkPricingService.instance.applyBatch(
        items: preview,
        opType: BulkPriceOpType.percentageIncrease,
        opValue: 10.0,
        target: BulkPriceTarget.sellingPrice,
      );

      final updatedP1 = (await db.getProductById(p1Id))!;
      expect(updatedP1.salePrice, 1100.0);

      final updatedP2 = (await db.getProductById(p2Id))!;
      expect(updatedP2.salePrice, 5000.0); // Skipped

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D17: CSV import/export
    // =========================================================================
    test('D17: CSV import/export round-trip', () async {
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      await db.insertProduct(const Product(
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

    test('D17b: CSV export hides reference pricing for non-Pro users',
        () async {
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));
      await db.insertProduct(const Product(
        name: 'CSV Free Product',
        priceCurrency: 'USD',
        referenceSalePrice: 15.0,
        salePrice: 7500.0,
        purchasePrice: 0,
      ));

      FeatureGate.setOverrideForTesting(false);
      try {
        final csvString = utf8.decode(await CsvService.instance.exportProducts());
        expect(csvString.contains('CSV Free Product'), isTrue);
        expect(csvString.contains('USD'), isFalse);
      } finally {
        FeatureGate.setOverrideForTesting(true);
      }
    });

    // =========================================================================
    // D18: Backup and Restore
    // =========================================================================
    test('D18: Backup and Restore preserves exchange_rates', () async {
      final rawDb = await db.database;
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
      final rawDb = await db.database;

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
    // D20: Performance Benchmark (5,000 products with 2 units each)
    // =========================================================================
    test('D20 (Benchmark): 5,000 products with 2 units each in one currency', () async {
      final rawDb = await db.database;
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));

      await rawDb.transaction((txn) async {
        final batch = txn.batch();
        for (int i = 1; i <= 5000; i++) {
          batch.rawInsert(
            "INSERT INTO products (id, name, price_currency, reference_sale_price, reference_wholesale_price, reference_purchase_price, sale_price, wholesale_price, purchase_price, stock_quantity, min_stock, is_taxable, is_active, type, created_at, updated_at) "
            "VALUES (?, ?, 'USD', 10.0, 8.0, 6.0, 5000.0, 4000.0, 3000.0, 100, 10, 1, 1, 'product', '2026-01-01', '2026-01-01')",
            [i, 'Benchmark Product $i'],
          );
          batch.rawInsert(
            "INSERT INTO product_units (id, product_id, unit_name, conversion_factor, reference_currency, reference_sale_price, reference_wholesale_price, sale_price, wholesale_price) "
            "VALUES (?, ?, 'Box', 12.0, 'USD', 110.0, 90.0, 55000.0, 45000.0)",
            [i * 2 - 1, i],
          );
          batch.rawInsert(
            "INSERT INTO product_units (id, product_id, unit_name, conversion_factor, reference_currency, reference_sale_price, reference_wholesale_price, sale_price, wholesale_price) "
            "VALUES (?, ?, 'Carton', 120.0, 'USD', 1000.0, 800.0, 500000.0, 400000.0)",
            [i * 2, i],
          );
        }
        await batch.commit(noResult: true);
      });

      final swReprice = Stopwatch()..start();
      final repriceResult = await ReferencePricingService.updateRateAndReprice('USD', 525.0);
      swReprice.stop();
      // ignore: avoid_print
      print('BENCHMARK_MEASURED_MS updateRateAndReprice: ${swReprice.elapsedMilliseconds} ms');
      expect(repriceResult.affectedProducts, 5000);
      expect(repriceResult.affectedUnits, 10000);

      final swRecalc = Stopwatch()..start();
      final recalcResult = await ReferencePricingService.recalculateAll();
      swRecalc.stop();
      // ignore: avoid_print
      print('BENCHMARK_MEASURED_MS recalculateAll: ${swRecalc.elapsedMilliseconds} ms');
      expect(recalcResult.affectedProducts, 5000);
      expect(recalcResult.affectedUnits, 10000);

      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });

    // =========================================================================
    // D21: Backup Compatibility (v25 Payload Without exchange_rates and New Columns)
    // =========================================================================
    test('D21 (Backup Legacy Compatibility): Restore v25 payload without exchange_rates and reference columns through local, encrypted, and drive paths', () async {
      final rawDb = await db.database;

      final legacyV25Payload = {
        'app': 'warqatek',
        'backup_version': 2,
        'database_version': 25,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'data': {
          'businesses': [
            {
              'id': 1,
              'name': 'Legacy Business',
              'owner_name': 'Owner',
              'phone': '123',
              'address': 'Sana\'a',
              'currency_code': 'YER',
              'wholesale_pricing_enabled': 1,
            }
          ],
          'contacts': [],
          'products': [
            {
              'id': 1,
              'name': 'Legacy Item',
              'sale_price': 1500.0,
              'wholesale_price': 1200.0,
              'purchase_price': 1000.0,
              'stock_quantity': 50.0,
              'min_stock': 5.0,
              'is_taxable': 1,
              'is_active': 1,
              'type': 'product',
              'created_at': '2026-01-01T00:00:00.000',
              'updated_at': '2026-01-01T00:00:00.000',
              // 4 columns omitted: price_currency, reference_sale_price, reference_wholesale_price, reference_purchase_price
            }
          ],
          'product_units': [
            {
              'id': 1,
              'product_id': 1,
              'unit_name': 'Dozen',
              'conversion_factor': 12.0,
              'sale_price': 18000.0,
              'wholesale_price': 14400.0,
              // 3 columns omitted: reference_currency, reference_sale_price, reference_wholesale_price
            }
          ],
          'documents': [],
          'document_items': [],
          'document_counters': [],
          'document_payments': [],
          'stock_movements': [],
          'tax_profiles': [],
          'payment_methods': [],
          'stocktake_sessions': [],
          'stocktake_items': [],
          'audit_log': [],
          'accounts': [],
          'journal_entries': [],
          'journal_lines': [],
          'app_settings': [],
          // exchange_rates key completely omitted
        },
        'assets': {'logo_base64': null},
      };

      // 0. Seed rates before restore to verify they get deleted by restore
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));
      var existingRates = await ReferencePricingDao.getRates(rawDb);
      expect(existingRates, isNotEmpty);

      // 1. Path: Local Unencrypted Restoration
      final jsonStr = jsonEncode(legacyV25Payload);
      final decodedJson = jsonDecode(jsonStr) as Map<String, dynamic>;
      final localSuccess = await BackupService.restoreFromJsonMap(decodedJson, createSafetyBackup: false);
      expect(localSuccess, isTrue);

      var restoredProd = (await db.getProductById(1))!;
      expect(restoredProd.priceCurrency, isNull);
      expect(restoredProd.referenceSalePrice, isNull);

      var restoredUnits = await db.getProductUnits(1);
      expect(restoredUnits.first.referenceCurrency, isNull);
      expect(restoredUnits.first.referenceSalePrice, isNull);
      // Assert exchange_rates is wiped and empty
      var ratesAfterRestore = await ReferencePricingDao.getRates(rawDb);
      expect(ratesAfterRestore, isEmpty);
      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);

      // Re-seed rate to test deletion on encrypted path
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));
      expect(await ReferencePricingDao.getRates(rawDb), isNotEmpty);

      // 2. Path: Local Encrypted Restoration
      final encryptedBytes = await BackupEncryptionService.encryptJson(jsonStr: jsonStr, password: 'P@ssword123');
      final decryptedStr = await BackupEncryptionService.decryptJson(encryptedBytes: encryptedBytes, password: 'P@ssword123');
      final encDecoded = jsonDecode(decryptedStr) as Map<String, dynamic>;
      final encSuccess = await BackupService.restoreFromJsonMap(encDecoded, createSafetyBackup: false);
      expect(encSuccess, isTrue);

      restoredProd = (await db.getProductById(1))!;
      expect(restoredProd.priceCurrency, isNull);
      ratesAfterRestore = await ReferencePricingDao.getRates(rawDb);
      expect(ratesAfterRestore, isEmpty);
      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);

      // Re-seed rate to test deletion on Drive path
      await ReferencePricingService.addCurrencyWithRate(ExchangeRate(
        code: 'USD',
        nameAr: 'دولار',
        symbol: '\$',
        rate: 500.0,
        isActive: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      ));
      expect(await ReferencePricingDao.getRates(rawDb), isNotEmpty);

      // 3. Path: Drive Cloud restoreFromDrive exact path
      TestWidgetsFlutterBinding.ensureInitialized();
      const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
      final driveTempDir = Directory.systemTemp.createTempSync('ref_pricing_drive_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        pathProviderChannel,
        (MethodCall methodCall) async => driveTempDir.path,
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProviderChannel, null);
        try {
          if (driveTempDir.existsSync()) {
            driveTempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      });

      final driveStorage = <String, Uint8List>{
        'v25_cloud_file': Uint8List.fromList(utf8.encode(jsonStr)),
      };
      final fakeDrive = _FakeGoogleDriveClient(driveStorage);
      GoogleDriveBackupService.instance.setClientForTesting(fakeDrive);

      final driveSuccess = await GoogleDriveBackupService.instance.restoreFromDrive(
        DriveBackupFile(
          id: 'v25_cloud_file',
          name: 'cloud_v25.waraq',
          sizeBytes: driveStorage['v25_cloud_file']!.length,
          modifiedTime: DateTime.now(),
        ),
      );
      expect(driveSuccess, isTrue);

      restoredProd = (await db.getProductById(1))!;
      expect(restoredProd.priceCurrency, isNull);
      restoredUnits = await db.getProductUnits(1);
      expect(restoredUnits.first.referenceCurrency, isNull);
      ratesAfterRestore = await ReferencePricingDao.getRates(rawDb);
      expect(ratesAfterRestore, isEmpty);
      expect(await ReferencePricingDao.verifyInvariants(rawDb), isEmpty);
    });
  }, skip: sqliteSkipReason ?? false);

  // =========================================================================
  // Static Guard Tests (Run Everywhere Unconditionally)
  // =========================================================================
  group('Reference Pricing Static Guard Tests', () {
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

    test('T-static (1): Sales and non-pricing code contains zero forbidden identifiers', () {
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
    });

    test('T-static (2): Restricted directories (accounting, pdf, reports) contain zero forbidden identifiers', () {
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
  });
}
