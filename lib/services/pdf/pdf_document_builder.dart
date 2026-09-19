import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../models/contact.dart';
import '../../models/document.dart';
import '../../models/document_item.dart';
import '../../utils/currency_utils.dart';
import '../../utils/print_settings.dart';
import 'pdf_customer_builder.dart';
import 'pdf_header_builder.dart';
import 'pdf_items_table_builder.dart';
import 'pdf_theme.dart';
import 'pdf_totals_builder.dart';
import 'pdf_text_utils.dart';

class PdfDocumentBuilder {
  static Future<Uint8List> build({
    required Document doc,
    required Business business,
    Contact? contact,
    required List<DocumentItem> items,
    required AppLocalizations l10n,
    Document? relatedDocument,
    PaperSize paperSize = PaperSize.a4,
  }) async {
    // Load fonts once regardless of paper size
    final regularFontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
    final regular = pw.Font.ttf(regularFontData);
    final bold = pw.Font.ttf(boldFontData);

    pw.MemoryImage? logoImage;
    if (business.logoPath != null && business.logoPath!.isNotEmpty) {
      final logoFile = File(business.logoPath!);
      if (await logoFile.exists()) {
        try {
          final logoBytes = await logoFile.readAsBytes();
          if (logoBytes.isNotEmpty) logoImage = pw.MemoryImage(logoBytes);
        } catch (_) {}
      }
    }

    if (paperSize == PaperSize.thermal80mm) {
      return _buildThermal(
        doc: doc,
        business: business,
        contact: contact,
        items: items,
        l10n: l10n,
        relatedDocument: relatedDocument,
        regular: regular,
        bold: bold,
        logoImage: logoImage,
      );
    }

    return _buildStandard(
      doc: doc,
      business: business,
      contact: contact,
      items: items,
      l10n: l10n,
      relatedDocument: relatedDocument,
      regular: regular,
      bold: bold,
      logoImage: logoImage,
      paperSize: paperSize,
    );
  }

