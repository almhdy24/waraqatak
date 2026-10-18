import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/customer_statement.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../utils/pdf_settings.dart';
import '../utils/print_settings.dart';
import 'pdf/pdf_customer_statement_builder.dart';
import 'pdf/pdf_document_builder.dart';
import 'pdf/pdf_report_builder.dart';
import 'package:printing/printing.dart';

class PdfService {
  static Future<Uint8List> generateDocumentPdf({
    required Document doc,
    required Business business,
    Contact? contact,
    required List<DocumentItem> items,
    required AppLocalizations l10n,
    Document? relatedDocument,
    PaperSize? paperSize,
    PdfStyleSettings? style,
  }) async {
    final size = paperSize ?? await PrintSettings.getDefaultSize();
    final pdfStyle = style ?? await PdfSettings.load();
    return PdfDocumentBuilder.build(
      doc: doc,
      business: business,
      contact: contact,
      items: items,
      l10n: l10n,
      relatedDocument: relatedDocument,
      paperSize: size,
      style: pdfStyle,
    );
  }

  static Future<void> sharePdf({
    required Document doc,
    required Business business,
    Contact? contact,
    required List<DocumentItem> items,
    required AppLocalizations l10n,
    Document? relatedDocument,
    PaperSize? paperSize,
  }) async {
    final bytes = await generateDocumentPdf(
      doc: doc,
      business: business,
      contact: contact,
      items: items,
      l10n: l10n,
      relatedDocument: relatedDocument,
      paperSize: paperSize,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: ['${doc.documentNumber}.pdf'],
      ),
    );
  }

  static Future<Uint8List> generateCustomerStatementPdf({
    required CustomerStatement statement,
    required Business business,
    required AppLocalizations l10n,
    PdfStyleSettings? style,
  }) async {
    final pdfStyle = style ?? await PdfSettings.load();
    return PdfCustomerStatementBuilder.build(
      statement: statement,
      business: business,
      l10n: l10n,
      style: pdfStyle,
    );
  }

  static Future<void> shareCustomerStatementPdf({
    required CustomerStatement statement,
    required Business business,
    required AppLocalizations l10n,
  }) async {
    final bytes = await generateCustomerStatementPdf(
      statement: statement,
      business: business,
      l10n: l10n,
    );

    final dateFmt = DateFormat('dd/MM/yyyy');
    final numFmt = NumberFormat('#,##0.##');
    final fromStr = dateFmt.format(statement.from);
    final toStr = dateFmt.format(statement.to);
    final balanceStr = numFmt.format(statement.closingBalance);

    final text = l10n.whatsAppStatementCaption(
      statement.contact.name,
      business.name,
      fromStr,
      toStr,
      balanceStr,
      statement.currencySymbol,
    );

    final fileName = 'statement_${statement.contact.name}_${DateFormat('yyyyMMdd').format(statement.to)}.pdf'
        .replaceAll(RegExp(r'\s+'), '_');

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        text: text,
      ),
    );
  }

  static Future<Uint8List> generateReportPdf({
    required Business business,
    required AppLocalizations l10n,
    required PdfReportData data,
    PdfStyleSettings? style,
  }) async {
    final pdfStyle = style ?? await PdfSettings.load();
    return PdfReportBuilder.build(
      business: business,
      l10n: l10n,
      data: data,
      style: pdfStyle,
    );
  }

  static Future<void> printOrShareReportPdf({
    required Business business,
    required AppLocalizations l10n,
    required PdfReportData data,
    String? fileName,
  }) async {
    final bytes = await generateReportPdf(
      business: business,
      l10n: l10n,
      data: data,
    );
    final safeName = (fileName ?? '${data.title}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf')
        .replaceAll(RegExp(r'\s+'), '_');

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: safeName,
    );
  }
}
