import 'package:elmahdi_api/elmahdi_api.dart';
import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/license_service.dart';
import '../services/subscription_service.dart';
import 'subscription_screen.dart';

/// Shown when the user has a pending or rejected order, or when routed here
/// from an expired/revoked state banner.
///
/// Returns [true] via [Navigator.pop] when a license is successfully activated,
/// so callers can refresh their entitlement state.
///
/// Never deletes or corrupts local data.
class PaywallScreen extends StatefulWidget {
  final EntitlementState state;
  const PaywallScreen({super.key, required this.state});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _checking = false;

  /// Route to SubscriptionScreen. On success, pop this screen with true so
  /// the caller (HomeScreen) refreshes entitlement.
  Future<void> _openSubscription() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _checkOrderStatus() async {
    final ref = widget.state.orderReference;
    if (ref == null) return;
    setState(() => _checking = true);
    try {
      final order = await SubscriptionService.getOrder(ref);
      if (!mounted) return;
      switch (order.status) {
        case OrderStatus.approved:
          final license = order.license!;
          final deviceId = widget.state.deviceId;
          try {
            await SubscriptionService.activateAndStore(license, deviceId);
            if (!mounted) return;
            Navigator.pop(context, true);
          } on ApiException catch (e) {
            if (!mounted) return;
            final l = AppLocalizations.of(context);
            final String msg;
            if (e.isForbidden) {
              final maxDevices = e.body?['max_devices'] as int?;
              final activeDevices = e.body?['active'] as int?;
              msg = maxDevices != null
                  ? '${l.deviceLimitStatus}: ${activeDevices ?? '?'}/$maxDevices'
                  : l.licenseRevokedStatus;
            } else {
              msg = l.serverError;
            }
            _showError(msg);
          } catch (_) {
            if (!mounted) return;
            _showError(AppLocalizations.of(context).operationFailed);
          }
        case OrderStatus.pending:
          _showInfo(AppLocalizations.of(context).orderPendingBody);
        case OrderStatus.rejected:
          await LicenseService.instance.setOrderRejected(ref, order.adminNote);
          if (!mounted) return;
          _showError(
            '${AppLocalizations.of(context).rejectionReason}: ${order.adminNote ?? ''}',
          );
      }
    } catch (_) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context).operationFailed);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final s = widget.state;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long, size: 36, color: cs.primary),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.appTitle,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              _StatusCard(state: s, l10n: l10n),

              const Spacer(),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security,
                        color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.dataAlwaysSafe,
                        style: TextStyle(
                            fontSize: 13, color: Colors.green.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ..._buildActions(s, l10n, cs),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(
      EntitlementState s, AppLocalizations l10n, ColorScheme cs) {
    // ── Pending order: offer to check status or cancel ──────────────────────
    if (s.orderStatus == PendingOrderStatus.pending) {
      return [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _checking ? null : _checkOrderStatus,
            child: _checking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(l10n.checkOrderStatus),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await LicenseService.instance.clearOrder();
            if (!mounted) return;
            await _openSubscription();
          },
          child: Text(l10n.cancelAndResubmit),
        ),
      ];
    }

    // ── Rejected order: clear and let user resubmit ─────────────────────────
    if (s.orderStatus == PendingOrderStatus.rejected) {
      return [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () async {
              await LicenseService.instance.clearOrder();
              if (!mounted) return;
              await _openSubscription();
            },
            child: Text(l10n.tryAgain),
          ),
        ),
      ];
    }

    // ── Subscription state (no pending order) ───────────────────────────────
    if (s.status == EntitlementStatus.licenseRevoked) {
      return [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _openSubscription,
            child: Text(l10n.subscribeNow),
          ),
        ),
      ];
    }

    final isRenewal = s.status == EntitlementStatus.licenseExpired;
    return [
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _openSubscription,
          style: FilledButton.styleFrom(
              backgroundColor: cs.primary, foregroundColor: Colors.white),
          child: Text(isRenewal ? l10n.renewNow : l10n.subscribeNow),
        ),
      ),
    ];
  }
}

class _StatusCard extends StatelessWidget {
  final EntitlementState state;
  final AppLocalizations l10n;
  const _StatusCard({required this.state, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final String title;
    final String body;
    final Color color;
    final IconData icon;

    if (state.orderStatus == PendingOrderStatus.pending) {
      title = l10n.orderPendingStatus;
      body =
          '${l10n.orderReferenceLabel}: ${state.orderReference ?? ''}\n\n${l10n.orderPendingBody}';
      color = cs.primary;
      icon = Icons.pending_outlined;
    } else if (state.orderStatus == PendingOrderStatus.rejected) {
      title = l10n.orderRejectedStatus;
      body = state.rejectionNote?.isNotEmpty == true
          ? '${l10n.rejectionReason}: ${state.rejectionNote}'
          : l10n.orderRejectedStatus;
      color = cs.error;
      icon = Icons.cancel_outlined;
    } else {
      switch (state.status) {
        case EntitlementStatus.trialExpired:
          title = l10n.trialExpiredHeadline;
          body = l10n.trialExpiredBody;
          color = cs.error;
          icon = Icons.timer_off_outlined;
        case EntitlementStatus.licenseExpired:
          title = l10n.licenseExpiredHeadline;
          body = l10n.licenseExpiredBody;
          color = cs.error;
          icon = Icons.event_busy_outlined;
        case EntitlementStatus.licenseRevoked:
          title = l10n.licenseRevokedStatus;
          body = l10n.contactUs;
          color = Colors.orange;
          icon = Icons.block_outlined;
        default:
          title = l10n.subscribeNow;
          body = '';
          color = cs.primary;
          icon = Icons.lock_outline;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
