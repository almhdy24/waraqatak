/// Data Access Object for reference-currency exchange rates and pricing operations.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../models/currency.dart';
import '../models/exchange_rate.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../models/reference_pricing_types.dart';
import '../services/access/access_guard.dart';
import '../services/access/permission_registry.dart';
import '../utils/reference_pricing_math.dart';

/// Static, transaction-aware DAO for reference pricing and exchange rates.
///
/// Invariants enforced by this layer:
/// - **I1:** `products.price_currency NOT NULL` => `products.reference_sale_price NOT NULL`.
/// - **I2:** `products.price_currency NULL` => all 3 `products.reference_*` are NULL AND
///   every unit of the product has `reference_sale_price`, `reference_wholesale_price`,
///   and `reference_currency` NULL.
/// - **I3:** A unit with any non-null reference price must have `reference_currency == its product's price_currency`;
///   a unit with no reference price must have `reference_currency NULL`.
/// - **I4:** Every `products.price_currency` has a corresponding row in `exchange_rates`;
///   every stored exchange rate satisfies [ReferencePricingMath.isValidRate].
abstract final class ReferencePricingDao {
  /// Fetches exchange rate records, optionally filtering to [activeOnly].
  ///
  /// Ordered by `is_active DESC, name_ar ASC`.
  static Future<List<ExchangeRate>> getRates(
    DatabaseExecutor ex, {
    bool activeOnly = false,
  }) async {
    final rows = await ex.query(
      'exchange_rates',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'is_active DESC, name_ar ASC',
    );
    return rows.map((r) => ExchangeRate.fromMap(r)).toList();
  }

