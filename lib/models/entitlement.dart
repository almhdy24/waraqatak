/// Subscription entitlement — what the user is allowed to do.
///
/// Order state (pending / rejected) is tracked separately in [PendingOrderStatus]
/// so that a user with an active trial or valid license is never blocked from
/// the app just because they also happen to have an order under review.
enum EntitlementStatus {
  trialActive,
  trialExpired,
  licensed,
  licenseExpired,
  licenseRevoked,
}

/// State of the most-recently submitted payment order.
///
/// Stored alongside — not instead of — the subscription entitlement.
enum PendingOrderStatus {
  none,
  pending,
  rejected,
}

class EntitlementState {
  final EntitlementStatus status;
  final String deviceId;

  /// Days remaining including today (only meaningful for [EntitlementStatus.trialActive]).
  final int trialDaysRemaining;

  final DateTime? licenseExpiresAt;

  // ── Order tracking (independent of subscription entitlement) ───────────────
  final PendingOrderStatus orderStatus;
  final String? orderReference;
  final String? rejectionNote;

  const EntitlementState({
    required this.status,
    required this.deviceId,
    this.trialDaysRemaining = 0,
    this.licenseExpiresAt,
    this.orderStatus = PendingOrderStatus.none,
    this.orderReference,
    this.rejectionNote,
  });

  /// True when the user may create documents and use paid features.
  bool get isSubscriptionActive =>
      status == EntitlementStatus.trialActive ||
      status == EntitlementStatus.licensed;
}
