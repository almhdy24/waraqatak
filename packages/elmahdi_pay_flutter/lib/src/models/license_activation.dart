/// Request body for POST /api/v1/pay/licenses/activate.
class ActivateLicenseRequest {
  final String licenseKey;

  /// Machine identifier — stored as [machine_id] on the server.
  final String machineId;

  /// Friendly device name (optional).
  final String? deviceName;

  /// Hardware device model (optional).
  final String? deviceModel;

  /// Target product slug (optional).
  final String? product;

  const ActivateLicenseRequest({
    required this.licenseKey,
    required this.machineId,
    this.deviceName,
    this.deviceModel,
    this.product,
  });

  Map<String, dynamic> toJson() => {
        'license_key': licenseKey,
        'machine_id': machineId,
        if (deviceName != null) 'device_name': deviceName,
        if (deviceModel != null) 'device_model': deviceModel,
        if (product != null) 'product': product,
      };
}

/// License metadata returned on short-key activation or verify.
class LicenseData {
  final String product;
  final String type; // 'perpetual' or 'timed'
  final String? issuedAt;
  final DateTime? expiresAt;
  final int maxDevices;

  const LicenseData({
    required this.product,
    required this.type,
    this.issuedAt,
    this.expiresAt,
    this.maxDevices = 1,
  });

  factory LicenseData.fromJson(Map<String, dynamic> json) {
    final expStr = json['expires_at']?.toString();
    final maxDev = json['max_devices'];
    return LicenseData(
      product: json['product']?.toString() ?? '',
      type: json['type']?.toString().toLowerCase() ?? 'perpetual',
      issuedAt: json['issued_at']?.toString(),
      expiresAt: (expStr != null && expStr.isNotEmpty)
          ? DateTime.tryParse(expStr)
          : null,
      maxDevices: maxDev is int
          ? maxDev
          : (int.tryParse(maxDev?.toString() ?? '') ?? 1),
    );
  }
}

/// Successful response from POST /api/v1/pay/licenses/activate.
///
/// Supports both legacy responses (activation_token) and short-key responses
/// (token + license object).
class ActivateLicenseResult {
  final String? activationToken;
  final String? token;
  final LicenseData? license;

  const ActivateLicenseResult({
    this.activationToken,
    this.token,
    this.license,
  });

  /// The active token returned by the server, whether under `token` or `activation_token`.
  String get effectiveToken => token ?? activationToken ?? '';

  factory ActivateLicenseResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final actToken = data['activation_token']?.toString();
    final tok = data['token']?.toString() ?? actToken;
    final licMap = data['license'] is Map<String, dynamic>
        ? data['license'] as Map<String, dynamic>
        : null;

    return ActivateLicenseResult(
      activationToken: actToken ?? tok,
      token: tok,
      license: licMap != null ? LicenseData.fromJson(licMap) : null,
    );
  }
}

/// Request body for POST /api/v1/pay/licenses/deactivate.
class DeactivateLicenseRequest {
  final String licenseKey;
  final String machineId;
  final String? reason;
  final String? product;

  const DeactivateLicenseRequest({
    required this.licenseKey,
    required this.machineId,
    this.reason,
    this.product,
  });

  Map<String, dynamic> toJson() => {
        'license_key': licenseKey,
        'machine_id': machineId,
        if (reason != null) 'reason': reason,
        if (product != null) 'product': product,
      };
}

/// Response from POST /api/v1/pay/licenses/deactivate.
class DeactivateLicenseResult {
  final bool success;
  final String code;
  final String message;
  final int activeDevices;
  final int maxDevices;

  const DeactivateLicenseResult({
    required this.success,
    required this.code,
    required this.message,
    required this.activeDevices,
    required this.maxDevices,
  });

