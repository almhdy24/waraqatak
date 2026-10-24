import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/business.dart';
import '../../utils/pdf_settings.dart';
import 'pdf_text_utils.dart';
import 'pdf_theme.dart';

class PdfHeaderBuilder {
  static pw.Widget build({
    required Business business,
    required pw.Font regular,
    required pw.Font bold,
    required PdfTheme theme,
    pw.MemoryImage? logoImage,
    required bool isArabic,
  }) {
    final style = theme.style;
    final modern = style.template == PdfTemplate.modern;
    final fallbackDir =
        isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final nameColor = modern ? theme.onPrimaryColor : theme.primaryColor;
    final infoColor = modern ? theme.onPrimaryColor : theme.textColor;

    // Show legalName under the trading name if different and set
    final showLegal = business.legalName != null &&
        business.legalName!.trim().isNotEmpty &&
        business.legalName!.trim() != business.name.trim();
    final showTax = style.showTaxId &&
        business.taxId != null &&
        business.taxId!.trim().isNotEmpty;
    final showTaxReg = business.taxReg != null &&
        business.taxReg!.trim().isNotEmpty;
    final showCR = business.commercialReg != null &&
        business.commercialReg!.trim().isNotEmpty;
    final showBranch = business.branch != null &&
        business.branch!.trim().isNotEmpty;

    final details = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfTextUtils.directionalText(
          business.name,
          font: bold,
          fontSize: theme.fs(18),
          color: nameColor,
          fallbackDirection: fallbackDir,
        ),
        if (showLegal)
          PdfTextUtils.directionalText(
            business.legalName!,
            font: regular,
            fontSize: theme.fs(11),
            color: infoColor,
            fallbackDirection: fallbackDir,
          ),
        if (showTax)
          PdfTextUtils.directionalText(
            '${isArabic ? 'الرقم الضريبي:' : 'Tax ID:'} ${business.taxId!}',
            font: regular,
            fontSize: theme.fs(10),
            color: infoColor,
            fallbackDirection: fallbackDir,
          ),
        if (showTaxReg)
          PdfTextUtils.directionalText(
            '${isArabic ? 'رقم التسجيل الضريبي:' : 'Tax Reg:'} ${business.taxReg!}',
            font: regular,
            fontSize: theme.fs(10),
            color: infoColor,
            fallbackDirection: fallbackDir,
          ),
        if (showCR)
          PdfTextUtils.directionalText(
            '${isArabic ? 'السجل التجاري:' : 'CR:'} ${business.commercialReg!}',
            font: regular,
            fontSize: theme.fs(10),
            color: infoColor,
            fallbackDirection: fallbackDir,
          ),
        if (showBranch)
          PdfTextUtils.directionalText(
            '${isArabic ? 'الفرع:' : 'Branch:'} ${business.branch!}',
            font: regular,
            fontSize: theme.fs(10),
            color: infoColor,
            fallbackDirection: fallbackDir,
          ),
        if (style.showBusinessContact) ...[
          pw.SizedBox(height: 4),
          if (business.phone.isNotEmpty)
            PdfTextUtils.directionalText(
              business.phone,
              font: regular,
              fontSize: theme.fs(11),
              color: infoColor,
              fallbackDirection: pw.TextDirection.ltr,
            ),
          if (business.address.isNotEmpty)
            PdfTextUtils.directionalText(
              business.address,
              font: regular,
              fontSize: theme.fs(11),
              color: infoColor,
            ),
          if (business.email != null && business.email!.trim().isNotEmpty)
            PdfTextUtils.directionalText(
              business.email!,
              font: regular,
              fontSize: theme.fs(11),
              color: infoColor,
              fallbackDirection: pw.TextDirection.ltr,
            ),
        ],
      ],
    );

    final logo = _logo(logoImage, theme, onBand: modern);
    final row = pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(child: details),
        if (logo != null) ...[pw.SizedBox(width: 12), logo],
      ],
    );

    switch (style.template) {
      case PdfTemplate.modern:
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
            color: theme.primaryColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: row,
        );
      case PdfTemplate.minimal:
        return pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: theme.borderColor, width: 0.8),
            ),
          ),
          child: row,
        );
      case PdfTemplate.classic:
        return row;
    }
  }

  static pw.Widget? _logo(
    pw.MemoryImage? image,
    PdfTheme theme, {
    required bool onBand,
  }) {
    final shape = theme.style.logoShape;
    if (image == null || shape == PdfLogoShape.hidden) return null;
    const size = 60.0;
    final borderColor = onBand ? theme.onPrimaryColor : theme.primaryColor;
    final img = pw.Image(image, width: size, height: size, fit: pw.BoxFit.cover);
    if (shape == PdfLogoShape.circle) {
      return pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          color: PdfColors.white,
          border: pw.Border.all(color: borderColor, width: 1),
        ),
        child: pw.ClipOval(child: img),
      );
    }
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: borderColor, width: 1),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: img,
      ),
    );
  }
}
