import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/license_service.dart';
import '../services/subscription_service.dart';
import 'main_shell.dart';
import 'subscription_screen.dart';

/// Shown when the user has no valid entitlement (trial expired, license
/// expired/revoked, etc.). Never deletes or corrupts local data.
class PaywallScreen extends StatefulWidget {
  final EntitlementState state;
  const PaywallScreen({super.key, required this.state});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _retrying = false;
  bool _checking = false;

  Future<void> _openSubscription() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
    if (result == true && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
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
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
              (_) => false,
            );
          } on ElmahdiPayForbiddenException catch (e) {
            if (e.maxDevices != null) {
              await LicenseService.instance.storeLicense(
                licenseKey: license.licenseKey,
                expiresAt: license.expiresAt,
                isActive: true,
              );
              await LicenseService.instance.markDeviceLimitReached();
            }
            if (!mounted) return;
            _showError(AppLocalizations.of(context).deviceLimitStatus);
          } catch (e) {
            if (!mounted) return;
            _showError(AppLocalizations.of(context).operationFailed);
          }
        case OrderStatus.pending:
          _showInfo(AppLocalizations.of(context).orderPendingBody);
        case OrderStatus.rejected:
          await LicenseService.instance.setOrderRejected(ref, order.adminNote);
          if (!mounted) return;
          _showError('${AppLocalizations.of(context).rejectionReason}: ${order.adminNote ?? ''}');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context).operationFailed);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _retryDeviceActivation() async {
    setState(() => _retrying = true);
    try {
      final key = await LicenseService.instance.licenseKey;
      final deviceId = widget.state.deviceId;
      if (key == null || key.isEmpty) {
        if (!mounted) return;
        _showError(AppLocalizations.of(context).operationFailed); // ignore: use_build_context_synchronously
        return;
      }
      await LicenseService.instance.clearDeviceLimitFlag();
      await SubscriptionService.retryActivation(key, deviceId);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } on ElmahdiPayForbiddenException catch (e) {
      await LicenseService.instance.markDeviceLimitReached();
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      _showError(e.maxDevices != null
          ? '${l.deviceLimitStatus}: ${e.activeDevices}/${e.maxDevices}'
          : l.licenseRevokedStatus);
    } catch (_) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context).operationFailed);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
              // Logo / branding
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

              // Status card
              _StatusCard(state: s, l10n: l10n),

              const Spacer(),

              // Data safety
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.green.shade700, size: 20),
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

              // Primary CTA
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
    switch (s.status) {
      case EntitlementStatus.orderPending:
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

      case EntitlementStatus.deviceLimitReached:
        return [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _retrying ? null : _retryDeviceActivation,
              child: _retrying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(l10n.tryAgain),
            ),
          ),
        ];

      case EntitlementStatus.licenseRevoked:
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

      case EntitlementStatus.orderRejected:
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

      default: // trialExpired, licenseExpired
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
}

class _StatusCard extends StatelessWidget {
  final EntitlementState state;
  final AppLocalizations l10n;
  const _StatusCard({required this.state, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (title, body, color, icon) = switch (state.status) {
      EntitlementStatus.trialExpired => (
          l10n.trialExpiredHeadline,
          l10n.trialExpiredBody,
          cs.error,
          Icons.timer_off_outlined,
        ),
      EntitlementStatus.licenseExpired => (
          l10n.licenseExpiredHeadline,
          l10n.licenseExpiredBody,
          cs.error,
          Icons.event_busy_outlined,
        ),
      EntitlementStatus.licenseRevoked => (
          l10n.licenseRevokedStatus,
          l10n.contactUs,
          Colors.orange,
          Icons.block_outlined,
        ),
      EntitlementStatus.orderPending => (
          l10n.orderPendingStatus,
          '${l10n.orderReferenceLabel}: ${state.orderReference ?? ''}\n\n${l10n.orderPendingBody}',
          cs.primary,
          Icons.pending_outlined,
        ),
      EntitlementStatus.orderRejected => (
          l10n.orderRejectedStatus,
          state.rejectionNote?.isNotEmpty == true
              ? '${l10n.rejectionReason}: ${state.rejectionNote}'
              : l10n.orderRejectedStatus,
          cs.error,
          Icons.cancel_outlined,
        ),
      EntitlementStatus.deviceLimitReached => (
          l10n.deviceLimitStatus,
          l10n.contactUs,
          Colors.orange,
          Icons.devices_outlined,
        ),
      _ => (l10n.subscribeNow, '', cs.primary, Icons.lock_outline),
    };

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
