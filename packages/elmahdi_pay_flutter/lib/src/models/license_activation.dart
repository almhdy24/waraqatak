import 'enums.dart';

/// Simplified activation record returned by the admin activations endpoint.
class LicenseActivation {
  final int id;
  final String deviceId;
  final String? deviceLabel;
  final ActivationStatus status;
  final DateTime activatedAt;
  final DateTime lastSeenAt;

  const LicenseActivation({
    required this.id,
    required this.deviceId,
    this.deviceLabel,
    required this.status,
    required this.activatedAt,
    required this.lastSeenAt,
  });

  factory LicenseActivation.fromJson(Map<String, dynamic> json) =>
      LicenseActivation(
        id: int.parse(json['id'].toString()),
        deviceId: json['device_id'] as String,
        deviceLabel: json['device_label'] as String?,
        status: ActivationStatus.fromString(json['status'] as String),
        activatedAt: _dt(json['activated_at'] as String),
        lastSeenAt: _dt(json['last_seen_at'] as String),
      );
}

/// Request body for POST /api/v1/pay/licenses/activate.
class ActivateLicenseRequest {
  final String licenseKey;

  /// Machine identifier — stored as [machine_id] on the server.
  final String machineId;

  const ActivateLicenseRequest({
    required this.licenseKey,
    required this.machineId,
  });

  Map<String, dynamic> toJson() => {
        'license_key': licenseKey,
        'machine_id': machineId,
      };
}

/// Successful response from POST /api/v1/pay/licenses/activate.
///
/// The [activationToken] is a signed JWT-style token the app can persist for
/// offline verification.
class ActivateLicenseResult {
  final String activationToken;

  const ActivateLicenseResult({required this.activationToken});

  factory ActivateLicenseResult.fromJson(Map<String, dynamic> json) =>
      ActivateLicenseResult(
        activationToken: json['activation_token'] as String,
      );
}

DateTime _dt(String s) => DateTime.parse(s.replaceAll(' ', 'T'));
