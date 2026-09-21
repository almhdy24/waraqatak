class PaymentMethod {
  final int id;
  final String name;
  final String currency;
  final String? instructions;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.currency,
    this.instructions,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: int.parse(json['id'].toString()),
        name: json['name'] as String,
        currency: json['currency'] as String,
        instructions: json['instructions'] as String?,
      );
}
