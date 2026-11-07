/// Domain types and exceptions for reference-currency pricing.
library;

/// Error codes thrown by reference pricing operations.
enum ReferencePricingError {
  /// Provided rate is not finite, out of bounds, or has too many decimal places.
  invalidRate,

  /// Provided price is not finite, out of bounds, or has too many decimal places.
  invalidPrice,

  /// Converted price exceeds the maximum allowed monetary value.
  priceOutOfRange,

  /// Exchange rate does not exist in the database or is invalid.
  rateMissing,

  /// Reference sale price is mandatory when a price currency is assigned.
  referencePriceRequired,

  /// Attempted to clear reference pricing without explicit permission flag.
  implicitClear,

  /// A repricing operation is already in progress.
  repricingInProgress,

  /// The specified currency code already exists.
  currencyExists,

  /// The base currency cannot be used as a reference currency.
  currencyIsBase,

  /// The requested currency code does not exist.
  currencyNotFound,

  /// Currency cannot be deleted because one or more products reference it.
  currencyInUse,

  /// Currency is archived and cannot be assigned to new products.
  currencyArchived,

  /// Base currency change is blocked because exchange rates or reference products exist.
  baseCurrencyChangeBlocked,

  /// Business settings are not yet configured.
  businessNotConfigured,
}

/// Exception thrown by reference pricing operations.
class ReferencePricingException implements Exception {
  /// Error classification code.
  final ReferencePricingError code;

  /// Human-readable technical or fallback message.
  final String message;

  /// Creates a [ReferencePricingException].
  const ReferencePricingException(this.code, this.message);

  @override
  String toString() => 'ReferencePricingException($code): $message';
}

/// Container for computed base-currency prices derived from reference prices.
class DerivedPrices {
  /// Derived sale price in base currency.
  final double? sale;

  /// Derived wholesale price in base currency.
  final double? wholesale;

  /// Derived purchase price in base currency.
  final double? purchase;

  /// Creates a [DerivedPrices] container.
  const DerivedPrices({
    this.sale,
    this.wholesale,
    this.purchase,
  });
}

/// Flags indicating whether product price fields are currently reference-driven.
class ReferenceDrivenFlags {
  /// Whether sale price is driven by reference pricing.
  final bool sale;

  /// Whether wholesale price is driven by reference pricing.
  final bool wholesale;

  /// Whether purchase price is driven by reference pricing.
  final bool purchase;

  /// Creates a [ReferenceDrivenFlags] container.
  const ReferenceDrivenFlags({
    required this.sale,
    required this.wholesale,
    required this.purchase,
  });
}

/// Statistics on updated entity counts from a repricing operation.
class RepriceCounts {
  /// Number of products updated.
  final int products;

  /// Number of product units updated.
  final int units;

  /// Creates a [RepriceCounts] instance.
  const RepriceCounts({
    required this.products,
    required this.units,
  });
}

/// A sample product before/after price change for repricing preview.
class RepriceSample {
  /// Product display name.
  final String name;

  /// Base-currency price before repricing.
  final double oldBase;

  /// Base-currency price after repricing.
  final double newBase;

  /// Creates a [RepriceSample] instance.
  const RepriceSample({
    required this.name,
    required this.oldBase,
    required this.newBase,
  });
}

/// Informational preview of a rate change or full recalculation.
class RepricePreview {
  /// Count of products that would be affected.
  final int affectedProducts;

  /// Count of product units that would be affected.
  final int affectedUnits;

  /// Sample products demonstrating price changes.
  final List<RepriceSample> samples;

  /// Creates a [RepricePreview] instance.
  const RepricePreview({
    required this.affectedProducts,
    required this.affectedUnits,
    required this.samples,
  });
}

/// Outcome of a committed repricing operation.
class RepriceResult {
  /// Count of affected products.
  final int affectedProducts;

  /// Count of affected product units.
  final int affectedUnits;

  /// List of currency codes that were repriced.
  final List<String> currencies;

  /// Creates a [RepriceResult].
  const RepriceResult({
    required this.affectedProducts,
    required this.affectedUnits,
    required this.currencies,
  });

  /// Represents an empty/no-op repricing result.
  const RepriceResult.empty()
      : affectedProducts = 0,
        affectedUnits = 0,
        currencies = const [];
}
