/// Domain model for an account in the persisted chart of accounts.
class AccountEntity {
  final String code;
  final String nameAr;
  final String nameEn;
  final String type; // 'asset', 'liability', 'equity', 'revenue', 'expense'
  final String normalSide; // 'debit', 'credit'
  final bool isSystem;

  const AccountEntity({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.type,
    required this.normalSide,
    this.isSystem = true,
  });

  bool get isDebitNormal => normalSide == 'debit';

  Map<String, dynamic> toMap() => {
    'code': code,
    'name_ar': nameAr,
    'name_en': nameEn,
    'type': type,
    'normal_side': normalSide,
    'is_system': isSystem ? 1 : 0,
  };

  factory AccountEntity.fromMap(Map<String, dynamic> map) => AccountEntity(
    code: map['code'] as String,
    nameAr: map['name_ar'] as String,
    nameEn: map['name_en'] as String,
    type: map['type'] as String,
    normalSide: map['normal_side'] as String,
    isSystem: (map['is_system'] as int? ?? 1) == 1,
  );
}