  /// Fetches a single exchange rate by currency [code], or returns null if not found.
  static Future<ExchangeRate?> getRate(DatabaseExecutor ex, String code) async {
    final rows = await ex.query(
      'exchange_rates',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExchangeRate.fromMap(rows.first);
  }

  /// Returns true if at least one exchange rate is registered in the database.
  static Future<bool> hasAnyRate(DatabaseExecutor ex) async {
    final rows = await ex.rawQuery('SELECT 1 FROM exchange_rates LIMIT 1');
    return rows.isNotEmpty;
  }

  /// Returns true if base currency changes should be blocked.
  ///
  /// Blocked when any exchange_rates row exists or any product has a non-null price_currency.
  static Future<bool> blocksBaseCurrencyChange(DatabaseExecutor ex) async {
    final rateRows = await ex.rawQuery('SELECT 1 FROM exchange_rates LIMIT 1');
    if (rateRows.isNotEmpty) return true;
    final prodRows = await ex.rawQuery(
      'SELECT 1 FROM products WHERE price_currency IS NOT NULL LIMIT 1',
    );
    return prodRows.isNotEmpty;
  }

  /// Returns the base currency code of the business.
  ///
  /// Throws [ReferencePricingException] with [ReferencePricingError.businessNotConfigured]
  /// if no business record exists. Defaults to 'SDG' if column is null/empty.
  static Future<String> businessCurrencyCode(DatabaseExecutor ex) async {
    final rows = await ex.rawQuery(
      'SELECT currency_code FROM businesses LIMIT 1',
    );
    if (rows.isEmpty) {
      throw const ReferencePricingException(
        ReferencePricingError.businessNotConfigured,
        'Business settings are not configured',
      );
    }
    final code = rows.first['currency_code'] as String?;
    if (code == null || code.trim().isEmpty) {
      return 'SDG';
    }
    return code.trim();
  }

  /// Inserts a new exchange rate row into `exchange_rates`.
  ///
  /// Validates [ExchangeRate.rate]. Throws [ReferencePricingException] if currency is the
  /// business base currency or already exists.
  static Future<void> insertRate(DatabaseExecutor txn, ExchangeRate e) async {
    AccessGuard.require(PermissionRegistry.pricingRates);
    ReferencePricingMath.assertValidRate(e.rate);
    final baseCode = await businessCurrencyCode(txn);
    if (e.code == baseCode) {
      throw const ReferencePricingException(
        ReferencePricingError.currencyIsBase,
        'Cannot add base currency as a reference currency',
      );
    }
    final existing = await getRate(txn, e.code);
    if (existing != null) {
      throw const ReferencePricingException(
        ReferencePricingError.currencyExists,
        'Currency already exists',
      );
    }
    await txn.insert('exchange_rates', e.toMap());
  }

  /// Updates an existing exchange rate row's rate and modification timestamp.
  ///
  /// Throws [ReferencePricingException] with [ReferencePricingError.currencyNotFound]
  /// if the currency row does not exist.
  static Future<void> updateRate(
    DatabaseExecutor txn,
    String code,
    double rate,
    DateTime updatedAt,
  ) async {
    AccessGuard.require(PermissionRegistry.pricingRates);
    ReferencePricingMath.assertValidRate(rate);
    final count = await txn.rawUpdate(
      'UPDATE exchange_rates SET rate = ?, updated_at = ? WHERE code = ?',
      [rate, updatedAt.toIso8601String(), code],
    );
    if (count == 0) {
      throw const ReferencePricingException(
        ReferencePricingError.currencyNotFound,
        'Exchange rate not found for update',
      );
    }
  }

  /// Sets the active status of an exchange rate currency.
  ///
  /// Throws [ReferencePricingException] with [ReferencePricingError.currencyNotFound]
  /// if missing.
  static Future<void> setActive(
    DatabaseExecutor txn,
    String code,
    bool active,
  ) async {
    AccessGuard.require(PermissionRegistry.pricingRates);
    final count = await txn.rawUpdate(
      'UPDATE exchange_rates SET is_active = ? WHERE code = ?',
      [active ? 1 : 0, code],
    );
    if (count == 0) {
      throw const ReferencePricingException(
        ReferencePricingError.currencyNotFound,
        'Exchange rate not found',
      );
    }
  }

  /// Deletes a custom exchange rate row if it is not used by any product.
  ///
  /// Returns true if deleted, false if not custom, not found, or in use.
  static Future<bool> deleteCustomIfUnused(
    DatabaseExecutor txn,
    String code,
  ) async {
    final rate = await getRate(txn, code);
    if (rate == null || !rate.isCustom) return false;

    final usedRows = await txn.rawQuery(
      'SELECT 1 FROM products WHERE price_currency = ? LIMIT 1',
      [code],
    );
    if (usedRows.isNotEmpty) return false;

    final count = await txn.delete(
      'exchange_rates',
      where: 'code = ?',
      whereArgs: [code],
    );
    return count > 0;
  }

  /// Reads the configured reference price rounding step from `app_settings`.
  static Future<int> readRounding(DatabaseExecutor ex) async {
    final rows = await ex.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['reference_price_rounding'],
      limit: 1,
    );
    if (rows.isEmpty) return ReferencePricingMath.defaultRounding;
    return ReferencePricingMath.parseRounding(rows.first['value'] as String?);
  }

  /// Writes the reference price rounding step to `app_settings`.
  static Future<void> writeRounding(DatabaseExecutor txn, int rounding) async {
    if (!ReferencePricingMath.allowedRounding.contains(rounding)) {
      throw ArgumentError('Invalid rounding value: $rounding');
    }
    await txn.rawInsert(
      'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
      ['reference_price_rounding', rounding.toString()],
    );
  }

  /// Asserts that currency [code] is assignable to a product.
  ///
  /// Re-validates within transaction that the rate row exists, is valid, differs from
  /// base currency, and is active (unless it matches [currentCurrency] of the product).
  static Future<void> assertAssignable(
    DatabaseExecutor ex,
    String code, {
    String? currentCurrency,
  }) async {
    final baseCode = await businessCurrencyCode(ex);
    if (code == baseCode) {
      throw const ReferencePricingException(
        ReferencePricingError.currencyIsBase,
        'Pricing currency cannot be base currency',
      );
    }
    final rateRow = await getRate(ex, code);
    if (rateRow == null || !ReferencePricingMath.isValidRate(rateRow.rate)) {
      throw const ReferencePricingException(
        ReferencePricingError.rateMissing,
        'Exchange rate is missing or invalid',
      );
    }
    if (!rateRow.isActive && code != currentCurrency) {
      throw const ReferencePricingException(
        ReferencePricingError.currencyArchived,
        'Currency is archived and cannot be newly assigned',
      );
    }
  }

