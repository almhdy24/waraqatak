import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import 'pdf/pdf_document_builder.dart';

class PdfService {
  static Future<Uint8List> generateDocumentPdf({
    required Document doc,
    required Business business,
    Contact? contact,
    required List<DocumentItem> items,
    required AppLocalizations l10n,
  }) {
    return PdfDocumentBuilder.build(
      doc: doc,
      business: business,
      contact: contact,
      items: items,
      l10n: l10n,
    );
  }

  static Future<void> sharePdf({
    required Document doc,
    required Business business,
    Contact? contact,
    required List<DocumentItem> items,
    required AppLocalizations l10n,
  }) async {
    final bytes = await generateDocumentPdf(
      doc: doc,
      business: business,
      contact: contact,
      items: items,
      l10n: l10n,
    );
    await SharePlus.instance.share(
      '${doc.documentNumber}.pdf',
    );
  }
}
