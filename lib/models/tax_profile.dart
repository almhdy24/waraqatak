class TaxProfile {
  static const String modeExclusive = 'exclusive';
  static const String modeInclusive = 'inclusive';

  final int? id;
  final String name;
  final String type; // 'vat', 'sales_tax', 'service_charge', 'other'
  final double rate;
  final bool isActive;
  final bool isDefault;
  final String calculationMode;
  final String? notes;

  const TaxProfile({
    this.id,
    required this.name,
    this.type = 'vat',
    required this.rate,
    this.isActive = true,
    this.isDefault = false,
    this.calculationMode = modeExclusive,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'rate': rate,
        'is_active': isActive ? 1 : 0,
        'is_default': isDefault ? 1 : 0,
        'calculation_mode': calculationMode,
        'notes': notes,
      };

  factory TaxProfile.fromMap(Map<String, dynamic> map) => TaxProfile(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String? ?? 'vat',
        rate: (map['rate'] as num?)?.toDouble() ?? 0,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        isDefault: (map['is_default'] as int? ?? 0) == 1,
        calculationMode: map['calculation_mode'] as String? ?? modeExclusive,
        notes: map['notes'] as String?,
      );

  TaxProfile copyWith({
    int? id,
    String? name,
    String? type,
    double? rate,
    bool? isActive,
    bool? isDefault,
    String? calculationMode,
    String? notes,
  }) =>
      TaxProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        rate: rate ?? this.rate,
        isActive: isActive ?? this.isActive,
        isDefault: isDefault ?? this.isDefault,
        calculationMode: calculationMode ?? this.calculationMode,
        notes: notes ?? this.notes,
      );
}
