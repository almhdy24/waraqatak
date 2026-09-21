import 'package:http/http.dart' as http;

import '../http_client.dart';
import '../models/license_activation.dart';
import '../models/order.dart';
import '../models/payment_method.dart';

class PublicApi {
  final HttpClient _http;

  PublicApi._(this._http);

  factory PublicApi.create(HttpClient http) => PublicApi._(http);

  /// Lists all active payment methods available to buyers.
  Future<List<PaymentMethod>> getPaymentMethods() async {
    final json = await _http.get('/pay/payment-methods');
    return (json['data'] as List)
        .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Submits a new payment order.
  ///
  /// Automatically uses multipart/form-data when [CreateOrderRequest.proofFileBytes]
  /// is set, plain JSON otherwise. Accepted proof MIME types: image/jpeg, image/png,
  /// image/webp, image/gif, application/pdf (max 10 MB — validated server-side).
  ///
  /// Throws [ElmahdiPayRateLimitException] if the IP exceeds 5 requests/hour.
  Future<CreateOrderResult> createOrder(CreateOrderRequest request) async {
    if (request.hasFile) {
      final json = await _http.postMultipart(
        '/pay/orders',
        fields: request.toFields(),
        files: [
          http.MultipartFile.fromBytes(
            'proof_file',
            request.proofFileBytes!,
            filename: request.proofFileName!,
          ),
        ],
      );
      return CreateOrderResult.fromJson(json);
    }
    final json = await _http.post('/pay/orders', body: request.toJson());
    return CreateOrderResult.fromJson(json);
  }

  /// Returns the status of an order by its reference (e.g. `ORD-ABC12345`).
  ///
  /// [Order.license] is populated when approved; [Order.adminNote] when rejected.
  ///
  /// Throws [ElmahdiPayNotFoundException] if the reference does not exist.
  Future<Order> getOrder(String reference) async {
    final json = await _http.get('/pay/orders/$reference');
    return Order.fromJson(json);
  }

  /// Activates [ActivateLicenseRequest.licenseKey] on a device.
  ///
  /// Returns an [ActivateLicenseResult] containing a signed [activationToken]
  /// for offline verification.
  ///
  /// Throws [ElmahdiPayForbiddenException] when the license is revoked or expired.
  /// Throws [ElmahdiPayNotFoundException] when the license key is invalid.
  /// Throws [ElmahdiPayAlreadyActivatedException] (409) when already activated
  /// on a different machine — admin must reset the activation first.
  Future<ActivateLicenseResult> activateLicense(
    ActivateLicenseRequest request,
  ) async {
    final json =
        await _http.post('/pay/licenses/activate', body: request.toJson());
    return ActivateLicenseResult.fromJson(json);
  }
}
