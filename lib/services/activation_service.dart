import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';

import 'license_service.dart';

/// Thin wrapper around the Elmahdi Pay SDK used only for key activation.
///
/// Nothing is bought, priced, or paid for inside the app. The user enters a
/// previously obtained activation key here to unlock Pro features. The only
/// data sent to the server is the activation key and the per-install device
/// identifier.
class ActivationService {
  ActivationService._();

  static const String _serverUrl = 'https://api.almhdy24.com';

  static ElmahdiPayClient? _client;

  static ElmahdiPayClient get _sdk {
    _client ??= ElmahdiPayClient(
      ElmahdiPayConfig(
        baseUrl: _serverUrl,
        timeout: const Duration(seconds: 20),
      ),
    );
    return _client!;
  }

  /// Activate [activationKey] on this device and persist it locally.
  ///
  /// The device identifier reused here is the same one created on first launch
  /// so re-entering the same key never consumes an extra device slot.
  /// Throws the SDK's typed exceptions (invalid key, revoked, already
  /// activated, network, etc.) — callers map them to UI copy.
  static Future<void> activate(String activationKey, String deviceId) async {
    await _sdk.public.activateLicense(
      ActivateLicenseRequest(
        licenseKey: activationKey,
        machineId: deviceId,
      ),
    );

    await LicenseService.instance.storeLicense(
      licenseKey: activationKey,
      expiresAt: null,
      isActive: true,
    );
  }

  static void close() {
    _client?.close();
    _client = null;
  }
}
