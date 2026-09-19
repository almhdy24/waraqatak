import 'dart:typed_data';

import 'enums.dart';
import 'license.dart';
import 'payment_method.dart';

class Order {
  final String reference;
  final String appSlug;
  final String buyerName;
  final double amount;
  final String currency;
  final PaymentMethod? paymentMethod;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Non-null when [status] is [OrderStatus.approved].
  final License? license;

  /// Non-null when [status] is [OrderStatus.rejected].
  final String? adminNote;

  const Order({
    required this.reference,
    required this.appSlug,
    required this.buyerName,
    required this.amount,
    required this.currency,
    this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.license,
    this.adminNote,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('data')
        ? json['data'] as Map<String, dynamic>
        : json;
    return Order(
      reference: data['reference'] as String,
      appSlug: data['app_slug'] as String,
      buyerName: data['buyer_name'] as String,
      amount: _parseAmount(data['amount']),
      currency: data['currency'] as String,
      paymentMethod: data['payment_method'] != null
          ? PaymentMethod.fromJson(
              data['payment_method'] as Map<String, dynamic>)
          : null,
      status: OrderStatus.fromString(data['status'] as String),
      createdAt: _dt(data['created_at'] as String),
      updatedAt: _dt(data['updated_at'] as String),
      license: data['license'] != null
          ? License.fromJson(data['license'] as Map<String, dynamic>)
          : null,
      adminNote: data['admin_note'] as String?,
    );
  }
}

class CreateOrderRequest {
  final String appSlug;
  final int paymentMethodId;
  final String buyerName;
  final String buyerContact;
  final double amount;
  final String currency;
  final String? proofNote;

  /// Optional idempotency key (max 64 chars). Use [ElmahdiPayClient.generateIdempotencyKey].
  final String? idempotencyKey;

  /// Raw bytes of the proof file. Requires [proofFileName].
  final Uint8List? proofFileBytes;

  /// Filename sent with the upload. The server detects MIME from file content — extension is for display only.
  final String? proofFileName;

  const CreateOrderRequest({
    required this.appSlug,
    required this.paymentMethodId,
    required this.buyerName,
    required this.buyerContact,
    required this.amount,
    required this.currency,
    this.proofNote,
    this.idempotencyKey,
    this.proofFileBytes,
    this.proofFileName,
  }) : assert(
          proofFileBytes == null || proofFileName != null,
          'proofFileName is required when proofFileBytes is provided',
        );

  Map<String, String> toFields() => {
        'app_slug': appSlug,
        'payment_method_id': paymentMethodId.toString(),
        'buyer_name': buyerName,
        'buyer_contact': buyerContact,
        'amount': amount.toString(),
        'currency': currency,
        if (proofNote != null) 'proof_note': proofNote!,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey!,
      };

  Map<String, dynamic> toJson() => {
        'app_slug': appSlug,
        'payment_method_id': paymentMethodId,
        'buyer_name': buyerName,
        'buyer_contact': buyerContact,
        'amount': amount,
        'currency': currency,
        if (proofNote != null) 'proof_note': proofNote,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      };

  bool get hasFile => proofFileBytes != null;
}

class CreateOrderResult {
  final String reference;
  final OrderStatus status;
  final PaymentMethod? paymentMethod;

  /// True when the server returned a cached result for this idempotency key.
  final bool idempotent;

  const CreateOrderResult({
    required this.reference,
    required this.status,
    this.paymentMethod,
    this.idempotent = false,
  });

  factory CreateOrderResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return CreateOrderResult(
      reference: data['reference'] as String,
      status: OrderStatus.fromString(data['status'] as String),
      paymentMethod: data['payment_method'] != null
          ? PaymentMethod.fromJson(
              data['payment_method'] as Map<String, dynamic>)
          : null,
      idempotent: json['idempotent'] as bool? ?? false,
    );
  }
}

// PHP PDO returns DECIMAL columns as strings; handle both.
double _parseAmount(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.parse(v);
  throw ArgumentError('Unexpected amount type: ${v.runtimeType}');
}

DateTime _dt(String s) => DateTime.parse(s.replaceAll(' ', 'T'));
