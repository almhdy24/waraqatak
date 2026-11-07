import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'money_utils.dart';

/// Parsing / formatting of user-typed numbers.
/// Rules: Arabic-Indic (٠-٩) and Eastern Arabic-Indic (۰-۹) digits are accepted.
/// '.' and '٫' are the decimal separator. ',' '،' '٬' are ALWAYS thousands
/// separators and are ignored when parsing.
class NumberInput {
  NumberInput._();

  /// ASCII digits, '.' decimal, '-' minus; grouping separators, spaces and
  /// bidi control marks removed. Other characters are kept unchanged.
  static String normalize(String input) {
    final b = StringBuffer();
    for (final r in input.runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        b.write(r - 0x0660);
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        b.write(r - 0x06F0);
      } else if (r == 0x066B) {
        b.write('.');
      } else if (r == 0x2212) {
        b.write('-');
      } else if (r == 0x002C || r == 0x060C || r == 0x066C) {
        // grouping separators: dropped
      } else if (r == 0x0020 ||
          r == 0x00A0 ||
          r == 0x202F ||
          r == 0x200E ||
          r == 0x200F ||
          r == 0x061C ||
          (r >= 0x202A && r <= 0x202E) ||
          (r >= 0x2066 && r <= 0x2069)) {
        // spaces and bidi control marks: dropped
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static final RegExp _plainNumber = RegExp(r'^-?\d*\.?\d*$');
  static final RegExp _hasDigit = RegExp(r'\d');

  /// Returns null for empty / invalid input (never throws, never guesses).
  static double? parse(String? text) {
    if (text == null) return null;
    final s = normalize(text);
    if (s.isEmpty || !_plainNumber.hasMatch(s) || !_hasDigit.hasMatch(s)) {
      return null;
    }
    return double.tryParse(s);
  }

  /// Inserts ',' every 3 digits in the integer part of a clean number string
  /// such as "-1500.25". Does not validate.
  static String group(String clean) {
    var sign = '';
    var s = clean;
    if (s.startsWith('-')) {
      sign = '-';
      s = s.substring(1);
    }
    final dot = s.indexOf('.');
    final intPart = dot == -1 ? s : s.substring(0, dot);
    final frac = dot == -1 ? '' : s.substring(dot);
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '$sign${buf.toString()}$frac';
  }

  /// Text for putting a number into an input field: grouped, no trailing zeros.
  static String formatForInput(double value, {int maxDecimals = 4}) {
    if (value.isNaN || value.isInfinite) return '';
    final rounded = MoneyUtils.round(value, maxDecimals);
    var s = rounded.toStringAsFixed(maxDecimals);
    if (maxDecimals > 0 && s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    if (s == '-0') s = '0';
    return group(s);
  }
}

/// Live formatter: converts Arabic digits, ignores typed commas (they are
/// thousands separators), re-inserts grouping commas, limits decimals.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({this.maxDecimals = 4, this.allowNegative = false});

  final int maxDecimals;
  final bool allowNegative;

  String _sanitize(String text) {
    final n = NumberInput.normalize(text);
    var negative = false;
    var seenDot = false;
    final intBuf = StringBuffer();
    final fracBuf = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      final c = n[i];
      final u = c.codeUnitAt(0);
      if (c == '-' && i == 0 && allowNegative) {
        negative = true;
      } else if (c == '.' && maxDecimals > 0 && !seenDot) {
        seenDot = true;
      } else if (u >= 48 && u <= 57) {
        if (seenDot) {
          if (fracBuf.length < maxDecimals) fracBuf.write(c);
        } else {
          intBuf.write(c);
        }
      }
    }
    var intPart = intBuf.toString().replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (intPart.isEmpty && seenDot) intPart = '0';
    final sb = StringBuffer();
    if (negative) sb.write('-');
    sb.write(intPart);
    if (seenDot) {
      sb.write('.');
      sb.write(fracBuf.toString());
    }
    return sb.toString();
  }

  int _offsetFor(String formatted, int significant) {
    if (significant <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted[i] != ',') {
        seen++;
        if (seen == significant) return i + 1;
      }
    }
    return formatted.length;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = NumberInput.group(_sanitize(newValue.text));
    final sel = newValue.selection;
    final raw = sel.isValid ? sel.extentOffset : newValue.text.length;
    final offset = math.min(math.max(raw, 0), newValue.text.length);
    final significant = _sanitize(newValue.text.substring(0, offset)).length;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetFor(formatted, significant),
      ),
      composing: TextRange.empty,
    );
  }
}
