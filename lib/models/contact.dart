class Contact {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String type; // customer / supplier

  const Contact({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.type = 'customer',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'type': type,
      };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        type: map['type'] as String? ?? 'customer',
      );
}