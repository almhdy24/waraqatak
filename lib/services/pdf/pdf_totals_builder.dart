import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../localization/app_localizations.dart';
import '../../models/document.dart';

class PdfTotalsBuilder {
  static pw.Widget build({
    required Document doc,
    required String currency,
    required AppLocalizations l10n,
    required pw.Font bold,
    required pw.Font regular,
    required PdfColor textColor,
    required PdfColor primaryColor,
    required bool isArabic,
  }) {
    final labelDirection =
        isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8F7F3),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _row(
            label: l10n.subtotal,
            value: doc.subtotal,
            currency: currency,
            font: regular,
            color: textColor,
            labelDirection: labelDirection,
          ),
          if (doc.discount > 0)
            _row(
              label: l10n.discount,
              value: doc.discount,
              currency: currency,
              font: regular,
              color: textColor,
              labelDirection: labelDirection,
            ),
          if (doc.taxAmount > 0)
            _row(
              label: doc.taxRate > 0
                  ? '${l10n.tax} (${doc.taxRate.toStringAsFixed(0)}%)'
                  : l10n.tax,
              value: doc.taxAmount,
              currency: currency,
              font: regular,
              color: textColor,
              labelDirection: labelDirection,
            ),
          pw.Divider(),
          _row(
            label: l10n.total,
            value: doc.total,
            currency: currency,
            font: bold,
            color: primaryColor,
            bold: true,
            labelDirection: labelDirection,
          ),
          if (doc.type == 'invoice') ...[
            _row(
              label: l10n.paid,
              value: doc.paid,
              currency: currency,
              font: regular,
              color: textColor,
              labelDirection: labelDirection,
            ),
            _row(
              label: l10n.remaining,
              value: doc.remaining,
              currency: currency,
              font: bold,
              color: const PdfColor.fromInt(0xFFD64545),
              bold: true,
              labelDirection: labelDirection,
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
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color,
              ),
            ),
          ),
          pw.Text(
            '${value.toStringAsFixed(2)} $currency',
            style: pw.TextStyle(
              font: font,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}