  static Future<Uint8List> _buildStandard({
    required Document doc,
    required Business business,
    Contact? contact,
    required List<DocumentItem> items,
    required AppLocalizations l10n,
    Document? relatedDocument,
    required pw.Font regular,
    required pw.Font bold,
    pw.MemoryImage? logoImage,
    PaperSize paperSize = PaperSize.a4,
  }) async {
    final pdf = pw.Document();
    final theme = PdfTheme.defaultTheme();
    final pageFormat = PrintSettings.pageFormatFor(paperSize);
    final margin = paperSize == PaperSize.a5 ? 16.0 : theme.margin;

    final isArabic = l10n.langCode == 'ar';
    final documentTypeLabel = _documentTypeLabel(doc.type, l10n);
    final currency = doc.currencyCode;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(margin),
        textDirection:
            isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        header: (context) => PdfHeaderBuilder.build(
          business: business,
          regular: regular,
          bold: bold,
          primaryColor: theme.primaryColor,
          textColor: theme.textColor,
          logoImage: logoImage,
          isArabic: isArabic,
        ),
        footer: null,
        build: (context) => [
          pw.SizedBox(height: 12),

          // Document title
          pw.Center(
            child: pw.Directionality(
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Text(
                documentTypeLabel,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 24,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 12),

          // Document info rows
          _buildInfoRow(
            label: l10n.documentNumber,
            value: doc.documentNumber,
            bold: bold,
            regular: regular,
            textColor: theme.textColor,
            isArabic: isArabic,
          ),
          _buildInfoRow(
            label: l10n.date,
            value: DateFormat('dd/MM/yyyy').format(doc.date),
            bold: bold,
            regular: regular,
            textColor: theme.textColor,
            isArabic: isArabic,
            valueDirection: pw.TextDirection.ltr,
          ),
          if (doc.type == 'quotation' && doc.validUntil != null)
            _buildInfoRow(
              label: l10n.validUntil,
              value: DateFormat('dd/MM/yyyy').format(doc.validUntil!),
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
              valueDirection: pw.TextDirection.ltr,
            ),
          if ((doc.type == 'payment_receipt' ||
                  doc.type == 'expense_voucher') &&
              doc.paymentMethod != null)
            _buildInfoRow(
              label: l10n.paymentMethod,
              value: CurrencyUtils.getPaymentMethodLabel(doc.paymentMethod!, l10n),
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
            ),
          if (doc.type == 'payment_receipt' && relatedDocument != null)
            _buildInfoRow(
              label: l10n.relatedInvoice,
              value: relatedDocument.documentNumber,
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
              valueDirection: pw.TextDirection.ltr,
            ),
          if (doc.type == 'invoice' && relatedDocument != null && relatedDocument.type == 'quotation')
            _buildInfoRow(
              label: l10n.sourceQuotation,
              value: relatedDocument.documentNumber,
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
              valueDirection: pw.TextDirection.ltr,
            ),
          pw.SizedBox(height: 12),

          // Customer
          if (contact != null || doc.recipientName != null)
            PdfCustomerBuilder.build(
              contact: contact,
              doc: doc,
              l10n: l10n,
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
            ),

          pw.Divider(color: theme.primaryColor, thickness: 1),
          pw.SizedBox(height: 12),

          // Items
          if (items.isNotEmpty) ...[
            PdfItemsTableBuilder.build(
              items: items,
              l10n: l10n,
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              borderColor: theme.borderColor,
              primaryColor: theme.primaryColor,
              lightBg: theme.lightBg,
              isArabic: isArabic,
            ),
            pw.SizedBox(height: 16),
          ],

          // Totals
          PdfTotalsBuilder.build(
            doc: doc,
            currency: currency,
            l10n: l10n,
            bold: bold,
            regular: regular,
            textColor: theme.textColor,
            primaryColor: theme.primaryColor,
            isArabic: isArabic,
          ),
          pw.SizedBox(height: 16),

          // Notes
          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
            pw.Directionality(
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Text(
                '${l10n.notes}:',
                style: pw.TextStyle(
                  font: bold,
                  color: theme.primaryColor,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            PdfTextUtils.directionalText(
              doc.notes!,
              font: regular,
              fontSize: 12,
              color: theme.textColor,
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoRow({
    required String label,
    required String value,
    required pw.Font bold,
    required pw.Font regular,
    required PdfColor textColor,
    required bool isArabic,
    pw.TextDirection? valueDirection,
  }) {
    final labelDirection =
        isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final actualValueDirection =
        valueDirection ?? PdfTextUtils.detectDirection(value);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Directionality(
            textDirection: labelDirection,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                font: bold,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Directionality(
              textDirection: actualValueDirection,
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 12,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _documentTypeLabel(String type, AppLocalizations l10n) {
    return switch (type) {
      'invoice'         => l10n.invoice,
      'purchase'        => l10n.purchase,
      'quotation'       => l10n.quotation,
      'payment_receipt' => l10n.paymentReceipt,
      'expense_voucher' => l10n.expenseVoucher,
      'custom'          => l10n.customDocument,
      _                 => l10n.documents,
    };
  }

  // ==================== Thermal 80mm layout ====================

  static Future<Uint8List> _buildThermal({
    required Document doc,
    required Business business,
    Contact? contact,
    required List<DocumentItem> items,
    required AppLocalizations l10n,
    Document? relatedDocument,
    required pw.Font regular,
    required pw.Font bold,
    pw.MemoryImage? logoImage,
  }) async {
    final pdf = pw.Document();
    final theme = PdfTheme.defaultTheme();
    final isArabic = l10n.langCode == 'ar';
    final textDir = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final numFmt = NumberFormat('#,##0.00');
    final currency = doc.currencyCode;
    const double fontSize = 10;
    const double smallSize = 9;

    pw.Widget txt(String s, {bool isBold = false, double size = fontSize, pw.TextAlign align = pw.TextAlign.start}) {
      return pw.Directionality(
        textDirection: s.isEmpty ? textDir : PdfTextUtils.detectDirection(s),
        child: pw.Text(s,
            textAlign: align,
            style: pw.TextStyle(font: isBold ? bold : regular, fontSize: size, color: theme.textColor)),
      );
    }

    pw.Widget divider() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text('─' * 32, style: pw.TextStyle(font: regular, fontSize: 8, color: theme.borderColor)),
        );

    final widgets = <pw.Widget>[];

    // Header
    widgets.add(pw.Center(child: txt(business.name, isBold: true, size: 13, align: pw.TextAlign.center)));
    if (business.phone.isNotEmpty) {
      widgets.add(pw.Center(child: txt(business.phone, size: smallSize, align: pw.TextAlign.center)));
    }
    if (business.address.isNotEmpty) {
      widgets.add(pw.Center(
          child: pw.Directionality(textDirection: textDir,
              child: pw.Text(business.address, textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regular, fontSize: smallSize, color: theme.textColor)))));
    }
    widgets.add(divider());

    // Doc info
    widgets.add(pw.Center(child: txt(_documentTypeLabel(doc.type, l10n), isBold: true, size: 12, align: pw.TextAlign.center)));
    widgets.add(txt('${l10n.documentNumber}: ${doc.documentNumber}', size: smallSize));
    widgets.add(txt('${l10n.date}: ${DateFormat('dd/MM/yyyy').format(doc.date)}', size: smallSize));

    // Contact
    final contactName = contact?.name ?? doc.recipientName;
    if (contactName != null && contactName.isNotEmpty) {
      widgets.add(pw.Directionality(textDirection: textDir,
          child: pw.Text('${l10n.customerOrParty}: $contactName',
              style: pw.TextStyle(font: regular, fontSize: smallSize, color: theme.textColor))));
    }
    widgets.add(divider());

    // Items
    for (final item in items) {
      widgets.add(pw.Directionality(textDirection: textDir,
          child: pw.Text(item.description,
              style: pw.TextStyle(font: bold, fontSize: fontSize, color: theme.textColor))));
      final lineTotal = item.quantity * item.price;
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          txt('${numFmt.format(item.quantity)} × ${numFmt.format(item.price)}', size: smallSize),
          txt('${numFmt.format(lineTotal)} $currency', size: smallSize),
        ],
      ));
      widgets.add(pw.SizedBox(height: 2));
    }
    widgets.add(divider());

    // Totals
    void totRow(String label, double value, {bool emph = false}) {
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Directionality(textDirection: textDir,
              child: pw.Text(label, style: pw.TextStyle(font: emph ? bold : regular, fontSize: fontSize))),
          pw.Text('${numFmt.format(value)} $currency',
              style: pw.TextStyle(font: emph ? bold : regular, fontSize: fontSize, color: emph ? theme.primaryColor : theme.textColor)),
        ],
      ));
    }

    if (doc.discount > 0) totRow(l10n.discount, doc.discount);
    if (doc.taxAmount > 0) totRow('${l10n.tax} ${doc.taxRate.toStringAsFixed(0)}%', doc.taxAmount);
    totRow(l10n.grandTotal, doc.total, emph: true);
    if (doc.paid > 0) totRow(l10n.paid, doc.paid);
    if (doc.remaining > 0) totRow(l10n.remaining, doc.remaining);

    // Notes
    if (doc.notes != null && doc.notes!.isNotEmpty) {
      widgets.add(divider());
      widgets.add(pw.Directionality(textDirection: textDir,
          child: pw.Text('${l10n.notes}: ${doc.notes!}',
              style: pw.TextStyle(font: regular, fontSize: smallSize, color: theme.textColor))));
    }
    widgets.add(pw.SizedBox(height: 8));

    pdf.addPage(pw.Page(
      pageFormat: PrintSettings.pageFormatFor(PaperSize.thermal80mm),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: widgets,
      ),
    ));

    return pdf.save();
  }
}
