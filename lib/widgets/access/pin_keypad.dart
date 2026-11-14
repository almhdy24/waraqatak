import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../localization/app_localizations.dart';

/// Reusable global PIN Keypad widget enforced to LTR layout (1 at top-left).
///
/// Ensures digits are Western 0-9, touch targets >= 64dp, includes haptic feedback,
/// pressed ripple affordance, and accessible semantics labels.
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onClear;
  final Widget? leftAction;
  final Widget? rightAction;
  final bool enabled;

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onClear,
    this.leftAction,
    this.rightAction,
    this.enabled = true,
  });

  void _handleDigit(String digit) {
    if (!enabled) return;
    HapticFeedback.lightImpact();
    onDigit(digit);
  }

  void _handleBackspace() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
    onBackspace();
  }

  void _handleClear() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 3; row++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var col = 1; col <= 3; col++) ...[
                  _KeypadDigitButton(
                    digit: '${row * 3 + col}',
                    onTap: () => _handleDigit('${row * 3 + col}'),
                    enabled: enabled,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              leftAction ?? const SizedBox(width: 72, height: 72),
              _KeypadDigitButton(
                digit: '0',
                onTap: () => _handleDigit('0'),
                enabled: enabled,
              ),
              rightAction ??
                  _KeypadIconButton(
                    icon: Icons.backspace_outlined,
                    semanticsLabel: 'Backspace',
                    onTap: _handleBackspace,
                    onLongPress: _handleClear,
                    enabled: enabled,
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadDigitButton extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;
  final bool enabled;

  const _KeypadDigitButton({
    required this.digit,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: digit,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: Center(
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  const _KeypadIconButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            onLongPress: enabled ? onLongPress : null,
            child: Center(
              child: Icon(icon, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

/// Direction-safe, animated indicator dots for PIN entry progress.
class PinDotsView extends StatelessWidget {
  final int length;
  final int maxDigits;
  final bool hasError;

  const PinDotsView({
    super.key,
    required this.length,
    this.maxDigits = 6,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(maxDigits, (i) {
          final filled = i < length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: filled ? 18 : 14,
            height: filled ? 18 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasError
                  ? cs.error
                  : (filled ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4)),
              border: Border.all(
                color: hasError
                    ? cs.error
                    : (filled ? cs.primary : cs.outlineVariant),
                width: filled ? 2 : 1,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: (hasError ? cs.error : cs.primary)
                            .withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

/// Horizontal shake animation container triggered on invalid PIN.
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;

  const ShakeWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.offset = 12.0,
  });

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final offset = sin(progress * pi * 8) * widget.offset * (1 - progress);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Reusable check / confirm button matching PinKeypad button styling.
class PinKeypadConfirmButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;
  final String semanticsLabel;

  const PinKeypadConfirmButton({
    super.key,
    required this.active,
    required this.onTap,
    this.semanticsLabel = 'Confirm',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: active && onTap != null,
      label: semanticsLabel,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: active
              ? cs.primary
              : cs.surfaceContainerHighest.withValues(alpha: 0.2),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: active ? onTap : null,
            child: Center(
              child: Icon(
                Icons.check_circle_rounded,
                size: 28,
                color: active ? cs.onPrimary : cs.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal dialog for PIN authentication or confirmation using the unified LTR keypad.
class PinEntryDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<bool> Function(String pin) onVerify;

  const PinEntryDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.onVerify,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Future<bool> Function(String pin) onVerify,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinEntryDialog(
        title: title,
        subtitle: subtitle,
        onVerify: onVerify,
      ),
    );
    return result ?? false;
  }

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  String _pin = '';
  bool _verifying = false;
  bool _hasError = false;
  String? _errorMessage;

  void _onDigit(String d) {
    if (_verifying || _pin.length >= 6) return;
    setState(() {
      _pin += d;
      _errorMessage = null;
      _hasError = false;
    });
  }

  void _onBackspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
      _hasError = false;
    });
  }

  void _onClear() {
    if (_verifying || _pin.isEmpty) return;
    setState(() {
      _pin = '';
      _errorMessage = null;
      _hasError = false;
    });
  }

  Future<void> _submit() async {
    if (_pin.length < 4 || _verifying) return;
    setState(() => _verifying = true);

    try {
      final success = await widget.onVerify(_pin);
      if (success) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    _shakeKey.currentState?.shake();
    final l10n = AppLocalizations.of(context);
    setState(() {
      _hasError = true;
      _verifying = false;
      _errorMessage = l10n.invalidPin;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _pin = '';
        _hasError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // balance leading close
              ],
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.subtitle!,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            ShakeWidget(
              key: _shakeKey,
              child: PinDotsView(
                length: _pin.length,
                maxDigits: 6,
                hasError: _hasError,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: cs.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            PinKeypad(
              enabled: !_verifying,
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              onClear: _onClear,
              leftAction: PinKeypadConfirmButton(
                active: _pin.length >= 4 && !_verifying,
                onTap: _pin.length >= 4 ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Normalizes Arabic-Indic and Persian digits to Western 0-9 for PIN fields.
class WesternPinInputFormatter extends TextInputFormatter {
  final int maxLength;
  const WesternPinInputFormatter({this.maxLength = 6});

  static String normalizeDigits(String text) {
    const arabicIndic = '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
    const persian = '\u06f0\u06f1\u06f2\u06f3\u06f4\u06f5\u06f6\u06f7\u06f8\u06f9';
    final sb = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final arIdx = arabicIndic.indexOf(ch);
      if (arIdx != -1) {
        sb.write(arIdx);
      } else {
        final faIdx = persian.indexOf(ch);
        if (faIdx != -1) {
          sb.write(faIdx);
        } else if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
          sb.write(ch);
        }
      }
    }
    return sb.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizeDigits(newValue.text);
    final clamped = normalized.length > maxLength
        ? normalized.substring(0, maxLength)
        : normalized;
    return TextEditingValue(
      text: clamped,
      selection: TextSelection.collapsed(offset: clamped.length),
    );
  }
}

