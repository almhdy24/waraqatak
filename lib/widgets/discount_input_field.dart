import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../utils/money_utils.dart';
import '../utils/number_input.dart';
import 'amount_field.dart';

enum DiscountType {
  amount,
  percentage;

  bool get isPercentage => this == DiscountType.percentage;
  bool get isAmount => this == DiscountType.amount;
}

enum DiscountSelectorType {
  segmented,
  dropdown,
}

/// A comprehensive discount input widget that supports entering either a fixed currency amount
/// (مبلغ) or a percentage rate (نسبة), without requiring the user to type the '%' symbol manually.
///
/// Automatically handles:
/// - Pure numeric percentage entry (0% - 100%) with '%' suffix indicator.
/// - Pure numeric amount entry with currency indicator and decimal precision.
/// - Smooth bidirectional type conversion (e.g. 10% on 500 -> 50, or 50 on 500 -> 10%).
/// - Automatic recalculation of percentage discounts when subtotal changes.
/// - Clear visual indicator of the active discount type (Segmented Control or Dropdown).
/// - Dynamic helper text showing the equivalent value (= 50 SDG or = 10%).
class DiscountInputField extends StatefulWidget {
  final DiscountType initialType;
  final double? initialDiscount;
  final double subtotal;
  final String currencySymbol;
  final int decimalDigits;
  final ValueChanged<double> onDiscountChanged;
  final ValueChanged<DiscountType>? onTypeChanged;
  final DiscountSelectorType selectorType;
  final bool enabled;
  final bool showHelperCalculation;
  final String? labelText;
  final bool isDense;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  const DiscountInputField({
    super.key,
    this.initialType = DiscountType.amount,
    this.initialDiscount,
    required this.subtotal,
    this.currencySymbol = '',
    this.decimalDigits = 2,
    required this.onDiscountChanged,
    this.onTypeChanged,
    this.selectorType = DiscountSelectorType.segmented,
    this.enabled = true,
    this.showHelperCalculation = true,
    this.labelText,
    this.isDense = false,
    this.textInputAction,
    this.focusNode,
    this.onTap,
  });

  @override
  State<DiscountInputField> createState() => _DiscountInputFieldState();
}

class _DiscountInputFieldState extends State<DiscountInputField> {
  late DiscountType _type;
  late final TextEditingController _controller;
  double _lastReportedDiscount = 0.0;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _controller = TextEditingController();

