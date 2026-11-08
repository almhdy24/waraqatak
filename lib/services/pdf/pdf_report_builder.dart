import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../utils/pdf_settings.dart';
import '../access/access_guard.dart';
import '../access/permission_registry.dart';
import 'pdf_fonts.dart';
import 'pdf_text_utils.dart';
import 'pdf_theme.dart';

/// Specification for a table column in a PDF report.
class PdfReportColumn {
  final String title;
  final double flex;
  final pw.TextAlign align;

  const PdfReportColumn({
    required this.title,
    this.flex = 1.0,
    this.align = pw.TextAlign.start,
  });
}

/// Key-value summary chip for top of PDF report.
class PdfReportSummaryCard {
  final String label;
  final String value;
  final PdfColor? color;

  const PdfReportSummaryCard({
    required this.label,
    required this.value,
    this.color,
  });
}

/// Complete data package to render any business report into PDF.
class PdfReportData {
  final String title;
  final String? subtitle;
  final String? dateRange;
  final String? warningNotice;
  final List<PdfReportSummaryCard> summaryCards;
  final List<PdfReportColumn> columns;
  final List<List<String>> rows;
  final List<String>? totalsRow;

  const PdfReportData({
    required this.title,
    this.subtitle,
    this.dateRange,
    this.warningNotice,
    this.summaryCards = const [],
    required this.columns,
    required this.rows,
    this.totalsRow,
  });
}

/// Generic PDF builder for tabular business reports.
class PdfReportBuilder {
  static final _timeFmt = DateFormat('dd/MM/yyyy HH:mm');