  factory DeactivateLicenseResult.fromJson(Map<String, dynamic> json) {
    return DeactivateLicenseResult(
      success: (json['success'] as bool?) ?? false,
      code: (json['code'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      activeDevices: (json['active_devices'] as int?) ?? 0,
      maxDevices: (json['max_devices'] as int?) ?? 1,
    );
  }
}

/// Request body for POST /api/v1/pay/licenses/verify.
class VerifyLicenseRequest {
  final String tokenOrKey;
  final String? machineId;
  final String? product;

  const VerifyLicenseRequest({
    required this.tokenOrKey,
    this.machineId,
    this.product,
  });

  Map<String, dynamic> toJson() => {
        'token': tokenOrKey,
        if (machineId != null) 'machine_id': machineId,
        if (product != null) 'product': product,
      };
}

/// Response from POST /api/v1/pay/licenses/verify.
class VerifyLicenseResult {
  final bool success;
  final bool valid;
  final String? error;
  final String? message;
  final Map<String, dynamic>? data;

  const VerifyLicenseResult({
    required this.success,
    required this.valid,
    this.error,
    this.message,
    this.data,
  });

  factory VerifyLicenseResult.fromJson(Map<String, dynamic> json) {
    return VerifyLicenseResult(
      success: (json['success'] as bool?) ?? false,
      valid: (json['valid'] as bool?) ?? false,
      error: json['error'] as String?,
      message: json['message'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// Request body for POST /api/v1/pay/trial/claim.
class TrialClaimRequest {
  final String product;
  final String machineId;
  final String? deviceName;
  final String? deviceModel;

  const TrialClaimRequest({
    required this.product,
    required this.machineId,
    this.deviceName,
    this.deviceModel,
  });

  Map<String, dynamic> toJson() => {
        'product': product,
        'machine_id': machineId,
        if (deviceName != null) 'device_name': deviceName,
        if (deviceModel != null) 'device_model': deviceModel,
      };
}

/// Result of POST /api/v1/pay/trial/claim.
class TrialClaimResult {
  final bool success;
  final bool eligible;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int daysRemaining;
  final DateTime? serverTime;
  final String? product;

  const TrialClaimResult({
    required this.success,
    required this.eligible,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.daysRemaining = 0,
    this.serverTime,
    this.product,
  });

  factory TrialClaimResult.fromJson(Map<String, dynamic> json) {
    final trial = json['trial'] is Map<String, dynamic>
        ? json['trial'] as Map<String, dynamic>
        : json;
    return TrialClaimResult(
      success: json['success'] == true,
      eligible: json['eligible'] == true,
      status: trial['status']?.toString() ?? 'expired',
      startedAt: DateTime.tryParse(trial['started_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(trial['expires_at']?.toString() ?? ''),
      daysRemaining: (trial['days_remaining'] as num?)?.toInt() ?? 0,
      serverTime: DateTime.tryParse(trial['server_time']?.toString() ?? ''),
      product: trial['product']?.toString(),
    );
  }
}

/// Request body for POST /api/v1/pay/trial/status.
class TrialStatusRequest {
  final String product;
  final String machineId;

  const TrialStatusRequest({
    required this.product,
    required this.machineId,
  });

  Map<String, dynamic> toJson() => {
        'product': product,
        'machine_id': machineId,
      };
}

/// Result of POST /api/v1/pay/trial/status.
class TrialStatusResult {
  final bool success;
  final bool hasTrial;
  final bool eligible;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int daysRemaining;
  final DateTime? serverTime;

  const TrialStatusResult({
    required this.success,
    required this.hasTrial,
    required this.eligible,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.daysRemaining = 0,
    this.serverTime,
  });

  factory TrialStatusResult.fromJson(Map<String, dynamic> json) {
    final trial = json['trial'] is Map<String, dynamic>
        ? json['trial'] as Map<String, dynamic>
        : null;
    return TrialStatusResult(
      success: json['success'] == true,
      hasTrial: json['has_trial'] == true,
      eligible: json['eligible'] == true,
      status: trial?['status']?.toString() ?? 'none',
      startedAt: DateTime.tryParse(trial?['started_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(trial?['expires_at']?.toString() ?? ''),
      daysRemaining: (trial?['days_remaining'] as num?)?.toInt() ?? 0,
      serverTime: DateTime.tryParse(json['server_time']?.toString() ?? ''),
    );
  }
}
