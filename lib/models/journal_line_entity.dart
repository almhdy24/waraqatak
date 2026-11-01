import '../utils/money_utils.dart';

/// Domain model for an immutable journal line representing a single debit or credit
/// in integer minor units of the base currency.
class JournalLineEntity {
  final int? id;
  final int entryId;
  final String accountCode;
  final int debitMinor;
  final int creditMinor;
  final int? productId;
  final int? contactId;

  const JournalLineEntity({
    this.id,
    required this.entryId,
    required this.accountCode,
    this.debitMinor = 0,
    this.creditMinor = 0,
    this.productId,
    this.contactId,
  });

  bool get isDebit => debitMinor > 0;
  bool get isCredit => creditMinor > 0;

  double getDebitAmount([int decimalDigits = 2]) =>
      MoneyUtils.fromMinorUnits(debitMinor, decimalDigits);

  double getCreditAmount([int decimalDigits = 2]) =>
      MoneyUtils.fromMinorUnits(creditMinor, decimalDigits);

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'entry_id': entryId,
    'account_code': accountCode,
    'debit_minor': debitMinor,
    'credit_minor': creditMinor,
    'product_id': productId,
    'contact_id': contactId,
  };

  factory JournalLineEntity.fromMap(Map<String, dynamic> map) => JournalLineEntity(
    id: map['id'] as int?,
    entryId: map['entry_id'] as int,
    accountCode: map['account_code'] as String,
    debitMinor: (map['debit_minor'] as num?)?.toInt() ?? 0,
    creditMinor: (map['credit_minor'] as num?)?.toInt() ?? 0,
    productId: map['product_id'] as int?,
    contactId: map['contact_id'] as int?,
  );
}
