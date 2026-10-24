import '../utils/money_utils.dart';

abstract class DocumentStatus {
  static const String draft         = 'draft';
  static const String issued        = 'issued';
  static const String partiallyPaid = 'partially_paid';
  static const String paid          = 'paid';
  static const String cancelled     = 'cancelled';

  /// Compute invoice payment status from paid/total amounts using canonical monetary precision.
  static String fromPayment(
    double paidAmount,
    double totalAmount, {
    int decimalDigits = 2,
  }) {
    if (MoneyUtils.isPaidInFull(paidAmount, totalAmount, decimalDigits)) {
      return paid;
    }
    if (MoneyUtils.toMinorUnits(paidAmount, decimalDigits) > 0) {
      return partiallyPaid;
    }
    return issued;
  }
}
