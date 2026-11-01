import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../services/activation_service.dart';
import '../services/license_service.dart';
import '../widgets/responsive.dart';
import '../widgets/support_guidance_card.dart';

/// Screen for entering an activation key.
///
/// There is no pricing, ordering, or payment in the app. The user enters a
/// previously obtained activation key here; on success, Pro features are
/// unlocked. The app itself does not describe where or how to obtain the key.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  String? _error;
  ActivationOutcome? _lastOutcome;
  String? _lastReferenceId;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _ctrl.text;
    if (ActivationService.normalizeKey(key).isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _lastOutcome = null;
      _lastReferenceId = null;
    });

    final String deviceId;
    try {
      deviceId = await LicenseService.instance.getOrCreateDeviceId();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() => _lastOutcome = ActivationOutcome.deviceUnavailable);
      _showError(l10n.activationDeviceUnavailable);
      return;
    }

    final res = await ActivationService.activateDetailed(key, deviceId);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _lastOutcome = res.outcome;
      _lastReferenceId = res.referenceId;
    });

    switch (res.outcome) {
      case ActivationOutcome.success:
        setState(() {
          _loading = false;
          _success = true;
        });
      case ActivationOutcome.invalid:
        _showError(l10n.invalidOrExpiredKey);
      case ActivationOutcome.tooManyAttempts:
        _showError(l10n.activationTooManyAttempts);
      case ActivationOutcome.serverUnreachable:
        _showError(l10n.activationServerUnreachable);
      case ActivationOutcome.deviceUnavailable:
        _showError(l10n.activationDeviceUnavailable);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activation),
        centerTitle: true,
      ),
      body: ResponsiveCenter(child: SafeArea(
        child: _success
            ? _buildSuccess(l10n, cs)
            : _buildForm(l10n, cs),
      )),
    );
  }

  Widget _buildForm(AppLocalizations l10n, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.vpn_key_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 20),
          Text(
            l10n.proFeaturesActivation,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.getActivationKeyInfo,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textDirection: TextDirection.ltr,
            // Keys are case-sensitive base64url segments joined by '.', so
            // no auto-capitalization, autocorrect or suggestions.
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(ActivationService.keyCharacter),
            ],
            decoration: InputDecoration(
              labelText: l10n.enterActivationKey,
              hintText: l10n.activationKeyHint,
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_outlined),
                tooltip: l10n.pasteKey,
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null && data!.text!.trim().isNotEmpty) {
                    final pasted = data.text!.trim();
                    _ctrl.text = pasted;
                    _ctrl.selection =
                        TextSelection.collapsed(offset: pasted.length);
                  }
                },
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              errorText: _error,
            ),
            onSubmitted: (_) => _activate(),
          ),
          if (_lastOutcome != null && _error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: cs.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getTipForOutcome(_lastOutcome!, l10n),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
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
          const SizedBox(height: 32),
          SupportGuidanceCard(
            referenceId: _lastReferenceId,
            rawKey: _ctrl.text,
          ),
        ],
      ),
    );
  }

  String _getTipForOutcome(
      ActivationOutcome outcome, AppLocalizations l10n) =>
      switch (outcome) {
        ActivationOutcome.invalid => l10n.activationTipKeyFormat,
        ActivationOutcome.serverUnreachable => l10n.activationTipServer,
        ActivationOutcome.tooManyAttempts => l10n.activationTipAttempts,
        ActivationOutcome.deviceUnavailable => l10n.activationTipDevice,
        ActivationOutcome.success => '',
      };

  Widget _buildSuccess(AppLocalizations l10n, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            l10n.activationSuccessTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.activationSuccessBody,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l10n.continueUsingApp),
            ),
          ),
        ],
      ),
    );
  }
}