  /// Computes base-currency prices from reference prices using the stored rate and rounding.
  ///
  /// This is the authoritative single conversion path for products, units, CSV, and repricing.
  static Future<DerivedPrices> computeDerivedPrices(
    DatabaseExecutor ex, {
    required String currencyCode,
    double? referenceSale,
    double? referenceWholesale,
    double? referencePurchase,
  }) async {
    final rateRow = await getRate(ex, currencyCode);
    if (rateRow == null || !ReferencePricingMath.isValidRate(rateRow.rate)) {
      throw const ReferencePricingException(
        ReferencePricingError.rateMissing,
        'Exchange rate missing or invalid for price calculation',
      );
    }
    final rounding = await readRounding(ex);
    final baseCode = await businessCurrencyCode(ex);
    final baseDecimals = Currency.decimalDigitsForCode(baseCode);

    final derivedSale = referenceSale != null
        ? ReferencePricingMath.convert(
            reference: referenceSale,
            rate: rateRow.rate,
            rounding: rounding,
            baseDecimals: baseDecimals,
          )
        : null;

    final derivedWholesale = referenceWholesale != null
        ? ReferencePricingMath.convert(
            reference: referenceWholesale,
            rate: rateRow.rate,
            rounding: rounding,
            baseDecimals: baseDecimals,
          )
        : null;

    final derivedPurchase = referencePurchase != null
        ? ReferencePricingMath.convert(
            reference: referencePurchase,
            rate: rateRow.rate,
            rounding: rounding,
            baseDecimals: baseDecimals,
          )
        : null;

    return DerivedPrices(
      sale: derivedSale,
      wholesale: derivedWholesale,
      purchase: derivedPurchase,
    );
  }

  /// Derives base-currency prices and sets metadata on a [Product] prior to insert/update.
  ///
  /// Clears reference fields if [p.priceCurrency] is null. Validates and converts
  /// reference values using the authoritative stored exchange rate and rounding settings.
  static Future<Product> deriveProduct(
    DatabaseExecutor txn,
    Product p, {
    String? previousCurrency,
  }) async {
    if (p.priceCurrency == null) {
      return p.copyWith(
        clearPriceCurrency: true,
        clearReferenceSalePrice: true,
        clearReferenceWholesalePrice: true,
        clearReferencePurchasePrice: true,
      );
    }
    if (p.referenceSalePrice == null) {
      throw const ReferencePricingException(
        ReferencePricingError.referencePriceRequired,
        'Reference sale price is required when price currency is set',
      );
    }
    await assertAssignable(
      txn,
      p.priceCurrency!,
      currentCurrency: previousCurrency,
    );
    final d = await computeDerivedPrices(
      txn,
      currencyCode: p.priceCurrency!,
      referenceSale: p.referenceSalePrice,
      referenceWholesale: p.referenceWholesalePrice,
      referencePurchase: p.referencePurchasePrice,
    );
    return p.copyWith(
      salePrice: d.sale!,
      wholesalePrice: d.wholesale ?? p.wholesalePrice,
      purchasePrice: d.purchase ?? p.purchasePrice,
    );
  }

  /// Normalizes a [ProductUnit] prior to insert/update based on parent product's [productCurrency].
  ///
  /// Clears stale or invalid reference prices while preserving base-currency prices.
  static Future<ProductUnit> normalizeUnit(
    DatabaseExecutor txn, {
    required String? productCurrency,
    required ProductUnit unit,
  }) async {
    if (productCurrency == null) {
      return unit.copyWith(
        clearReferenceSalePrice: true,
        clearReferenceWholesalePrice: true,
        clearReferenceCurrency: true,
      );
    }
    if (!unit.hasReferencePrices) {
      return unit.copyWith(clearReferenceCurrency: true);
    }
    if (unit.referenceCurrency != productCurrency) {
      return unit.copyWith(
        clearReferenceSalePrice: true,
        clearReferenceWholesalePrice: true,
        clearReferenceCurrency: true,
      );
    }
    final d = await computeDerivedPrices(
      txn,
      currencyCode: productCurrency,
      referenceSale: unit.referenceSalePrice,
      referenceWholesale: unit.referenceWholesalePrice,
    );
    return unit.copyWith(
      salePrice: d.sale ?? unit.salePrice,
      wholesalePrice: d.wholesale ?? unit.wholesalePrice,
      referenceCurrency: productCurrency,
    );
  }