    if (widget.initialDiscount != null && widget.initialDiscount! > 0) {
      if (_type == DiscountType.amount) {
        _controller.text = NumberInput.formatForInput(
          widget.initialDiscount!,
          maxDecimals: widget.decimalDigits,
        );
      } else {
        final pct = widget.subtotal > 0
            ? (widget.initialDiscount! / widget.subtotal) * 100.0
            : 0.0;
        _controller.text = NumberInput.formatForInput(pct, maxDecimals: 2);
      }
      _lastReportedDiscount = widget.initialDiscount!;
    }

    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
      _notifyDiscount();
    }
  }

  @override
  void didUpdateWidget(covariant DiscountInputField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.subtotal != widget.subtotal &&
        _type == DiscountType.percentage) {
      // Subtotal changed while percentage is active: recalculate discount amount
      _notifyDiscount();
    }

    if (widget.initialDiscount != null &&
        widget.initialDiscount != oldWidget.initialDiscount &&
        (widget.initialDiscount! - _lastReportedDiscount).abs() > 0.0001) {
      _syncFromExternalDiscount(widget.initialDiscount!);
    }
  }

  void _syncFromExternalDiscount(double discount) {
    if (_type == DiscountType.amount) {
      final text = discount > 0
          ? NumberInput.formatForInput(discount, maxDecimals: widget.decimalDigits)
          : '';
      if (_controller.text != text) {
        _controller.text = text;
      }
    } else {
      final pct = (widget.subtotal > 0 && discount > 0)
          ? ((discount / widget.subtotal) * 100.0).clamp(0.0, 100.0)
          : 0.0;
      final text = pct > 0
          ? NumberInput.formatForInput(pct, maxDecimals: 2)
          : '';
      if (_controller.text != text) {
        _controller.text = text;
      }
    }
    _lastReportedDiscount = discount;
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  double get _currentEffectiveDiscount {
    final raw = NumberInput.parse(_controller.text);
    if (raw == null || raw <= 0) return 0.0;

    if (_type == DiscountType.amount) {
      return math.max(0.0, raw);
    } else {
      final clampedPct = raw.clamp(0.0, 100.0);
      if (widget.subtotal <= 0) return 0.0;
      return MoneyUtils.round(
        widget.subtotal * (clampedPct / 100.0),
        widget.decimalDigits,
      );
    }
  }

  void _notifyDiscount() {
    final effective = _currentEffectiveDiscount;
    if ((effective - _lastReportedDiscount).abs() > 0.00001) {
      _lastReportedDiscount = effective;
      widget.onDiscountChanged(effective);
    }
  }

  void _setType(DiscountType newType) {
    if (_type == newType) return;
    final currentRaw = NumberInput.parse(_controller.text) ?? 0.0;

    setState(() {
      _type = newType;
      if (currentRaw > 0 && widget.subtotal > 0) {
        if (newType == DiscountType.percentage) {
          // Amount -> Percentage
          final pct = ((currentRaw / widget.subtotal) * 100.0).clamp(0.0, 100.0);
          _controller.text = NumberInput.formatForInput(pct, maxDecimals: 2);
        } else {
          // Percentage -> Amount
          final amt = MoneyUtils.round(
            widget.subtotal * (currentRaw.clamp(0.0, 100.0) / 100.0),
            widget.decimalDigits,
          );
          _controller.text = NumberInput.formatForInput(
            amt,
            maxDecimals: widget.decimalDigits,
          );
        }
      } else if (currentRaw <= 0) {
        _controller.text = '';
      }
    });

    _notifyDiscount();
    widget.onTypeChanged?.call(newType);
  }

  String? _validator(String? value) {
    final l10n = AppLocalizations.of(context);
    final numVal = NumberInput.parse(value);
    if (numVal == null || numVal <= 0) return null;

    if (_type == DiscountType.percentage) {
      if (numVal > 100) return l10n.discountPercentExceedsMax;
    } else {
      if (widget.subtotal > 0 && numVal > widget.subtotal) {
        return l10n.discountAmountExceedsSubtotal;
      }
    }
    return null;
  }

  String? _getHelperText(AppLocalizations l10n) {
    if (!widget.showHelperCalculation) return null;
    final numVal = NumberInput.parse(_controller.text);
    if (numVal == null || numVal <= 0 || widget.subtotal <= 0) return null;

    if (_type == DiscountType.percentage) {
      final effectiveAmt = MoneyUtils.round(
        widget.subtotal * (numVal.clamp(0.0, 100.0) / 100.0),
        widget.decimalDigits,
      );
      final formatted =
          '${NumberInput.formatForInput(effectiveAmt, maxDecimals: widget.decimalDigits)} ${widget.currencySymbol}'
              .trim();
      return '= $formatted';
    } else {
      final pct = (numVal / widget.subtotal) * 100.0;
      return '= ${NumberInput.formatForInput(pct, maxDecimals: 1)}%';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPercentage = _type == DiscountType.percentage;

    final inputField = AmountField(
      controller: _controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      maxDecimals: isPercentage ? 2 : widget.decimalDigits,
      showMultipliers: !isPercentage,
      textInputAction: widget.textInputAction,
      onTap: widget.onTap,
      decoration: InputDecoration(
        labelText: widget.labelText ?? l10n.discount,
        isDense: widget.isDense,
        prefixIcon: Icon(
          isPercentage ? Icons.percent_rounded : Icons.payments_outlined,
          size: 20,
        ),
        suffixText: isPercentage
            ? '%'
            : (widget.currencySymbol.isNotEmpty ? widget.currencySymbol : null),
        helperText: _getHelperText(l10n),
      ),
      validator: _validator,
      onChanged: (_) => _notifyDiscount(),
    );

    if (widget.selectorType == DiscountSelectorType.segmented) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: inputField),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SegmentedButton<DiscountType>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              ),
              segments: [
                ButtonSegment(
                  value: DiscountType.amount,
                  label: Text(
                    l10n.discountTypeAmount,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
                ButtonSegment(
                  value: DiscountType.percentage,
                  label: Text(
                    l10n.discountTypePercentage,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              selected: {_type},
              onSelectionChanged: widget.enabled ? (s) => _setType(s.first) : null,
            ),
          ),
        ],
      );
    } else {
      // Dropdown selector beside the input
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: inputField),
          const SizedBox(width: 6),
          Container(
            height: widget.isDense ? 40 : 48,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DiscountType>(
                value: _type,
                isDense: true,
                borderRadius: BorderRadius.circular(8),
                items: [
                  DropdownMenuItem(
                    value: DiscountType.amount,
                    child: Text(
                      l10n.discountTypeAmount,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DropdownMenuItem(
                    value: DiscountType.percentage,
                    child: Text(
                      l10n.discountTypePercentage,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                onChanged: widget.enabled
                    ? (t) {
                        if (t != null) _setType(t);
                      }
                    : null,
              ),
            ),
          ),
        ],
      );
    }
  }
}
