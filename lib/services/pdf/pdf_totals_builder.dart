import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../localization/app_localizations.dart';
import '../../models/document.dart';
import '../../utils/format_utils.dart';
import '../../utils/pdf_settings.dart';
import 'pdf_theme.dart';

class PdfTotalsBuilder {
  static final _money = NumberFormat('#,##0.00', 'en');

  static pw.Widget build({
    required Document doc,
    required String currency,
    required AppLocalizations l10n,
    required pw.Font bold,
    required pw.Font regular,
    required PdfTheme theme,
    required bool isArabic,
  }) {
    final labelDirection = isArabic
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
    final textColor = theme.textColor;
    final primaryColor = theme.primaryColor;
    final fontSize = theme.fs(11);
    final minimal = theme.style.template == PdfTemplate.minimal;

    final isInclusiveTax =
        (doc.subtotal - doc.discount - doc.total).abs() < 0.01 &&
        doc.taxAmount > 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: minimal
          ? pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: theme.primaryColor, width: 1.2),
              ),
            )
          : pw.BoxDecoration(
              color: theme.lightBg,
              border: pw.Border.all(color: theme.borderColor),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (isInclusiveTax) ...[
            _row(
              label: l10n.subtotalInclusive,
              value: doc.subtotal,
              currency: currency,
              font: regular,
              color: textColor,
              labelDirection: labelDirection,
              fontSize: fontSize,
            ),
            if (doc.discount > 0)
              _row(
                label: l10n.discount,
                value: doc.discount,
                currency: currency,
                font: regular,
                color: textColor,
                labelDirection: labelDirection,
                fontSize: fontSize,
              ),
            _row(
              label: l10n.netTaxableBase,
              value: doc.total - doc.taxAmount,
              currency: currency,
              font: regular,
              color: textColor,
              labelDirection: labelDirection,
              fontSize: fontSize,
            ),
            _row(
              label: doc.taxRate > 0
                  ? '${l10n.taxIncluded} (${FormatUtils.formatTaxRate(doc.taxRate)})'
                  : l10n.taxIncluded,
              value: doc.taxAmount,
              currency: currency,
              font: regular,
              color: textColor,
              labelDirection: labelDirection,
              fontSize: fontSize,
            ),
          ] else ...[
            _row(
              label: l10n.subtotal,
              value: doc.subtotal,
              currency: currency,
              font: regular,
              color: textColor,
              labelDirection: labelDirection,
              fontSize: fontSize,
            ),
            if (doc.discount > 0)
              _row(
                label: l10n.discount,
                value: doc.discount,
                currency: currency,
                font: regular,
                color: textColor,
                labelDirection: labelDirection,
                fontSize: fontSize,
              ),
            if (doc.taxAmount > 0)
              _row(
                label: doc.taxRate > 0
                    ? '${l10n.tax} (${FormatUtils.formatTaxRate(doc.taxRate)})'
                    : l10n.tax,
                value: doc.taxAmount,
                currency: currency,
                font: regular,
                color: textColor,
                labelDirection: labelDirection,
                fontSize: fontSize,
              ),
          ],
          pw.Divider(color: theme.borderColor),
          _row(
            label: l10n.total,
            value: doc.total,
            currency: currency,
            font: bold,
            color: primaryColor,
            bold: true,
            labelDirection: labelDirection,
            fontSize: fontSize,
          ),
          if ((doc.type == 'invoice' || doc.type == 'purchase') &&
              theme.style.showPaymentSummary) ...[
            _row(
              label: l10n.paid,
              value: doc.paid,
              currency: currency,
              font: regular,
              color: textColor,
              labelDirection: labelDirection,
              fontSize: fontSize,
            ),
            _row(
              label: l10n.remaining,
              value: doc.remaining,
              currency: currency,
              font: bold,
              color: theme.dangerColor,
              bold: true,
              labelDirection: labelDirection,
              fontSize: fontSize,
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _row({
    required String label,
    required double value,
    required String currency,
    required pw.Font font,
    required PdfColor color,
    required pw.TextDirection labelDirection,
    required double fontSize,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Directionality(
            textDirection: labelDirection,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: font,
                fontSize: bold ? fontSize * 1.1 : fontSize,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color,
              ),
            ),
          ),
          pw.Text(
            '${_money.format(value)} $currency',
            style: pw.TextStyle(
              font: font,
              fontSize: bold ? fontSize * 1.1 : fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
