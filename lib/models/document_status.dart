abstract class DocumentStatus {
  static const String draft         = 'draft';
  static const String issued        = 'issued';
  static const String partiallyPaid = 'partially_paid';
  static const String paid          = 'paid';
  static const String cancelled     = 'cancelled';

  /// Compute invoice payment status from paid/total amounts.
  static String fromPayment(double paidAmount, double totalAmount) {
    if (paidAmount >= totalAmount) return paid;
    if (paidAmount > 0) return partiallyPaid;
    return issued;
  }
}
