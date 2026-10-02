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
