import 'enums.dart';

class LicenseActivation {
  final int id;
  final int licenseId;
  final String deviceId;
  final String? deviceLabel;
  final ActivationStatus status;
  final DateTime activatedAt;
  final DateTime lastSeenAt;
  final DateTime? deactivatedAt;

  const LicenseActivation({
    required this.id,
    required this.licenseId,
    required this.deviceId,
    this.deviceLabel,
    required this.status,
    required this.activatedAt,
    required this.lastSeenAt,
    this.deactivatedAt,
  });

  factory LicenseActivation.fromJson(Map<String, dynamic> json) =>
      LicenseActivation(
        id: json['id'] as int,
        licenseId: json['license_id'] as int,
        deviceId: json['device_id'] as String,
        deviceLabel: json['device_label'] as String?,
        status: ActivationStatus.fromString(json['status'] as String),
        activatedAt: _dt(json['activated_at'] as String),
        lastSeenAt: _dt(json['last_seen_at'] as String),
        deactivatedAt: _dtOpt(json['deactivated_at'] as String?),
      );
}

class ActivateLicenseRequest {
  final String licenseKey;
  final String deviceId;
  final String? deviceLabel;

  const ActivateLicenseRequest({
    required this.licenseKey,
    required this.deviceId,
    this.deviceLabel,
  });

  Map<String, dynamic> toJson() => {
        'license_key': licenseKey,
        'device_id': deviceId,
        if (deviceLabel != null) 'device_label': deviceLabel,
      };
}

class ActivateLicenseResult {
  final LicenseActivation activation;

  /// True when this device was already activated — [LicenseActivation.lastSeenAt] was updated.
  final bool reactivated;

  const ActivateLicenseResult({
    required this.activation,
    required this.reactivated,
  });

  factory ActivateLicenseResult.fromJson(Map<String, dynamic> json) =>
      ActivateLicenseResult(
        activation:
            LicenseActivation.fromJson(json['data'] as Map<String, dynamic>),
        reactivated: json['reactivated'] as bool? ?? false,
      );
}

DateTime _dt(String s) => DateTime.parse(s.replaceAll(' ', 'T'));
DateTime? _dtOpt(String? s) => s == null ? null : _dt(s);
