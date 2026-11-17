import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';
import '../utils/format_utils.dart';
import 'app_design_tokens.dart';

/// Reusable financial summary and balance card for Invoices, Purchases,
/// and Quotations. Clearly distinguishes calculated vs user-entered amounts.
class AppTotalsCard extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double taxRate;
  final double total;
  final double paid;
  final double remaining;
  final String currencySymbol;
  final bool showPaymentRow;
  final String? paymentHelperText;
  final bool isTaxInclusive;
  final double? netTaxableBase;

  const AppTotalsCard({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.taxRate,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.currencySymbol,
    this.showPaymentRow = true,
    this.paymentHelperText,
    this.isTaxInclusive = false,
    this.netTaxableBase,
  });

  String _fmt(double v) =>
      '${NumberFormat('#,##0.00').format(v)} $currencySymbol';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppDesignTokens.br16,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: AppDesignTokens.softShadow(context),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.space16,
        vertical: AppDesignTokens.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 20, color: cs.primary),
              const SizedBox(width: AppDesignTokens.space8),
              Expanded(
                child: Text(
                  l10n.financialSummaryCardTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.space12),
          _buildRow(
            isTaxInclusive ? l10n.subtotalInclusive : l10n.subtotal,
            _fmt(subtotal),
            theme,
            cs,
          ),
          if (discount > 0)
            _buildRow(
              l10n.discount,
              '- ${_fmt(discount)}',
              theme,
              cs,
              valueColor: AppDesignTokens.danger,
            ),
          if (isTaxInclusive && (taxAmount > 0 || taxRate > 0)) ...[
            if (netTaxableBase != null)
              _buildRow(l10n.netTaxableBase, _fmt(netTaxableBase!), theme, cs),
            _buildRow(
              '${l10n.taxIncluded} (${FormatUtils.formatTaxRate(taxRate)})',
              _fmt(taxAmount),
              theme,
              cs,
            ),
          ] else if (taxAmount > 0 || taxRate > 0) ...[
            _buildRow(
              '${l10n.tax} (${FormatUtils.formatTaxRate(taxRate)})',
              _fmt(taxAmount),
              theme,
              cs,
            ),
          ],
          const Divider(height: AppDesignTokens.space20),
          _buildRow(
            l10n.total,
            _fmt(total),
            theme,
            cs,
            isTotal: true,
            valueColor: cs.primary,
          ),
          if (showPaymentRow) ...[
            const SizedBox(height: AppDesignTokens.space8),
            _buildRow(l10n.paid, _fmt(paid), theme, cs),
            const SizedBox(height: AppDesignTokens.space4),
            _buildRow(
              l10n.remaining,
              _fmt(remaining),
              theme,
              cs,
              isTotal: true,
              valueColor: remaining > 0
                  ? AppDesignTokens.danger
                  : AppDesignTokens.success,
            ),
            if (paymentHelperText != null && paymentHelperText!.isNotEmpty) ...[
              const SizedBox(height: AppDesignTokens.space8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignTokens.space12,
                  vertical: AppDesignTokens.space6,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: AppDesignTokens.br8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppDesignTokens.space8),
                    Expanded(
                      child: Text(
                        paymentHelperText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value,
    ThemeData theme,
    ColorScheme cs, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
          ),
          Text(
            value,
            style: isTotal
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? cs.primary,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ],
      ),
    );
  }
}
