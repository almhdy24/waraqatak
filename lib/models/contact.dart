class Contact {
  static const String categoryRetail = 'retail';
  static const String categoryWholesale = 'wholesale';

  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String type; // customer / supplier
  final String pricingCategory; // retail / wholesale
  final bool active;
  final String? legalName;
  final String? taxId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Contact({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.type = 'customer',
    this.pricingCategory = categoryRetail,
    this.active = true,
    this.legalName,
    this.taxId,
    this.createdAt,
    this.updatedAt,
  });

  Contact copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    String? type,
    String? pricingCategory,
    bool? active,
    String? legalName,
    String? taxId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Contact(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        type: type ?? this.type,
        pricingCategory: pricingCategory ?? this.pricingCategory,
        active: active ?? this.active,
        legalName: legalName ?? this.legalName,
        taxId: taxId ?? this.taxId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'type': type,
        'pricing_category': pricingCategory,
        'active': active ? 1 : 0,
        'legal_name': legalName,
        'tax_id': taxId,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        notes: map['notes'] as String?,
        type: map['type'] as String? ?? 'customer',
        pricingCategory:
            map['pricing_category'] as String? ?? categoryRetail,
        active: (map['active'] as int? ?? 1) == 1,
        legalName: map['legal_name'] as String?,
        taxId: map['tax_id'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
      );
}
