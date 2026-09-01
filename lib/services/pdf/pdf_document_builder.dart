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
  }) async {
    final pdf = pw.Document();
    final theme = PdfTheme.defaultTheme();

    // Load fonts
    final regularFontData =
        await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final boldFontData =
        await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
    final regular = pw.Font.ttf(regularFontData);
    final bold = pw.Font.ttf(boldFontData);

    // Load logo
    pw.MemoryImage? logoImage;
    if (business.logoPath != null && business.logoPath!.isNotEmpty) {
      final logoFile = File(business.logoPath!);
      if (await logoFile.exists()) {
        try {
          final logoBytes = await logoFile.readAsBytes();
          if (logoBytes.isNotEmpty) {
            logoImage = pw.MemoryImage(logoBytes);
          }
        } catch (_) {}
      }
    }

    final isArabic = l10n.langCode == 'ar';
    final documentTypeLabel = _documentTypeLabel(doc.type, l10n);
    // ✅ FIX: use currencyCode instead of currency
    final currency = business.currencyCode;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(theme.margin),
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
              value: doc.paymentMethod!,
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
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
    switch (type) {
      case 'invoice':
        return l10n.invoice;
      case 'quotation':
        return l10n.quotation;
      case 'payment_receipt':
        return l10n.paymentReceipt;
      case 'expense_voucher':
        return l10n.expenseVoucher;
      case 'custom':
        return l10n.customDocument;
      default:
        return l10n.documents;
    }
  }
}