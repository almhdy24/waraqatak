import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../utils/print_settings.dart';
import 'pdf/pdf_document_builder.dart';

class PdfService {
  static Future<Uint8List> generateDocumentPdf({
    required Document doc,
    required Business business,
    Contact? contact,
    required List<DocumentItem> items,
    required AppLocalizations l10n,
    Document? relatedDocument,
    PaperSize? paperSize,
  }) async {
    final size = paperSize ?? await PrintSettings.getDefaultSize();
    return PdfDocumentBuilder.build(
      doc: doc,
      business: business,
      contact: contact,
      items: items,
      l10n: l10n,
      relatedDocument: relatedDocument,
      paperSize: size,
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
}
