import '../utils/money_utils.dart';

class OpenDocumentBalance {
  const OpenDocumentBalance({required this.id, required this.remaining});
  final int id;
  final double remaining;
}

class PaymentAllocation {
  const PaymentAllocation({required this.documentId, required this.amount});
  final int documentId;
  final double amount;
}

class PaymentAllocationException implements Exception {
  const PaymentAllocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PaymentAllocator {
  PaymentAllocator._();

  /// Oldest-first allocation. [open] must already be ordered oldest first.
  static List<PaymentAllocation> planFifo({
    required List<OpenDocumentBalance> open,
    required double amount,
    required int decimalDigits,
  }) {
    final total = MoneyUtils.round(amount, decimalDigits);
    if (total <= 0) {
      throw const PaymentAllocationException(
        'Payment amount must be greater than zero',
      );
    }
    final payable = open
        .where((d) => MoneyUtils.round(d.remaining, decimalDigits) > 0)
        .toList();
    if (payable.isEmpty) {
      throw const PaymentAllocationException(
        'No open documents for this contact',
      );
    }
    var outstanding = 0.0;
    for (final d in payable) {
      outstanding = MoneyUtils.round(
        outstanding + MoneyUtils.round(d.remaining, decimalDigits),
        decimalDigits,
      );
    }
    if (MoneyUtils.round(total - outstanding, decimalDigits) > 0) {
      throw const PaymentAllocationException(
        'Payment exceeds outstanding balance',
      );
    }
    final result = <PaymentAllocation>[];
    var left = total;
    for (final d in payable) {
      if (left <= 0) break;
      final rem = MoneyUtils.round(d.remaining, decimalDigits);
      final take = left < rem ? left : rem;
      result.add(PaymentAllocation(documentId: d.id, amount: take));
      left = MoneyUtils.round(left - take, decimalDigits);
    }
    return result;
  }
}
