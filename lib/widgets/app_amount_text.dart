import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'app_design_tokens.dart';

/// Standard, locale-safe monetary amount presentation widget.
///
/// Prevents digit transposition in RTL contexts while preserving proper
/// spacing and typography for currency symbols.
///
/// Wraps content in a unified [Semantics] node so screen readers and assistive
/// tools read the complete monetary value and currency as a single utterance.
class AppAmountText extends StatelessWidget {
  final double amount;
  final String? currencySymbol;
  final TextStyle? style;
  final Color? color;
  final FontWeight? fontWeight;
  final double? fontSize;
  final int decimalDigits;
  final String? prefix;
  final bool? isDebit;
  final String? semanticsLabel;

  const AppAmountText({
    super.key,
    required this.amount,
    this.currencySymbol,
    this.style,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.decimalDigits = 2,
    this.prefix,
    this.isDebit,
    this.semanticsLabel,
  });

  /// Formatted numeric amount without currency symbol or sign prefix.
  String get formattedAmount {
    final pattern = decimalDigits > 0
        ? '#,##0.${'0' * decimalDigits}'
        : '#,##0';
    return NumberFormat(pattern).format(amount.abs());
  }

  /// Resolved sign prefix (+, -, or custom prefix).
  String get resolvedPrefix {
    if (prefix != null) {
      return prefix!;
    } else if (isDebit != null) {
      return isDebit! ? '-' : '+';
    } else if (amount < 0) {
      return '-';
    }
    return '';
  }

  /// Canonical full textual representation (e.g. "50,000 ج.س" or "-50,000.00 ج.س").
  String get fullText {
    final sign = resolvedPrefix;
    final sym = currencySymbol?.trim() ?? '';
    final formattedNumber = formattedAmount;
    if (sym.isEmpty) {
      return '$sign$formattedNumber';
    }
    return '$sign$formattedNumber $sym';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Color? resolvedColor = color;
    if (resolvedColor == null && isDebit != null) {
      resolvedColor = isDebit!
          ? AppDesignTokens.semanticDanger(context)
          : AppDesignTokens.semanticSuccess(context);
    }
    resolvedColor ??= cs.onSurface;

    final effectiveStyle = (style ?? theme.textTheme.bodyMedium)?.copyWith(
      color: resolvedColor,
      fontWeight: fontWeight ?? style?.fontWeight,
      fontSize: fontSize ?? style?.fontSize,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final formattedNumber = formattedAmount;
    final signPrefix = resolvedPrefix;
    final symbol = currencySymbol?.trim() ?? '';

    final resolvedSemantics = semanticsLabel ?? fullText;

    return Semantics(
      container: true,
      label: resolvedSemantics,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (signPrefix.isNotEmpty)
            Text(signPrefix, style: effectiveStyle),
          // Numbers formatted in LTR to ensure proper numeral display
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(formattedNumber, style: effectiveStyle),
          ),
          if (symbol.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              symbol,
              style: effectiveStyle?.copyWith(
                fontSize: (effectiveStyle.fontSize ?? 14) * 0.85,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
