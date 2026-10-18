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
      return l10n.isArabic
          ? 'رمز المنتج (SKU) مسجل مسبقاً لمنتج آخر'
          : 'Product SKU is already in use by another product';
    }

    // General unique constraint
    if (lower.contains('unique constraint failed')) {
      return l10n.isArabic
          ? 'هذا السجل مسجل مسبقاً في النظام، يرجى التحقق من عدم التكرار'
          : 'This record already exists in the system';
    }

    // Foreign key constraint (item in use)
    if (lower.contains('foreign key constraint failed')) {
      return l10n.isArabic
          ? 'لا يمكن إتمام العملية لوجود مستندات أو سجلات مرتبطة بهذا العنصر'
          : 'Cannot complete operation because this item is referenced by existing records';
    }

    // Insufficient stock
    if (lower.contains('insufficient stock')) {
      return l10n.isArabic
          ? 'الكمية المتوفرة في المخزن غير كافية لإتمام العملية'
          : 'Insufficient stock to complete this transaction';
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
      return l10n.isArabic
          ? 'تعذّر الاتصال بالإنترنت، يرجى التحقق من الشبكة ثم إعادة المحاولة'
          : 'Could not connect to the network. Please check your internet connection';
    }

    // Timeout
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return l10n.isArabic
          ? 'استغرقت العملية وقتاً أطول من المتوقع، يرجى إعادة المحاولة'
          : 'The operation timed out. Please try again';
    }

    // Format exception / invalid number
    if (lower.contains('formatexception')) {
      return l10n.isArabic
          ? 'يرجى التأكد من كتابة الأرقام والمبالغ بشكل صحيح'
          : 'Please enter valid numbers';
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
