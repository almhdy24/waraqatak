import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/money_utils.dart';
import '../utils/number_input.dart';

/// Numeric text field: Arabic digits, live thousands grouping, and optional
/// "×10 ×100 ×1,000 ×10,000 ×1,000,000" chips while focused.
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

  static const List<int> multipliers = [10, 100, 1000, 10000, 1000000];
  static const double _maxResult = 1e13;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

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

  void _multiply(int factor) {
    final current = NumberInput.parse(widget.controller.text);
    if (current == null) return;
    final result = MoneyUtils.round(current * factor, widget.maxDecimals);
    final text = NumberInput.formatForInput(
      result,
      maxDecimals: widget.maxDecimals,
    );
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
    _node.requestFocus();
  }

  Widget _buildChips(double value) {
    final chips = <Widget>[];
    for (final f in AmountField.multipliers) {
      if ((value * f).abs() > AmountField._maxResult) continue;
      chips.add(
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: ActionChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '×${NumberInput.formatForInput(f.toDouble(), maxDecimals: 0)}',
              ),
            ),
            onPressed: () => _multiply(f),
          ),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
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
    final value = NumberInput.parse(widget.controller.text);
    final show =
        _node.hasFocus &&
        widget.enabled &&
        !widget.readOnly &&
        value != null &&
        value > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [field, if (show) _buildChips(value)],
    );
  }
}
