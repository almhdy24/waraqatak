import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../screens/about_screen.dart';
import '../services/activation_service.dart';
import '../services/analytics/analytics_service.dart';
import '../services/license_key.dart';
import '../services/license_service.dart';
import 'app_snackbar.dart';

/// Single source of truth for activation key input, format validation,
/// network submission, outcome handling, and error/cooldown states.
class ActivationKeyInputWidget extends StatefulWidget {
  final VoidCallback? onActivated;
  final ValueChanged<ActivationOutcome>? onOutcome;
  final ValueChanged<bool>? onLoadingChanged;
  final bool showHeader;

  const ActivationKeyInputWidget({
    super.key,
    this.onActivated,
    this.onOutcome,
    this.onLoadingChanged,
    this.showHeader = true,
  });

  @override
  State<ActivationKeyInputWidget> createState() =>
      _ActivationKeyInputWidgetState();

  /// Cheap local format check for short Crockford keys and long signed payload keys.
  static bool isFormatValid(String rawKey) {
    final key = ActivationService.normalizeKey(rawKey);
    if (key.isEmpty) return false;
    if (ShortLicenseKey.isShortKey(key)) {
      final norm = ShortLicenseKey.normalize(key);
      return ShortLicenseKey.verifyChecksum(norm);
    }
    return LicenseKeyClaims.tryParse(key) != null;
  }
}