  /// Clears all unit reference fields for a given product ID while keeping base prices intact.
  static Future<void> clearUnitReferences(
    DatabaseExecutor txn,
    int productId,
  ) async {
    await txn.rawUpdate(
      'UPDATE product_units SET reference_sale_price = NULL, reference_wholesale_price = NULL, reference_currency = NULL WHERE product_id = ?',
      [productId],
    );
  }

  /// Reads reference-driven status flags for a set of product IDs from the database.
  static Future<Map<int, ReferenceDrivenFlags>> getReferenceDrivenFlags(
    DatabaseExecutor ex,
    Iterable<int> productIds,
  ) async {
    final result = <int, ReferenceDrivenFlags>{};
    final idList = productIds.toList();
    const chunkSize = 500;
    for (int i = 0; i < idList.length; i += chunkSize) {
      final chunk = idList.sublist(i, math.min(i + chunkSize, idList.length));
      if (chunk.isEmpty) continue;
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await ex.rawQuery(
        'SELECT id, price_currency, reference_wholesale_price, reference_purchase_price FROM products WHERE id IN ($placeholders)',
        chunk,
      );
      for (final r in rows) {
        final id = r['id'] as int;
        final hasCurr = r['price_currency'] != null;
        result[id] = ReferenceDrivenFlags(
          sale: hasCurr,
          wholesale: hasCurr && r['reference_wholesale_price'] != null,
          purchase: hasCurr && r['reference_purchase_price'] != null,
        );
      }
    }
    return result;
  }

  /// Reprices all products and units associated with currency [code].
  ///
  /// Updates only base-currency columns driven by reference prices.
  /// Uses a batch inside [txn] and returns affected counts.
  static Future<RepriceCounts> repriceCurrency(
    DatabaseExecutor txn,
    String code,
  ) async {
    AccessGuard.require(PermissionRegistry.pricingManage);
    final rateRow = await getRate(txn, code);
    if (rateRow == null || !ReferencePricingMath.isValidRate(rateRow.rate)) {
      throw const ReferencePricingException(
        ReferencePricingError.rateMissing,
        'Cannot reprice currency without valid rate',
      );
    }
    final rate = rateRow.rate;
    final rounding = await readRounding(txn);
    final baseCode = await businessCurrencyCode(txn);
    final baseDecimals = Currency.decimalDigitsForCode(baseCode);

    final prodRows = await txn.rawQuery(
      'SELECT id, reference_sale_price, reference_wholesale_price, reference_purchase_price FROM products WHERE price_currency = ?',
      [code],
    );

    final unitRows = await txn.rawQuery(
      '''
      SELECT u.id, u.reference_sale_price, u.reference_wholesale_price
      FROM product_units u
      JOIN products p ON p.id = u.product_id
      WHERE p.price_currency = ?
        AND u.reference_currency = p.price_currency
        AND (u.reference_sale_price IS NOT NULL OR u.reference_wholesale_price IS NOT NULL)
      ''',
      [code],
    );

    final batch = txn.batch();
    final nowIso = DateTime.now().toIso8601String();

    for (final p in prodRows) {
      final pId = p['id'] as int;
      final refSale = (p['reference_sale_price'] as num).toDouble();
      final refWs = (p['reference_wholesale_price'] as num?)?.toDouble();
      final refPur = (p['reference_purchase_price'] as num?)?.toDouble();

      final newSale = ReferencePricingMath.convert(
        reference: refSale,
        rate: rate,
        rounding: rounding,
        baseDecimals: baseDecimals,
      );

      final updateMap = <String, dynamic>{
        'updated_at': nowIso,
        'sale_price': newSale,
      };

      if (refWs != null) {
        updateMap['wholesale_price'] = ReferencePricingMath.convert(
          reference: refWs,
          rate: rate,
          rounding: rounding,
          baseDecimals: baseDecimals,
        );
      }

      if (refPur != null) {
        updateMap['purchase_price'] = ReferencePricingMath.convert(
          reference: refPur,
          rate: rate,
          rounding: rounding,
          baseDecimals: baseDecimals,
        );
      }

      batch.update(
        'products',
        updateMap,
        where: 'id = ?',
        whereArgs: [pId],
      );
    }

    for (final u in unitRows) {
      final uId = u['id'] as int;
      final refSale = (u['reference_sale_price'] as num?)?.toDouble();
      final refWs = (u['reference_wholesale_price'] as num?)?.toDouble();

      final updateMap = <String, dynamic>{};
      if (refSale != null) {
        updateMap['sale_price'] = ReferencePricingMath.convert(
          reference: refSale,
          rate: rate,
          rounding: rounding,
          baseDecimals: baseDecimals,
        );
      }
      if (refWs != null) {
        updateMap['wholesale_price'] = ReferencePricingMath.convert(
          reference: refWs,
          rate: rate,
          rounding: rounding,
          baseDecimals: baseDecimals,
        );
      }

      if (updateMap.isNotEmpty) {
        batch.update(
          'product_units',
          updateMap,
          where: 'id = ?',
          whereArgs: [uId],
        );
      }
    }

    await batch.commit(noResult: true);
    return RepriceCounts(
      products: prodRows.length,
      units: unitRows.length,
    );
  }

