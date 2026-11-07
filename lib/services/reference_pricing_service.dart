/// Application service for reference pricing and exchange rates management.
library;

import 'package:meta/meta.dart';

import '../core/catalog_events.dart';
import '../database/database_helper.dart';
import '../database/reference_pricing_dao.dart';
import '../models/exchange_rate.dart';
import '../models/reference_pricing_types.dart';

/// Service providing public APIs for reference pricing, exchange rates, and catalog repricing.
///
/// Contains NO SQL. Coordinates database transactions and delegates all data access
/// to [ReferencePricingDao].
abstract final class ReferencePricingService {
  static bool _busy = false;

  /// Sets the internal busy re-entrancy flag for testing.
  @visibleForTesting
  static void setBusyForTest(bool val) => _busy = val;

  /// Fetches registered exchange rates, optionally filtering to active ones.
  static Future<List<ExchangeRate>> getRates({bool activeOnly = false}) async {
    final db = await DatabaseHelper.instance.database;
    return ReferencePricingDao.getRates(db, activeOnly: activeOnly);
  }

  /// Returns true if at least one exchange rate exists.
  static Future<bool> hasRates() async {
    final db = await DatabaseHelper.instance.database;
    return ReferencePricingDao.hasAnyRate(db);
  }

  /// Reads the configured converted-price rounding step from settings.
  static Future<int> getRounding() async {
    final db = await DatabaseHelper.instance.database;
    return ReferencePricingDao.readRounding(db);
  }

  /// Writes a new converted-price rounding step to settings.
  static Future<void> setRounding(int rounding) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction(
      (txn) => ReferencePricingDao.writeRounding(txn, rounding),
    );
  }

  /// Sets the active status of an exchange rate currency.
  static Future<void> setCurrencyActive(String code, bool active) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction(
      (txn) => ReferencePricingDao.setActive(txn, code, active),
    );
  }

  /// Deletes a custom exchange rate if not referenced by any product.
  static Future<bool> deleteCustomCurrency(String code) async {
    final db = await DatabaseHelper.instance.database;
    return db.transaction(
      (txn) => ReferencePricingDao.deleteCustomIfUnused(txn, code),
    );
  }

  /// Returns a preview of changes if currency [code] rate is updated to [newRate].
  static Future<RepricePreview> previewRateChange(
    String code,
    double newRate,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return ReferencePricingDao.previewRateChange(db, code, newRate);
  }

  /// Returns a count preview of recalculating all reference prices.
  static Future<RepricePreview> previewRecalculateAll() async {
    final db = await DatabaseHelper.instance.database;
    return ReferencePricingDao.previewRecalculateAll(db);
  }

  /// Adds a new reference currency with its initial exchange rate.
  ///
  /// Atomically inserts the rate row and logs an audit event.
  static Future<void> addCurrencyWithRate(ExchangeRate entry) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await ReferencePricingDao.insertRate(
        txn,
        entry.copyWith(updatedAt: DateTime.now()),
      );
      await ReferencePricingDao.writeAudit(
        txn,
        action: 'exchange_rate_added',
        entityType: 'exchange_rate',
        details: {
          'code': entry.code,
          'rate': entry.rate,
        },
      );
    });
  }

  /// Updates an exchange rate and immediately reprices all associated products and units.
  ///
  /// Protected by a re-entrancy guard. Executes inside a single transaction;
  /// any failure rolls back the rate change and all price modifications.
  static Future<RepriceResult> updateRateAndReprice(
    String code,
    double newRate,
  ) async {
    if (_busy) {
      throw const ReferencePricingException(
        ReferencePricingError.repricingInProgress,
        'A price update is already running. Please wait.',
      );
    }
    _busy = true;
    try {
      final db = await DatabaseHelper.instance.database;
      int affectedProducts = 0;
      int affectedUnits = 0;
      bool changed = false;

      await db.transaction((txn) async {
        final old = await ReferencePricingDao.getRate(txn, code);
        if (old == null) {
          throw const ReferencePricingException(
            ReferencePricingError.currencyNotFound,
            'Currency not found',
          );
        }
        if (old.rate == newRate) {
          return;
        }
        changed = true;
        await ReferencePricingDao.updateRate(
          txn,
          code,
          newRate,
          DateTime.now(),
        );
        final counts = await ReferencePricingDao.repriceCurrency(txn, code);
        affectedProducts = counts.products;
        affectedUnits = counts.units;

        await ReferencePricingDao.writeAudit(
          txn,
          action: 'exchange_rate_updated',
          entityType: 'exchange_rate',
          details: {
            'code': code,
            'oldRate': old.rate,
            'newRate': newRate,
            'affectedProducts': affectedProducts,
            'affectedUnits': affectedUnits,
          },
        );
      });

      if (!changed) {
        return const RepriceResult.empty();
      }

      if (affectedProducts > 0 || affectedUnits > 0) {
        CatalogEvents.notifyPricesChanged();
      }

      return RepriceResult(
        affectedProducts: affectedProducts,
        affectedUnits: affectedUnits,
        currencies: [code],
      );
    } finally {
      _busy = false;
    }
  }

  /// Recalculates base-currency prices for all products and units across all reference currencies.
  ///
  /// Protected by a re-entrancy guard. Executes inside a single transaction;
  /// any failure rolls back all price recalculations and the audit event.
  static Future<RepriceResult> recalculateAll() async {
    if (_busy) {
      throw const ReferencePricingException(
        ReferencePricingError.repricingInProgress,
        'A price update is already running. Please wait.',
      );
    }
    _busy = true;
    try {
      final db = await DatabaseHelper.instance.database;
      int totalProducts = 0;
      int totalUnits = 0;
      List<String> currencies = const [];

      await db.transaction((txn) async {
        currencies = await ReferencePricingDao.currenciesInUse(txn);
        for (final code in currencies) {
          final counts = await ReferencePricingDao.repriceCurrency(txn, code);
          totalProducts += counts.products;
          totalUnits += counts.units;
        }
        await ReferencePricingDao.writeAudit(
          txn,
          action: 'reference_prices_recalculated',
          entityType: 'exchange_rate',
          details: {
            'currencies': currencies,
            'affected_products': totalProducts,
            'affected_units': totalUnits,
          },
        );
      });

      if (totalProducts > 0 || totalUnits > 0) {
        CatalogEvents.notifyPricesChanged();
      }

      return RepriceResult(
        affectedProducts: totalProducts,
        affectedUnits: totalUnits,
        currencies: currencies,
      );
    } finally {
      _busy = false;
    }
  }
}
