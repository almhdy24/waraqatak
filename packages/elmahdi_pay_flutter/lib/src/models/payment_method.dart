class PaymentMethod {
  final int id;
  final String name;
  final String currency;
  final String? instructions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.currency,
    this.instructions,
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: int.parse(json['id'].toString()),
        name: json['name'] as String,
        currency: json['currency'] as String,
        instructions: json['instructions'] as String?,
        createdAt: _dt(json['created_at'] as String?),
        updatedAt: _dt(json['updated_at'] as String?),
      );
}

DateTime? _dt(String? s) =>
    s == null ? null : DateTime.parse(s.replaceAll(' ', 'T'));