  /// Returns list of distinct currency codes currently used by catalog products.
  static Future<List<String>> currenciesInUse(DatabaseExecutor ex) async {
    final rows = await ex.rawQuery(
      'SELECT DISTINCT price_currency FROM products WHERE price_currency IS NOT NULL ORDER BY price_currency ASC',
    );
    return rows.map((r) => r['price_currency'] as String).toList();
  }

  /// Read-only preview of what repricing with [newRate] would alter for currency [code].
  static Future<RepricePreview> previewRateChange(
    DatabaseExecutor ex,
    String code,
    double newRate,
  ) async {
    ReferencePricingMath.assertValidRate(newRate);
    final rounding = await readRounding(ex);
    final baseCode = await businessCurrencyCode(ex);
    final baseDecimals = Currency.decimalDigitsForCode(baseCode);

    final prodRows = await ex.rawQuery(
      'SELECT name, sale_price, reference_sale_price FROM products WHERE price_currency = ?',
      [code],
    );

    final unitCountRows = await ex.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM product_units u
      JOIN products p ON p.id = u.product_id
      WHERE p.price_currency = ?
        AND u.reference_currency = p.price_currency
        AND (u.reference_sale_price IS NOT NULL OR u.reference_wholesale_price IS NOT NULL)
      ''',
      [code],
    );
    final unitCount = (unitCountRows.first['count'] as num?)?.toInt() ?? 0;

    final samples = <RepriceSample>[];
    for (int i = 0; i < math.min(3, prodRows.length); i++) {
      final row = prodRows[i];
      final name = row['name'] as String;
      final oldSale = (row['sale_price'] as num?)?.toDouble() ?? 0.0;
      final refSale = (row['reference_sale_price'] as num?)?.toDouble() ?? 0.0;
      final newSale = ReferencePricingMath.convert(
        reference: refSale,
        rate: newRate,
        rounding: rounding,
        baseDecimals: baseDecimals,
      );
      samples.add(RepriceSample(
        name: name,
        oldBase: oldSale,
        newBase: newSale,
      ));
    }

    return RepricePreview(
      affectedProducts: prodRows.length,
      affectedUnits: unitCount,
      samples: samples,
    );
  }

  /// Read-only count preview of recalculating all reference prices across all currencies.
  static Future<RepricePreview> previewRecalculateAll(
    DatabaseExecutor ex,
  ) async {
    final prodCountRows = await ex.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE price_currency IS NOT NULL',
    );
    final prodCount = (prodCountRows.first['count'] as num?)?.toInt() ?? 0;

    final unitCountRows = await ex.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM product_units u
      JOIN products p ON p.id = u.product_id
      WHERE p.price_currency IS NOT NULL
        AND u.reference_currency = p.price_currency
        AND (u.reference_sale_price IS NOT NULL OR u.reference_wholesale_price IS NOT NULL)
      ''',
    );
    final unitCount = (unitCountRows.first['count'] as num?)?.toInt() ?? 0;

