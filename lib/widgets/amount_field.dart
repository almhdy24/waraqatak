import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/money_utils.dart';
import '../utils/number_input.dart';

/// Numeric text field: Arabic digits, live thousands grouping, and optional
/// quick-result chips while focused. Each chip shows the value the field will
/// get when tapped (e.g. typing 5 shows 500 / 5,000 / 5,000,000) and a one-tap
/// undo chip appears after a chip was used.
class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onEditingComplete,
    this.onSaved,
    this.onTap,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.style,
    this.autovalidateMode,
    this.maxDecimals = 4,
    this.allowNegative = false,
    this.showMultipliers = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onEditingComplete;
  final FormFieldSetter<String>? onSaved;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final TextStyle? style;
  final AutovalidateMode? autovalidateMode;
  final int maxDecimals;
  final bool allowNegative;
  final bool showMultipliers;

  static const List<int> multipliers = [100, 1000, 1000000];
  static const double _maxResult = 1e13;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  /// Field text before the last chip was applied.
  String? _undoText;

  /// Field text produced by the last chip. Undo is offered only while the
  /// field still holds exactly this text, so any later edit (typed or set by
  /// the parent) hides it automatically.
  String? _multipliedText;

  bool get _canUndo =>
      _undoText != null && widget.controller.text == _multipliedText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _node.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _undoText = null;
      _multipliedText = null;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownNode)?.removeListener(_onChange);
      _node.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    (widget.focusNode ?? _ownNode)?.removeListener(_onChange);
    _ownNode?.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _setText(String text) {
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
    _node.requestFocus();
  }

  void _multiply(int factor) {
    final current = NumberInput.parse(widget.controller.text);
    if (current == null) return;
    final result = MoneyUtils.round(current * factor, widget.maxDecimals);
    final text = NumberInput.formatForInput(
      result,
      maxDecimals: widget.maxDecimals,
    );
    HapticFeedback.selectionClick();
    _undoText = widget.controller.text;
    _multipliedText = text;
    _setText(text);
  }

  void _undo() {
    final prev = _undoText;
    if (prev == null) return;
    HapticFeedback.selectionClick();
    _undoText = null;
    _multipliedText = null;
    _setText(prev);
  }

  Widget _buildChips(double value) {
    final cs = Theme.of(context).colorScheme;
    final chips = <Widget>[];

    if (_canUndo) {
      chips.add(
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ActionChip(
            backgroundColor: cs.secondaryContainer,
            side: BorderSide.none,
            avatar: Icon(
              Icons.undo_rounded,
              size: 18,
              color: cs.onSecondaryContainer,
            ),
            label: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                _undoText!.isEmpty ? '0' : _undoText!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
            onPressed: _undo,
          ),
        ),
      );
    }

    if (value > 0) {
      for (final f in AmountField.multipliers) {
        final multiplied = MoneyUtils.round(value * f, widget.maxDecimals);
        if (multiplied.abs() > AmountField._maxResult) continue;
        final label = NumberInput.formatForInput(
          multiplied,
          maxDecimals: widget.maxDecimals,
        );
        chips.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ActionChip(
              // Long-press hint keeps the factor discoverable without
              // spending chip width on it.
              tooltip: '×${NumberInput.formatForInput(f.toDouble(), maxDecimals: 0)}',
              label: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onPressed: () => _multiply(f),
            ),
          ),
        );
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ExcludeFocus(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: chips),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      focusNode: _node,
      decoration: widget.decoration,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onEditingComplete: widget.onEditingComplete,
      onSaved: widget.onSaved,
      onTap: widget.onTap,
      textInputAction: widget.textInputAction,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      style: widget.style,
      autovalidateMode: widget.autovalidateMode,
      keyboardType: TextInputType.numberWithOptions(
        decimal: widget.maxDecimals > 0,
        signed: widget.allowNegative,
      ),
      inputFormatters: [
        AmountInputFormatter(
          maxDecimals: widget.maxDecimals,
          allowNegative: widget.allowNegative,
        ),
      ],
    );
    if (!widget.showMultipliers) return field;

    final value = NumberInput.parse(widget.controller.text) ?? 0;
    final show =
        _node.hasFocus &&
        widget.enabled &&
        !widget.readOnly &&
        (value > 0 || _canUndo);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        // Smooth appear/disappear so the form does not jump on focus.
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.topCenter,
          child: show ? _buildChips(value) : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
