import 'package:elmahdi_api/elmahdi_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../models/subscription_plan.dart';
import '../services/license_service.dart';
import '../services/subscription_service.dart';
import 'payment_flow_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Entitlement
  EntitlementState? _entitlement;
  bool _entitlementLoading = true;

  // Plans (server-loaded)
  List<SubscriptionPlan> _plans = [];
  bool _plansLoading = true;
  String? _plansError;
  SubscriptionPlan? _selected;

  bool _showRenewal = false;

  @override
  void initState() {
    super.initState();
    _loadEntitlement();
    _loadPlans();
  }

  Future<void> _loadEntitlement() async {
    final s = await LicenseService.instance.checkEntitlement();
    if (!mounted) return;
    setState(() {
      _entitlement = s;
      _entitlementLoading = false;
    });
  }

  Future<void> _loadPlans() async {
    setState(() {
      _plansLoading = true;
      _plansError = null;
    });
    try {
      final plans = await SubscriptionService.fetchPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _plansLoading = false;
        if (_selected == null && plans.isNotEmpty) {
          _selected = plans.last;
        }
      });
    } on NetworkException {
      if (!mounted) return;
      setState(() {
        _plansLoading = false;
        _plansError = AppLocalizations.of(context).networkError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plansLoading = false;
        _plansError = AppLocalizations.of(context).plansLoadError;
      });
    }
  }

  bool get _isLicensed => _entitlement?.status == EntitlementStatus.licensed;

  Future<void> _subscribe() async {
    final plan = _selected;
    if (plan == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PaymentFlowScreen(plan: plan)),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F3),
      appBar: AppBar(
        title: Text(l10n.subscription),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _entitlementLoading
          ? const Center(child: CircularProgressIndicator())
          : _isLicensed && !_showRenewal
              ? _buildLicensedView(l10n, cs)
              : _buildPlansView(l10n, cs),
    );
  }

  // ── Licensed view ─────────────────────────────────────────────────────────

  Widget _buildLicensedView(AppLocalizations l10n, ColorScheme cs) {
    final e = _entitlement!;
    final expiryStr =
        e.licenseExpiresAt?.toLocal().toString().split(' ').first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 56),
              const SizedBox(height: 12),
              Text(
                l10n.licensedStatus,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.licenseActiveDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (expiryStr != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '${l10n.licenseExpiresOn}  $expiryStr',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 18, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.dataAlwaysSafe,
                  style:
                      TextStyle(fontSize: 12, color: Colors.green.shade800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showRenewal = true),
          icon: const Icon(Icons.autorenew_rounded),
          label: Text(l10n.renewEarly),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: cs.primary),
            foregroundColor: cs.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // ── Plans view ────────────────────────────────────────────────────────────

  Widget _buildPlansView(AppLocalizations l10n, ColorScheme cs) {
    final isRenewal = _isLicensed ||
        _entitlement?.status == EntitlementStatus.licenseExpired;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (_showRenewal)
          _BackTile(onTap: () => setState(() => _showRenewal = false)),

        _Header(entitlement: _entitlement, l10n: l10n, cs: cs),
        const SizedBox(height: 24),

        Text(l10n.choosePlan,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          l10n.limitedPromoOffer,
          style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        // Plans content: loading / error / cards
        if (_plansLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_plansError != null)
          _PlansErrorTile(error: _plansError!, onRetry: _loadPlans, l10n: l10n)
        else if (_plans.isEmpty)
          _PlansErrorTile(
              error: l10n.plansLoadError, onRetry: _loadPlans, l10n: l10n)
        else
          ..._plans.map((plan) => _PlanCard(
                plan: plan,
                isSelected: _selected?.id == plan.id,
                l10n: l10n,
                cs: cs,
                onTap: () => setState(() => _selected = plan),
              )),

        const SizedBox(height: 12),
        _TrustRow(l10n: l10n),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: (_selected != null && !_plansLoading) ? _subscribe : null,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              isRenewal ? l10n.renewNow : l10n.subscribeNow,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 20),
        _RestoreKeyTile(onRestored: () {
          LicenseService.instance.invalidateCache();
          Navigator.pop(context, true);
        }),
      ],
    );
  }
}

// ── Back tile ─────────────────────────────────────────────────────────────────

class _BackTile extends StatelessWidget {
  final VoidCallback onTap;
  const _BackTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).licensedStatus,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
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

    final isExpired = s.status == EntitlementStatus.licenseExpired ||
        s.status == EntitlementStatus.trialExpired;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpired
            ? cs.error.withValues(alpha: 0.08)
            : cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? cs.error.withValues(alpha: 0.3)
              : cs.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        s.status == EntitlementStatus.licenseExpired
            ? l10n.licenseExpiredBody
            : l10n.trialExpiredBody,
        style: TextStyle(
            fontSize: 14, color: isExpired ? cs.error : cs.primary),
      ),
    );
  }
}

// ── Plans error tile ──────────────────────────────────────────────────────────

class _PlansErrorTile extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final AppLocalizations l10n;
  const _PlansErrorTile(
      {required this.error, required this.onRetry, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.error)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(l10n.retry),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
            ),
          ),
        ],
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
    final borderColor = isSelected ? cs.primary : cs.outlineVariant;
    final bg =
        isSelected ? cs.primary.withValues(alpha: 0.06) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    _badge(l10n.mostPopularBadge, cs.primary, Colors.white)
                  else if (plan.hasDiscount)
                    _badge(l10n.limitedPromoOffer, Colors.orange.shade50,
                        Colors.orange.shade800,
                        border: Colors.orange.shade300),
                ],
              ),
              const SizedBox(height: 10),
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

  Widget _badge(String text, Color bg, Color fg, {Color? border}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: Text(text,
            style: TextStyle(
                color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

// ── Restore License Key Tile ──────────────────────────────────────────────────

class _RestoreKeyTile extends StatelessWidget {
  final VoidCallback onRestored;
  const _RestoreKeyTile({required this.onRestored});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _showSheet(context, l10n, cs),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.vpn_key_outlined,
                size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.haveALicenseKey,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(l10n.formattedPhoneNote,
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          height: 1.4)),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet(
      BuildContext context, AppLocalizations l10n, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _KeyEntrySheet(l10n: l10n, cs: cs, onRestored: onRestored),
    );
  }
}

class _KeyEntrySheet extends StatefulWidget {
  final AppLocalizations l10n;
  final ColorScheme cs;
  final VoidCallback onRestored;
  const _KeyEntrySheet(
      {required this.l10n, required this.cs, required this.onRestored});

  @override
  State<_KeyEntrySheet> createState() => _KeyEntrySheetState();
}

class _KeyEntrySheetState extends State<_KeyEntrySheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deviceId = await LicenseService.instance.getOrCreateDeviceId();
      await SubscriptionService.activateByKey(key, deviceId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onRestored();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.isForbidden
            ? widget.l10n.invalidLicenseKey
            : widget.l10n.serverError;
      });
    } on NetworkException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.l10n.networkError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.l10n.operationFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final cs = widget.cs;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(l10n.restoreLicense,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(l10n.formattedPhoneNote,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.4)),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.enterLicenseKey,
                hintText: l10n.licenseKeyHint,
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                errorText: _error,
              ),
              onSubmitted: (_) => _activate(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _loading ? null : _activate,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(l10n.activate,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security_outlined,
              size: 14, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Flexible(
            child: Text(l10n.dataAlwaysSafe,
                maxLines: 2,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
        ],
      );
}
