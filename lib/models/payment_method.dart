class PaymentMethod {
  final int? id;
  final String key;
  final String labelAr;
  final String labelEn;
  final bool isEnabled;
  final bool isDefault;
  final int sortOrder;
  final bool isPredefined;

  const PaymentMethod({
    this.id,
    required this.key,
    required this.labelAr,
    required this.labelEn,
    this.isEnabled = false,
    this.isDefault = false,
    this.sortOrder = 0,
    this.isPredefined = true,
  });

  String label(String langCode) => langCode == 'ar' ? labelAr : labelEn;

  factory PaymentMethod.fromMap(Map<String, dynamic> m) => PaymentMethod(
        id: m['id'] as int?,
        key: m['key'] as String,
        labelAr: m['label_ar'] as String,
        labelEn: m['label_en'] as String,
        isEnabled: (m['is_enabled'] as int?) == 1,
        isDefault: (m['is_default'] as int?) == 1,
        sortOrder: (m['sort_order'] as int?) ?? 0,
        isPredefined: (m['is_predefined'] as int?) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'key': key,
        'label_ar': labelAr,
        'label_en': labelEn,
        'is_enabled': isEnabled ? 1 : 0,
        'is_default': isDefault ? 1 : 0,
        'sort_order': sortOrder,
        'is_predefined': isPredefined ? 1 : 0,
      };

  PaymentMethod copyWith({
    int? id,
    String? key,
    String? labelAr,
    String? labelEn,
    bool? isEnabled,
    bool? isDefault,
    int? sortOrder,
    bool? isPredefined,
  }) =>
      PaymentMethod(
        id: id ?? this.id,
        key: key ?? this.key,
        labelAr: labelAr ?? this.labelAr,
        labelEn: labelEn ?? this.labelEn,
        isEnabled: isEnabled ?? this.isEnabled,
        isDefault: isDefault ?? this.isDefault,
        sortOrder: sortOrder ?? this.sortOrder,
        isPredefined: isPredefined ?? this.isPredefined,
      );
}