class _ActivationKeyInputWidgetState extends State<ActivationKeyInputWidget> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = false;
  bool _success = false;
  ActivationOutcome? _lastOutcome;
  String? _error;
  String? _tip;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_error != null || _tip != null || _lastOutcome != null) {
      setState(() {
        _error = null;
        _tip = null;
        _lastOutcome = null;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownSeconds = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 1) {
          _cooldownSeconds--;
        } else {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final normalized = ActivationService.normalizeKey(data.text!);
      _ctrl.text = normalized;
      _ctrl.selection = TextSelection.collapsed(offset: normalized.length);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AppSnackBar.show(
          context,
          l10n.keyPastedFeedback,
          severity: AppSnackBarSeverity.info,
        );
      }
    }
  }

  Future<void> _activate() async {
    final rawKey = _ctrl.text;
    final normalizedKey = ActivationService.normalizeKey(rawKey);
    if (!ActivationKeyInputWidget.isFormatValid(rawKey)) return;

    _focusNode.unfocus();
    try {
      AnalyticsService.instance.track(AnalyticsEvent.activationStarted);
    } catch (_) {}

    setState(() {
      _loading = true;
      _error = null;
      _tip = null;
      _lastOutcome = null;
    });
    widget.onLoadingChanged?.call(true);

    try {
      final deviceId = await LicenseService.instance.getOrCreateDeviceId();
      final res = await ActivationService.activateDetailed(rawKey, deviceId);
      if (!mounted) return;

      _lastOutcome = res.outcome;
      widget.onOutcome?.call(res.outcome);

      try {
        final reason = _mapOutcomeToReason(res.outcome);
        AnalyticsService.instance.track(AnalyticsEvent.activationResult, {
          'ok': res.outcome == ActivationOutcome.success,
          'reason': reason,
        });
      } catch (_) {}

      final l10n = AppLocalizations.of(context);
      if (res.outcome == ActivationOutcome.success) {
        _ctrl.clear();
        try {
          final clip = await Clipboard.getData(Clipboard.kTextPlain);
          if (clip?.text != null &&
              ActivationService.normalizeKey(clip!.text!) == normalizedKey) {
            await Clipboard.setData(const ClipboardData(text: ''));
          }
        } catch (_) {}

        setState(() {
          _success = true;
          _loading = false;
          _error = null;
          _tip = null;
        });
        widget.onLoadingChanged?.call(false);

        if (mounted) {
          widget.onActivated?.call();
        }
        return;
      }

      if (res.outcome == ActivationOutcome.tooManyAttempts) {
        _startCooldown();
      }

      setState(() {
        _error = _getErrorMessage(res.outcome, l10n);
        _tip = _getTipMessage(res.outcome, l10n);
      });
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _error = l10n.activationUnexpectedError;
        _tip = null;
      });
    } finally {
      if (mounted && !_success) {
        setState(() {
          _loading = false;
        });
        widget.onLoadingChanged?.call(false);
      }
    }
  }

  String _getErrorMessage(ActivationOutcome outcome, AppLocalizations l10n) =>
      switch (outcome) {
        ActivationOutcome.invalid => l10n.invalidOrExpiredKey,
        ActivationOutcome.tooManyAttempts => l10n.activationTooManyAttempts,
        ActivationOutcome.serverUnreachable => l10n.activationServerUnreachable,
        ActivationOutcome.deviceUnavailable => l10n.activationDeviceUnavailable,
        ActivationOutcome.storageFailed => l10n.activationStorageFailed,
        ActivationOutcome.success => '',
      };

  String _getTipMessage(ActivationOutcome outcome, AppLocalizations l10n) =>
      switch (outcome) {
        ActivationOutcome.invalid => l10n.activationTipKeyFormat,
        ActivationOutcome.tooManyAttempts => l10n.activationTipAttempts,
        ActivationOutcome.serverUnreachable => l10n.activationTipServer,
        ActivationOutcome.deviceUnavailable => l10n.activationTipDevice,
        ActivationOutcome.storageFailed => l10n.activationTipStorage,
        ActivationOutcome.success => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_success) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 24, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.activationSuccessDone,
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final rawKey = _ctrl.text;
    final isValid = ActivationKeyInputWidget.isFormatValid(rawKey);
    final canSubmit = !_loading && _cooldownSeconds == 0 && isValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          Text(
            l10n.alreadyHaveKeyTitle,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          l10n.activationKeyHelperText,
          style: textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          readOnly: _loading,
          minLines: 2,
          maxLines: 3,
          autofocus: false,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.visiblePassword,
          style: textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            letterSpacing: 1.05,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(ActivationService.keyCharacter),
          ],
          decoration: InputDecoration(
            labelText: l10n.enterActivationKey,
            hintText: l10n.activationKeyHint,
            prefixIcon: const Icon(Icons.vpn_key_outlined),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isValid)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Tooltip(
                      message: l10n.validKeyFormat,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                    ),
                  ),
                if (rawKey.isNotEmpty && !_loading)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    tooltip: l10n.clearKeyTooltip,
                    onPressed: () => _ctrl.clear(),
                  ),
                if (!_loading)
                  IconButton(
                    icon: const Icon(Icons.content_paste_outlined, size: 20),
                    tooltip: l10n.pasteKey,
                    onPressed: _pasteFromClipboard,
                  ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: canSubmit ? (_) => _activate() : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: cs.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onErrorContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_tip != null && _tip!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 28),
                    child: Text(
                      _tip!,
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                if (_lastOutcome == ActivationOutcome.serverUnreachable) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 24),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _loading ? null : _activate,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(l10n.retry),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.help_outline_rounded,
                            size: 16,
                          ),
                          label: Text(l10n.helpAndSupport),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: canSubmit ? _activate : null,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.verifyingKey,
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _cooldownSeconds > 0
                        ? l10n.activateCooldown(_cooldownSeconds)
                        : l10n.activate,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: Text(l10n.helpAndSupport),
          ),
        ),
      ],
    );
  }

  static String _mapOutcomeToReason(ActivationOutcome outcome) {
    switch (outcome) {
      case ActivationOutcome.success:
        return 'success';
      case ActivationOutcome.serverUnreachable:
        return 'network_error';
      case ActivationOutcome.invalid:
        return 'invalid_key';
      case ActivationOutcome.tooManyAttempts:
        return 'device_limit';
      case ActivationOutcome.deviceUnavailable:
      case ActivationOutcome.storageFailed:
        return 'unknown';
    }
  }
}
