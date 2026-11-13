/// Reusable UI widgets and selection reconciliation for reference pricing.
library;

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/exchange_rate.dart';
import '../models/reference_pricing_types.dart';
import '../utils/number_input.dart';
import '../utils/reference_pricing_math.dart';

const String _baseSentinel = '__BASE_CURRENCY__';

/// Dropdown selector for choosing between base currency and available reference currencies.
class PricingCurrencySelector extends StatelessWidget {
  /// Base currency code of the business (e.g. SDG).
  final String baseCurrencyCode;

  /// Base currency symbol (e.g. ج.س).
  final String baseSymbol;

  /// Available reference currency exchange rates.
  final List<ExchangeRate> options;

  /// Currently selected currency code, or null for base currency.
  final String? value;

  /// Callback invoked when a currency or base currency (null) is selected.
  final ValueChanged<String?> onChanged;

  /// Creates a [PricingCurrencySelector].
  const PricingCurrencySelector({
    super.key,
    required this.baseCurrencyCode,
    required this.baseSymbol,
    required this.options,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveValue = value ?? _baseSentinel;

    return DropdownButtonFormField<String>(
      key: ValueKey('pricing_currency_selector_$effectiveValue'),
      initialValue: effectiveValue,
      decoration: InputDecoration(
        labelText: l10n.pricingCurrency,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: [
        DropdownMenuItem<String>(
          value: _baseSentinel,
          child: Text('$baseCurrencyCode ($baseSymbol)'),
        ),
        ...options.map((opt) {
          return DropdownMenuItem<String>(
            value: opt.code,
            child: Text('${opt.nameAr} (${opt.code})'),
          );
        }),
      ],
      onChanged: (selected) {
        if (selected == null || selected == _baseSentinel) {
          onChanged(null);
        } else {
          onChanged(selected);
        }
      },
    );
  }
}

/// Text input field for entering a reference price, displaying a live converted base price.
class ReferencePriceField extends StatelessWidget {
  /// Controller owning the reference price text.
  final TextEditingController controller;

  /// Suffix currency code displayed in the field.
  final String currencyCode;

  /// Conversion exchange rate, or null if missing.
  final double? rate;

  /// Converted price rounding step.
  final int rounding;

  /// Base currency decimal digits.
  final int baseDecimals;

  /// Base currency display symbol.
  final String baseSymbol;

  /// Input field label.
  final String label;

  /// Whether non-empty entry is required for form validation.
  final bool requiredField;

  /// Helper text displayed when the input field is currently empty.
  final String? helperWhenEmpty;

  /// Creates a [ReferencePriceField].
  const ReferencePriceField({
    super.key,
    required this.controller,
    required this.currencyCode,
    required this.rate,
    required this.rounding,
    required this.baseDecimals,
    required this.baseSymbol,
    required this.label,
    this.requiredField = false,
    this.helperWhenEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, val, _) {
        String? liveHelper = helperWhenEmpty;
        final trimmed = val.text.trim();

        if (trimmed.isNotEmpty && rate != null) {
          final refVal = ReferencePricingMath.parseReferencePrice(trimmed);
          if (refVal != null) {
            try {
              final converted = ReferencePricingMath.convert(
                reference: refVal,
                rate: rate!,
                rounding: rounding,
                baseDecimals: baseDecimals,
              );
              liveHelper = '= $converted $baseSymbol';
            } on ReferencePricingException {
              liveHelper = null;
            }
          }
        }

        return TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            AmountInputFormatter(
              maxDecimals: ReferencePricingMath.maxReferenceDecimals,
            ),
          ],
          decoration: InputDecoration(
            labelText: label,
            suffixText: currencyCode,
            helperText: liveHelper,
            helperMaxLines: 2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (text) {
            final t = text?.trim() ?? '';
            if (t.isEmpty) {
              if (requiredField) {
                return l10n.refErrReferencePriceRequired;
              }
              return null;
            }
            final parsed = ReferencePricingMath.parseReferencePrice(t);
            if (parsed == null) {
              return l10n.refErrInvalidPrice;
            }
            return null;
          },
        );
      },
    );
  }
}

/// Result of reconciling a selected currency against current catalog state.
class PricingSelectionResult {
  /// The reconciled currency code, or null for base currency.
  final String? code;

  /// Whether the selection was reverted due to archival or unavailability.
  final bool reverted;

  /// Creates a [PricingSelectionResult].
  const PricingSelectionResult({required this.code, required this.reverted});
}

/// Pure static reconciliation helper for currency selections.
abstract final class PricingSelection {
  /// Reconciles a [selected] currency code against [storedCurrency], [activeCodes], and [allCodes].
  static PricingSelectionResult reconcile({
    required String? selected,
    required String? storedCurrency,
    required Set<String> activeCodes,
    required Set<String> allCodes,
  }) {
    if (selected == null) {
      return const PricingSelectionResult(code: null, reverted: false);
    }
    if (selected == storedCurrency && allCodes.contains(selected)) {
      return PricingSelectionResult(code: selected, reverted: false);
    }
    if (activeCodes.contains(selected)) {
      return PricingSelectionResult(code: selected, reverted: false);
    }
    final fallback =
        (storedCurrency != null && allCodes.contains(storedCurrency))
        ? storedCurrency
        : null;
    return PricingSelectionResult(code: fallback, reverted: true);
  }
}
