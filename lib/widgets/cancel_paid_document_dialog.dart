import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';
import '../models/document.dart';
import 'app_design_tokens.dart';

class CancelPaidDocumentResult {
  final bool confirmed;
  final String refundStatus;

  const CancelPaidDocumentResult({
    required this.confirmed,
    required this.refundStatus,
  });
}

/// Confirmation dialog displayed when cancelling a document with paid > 0.
/// Explains that payments will disappear from reports, warns against creating
/// a separate voucher to prevent double counting, and allows selecting the refund status.
class CancelPaidDocumentDialog extends StatefulWidget {
  final Document document;

  const CancelPaidDocumentDialog({
    super.key,
    required this.document,
  });

  static Future<CancelPaidDocumentResult?> show(
    BuildContext context, {
    required Document document,
  }) {
    return showDialog<CancelPaidDocumentResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CancelPaidDocumentDialog(document: document),
    );
  }

  @override
  State<CancelPaidDocumentDialog> createState() =>
      _CancelPaidDocumentDialogState();
}

class _CancelPaidDocumentDialogState extends State<CancelPaidDocumentDialog> {
  String _selectedStatus = 'refunded';
  static final _numFmt = NumberFormat('#,##0.##');

  Widget _buildStatusTile({
    required BuildContext context,
    required String title,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final doc = widget.document;
    final isInvoice = doc.type == 'invoice';
    final sym = doc.currencySymbol;

    final dangerColor = AppDesignTokens.semanticDanger(context);
    final warningColor = AppDesignTokens.semanticWarning(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.br20),
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dangerColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, size: 22, color: dangerColor),
          ),
          const SizedBox(width: AppDesignTokens.space12),
          Expanded(
            child: Text(
              l10n.cancelPaidDocumentTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Paid amount pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                l10n.cancelPaidRecordedAmount(_numFmt.format(doc.paid), sym),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Disappears from reports warning
            Text(
              l10n.cancelPaidReportsWarning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),

            // Manual settlement instruction
            Text(
              isInvoice
                  ? l10n.cancelPaidCustomerReturnInstruction
                  : l10n.cancelPaidSupplierReturnInstruction,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Anti double-counting warning banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: warningColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: warningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isInvoice
                          ? l10n.cancelPaidDoubleCountWarning
                          : l10n.cancelPaidDoubleCountWarningPurchase,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: warningColor,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Refund status selector
            Text(
              l10n.refundStatusLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            _buildStatusTile(
              context: context,
              title: l10n.refundStatusRefunded,
              value: 'refunded',
              isSelected: _selectedStatus == 'refunded',
              onTap: () => setState(() => _selectedStatus = 'refunded'),
            ),
            _buildStatusTile(
              context: context,
              title: l10n.refundStatusNotRefunded,
              value: 'unrefunded',
              isSelected: _selectedStatus == 'unrefunded',
              onTap: () => setState(() => _selectedStatus = 'unrefunded'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(l10n.keepDocument),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              CancelPaidDocumentResult(
                confirmed: true,
                refundStatus: _selectedStatus,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          child: Text(l10n.confirmAndCancel),
        ),
      ],
    );
  }
}

/// Dialog to update refund status of an already cancelled document.
class UpdateRefundStatusDialog extends StatefulWidget {
  final String? initialStatus;

  const UpdateRefundStatusDialog({
    super.key,
    this.initialStatus,
  });

  static Future<String?> show(
    BuildContext context, {
    String? initialStatus,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UpdateRefundStatusDialog(initialStatus: initialStatus),
    );
  }

  @override
  State<UpdateRefundStatusDialog> createState() =>
      _UpdateRefundStatusDialogState();
}

class _UpdateRefundStatusDialogState extends State<UpdateRefundStatusDialog> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus == 'unrefunded' ? 'unrefunded' : 'refunded';
  }

  Widget _buildTile({
    required BuildContext context,
    required String title,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _status == value;
    return InkWell(
      onTap: () => setState(() => _status = value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesignTokens.br20),
      title: Text(l10n.updateRefundStatus),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTile(
            context: context,
            title: l10n.refundStatusRefunded,
            value: 'refunded',
          ),
          _buildTile(
            context: context,
            title: l10n.refundStatusNotRefunded,
            value: 'unrefunded',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _status),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
