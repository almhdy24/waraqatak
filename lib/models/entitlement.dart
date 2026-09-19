enum EntitlementStatus {
  trialActive,
  trialExpired,
  licensed,
  licenseExpired,
  licenseRevoked,
  orderPending,
  orderRejected,
  deviceLimitReached,
}

class EntitlementState {
  final EntitlementStatus status;
  final String deviceId;

  /// Days remaining including today (only meaningful when [status] is [EntitlementStatus.trialActive]).
  final int trialDaysRemaining;

  final DateTime? licenseExpiresAt;
  final String? orderReference;
  final String? rejectionNote;
  final int? maxDevices;
  final int? activeDevices;

  const EntitlementState({
    required this.status,
    required this.deviceId,
    this.trialDaysRemaining = 0,
    this.licenseExpiresAt,
    this.orderReference,
    this.rejectionNote,
    this.maxDevices,
    this.activeDevices,
  });

  bool get canUseApp =>
      status == EntitlementStatus.trialActive ||
      status == EntitlementStatus.licensed;
}