    return RepricePreview(
      affectedProducts: prodCount,
      affectedUnits: unitCount,
      samples: const [],
    );
  }

  /// Writes an un-swallowed audit log record for reference pricing operations.
  static Future<void> writeAudit(
    DatabaseExecutor txn, {
    required String action,
    required String entityType,
    required Map<String, Object?> details,
  }) async {
    await txn.insert('audit_log', {
      'action': action,
      'entity_type': entityType,
      'entity_id': null,
      'details': jsonEncode(details),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Verifies core database invariants I1, I2, I3, I4, returning human-readable violations.
  static Future<List<String>> verifyInvariants(DatabaseExecutor ex) async {
    final violations = <String>[];

    // I1: products.price_currency NOT NULL => products.reference_sale_price NOT NULL
    final i1Rows = await ex.rawQuery(
      'SELECT id, name FROM products WHERE price_currency IS NOT NULL AND reference_sale_price IS NULL',
    );
    for (final r in i1Rows) {
      violations.add(
        'I1: Product ${r['id']} ("${r['name']}") has price_currency set but reference_sale_price is NULL',
      );
    }

    // I2: products.price_currency NULL => products.reference_* are NULL AND units have reference_* and reference_currency NULL
    final i2ProdRows = await ex.rawQuery(
      'SELECT id, name FROM products WHERE price_currency IS NULL AND (reference_sale_price IS NOT NULL OR reference_wholesale_price IS NOT NULL OR reference_purchase_price IS NOT NULL)',
    );
    for (final r in i2ProdRows) {
      violations.add(
        'I2: Product ${r['id']} ("${r['name']}") has NULL price_currency but non-null reference prices',
      );
    }

    final i2UnitRows = await ex.rawQuery(
      '''
      SELECT u.id, u.unit_name, p.id as product_id
      FROM product_units u
      JOIN products p ON p.id = u.product_id
      WHERE p.price_currency IS NULL
        AND (u.reference_sale_price IS NOT NULL OR u.reference_wholesale_price IS NOT NULL OR u.reference_currency IS NOT NULL)
      ''',
    );
    for (final r in i2UnitRows) {
      violations.add(
        'I2: Unit ${r['id']} ("${r['unit_name']}") belongs to base product ${r['product_id']} but has reference pricing data',
      );
    }

    // I3: unit with reference price has reference_currency == product.price_currency; unit with no reference price has reference_currency NULL
    final i3MismatchRows = await ex.rawQuery(
      '''
      SELECT u.id, u.unit_name, u.reference_currency, p.price_currency
      FROM product_units u
      JOIN products p ON p.id = u.product_id
      WHERE (u.reference_sale_price IS NOT NULL OR u.reference_wholesale_price IS NOT NULL)
        AND (u.reference_currency IS NULL OR u.reference_currency != p.price_currency)
      ''',
    );
    for (final r in i3MismatchRows) {
      violations.add(
        'I3: Unit ${r['id']} ("${r['unit_name']}") reference_currency "${r['reference_currency']}" does not match product price_currency "${r['price_currency']}"',
      );
    }

    final i3OrphanCurrRows = await ex.rawQuery(
      '''
      SELECT u.id, u.unit_name
      FROM product_units u
      WHERE u.reference_currency IS NOT NULL
        AND u.reference_sale_price IS NULL
        AND u.reference_wholesale_price IS NULL
      ''',
    );
    for (final r in i3OrphanCurrRows) {
      violations.add(
        'I3: Unit ${r['id']} ("${r['unit_name']}") has reference_currency set but no reference prices',
      );
    }

    // I4: every products.price_currency has a row in exchange_rates; every stored rate satisfies isValidRate
    final i4MissingRateRows = await ex.rawQuery(
      '''
      SELECT p.id, p.name, p.price_currency
      FROM products p
      LEFT JOIN exchange_rates r ON r.code = p.price_currency
      WHERE p.price_currency IS NOT NULL AND r.code IS NULL
      ''',
    );
    for (final r in i4MissingRateRows) {
      violations.add(
        'I4: Product ${r['id']} ("${r['name']}") references currency "${r['price_currency']}" which has no row in exchange_rates',
      );
    }

    final allRates = await ex.rawQuery('SELECT code, rate FROM exchange_rates');
    for (final r in allRates) {
      final code = r['code'] as String;
      final rawRate = r['rate'];
      final double? rate = (rawRate is num) ? rawRate.toDouble() : null;
      if (rate == null || !ReferencePricingMath.isValidRate(rate)) {
        violations.add(
          'I4: Exchange rate for "$code" ($rate) is invalid (must be finite, > 0, <= 1e9, <= 6 decimal places)',
        );
      }
    }

    return violations;
  }
}
