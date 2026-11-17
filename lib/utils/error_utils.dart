import 'package:flutter/foundation.dart';
import '../localization/app_localizations.dart';
import '../models/reference_pricing_types.dart';
import '../services/access/access_error.dart';
import '../services/access/access_messages.dart';

/// Centralized utility to convert technical exceptions and database errors
/// into clear, actionable, friendly Arabic messages for business users,
/// while maintaining full diagnostic logging for developers in debug mode.
class ErrorUtils {
  static String getFriendlyErrorMessage(
    Object error, {
    AppLocalizations? l10n,
  }) {
    if (l10n != null) {
      return toFriendlyMessage(error, l10n);
    }
    return toFriendlyMessage(error, AppLocalizations('ar'));
  }

  static String toFriendlyMessage(Object error, AppLocalizations l10n) {
    if (error is AccessError) {
      return localizeAccessError(
        l10n,
        error.code,
        permissionKey: error.permissionKey,
        args: error.args,
      );
    }

    if (error is ReferencePricingException) {
      return switch (error.code) {
        ReferencePricingError.invalidRate => l10n.refErrInvalidRate,
        ReferencePricingError.invalidPrice => l10n.refErrInvalidPrice,
        ReferencePricingError.priceOutOfRange => l10n.refErrPriceOutOfRange,
        ReferencePricingError.rateMissing => l10n.rateMissingForCurrency,
        ReferencePricingError.referencePriceRequired =>
          l10n.refErrReferencePriceRequired,
        ReferencePricingError.repricingInProgress => l10n.refErrRepricingBusy,
        ReferencePricingError.currencyExists => l10n.refErrCurrencyExists,
        ReferencePricingError.currencyIsBase => l10n.refErrCurrencyIsBase,
        ReferencePricingError.currencyInUse => l10n.currencyInUse,
        ReferencePricingError.currencyArchived => l10n.refErrCurrencyArchived,
        ReferencePricingError.baseCurrencyChangeBlocked =>
          l10n.currencyChangeBlockedByRates,
        ReferencePricingError.businessNotConfigured => l10n.setupBusinessFirst,
        ReferencePricingError.proFeatureRequired => l10n.proFeatureTitle,
        ReferencePricingError.implicitClear ||
        ReferencePricingError.currencyNotFound => l10n.refErrGeneric,
      };
    }

    final raw = error.toString();
    debugPrint('[Waraqatak Error] $raw');

    final lower = raw.toLowerCase();

    // Permission / Access control errors
    if (raw.contains('PermissionDeniedException') ||
        raw.contains('AccessErrorCode.missingPermission')) {
      final permMatch = RegExp(
        r'PermissionDeniedException\(([^, )]+)',
      ).firstMatch(raw);
      final perm = permMatch?.group(1);
      return localizeAccessError(
        l10n,
        AccessErrorCode.missingPermission,
        permissionKey: perm,
      );
    }

    // Barcode duplicate
    if (lower.contains('unique constraint failed: products.barcode') ||
        lower.contains('barcode is already in use') ||
        lower.contains('duplicate barcode')) {
      return l10n.duplicateBarcode;
    }

    // SKU / code duplicate
    if (lower.contains('unique constraint failed: products.code')) {
      return l10n.errorDuplicateSku;
    }

    // General unique constraint
    if (lower.contains('unique constraint failed')) {
      return l10n.errorDuplicateRecord;
    }

    // Foreign key constraint (item in use)
    if (lower.contains('foreign key constraint failed')) {
      return l10n.errorForeignKeyConstraint;
    }

    // Insufficient stock
    if (lower.contains('insufficient stock')) {
      return l10n.errorInsufficientStockGeneral;
    }

    // Product in use
    if (raw.contains('ProductInUseException') ||
        lower.contains('product is in use')) {
      return l10n.errProductInUse;
    }

    // Image storage error
    if (raw.contains('ImageStorageException') ||
        lower.contains('image storage failed')) {
      return l10n.logoInvalidImage;
    }

    // Stock cannot be negative
    if (lower.contains('stock cannot be negative') ||
        lower.contains('negative stock')) {
      return l10n.stockCannotBeNegative;
    }

    final msg = error.toString();
    if (msg.contains(
      'Cannot delete product with existing invoice or purchase history',
    )) {
      return l10n.errorDeleteProductHasHistory;
    }
    if (msg.contains('Discount cannot exceed subtotal')) {
      return l10n.errorDiscountExceedsSubtotal;
    }
    if (msg.contains('Paid amount cannot exceed total')) {
      return l10n.errorPaidExceedsTotal;
    }
    if (msg.contains('Amount cannot be negative') ||
        msg.contains('Unit price cannot be negative') ||
        msg.contains('cannot be negative')) {
      return l10n.errorNegativeAmount;
    }
    if (lower.contains('at least 1 day') ||
        lower.contains('validity period must be') ||
        lower.contains('valid until date is required')) {
      return l10n.errorValidityMinDays;
    }
    if (msg.contains('validUntil must be on or after date') ||
        msg.contains('Valid-until date cannot be before') ||
        msg.contains('Valid until must be after document date') ||
        lower.contains('valid until') ||
        lower.contains('validuntil') ||
        lower.contains('valid-until')) {
      return l10n.errorValidUntilBeforeDate;
    }

    // FIFO allocation errors (D5)
    if (lower.contains('payment exceeds outstanding balance')) {
      return l10n.errorPaymentExceedsOutstanding;
    }
    if (lower.contains('no open documents for this contact')) {
      return l10n.voucherNoOpenDocuments;
    }

    // Cancellation & editing errors (B7)
    if (lower.contains('document is already cancelled')) {
      return l10n.errorDocumentAlreadyCancelled;
    }
    if (lower.contains('cannot reduce total') ||
        lower.contains('below recorded payments')) {
      return l10n.errorCannotReduceTotalBelowPayments;
    }
    if (lower.contains('cannot cancel purchase') ||
        lower.contains('insufficient stock to cancel purchase') ||
        lower.contains('consumed this stock')) {
      return l10n.errorInsufficientStockToCancelPurchase;
    }

    // Network / connectivity
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('network') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('handshakeexception')) {
      return l10n.errorNetworkConnectivity;
    }

