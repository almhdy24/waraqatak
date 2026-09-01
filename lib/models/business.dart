import 'currency.dart';

class Business {
  final int? id;
  final String name;
  final String ownerName;
  final String phone;
  final String address;
  final String? email;
  final String? logoPath;
  final String currencyCode;
  final double taxRate;

  const Business({
    this.id,
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.address,
    this.email,
    this.logoPath,
    this.currencyCode = 'SDG',
    this.taxRate = 0,
  });

  String get currencySymbol => Currency.symbolForCode(currencyCode);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'address': address,
        'email': email,
        'logo_path': logoPath,
        'currency_code': currencyCode,
        'tax_rate': taxRate,
      };

  factory Business.fromMap(Map<String, dynamic> map) => Business(
        id: map['id'] as int?,
        name: map['name'] as String,
        ownerName: map['owner_name'] as String,
        phone: map['phone'] as String,
        address: map['address'] as String,
        email: map['email'] as String?,
        logoPath: map['logo_path'] as String?,
        currencyCode: map['currency_code'] as String? ?? 'SDG',
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
      );
}