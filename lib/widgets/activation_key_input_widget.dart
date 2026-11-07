import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../services/activation_service.dart';
import '../services/license_service.dart';

/// Shared key-input and activation widget used across license & activation screens.
///
/// Preserves the exact key normalization, device ID resolution, and authoritative
/// [ActivationService.activateDetailed] verification.
class ActivationKeyInputWidget extends StatefulWidget {
  final VoidCallback? onActivated;
  final bool showHeader;

  const ActivationKeyInputWidget({
    super.key,
    this.onActivated,
    this.showHeader = true,
  });

  @override
  State<ActivationKeyInputWidget> createState() =>
      _ActivationKeyInputWidgetState();
}

class _ActivationKeyInputWidgetState extends State<ActivationKeyInputWidget> {
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
      _success = false;
    });

    final String deviceId;
    try {
      deviceId = await LicenseService.instance.getOrCreateDeviceId();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = l10n.activationFailureGuidance;
      });
      return;
    }

    final res = await ActivationService.activateDetailed(key, deviceId);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    if (res.outcome == ActivationOutcome.success) {
      setState(() {
        _loading = false;
        _success = true;
      });
      widget.onActivated?.call();
    } else {
      setState(() {
        _loading = false;
        _error = l10n.activationFailureGuidance;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          Text(
            l10n.alreadyHaveKeyTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.enterKeyHintText,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _ctrl,
          textDirection: TextDirection.ltr,
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
                  _ctrl.selection = TextSelection.collapsed(
                    offset: pasted.length,
                  );
                }
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _activate(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: cs.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onErrorContainer,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_success) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.green,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.activationSuccessDone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _loading ? null : _activate,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    l10n.activate,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
