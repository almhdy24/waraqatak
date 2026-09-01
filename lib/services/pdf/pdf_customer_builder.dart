import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../localization/app_localizations.dart';
import '../../models/contact.dart';
import '../../models/document.dart';
import 'pdf_text_utils.dart';

class PdfCustomerBuilder {
  static pw.Widget build({
    required Contact? contact,
    required Document doc,
    required AppLocalizations l10n,
    required pw.Font bold,
    required pw.Font regular,
    required PdfColor textColor,
    required bool isArabic,
  }) {
    final name = contact?.name ?? doc.recipientName ?? '';
    final phone = contact?.phone ?? doc.recipientPhone;
    final address = contact?.address;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8F7F3),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Label
          pw.Directionality(
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Text(
              '${l10n.customerOrParty}:',
              style: pw.TextStyle(
                font: bold,
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          // Name with its own direction
          PdfTextUtils.directionalText(
            name,
            font: bold,
            fontSize: 13,
            color: textColor,
          ),
          if (phone != null) ...[
            pw.SizedBox(height: 4),
            pw.Directionality(
              textDirection: isArabic
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              child: pw.Text(
                '${l10n.phone}:',
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 11,
                  color: textColor,
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            PdfTextUtils.directionalText(
              phone,
              font: regular,
              fontSize: 11,
              color: textColor,
              fallbackDirection: pw.TextDirection.ltr,
            ),
          ],
          if (address != null) ...[
            pw.SizedBox(height: 4),
            pw.Directionality(
              textDirection: isArabic
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              child: pw.Text(
                '${l10n.address}:',
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 11,
                  color: textColor,
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            PdfTextUtils.directionalText(
              address,
              font: regular,
              fontSize: 11,
              color: textColor,
            ),
          ],
        ],
      ),
    );
  }
}