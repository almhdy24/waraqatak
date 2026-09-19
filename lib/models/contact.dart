class Contact {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String type; // customer / supplier
  final bool active;
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
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'type': type,
        'active': active ? 1 : 0,
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
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
      );
}