    // Timeout
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return l10n.errorOperationTimeout;
    }

    // Format exception / invalid number
    if (lower.contains('formatexception')) {
      return l10n.errorInvalidNumberFormat;
    }

    // Purchase cannot be edited with subsequent movements
    if (lower.contains('subsequent sales or movements')) {
      return l10n.cannotEditPurchaseWithSubsequentSales;
    }

    // Accounting period lock
    if (lower.contains('period is closed') ||
        lower.contains('books_closed_through') ||
        lower.contains('accounting period is closed')) {
      return l10n.errorPeriodClosed;
    }

    // Active payment receipts / vouchers guard on cancellation
    final activeVouchersMatch = RegExp(
      r'active payment receipts/vouchers \(([^)]+)\)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (activeVouchersMatch != null) {
      final numbers = activeVouchersMatch.group(1) ?? '';
      return l10n.cannotCancelWithActiveVouchers(numbers);
    }

    // Clean up technical prefixes like "Exception: ", "Bad state: ", "Invalid argument(s): "
    final cleaned = raw
        .replaceFirst(
          RegExp(
            r'^(Exception|Bad state|Invalid argument\(s\)|DatabaseException):\s*',
          ),
          '',
        )
        .trim();

    if (cleaned.isNotEmpty &&
        !cleaned.contains('NoSuchMethodError') &&
        !cleaned.contains('Null check operator') &&
        !cleaned.contains('PermissionDeniedException') &&
        !cleaned.contains('AccessError')) {
      return cleaned;
    }

    return l10n.operationFailed;
  }
}
