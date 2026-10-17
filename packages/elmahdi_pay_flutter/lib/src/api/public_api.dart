import '../http_client.dart';
import '../models/license_activation.dart';

/// Activation-only public API.
///
/// This SDK is intentionally narrow: it supports a single operation —
/// activating a license key that the user obtained **outside the app**.
/// There are no order, payment, or pricing endpoints exposed to callers,
/// consistent with Google Play's consumption-only distribution model.
class PublicApi {
  final HttpClient _http;

  PublicApi._(this._http);

  factory PublicApi.create(HttpClient http) => PublicApi._(http);

  /// Activates [ActivateLicenseRequest.licenseKey] on this device.
  ///
  /// The request body contains only `license_key` and `machine_id`.
  /// Returns an [ActivateLicenseResult] containing a signed activation token.
  ///
  /// Throws [ElmahdiPayForbiddenException] when the license is revoked
  /// or the activation slot is already used by another device.
  /// Throws [ElmahdiPayNotFoundException] when the license key is invalid.
  /// Throws [ElmahdiPayAlreadyActivatedException] (409) when already
  /// activated on a different machine.
  Future<ActivateLicenseResult> activateLicense(
    ActivateLicenseRequest request,
  ) async {
    final json =
        await _http.post('/pay/licenses/activate', body: request.toJson());
    return ActivateLicenseResult.fromJson(json);
  }

  /// Deactivates [DeactivateLicenseRequest.licenseKey] on this device.
  ///
  /// Releases an activation slot on the licensing server.
  Future<DeactivateLicenseResult> deactivateLicense(
    DeactivateLicenseRequest request,
  ) async {
    final json =
        await _http.post('/pay/licenses/deactivate', body: request.toJson());
    return DeactivateLicenseResult.fromJson(json);
  }

  /// Verifies an activation token or license key online with the licensing server.
  Future<VerifyLicenseResult> verifyLicense(
    VerifyLicenseRequest request,
  ) async {
    final json =
        await _http.post('/pay/licenses/verify', body: request.toJson());
    return VerifyLicenseResult.fromJson(json);
  }
}
