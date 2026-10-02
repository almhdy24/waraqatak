import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter/foundation.dart';

import 'license_service.dart';

/// Thin wrapper around the Elmahdi Pay SDK.
///
/// - Never stores admin tokens or server secrets in the APK.
/// - Idempotency key is generated once and persisted before each order
///   so retries never duplicate orders.
class SubscriptionService {
  SubscriptionService._();

  // ── Configuration ──────────────────────────────────────────────────────────
  static const String serverUrl = 'https://api.almhdy24.com';
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
        machineId: deviceId,
      ),
    );

    await LicenseService.instance.storeLicense(
      licenseKey: license.licenseKey,
      expiresAt: license.expiresAt,
      isActive: license.status == LicenseStatus.active,
      activationToken: result.activationToken,
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
        ActivateLicenseRequest(licenseKey: licenseKey, machineId: deviceId),
      );

  /// Activate a license by key only — used when the user manually enters their
  /// key after formatting their phone or reinstalling the app.
  ///
  /// The activation response carries no expiry, so a previously stored expiry
  /// for the same key is kept. Server-side expiry or revocation is picked up by
  /// [revalidateStoredLicense].
  static Future<void> activateByKey(String licenseKey, String deviceId) async {
    final result = await _sdk.public.activateLicense(
      ActivateLicenseRequest(licenseKey: licenseKey, machineId: deviceId),
    );
    await LicenseService.instance.storeLicense(
      licenseKey: licenseKey,
      expiresAt: await LicenseService.instance.storedExpiryFor(licenseKey),
      isActive: true,
      activationToken: result.activationToken,
    );
  }

  /// Re-checks the stored license with the server, at most once per
  /// [LicenseService.revalidationInterval].
  ///
  /// Offline-first: network errors, rate limits and unexpected responses keep
  /// the current local state. Only a definitive server answer (403 revoked /
  /// expired, 404 unknown key) downgrades the license. Never throws.
  static Future<void> revalidateStoredLicense() async {
    try {
      final service = LicenseService.instance;
      if (!await service.needsRevalidation()) return;
      final key = await service.licenseKey;
      if (key == null || key.isEmpty) return;
      final deviceId = await service.getOrCreateDeviceId();

      try {
        final result = await _sdk.public.activateLicense(
          ActivateLicenseRequest(licenseKey: key, machineId: deviceId),
        );
        await service.markLicenseVerified(result.activationToken);
      } catch (e) {
        switch (classifyRevalidationError(e)) {
          case LicenseRevalidationOutcome.revoked:
            await service.markLicenseRevoked();
          case LicenseRevalidationOutcome.expired:
            await service.markLicenseExpired();
          case LicenseRevalidationOutcome.keep:
            break;
        }
      }
    } catch (e) {
      debugPrint('License revalidation skipped: $e');
    }
  }

  /// Maps an activation error during revalidation to the action to take.
  @visibleForTesting
  static LicenseRevalidationOutcome classifyRevalidationError(Object e) {
    if (e is ElmahdiPayNotFoundException) {
      return LicenseRevalidationOutcome.revoked;
    }
    if (e is ElmahdiPayForbiddenException) {
      // Device-limit responses are not a verdict on the license itself.
      if (e.maxDevices != null || e.activeDevices != null) {
        return LicenseRevalidationOutcome.keep;
      }
      return e.message.toLowerCase().contains('expir')
          ? LicenseRevalidationOutcome.expired
          : LicenseRevalidationOutcome.revoked;
    }
    return LicenseRevalidationOutcome.keep;
  }

  static void close() {
    _client?.close();
    _client = null;
  }
}

/// Result of re-checking a stored license with the server.
enum LicenseRevalidationOutcome { keep, revoked, expired }
