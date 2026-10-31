import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../localization/app_localizations.dart';
import '../../models/document_item.dart';
import '../../utils/pdf_settings.dart';
import 'pdf_text_utils.dart';
import 'pdf_theme.dart';

class PdfItemsTableBuilder {
  static final _money = NumberFormat('#,##0.00');
  static final _qty = NumberFormat('#,##0.###');

  static pw.Widget build({
    required List<DocumentItem> items,
    required AppLocalizations l10n,
    required pw.Font bold,
    required pw.Font regular,
    required PdfTheme theme,
    required bool isArabic,
  }) {
    final minimal = theme.style.template == PdfTemplate.minimal;
    final modern = theme.style.template == PdfTemplate.modern;
    final headerText = modern ? theme.onPrimaryColor : theme.primaryColor;
    final headerBg = modern ? theme.primaryColor : (minimal ? null : theme.lightBg);

    // Column order is reversed for Arabic so "#" and "item" sit on the right.
    List<T> ordered<T>(List<T> cells) =>
        isArabic ? cells.reversed.toList() : cells;

    final header = ordered([
      _cell('#', bold, headerText, theme, center: true),
      _cell(l10n.item, bold, headerText, theme),
      _cell(l10n.quantity, bold, headerText, theme, center: true),
      _cell(l10n.price, bold, headerText, theme, numeric: true, isArabic: isArabic),
      _cell(l10n.total, bold, headerText, theme, numeric: true, isArabic: isArabic),
    ]);

    final rows = <pw.TableRow>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final striped = theme.style.zebraRows && i.isOdd;
      rows.add(pw.TableRow(
        decoration: striped
            ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB))
            : null,
        children: ordered([
          _cell('${i + 1}', regular, theme.mutedTextColor, theme, center: true),
          _cell(item.description, regular, theme.textColor, theme),
          _cell(
            item.saleUnit != null && item.saleUnit!.isNotEmpty
                ? '${_qty.format(item.quantity)} ${item.saleUnit}'
                : _qty.format(item.quantity),
            regular,
            theme.textColor,
            theme,
            center: true,
          ),
          _cell(_money.format(item.price), regular, theme.textColor, theme,
              numeric: true, isArabic: isArabic),
          _cell(_money.format(item.total), bold, theme.textColor, theme,
              numeric: true, isArabic: isArabic),
        ]),
      ));
    }

    final itemCol = isArabic ? 3 : 1;
    final numCol = isArabic ? 4 : 0;
    return pw.Table(
      border: minimal
          ? pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(color: theme.borderColor, width: 0.6),
              bottom: pw.BorderSide(color: theme.borderColor, width: 0.6),
            )
          : pw.TableBorder.all(color: theme.borderColor, width: 0.8),
      columnWidths: {
        numCol: const pw.FixedColumnWidth(26),
        itemCol: const pw.FlexColumnWidth(3.2),
      },
      defaultColumnWidth: const pw.FlexColumnWidth(1.3),
      children: [
        pw.TableRow(
          decoration: headerBg == null
              ? pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: theme.primaryColor, width: 1.2),
                  ),
                )
              : pw.BoxDecoration(color: headerBg),
          repeat: true,
          children: header,
        ),
        ...rows,
      ],
    );
  }

  static pw.Widget _cell(
    String text,
    pw.Font font,
    PdfColor color,
    PdfTheme theme, {
    bool center = false,
    bool numeric = false,
    bool isArabic = false,
  }) {
    final align = center
        ? pw.Alignment.center
        // Numbers align to the trailing edge of the reading direction.
        : numeric
            ? (isArabic ? pw.Alignment.centerLeft : pw.Alignment.centerRight)
            : (isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft);
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: PdfTextUtils.directionalText(
        text,
        font: font,
        fontSize: theme.fs(10.5),
        color: color,
      ),
    );
  }
}
