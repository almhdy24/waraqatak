import 'dart:typed_data';

import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';

import 'license_service.dart';

/// Thin wrapper around the Elmahdi Pay SDK.
///
/// - Never stores admin tokens or server secrets in the APK.
/// - Idempotency key is generated once and persisted before each order
///   so retries never duplicate orders.
class SubscriptionService {
  SubscriptionService._();

  // ── Configuration ──────────────────────────────────────────────────────────
  // Server URL for the Elmahdi Pay backend. Update this after deployment.
  static const String serverUrl = 'https://pay.elmahdi.dev';
  static const String _appSlug  = 'com.elmahdi.waraqatak';
  static const String _currency  = 'SDG';

  // ── SDK client (lazy singleton) ────────────────────────────────────────────

  static ElmahdiPayClient? _client;

  static ElmahdiPayClient get _sdk {
    _client ??= ElmahdiPayClient(
      ElmahdiPayConfig(
        baseUrl: serverUrl,
        timeout: const Duration(seconds: 20),
      ),
    );
    return _client!;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<List<PaymentMethod>> getPaymentMethods() =>
      _sdk.public.getPaymentMethods();

  /// Create (or idempotently re-fetch) an order for [amount] SDG.
  ///
  /// Generates and persists an idempotency key before the network call so
  /// that retrying after a timeout never creates a duplicate order.
  static Future<CreateOrderResult> createOrder({
    required int paymentMethodId,
    required String buyerName,
    required String buyerContact,
    required double amount,
    String? proofNote,
    Uint8List? proofFileBytes,
    String? proofFileName,
  }) async {
    var ikey = await LicenseService.instance.getSavedIdempotencyKey();
    if (ikey == null) {
      ikey = ElmahdiPayClient.generateIdempotencyKey();
      await LicenseService.instance.saveIdempotencyKey(ikey);
    }

    final result = await _sdk.public.createOrder(CreateOrderRequest(
      appSlug: _appSlug,
      paymentMethodId: paymentMethodId,
      buyerName: buyerName,
      buyerContact: buyerContact,
      amount: amount,
      currency: _currency,
      proofNote: proofNote,
      idempotencyKey: ikey,
      proofFileBytes: proofFileBytes,
      proofFileName: proofFileName,
    ));

    await LicenseService.instance.setOrderPending(result.reference);
    return result;
  }

  static Future<Order> getOrder(String reference) =>
      _sdk.public.getOrder(reference);

  /// Activate [license] on this device and persist it locally.
  ///
  /// Uses the same [deviceId] that was created on first launch — never
  /// generates a new one for renewal or re-activation.
  static Future<ActivateLicenseResult> activateAndStore(
    License license,
    String deviceId,
  ) async {
    final result = await _sdk.public.activateLicense(
      ActivateLicenseRequest(
        licenseKey: license.licenseKey,
        deviceId: deviceId,
      ),
    );

    await LicenseService.instance.storeLicense(
      licenseKey: license.licenseKey,
      expiresAt: license.expiresAt,
      isActive: license.status == LicenseStatus.active,
    );

    return result;
  }

  /// Retry activation using the stored license key (e.g. after device limit
  /// was resolved by admin deactivating another device).
  static Future<ActivateLicenseResult> retryActivation(
    String licenseKey,
    String deviceId,
  ) =>
      _sdk.public.activateLicense(
        ActivateLicenseRequest(licenseKey: licenseKey, deviceId: deviceId),
      );

  static void close() {
    _client?.close();
    _client = null;
  }
}
