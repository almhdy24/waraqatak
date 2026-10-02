import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../services/activation_service.dart';
import '../services/license_service.dart';

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
    });

    final deviceId = await LicenseService.instance.getOrCreateDeviceId();
    final outcome = await ActivationService.activate(key, deviceId);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    switch (outcome) {
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
      body: SafeArea(
        child: _success
            ? _buildSuccess(l10n, cs)
            : _buildForm(l10n, cs),
      ),
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
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
            ],
            decoration: InputDecoration(
              labelText: l10n.enterActivationKey,
              hintText: l10n.activationKeyHint,
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              errorText: _error,
            ),
            onSubmitted: (_) => _activate(),
          ),
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
        ],
      ),
    );
  }

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
