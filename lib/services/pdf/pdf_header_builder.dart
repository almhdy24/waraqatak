import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/business.dart';
import 'pdf_text_utils.dart';

class PdfHeaderBuilder {
  static pw.Widget build({
    required Business business,
    required pw.Font regular,
    required pw.Font bold,
    required PdfColor primaryColor,
    required PdfColor textColor,
    pw.MemoryImage? logoImage,
    required bool isArabic,
  }) {
    final fallbackDir =
        isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    // Show legalName under the trading name if different and set
    final showLegal = business.legalName != null &&
        business.legalName!.trim().isNotEmpty &&
        business.legalName!.trim() != business.name.trim();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              PdfTextUtils.directionalText(
                business.name,
                font: bold,
                fontSize: 18,
                color: primaryColor,
                fallbackDirection: fallbackDir,
              ),
              if (showLegal)
                PdfTextUtils.directionalText(
                  business.legalName!,
                  font: regular,
                  fontSize: 11,
                  color: textColor,
                  fallbackDirection: fallbackDir,
                ),
              if (business.taxId != null && business.taxId!.trim().isNotEmpty)
                PdfTextUtils.directionalText(
                  business.taxId!,
                  font: regular,
                  fontSize: 10,
                  color: textColor,
                  fallbackDirection: pw.TextDirection.ltr,
                ),
              pw.SizedBox(height: 4),
              if (business.phone.isNotEmpty)
                PdfTextUtils.directionalText(
                  business.phone,
                  font: regular,
                  fontSize: 11,
                  color: textColor,
                  fallbackDirection: pw.TextDirection.ltr,
                ),
              if (business.address.isNotEmpty)
                PdfTextUtils.directionalText(
                  business.address,
                  font: regular,
                  fontSize: 11,
                  color: textColor,
                ),
              if (business.email != null &&
                  business.email!.trim().isNotEmpty)
                PdfTextUtils.directionalText(
                  business.email!,
                  font: regular,
                  fontSize: 11,
                  color: textColor,
                  fallbackDirection: pw.TextDirection.ltr,
                ),
            ],
          ),
        ),
        if (logoImage != null)
          pw.Container(
            width: 60,
            height: 60,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: primaryColor, width: 1),
            ),
            child: pw.ClipOval(
              child: pw.Image(
                logoImage,
                width: 60,
                height: 60,
                fit: pw.BoxFit.cover,
              ),
            ),
          ),
      ],
    );
  }
}
