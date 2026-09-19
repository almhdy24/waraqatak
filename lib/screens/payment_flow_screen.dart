import 'dart:typed_data';

import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/subscription_plan.dart';
import '../services/license_service.dart';
import '../services/subscription_service.dart';

/// Multi-step payment flow:
///   Load methods → Fill form → Submit → Pending → Check status → Activate → Success
///
/// Returns [true] to the caller when the license is successfully activated.
class PaymentFlowScreen extends StatefulWidget {
  final SubscriptionPlan plan;
  const PaymentFlowScreen({super.key, required this.plan});

  @override
  State<PaymentFlowScreen> createState() => _PaymentFlowScreenState();
}

enum _Step {
  loadingMethods,
  fillForm,
  submitting,
  pending,
  checking,
  activating,
  success,
}

class _PaymentFlowScreenState extends State<PaymentFlowScreen> {
  _Step _step = _Step.loadingMethods;
  String? _error;

  // Payment methods
  List<PaymentMethod> _methods = [];
  PaymentMethod? _selectedMethod;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _noteCtrl    = TextEditingController();

  // Proof
  Uint8List? _proofBytes;
  String?    _proofName;

  // Order
  String? _orderRef;
  String? _rejectionNote;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    try {
      final methods = await SubscriptionService.getPaymentMethods();
      if (!mounted) return;
      if (methods.isEmpty) {
        setState(() {
          _step = _Step.fillForm;
          _error = AppLocalizations.of(context).noPaymentMethodsAvailable;
        });
        return;
      }
      setState(() {
        _methods = methods;
        _selectedMethod = methods.first;
        _step = _Step.fillForm;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _step = _Step.fillForm;
        _error = AppLocalizations.of(context).noPaymentMethodsAvailable;
      });
    }
  }

  Future<void> _pickProof() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _proofBytes = bytes;
        _proofName  = file.name;
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMethod == null) return;

    setState(() {
      _step  = _Step.submitting;
      _error = null;
    });

    try {
      final result = await SubscriptionService.createOrder(
        paymentMethodId: _selectedMethod!.id,
        buyerName:       _nameCtrl.text.trim(),
        buyerContact:    _contactCtrl.text.trim(),
        amount:          widget.plan.priceSDG,
        proofNote:       _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        proofFileBytes:  _proofBytes,
        proofFileName:   _proofName,
      );
      if (!mounted) return;
      setState(() {
        _orderRef = result.reference;
        _step     = _Step.pending;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step  = _Step.fillForm;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _checkStatus() async {
    final ref = _orderRef;
    if (ref == null) return;

    setState(() {
      _step  = _Step.checking;
      _error = null;
    });

    try {
      final order = await SubscriptionService.getOrder(ref);
      if (!mounted) return;

      switch (order.status) {
        case OrderStatus.approved:
          await _activateLicense(order.license!);
        case OrderStatus.rejected:
          await LicenseService.instance.setOrderRejected(ref, order.adminNote);
          if (!mounted) return;
          setState(() {
            _step          = _Step.pending;
            _rejectionNote = order.adminNote;
            _error = AppLocalizations.of(context).orderRejectedStatus;
          });
        case OrderStatus.pending:
          setState(() {
            _step  = _Step.pending;
            _error = null;
          });
          _showInfo(AppLocalizations.of(context).orderPendingBody);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step  = _Step.pending;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _activateLicense(License license) async {
    setState(() => _step = _Step.activating);
    final deviceId = await LicenseService.instance.getOrCreateDeviceId();
    try {
      await SubscriptionService.activateAndStore(license, deviceId);
      if (!mounted) return;
      setState(() => _step = _Step.success);
    } on ElmahdiPayForbiddenException catch (e) {
      if (e.maxDevices != null) {
        await LicenseService.instance.storeLicense(
          licenseKey: license.licenseKey,
          expiresAt:  license.expiresAt,
          isActive:   true,
        );
        await LicenseService.instance.markDeviceLimitReached();
      }
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final msg = e.maxDevices != null
          ? '${l.deviceLimitStatus}: ${e.activeDevices}/${e.maxDevices}'
          : l.licenseRevokedStatus;
      setState(() {
        _step  = _Step.pending;
        _error = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step  = _Step.pending;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final l = AppLocalizations.of(context);
    if (e is ElmahdiPayNetworkException)   return l.networkError;
    if (e is ElmahdiPayRateLimitException) return l.rateLimitError;
    if (e is ElmahdiPayValidationException) return e.message;
    return l.operationFailed;
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F3),
      appBar: AppBar(
        title: Text(widget.plan.name(l10n.langCode)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(l10n),
      ),
    );
  }

  Widget _buildStep(AppLocalizations l10n) {
    return switch (_step) {
      _Step.loadingMethods => const Center(
          key: ValueKey('loading'),
          child: CircularProgressIndicator()),
      _Step.fillForm   => _buildForm(l10n),
      _Step.submitting => _buildBusy(l10n, l10n.submitOrder),
      _Step.pending    => _buildPending(l10n),
      _Step.checking   => _buildBusy(l10n, l10n.checkOrderStatus),
      _Step.activating => _buildBusy(l10n, l10n.activating),
      _Step.success    => _buildSuccess(l10n),
    };
  }

  Widget _buildBusy(AppLocalizations l10n, String label) => Center(
        key: const ValueKey('busy'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      );

  // ── Form ───────────────────────────────────────────────────────────────────

  Widget _buildForm(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('form'),
        padding: const EdgeInsets.all(16),
        children: [
          // Amount summary
          _AmountCard(plan: widget.plan, l10n: l10n, cs: cs),
          const SizedBox(height: 16),

          if (_error != null)
            _ErrorBanner(message: _error!, cs: cs),

          // Payment method
          if (_methods.isNotEmpty) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.choosePaymentMethod,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    ..._methods.map((m) => _MethodTile(
                          method: m,
                          isSelected: _selectedMethod?.id == m.id,
                          onTap: () =>
                              setState(() => _selectedMethod = m),
                        )),
                    if (_selectedMethod?.instructions != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.paymentInstructions,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(_selectedMethod!.instructions!,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Help note
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.enterCorrectDataNote,
                    style: TextStyle(fontSize: 13, color: cs.primary, height: 1.45),
                  ),
                ),
              ],
            ),
          ),

          // Buyer details
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cs.outlineVariant)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.buyerNameLabel,
                      helperText: l10n.buyerNameHelper,
                      helperMaxLines: 2,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l10n.required
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.buyerContactLabel,
                      helperText: l10n.buyerContactHelper,
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l10n.required
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration:
                        InputDecoration(hintText: l10n.proofNoteLabel),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Proof upload
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cs.outlineVariant)),
            child: ListTile(
              leading: Icon(
                  _proofBytes != null
                      ? Icons.check_circle_outline
                      : Icons.upload_file_outlined,
                  color: _proofBytes != null
                      ? Colors.green
                      : cs.primary),
              title: Text(_proofName ?? l10n.attachProof),
              subtitle: _proofBytes != null
                  ? Text('${(_proofBytes!.length / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(fontSize: 11))
                  : null,
              onTap: _pickProof,
              trailing: _proofBytes != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _proofBytes = null;
                        _proofName  = null;
                      }),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white),
              child: Text(l10n.submitOrder,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pending ────────────────────────────────────────────────────────────────

  Widget _buildPending(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final isRejected = _rejectionNote != null;

    return Padding(
      key: const ValueKey('pending'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isRejected ? Icons.cancel_outlined : Icons.pending_outlined,
            size: 64,
            color: isRejected ? cs.error : cs.primary,
          ),
          const SizedBox(height: 16),
          Text(
            isRejected ? l10n.orderRejectedStatus : l10n.orderSubmittedTitle,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_orderRef != null)
            SelectableText('${l10n.orderReferenceLabel}: $_orderRef',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            isRejected
                ? '${l10n.rejectionReason}: ${_rejectionNote ?? ''}'
                : l10n.orderPendingBody,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _ErrorBanner(message: _error!, cs: cs),
          ],
          const SizedBox(height: 32),
          if (!isRejected)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _checkStatus,
                child: Text(l10n.checkOrderStatus),
              ),
            ),
          if (isRejected) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  await LicenseService.instance.clearOrder();
                  if (!mounted) return;
                  setState(() {
                    _orderRef      = null;
                    _rejectionNote = null;
                    _error         = null;
                    _step          = _Step.fillForm;
                  });
                },
                child: Text(l10n.tryAgain),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Success ────────────────────────────────────────────────────────────────

  Widget _buildSuccess(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text(l10n.activationSuccessTitle,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.activationSuccessBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white),
              child: Text(l10n.continueUsingApp),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final AppLocalizations l10n;
  final ColorScheme cs;
  const _AmountCard(
      {required this.plan, required this.l10n, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withValues(alpha: 0.75)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name(l10n.langCode),
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13)),
          Text(
            '${SubscriptionPlan.fmt(plan.priceSDG)} SDG',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold),
          ),
          if (plan.hasDiscount)
            Text(
              '${l10n.saveBadge} ${SubscriptionPlan.fmt(plan.savingsSDG!)} SDG',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;
  const _MethodTile(
      {required this.method,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? cs.primary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.name,
                      style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  if (method.currency != 'SDG')
                    Text(method.currency,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final ColorScheme cs;
  const _ErrorBanner({required this.message, required this.cs});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: TextStyle(color: cs.error, fontSize: 13))),
          ],
        ),
      );
}