  static Future<Uint8List> build({
    required Business business,
    required AppLocalizations l10n,
    required PdfReportData data,
    PdfStyleSettings style = const PdfStyleSettings(),
  }) async {
    AccessGuard.require(PermissionRegistry.reportsExportPdf);
    final theme = PdfTheme.fromSettings(style);
    final regularFontData =
        await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final boldFontData =
        await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
    final regular = ArabicTtfFont(regularFontData);
    final bold = ArabicTtfFont(boldFontData);

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

    final pdf = pw.Document();
    final isArabic = l10n.isArabic;
    final textDir = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: _pageTheme(regular, bold, rtl: isArabic),
        textDirection: textDir,
        header: (context) => _buildHeader(
          business: business,
          logoImage: logoImage,
          data: data,
          theme: theme,
          bold: bold,
          regular: regular,
          isArabic: isArabic,
          l10n: l10n,
        ),
        footer: (context) => _buildFooter(
          context: context,
          theme: theme,
          regular: regular,
          l10n: l10n,
        ),
        build: (context) => [
          pw.SizedBox(height: 8),

          // Optional warning notice
          if (data.warningNotice != null && data.warningNotice!.isNotEmpty) ...[
            _buildWarningBox(
              data.warningNotice!,
              theme: theme,
              bold: bold,
              regular: regular,
            ),
            pw.SizedBox(height: 10),
          ],

          // Summary Cards
          if (data.summaryCards.isNotEmpty) ...[
            _buildSummaryRow(
              data.summaryCards,
              theme: theme,
              bold: bold,
              regular: regular,
            ),
            pw.SizedBox(height: 12),
          ],

          // Table
          _buildTable(
            data: data,
            theme: theme,
            bold: bold,
            regular: regular,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.ThemeData _pageTheme(
    pw.Font regular,
    pw.Font bold, {
    required bool rtl,
  }) {
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: [regular],
    );
  }

  static pw.Widget _buildHeader({
    required Business business,
    required pw.MemoryImage? logoImage,
    required PdfReportData data,
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
    required bool isArabic,
    required AppLocalizations l10n,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logoImage != null) ...[
            pw.Container(
              width: 48,
              height: 48,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                PdfTextUtils.directionalText(
                  business.name,
                  font: bold,
                  fontSize: theme.fs(14),
                  color: theme.textColor,
                ),
                if (business.phone.isNotEmpty)
                  PdfTextUtils.directionalText(
                    business.phone,
                    font: regular,
                    fontSize: theme.fs(8.5),
                    color: theme.mutedTextColor,
                    fallbackDirection: pw.TextDirection.ltr,
                  ),
                if (business.taxId != null && business.taxId!.isNotEmpty)
                  PdfTextUtils.directionalText(
                    '${l10n.taxId}: ${business.taxId}',
                    font: regular,
                    fontSize: theme.fs(8.5),
                    color: theme.mutedTextColor,
                    fallbackDirection: pw.TextDirection.ltr,
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              PdfTextUtils.directionalText(
                data.title,
                font: bold,
                fontSize: theme.fs(13),
                color: theme.primaryColor,
              ),
              if (data.subtitle != null && data.subtitle!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                PdfTextUtils.directionalText(
                  data.subtitle!,
                  font: regular,
                  fontSize: theme.fs(9),
                  color: theme.mutedTextColor,
                ),
              ],
              if (data.dateRange != null && data.dateRange!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                PdfTextUtils.directionalText(
                  '${l10n.reportPeriod}: ${data.dateRange}',
                  font: regular,
                  fontSize: theme.fs(8.5),
                  color: theme.mutedTextColor,
                  fallbackDirection: pw.TextDirection.ltr,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildWarningBox(
    String warning, {
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.amber700, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: PdfTextUtils.directionalText(
              warning,
              font: regular,
              fontSize: theme.fs(8.5),
              color: PdfColors.amber900,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    List<PdfReportSummaryCard> cards, {
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
  }) {
    return pw.Row(
      children: cards.map((card) {
        final cardColor = card.color ?? theme.primaryColor;
        return pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 3),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                PdfTextUtils.directionalText(
                  card.label,
                  font: regular,
                  fontSize: theme.fs(8),
                  color: theme.mutedTextColor,
                ),
                pw.SizedBox(height: 2),
                PdfTextUtils.directionalText(
                  card.value,
                  font: bold,
                  fontSize: theme.fs(10.5),
                  color: cardColor,
                  fallbackDirection: pw.TextDirection.ltr,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildTable({
    required PdfReportData data,
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
  }) {
    final colWidths = <int, pw.TableColumnWidth>{};
    for (int i = 0; i < data.columns.length; i++) {
      colWidths[i] = pw.FlexColumnWidth(data.columns[i].flex);
    }

    final tableRows = <pw.TableRow>[];

    // Header Row
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: theme.lightBg),
        children: data.columns.map((c) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: PdfTextUtils.directionalText(
              c.title,
              font: bold,
              fontSize: theme.fs(8.5),
              color: theme.primaryColor,
              fallbackDirection: pw.TextDirection.ltr,
            ),
          );
        }).toList(),
      ),
    );

    // Body Rows
    for (int rIdx = 0; rIdx < data.rows.length; rIdx++) {
      final row = data.rows[rIdx];
      final isEven = rIdx % 2 == 0;
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.white : PdfColors.grey50,
          ),
          children: List.generate(data.columns.length, (cIdx) {
            final text = cIdx < row.length ? row[cIdx] : '';
            final col = data.columns[cIdx];
            final cellAlign = col.align == pw.TextAlign.right
                ? pw.Alignment.centerRight
                : (col.align == pw.TextAlign.center
                    ? pw.Alignment.center
                    : pw.Alignment.centerLeft);
            return pw.Container(
              alignment: cellAlign,
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: PdfTextUtils.directionalText(
                text,
                font: regular,
                fontSize: theme.fs(8),
                color: theme.textColor,
                fallbackDirection: pw.TextDirection.ltr,
              ),
            );
          }),
        ),
      );
    }

    // Optional Totals Row
    if (data.totalsRow != null) {
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            border: const pw.Border(
              top: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
            ),
          ),
          children: List.generate(data.columns.length, (cIdx) {
            final text = cIdx < data.totalsRow!.length ? data.totalsRow![cIdx] : '';
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: PdfTextUtils.directionalText(
                text,
                font: bold,
                fontSize: theme.fs(8.5),
                color: theme.textColor,
                fallbackDirection: pw.TextDirection.ltr,
              ),
            );
          }),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: colWidths,
      children: tableRows,
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required PdfTheme theme,
    required pw.Font regular,
    required AppLocalizations l10n,
  }) {
    final nowStr = _timeFmt.format(DateTime.now());
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          PdfTextUtils.directionalText(
            '${l10n.reportGeneratedAt}: $nowStr',
            font: regular,
            fontSize: theme.fs(7.5),
            color: theme.mutedTextColor,
            fallbackDirection: pw.TextDirection.ltr,
          ),
          PdfTextUtils.directionalText(
            '${l10n.page} ${context.pageNumber} / ${context.pagesCount}',
            font: regular,
            fontSize: theme.fs(7.5),
            color: theme.mutedTextColor,
            fallbackDirection: pw.TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
