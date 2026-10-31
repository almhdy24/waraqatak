import 'package:flutter/foundation.dart';
import '../localization/app_localizations.dart';

/// Centralized utility to convert technical exceptions and database errors
/// into clear, actionable, friendly Arabic messages for business users,
/// while maintaining full diagnostic logging for developers in debug mode.
class ErrorUtils {
  static String getFriendlyErrorMessage(Object error, {AppLocalizations? l10n}) {
    if (l10n != null) {
      return toFriendlyMessage(error, l10n);
    }
    return toFriendlyMessage(error, AppLocalizations('ar'));
  }

  static String toFriendlyMessage(Object error, AppLocalizations l10n) {
    final raw = error.toString();
    debugPrint('[Waraqatak Error] $raw');

    final lower = raw.toLowerCase();

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

    // Stock cannot be negative
    if (lower.contains('stock cannot be negative') ||
        lower.contains('negative stock')) {
      return l10n.stockCannotBeNegative;
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

    // Clean up technical prefixes like "Exception: ", "Bad state: ", "Invalid argument(s): "
    final cleaned = raw
        .replaceFirst(RegExp(r'^(Exception|Bad state|Invalid argument\(s\)|DatabaseException):\s*'), '')
        .trim();

    if (cleaned.isNotEmpty && !cleaned.contains('NoSuchMethodError') && !cleaned.contains('Null check operator')) {
      return cleaned;
    }

    return l10n.operationFailed;
  }
}
