import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../models/subscription_plan.dart';
import '../services/license_service.dart';
import 'payment_flow_screen.dart';

/// Arabic-RTL subscription / plan selection screen.
///
/// Returns [true] if the user successfully activates a license so the caller
/// can navigate to the main shell.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionPlan _selected = SubscriptionPlan.plans.last; // annual default
  EntitlementState? _entitlement;
  bool _loadingState = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await LicenseService.instance.checkEntitlement();
    if (!mounted) return;
    setState(() {
      _entitlement = s;
      _loadingState = false;
    });
  }

  Future<void> _subscribe() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => PaymentFlowScreen(plan: _selected)),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isRenewal = _entitlement?.status == EntitlementStatus.licenseExpired;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F3),
      appBar: AppBar(
        title: Text(l10n.subscription),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loadingState
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                // ── Header ──────────────────────────────────────────────────
                _Header(entitlement: _entitlement, l10n: l10n, cs: cs),
                const SizedBox(height: 24),

                // ── Plans ────────────────────────────────────────────────────
                Text(l10n.choosePlan,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  l10n.limitedPromoOffer,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...SubscriptionPlan.plans.map((plan) => _PlanCard(
                      plan: plan,
                      isSelected: _selected.id == plan.id,
                      l10n: l10n,
                      cs: cs,
                      onTap: () => setState(() => _selected = plan),
                    )),

                const SizedBox(height: 12),

                // ── Trust signals ────────────────────────────────────────────
                _TrustRow(l10n: l10n),
                const SizedBox(height: 24),

                // ── CTA ──────────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _subscribe,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      isRenewal ? l10n.renewNow : l10n.subscribeNow,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final EntitlementState? entitlement;
  final AppLocalizations l10n;
  final ColorScheme cs;
  const _Header(
      {required this.entitlement, required this.l10n, required this.cs});

  @override
  Widget build(BuildContext context) {
    final s = entitlement;
    if (s == null) return const SizedBox.shrink();

    if (s.status == EntitlementStatus.trialActive) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.trialActiveStatus,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              '${s.trialDaysRemaining} ${l10n.daysLeftInTrial}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(l10n.trialFreeDays,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        s.status == EntitlementStatus.licenseExpired
            ? l10n.licenseExpiredBody
            : l10n.trialExpiredBody,
        style: TextStyle(fontSize: 14, color: cs.error),
      ),
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final AppLocalizations l10n;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.l10n,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? cs.primary : cs.outlineVariant;
    final bg = isSelected
        ? cs.primary.withValues(alpha: 0.06)
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: Text(plan.name(l10n.langCode),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? cs.primary : null)),
                  ),
                  if (plan.isMostPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.mostPopularBadge,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (plan.hasDiscount)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        l10n.limitedPromoOffer,
                        style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Prices row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${SubscriptionPlan.fmt(plan.priceSDG)} SDG',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? cs.primary : null),
                  ),
                  if (plan.hasDiscount) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${SubscriptionPlan.fmt(plan.originalPriceSDG!)} SDG',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // Savings + monthly equivalent
              if (plan.savingsSDG != null)
                Text(
                  '${l10n.saveBadge} ${SubscriptionPlan.fmt(plan.savingsSDG!)} SDG',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600),
                ),
              if (plan.durationDays >= 90)
                Text(
                  '${l10n.equivalentMonthly} ${SubscriptionPlan.fmt(plan.monthlyEquivalentSDG)} SDG ${l10n.perMonthSuffix}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),

              // Renewal indicator
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.autorenew, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(l10n.subscriptionRenewable,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Trust Row ─────────────────────────────────────────────────────────────────

class _TrustRow extends StatelessWidget {
  final AppLocalizations l10n;
  const _TrustRow({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chip(Icons.security_outlined, l10n.dataAlwaysSafe),
      ],
    );
  }

  Widget _chip(IconData icon, String label) => Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
            ),
          ],
        ),
      );
}
