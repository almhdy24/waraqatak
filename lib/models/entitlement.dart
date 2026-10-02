/// Entitlement — what the user is allowed to do.
///
/// There are no purchases or orders in the app; Pro features are unlocked only
/// via an activation key entered on the activation screen.
enum EntitlementStatus {
  trialActive,
  trialExpired,
  licensed,
  licenseExpired,
  licenseRevoked,
}

class EntitlementState {
  final EntitlementStatus status;
  final String deviceId;

  /// Days remaining including today (only meaningful for [EntitlementStatus.trialActive]).
  final int trialDaysRemaining;

  final DateTime? licenseExpiresAt;

  const EntitlementState({
    required this.status,
    required this.deviceId,
    this.trialDaysRemaining = 0,
    this.licenseExpiresAt,
  });

  /// True when the user may use Pro features.
  bool get isSubscriptionActive =>
      status == EntitlementStatus.trialActive ||
      status == EntitlementStatus.licensed;
}
