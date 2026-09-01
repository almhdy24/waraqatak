import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../localization/app_localizations.dart';
import '../../models/document_item.dart';
import 'pdf_text_utils.dart';

class PdfItemsTableBuilder {
  static pw.Widget build({
    required List<DocumentItem> items,
    required AppLocalizations l10n,
    required pw.Font bold,
    required pw.Font regular,
    required PdfColor textColor,
    required PdfColor borderColor,
    required PdfColor primaryColor,
    required PdfColor lightBg,
    required bool isArabic,
  }) {
    final headerCells = [
      _headerCell(l10n.item, bold, primaryColor),
      _headerCell(l10n.quantity, bold, primaryColor),
      _headerCell(l10n.price, bold, primaryColor),
      _headerCell(l10n.total, bold, primaryColor),
    ];

    // Layout direction: reverse column order for Arabic
    final orderedHeader =
        isArabic ? headerCells.reversed.toList() : headerCells;

    final rows = items.map((item) {
      final dataCells = [
        _dataCell(item.description, regular, textColor),
        _dataCell(item.quantity.toString(), regular, textColor),
        _dataCell(item.price.toStringAsFixed(2), regular, textColor),
        _dataCell(item.total.toStringAsFixed(2), regular, textColor),
      ];
      final orderedCells =
          isArabic ? dataCells.reversed.toList() : dataCells;
      return pw.TableRow(children: orderedCells);
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: borderColor),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: lightBg),
          children: orderedHeader,
        ),
        ...rows,
      ],
    );
  }

  static pw.Widget _headerCell(
      String text, pw.Font font, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _dataCell(
      String text, pw.Font font, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: PdfTextUtils.directionalText(
        text,
        font: font,
        color: color,
      ),
    );
  }
}