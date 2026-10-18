import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../models/customer_statement.dart';
import '../../utils/pdf_settings.dart';
import 'pdf_fonts.dart';
import 'pdf_text_utils.dart';
import 'pdf_theme.dart';

class PdfCustomerStatementBuilder {
  static final _numFmt = NumberFormat('#,##0.##');
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _timeFmt = DateFormat('dd/MM/yyyy HH:mm');

  static Future<Uint8List> build({
    required CustomerStatement statement,
    required Business business,
    required AppLocalizations l10n,
    PdfStyleSettings style = const PdfStyleSettings(),
  }) async {
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
    final textDir =
        isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: _pageTheme(regular, bold, rtl: isArabic),
        textDirection: textDir,
        header: (context) => _buildHeader(
          business: business,
          logoImage: logoImage,
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
          textDir: textDir,
          l10n: l10n,
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          // Customer & Period Info
          _buildCustomerInfo(
            statement: statement,
            theme: theme,
            bold: bold,
            regular: regular,
            isArabic: isArabic,
            l10n: l10n,
          ),
          pw.SizedBox(height: 12),

          // Warnings if discrepancies exist
          if (statement.hasDiscrepancy) ...[
            _buildWarningBox(
              warnings: statement.warnings,
              theme: theme,
              bold: bold,
              regular: regular,
              isArabic: isArabic,
              l10n: l10n,
              symbol: statement.currencySymbol,
            ),
            pw.SizedBox(height: 12),
          ],

          // Summary 4-card row
          _buildSummaryCards(
            statement: statement,
            theme: theme,
            bold: bold,
            regular: regular,
            isArabic: isArabic,
            l10n: l10n,
          ),
          pw.SizedBox(height: 16),

          // Main Transactions Table
          _buildTransactionsTable(
            statement: statement,
            theme: theme,
            bold: bold,
            regular: regular,
            isArabic: isArabic,
            l10n: l10n,
          ),

          // Cancelled invoice receipts explanatory section (if any)
          if (statement.hasCancelledInvoiceReceipts) ...[
            pw.SizedBox(height: 18),
            _buildCancelledReceiptsSection(
              receipts: statement.cancelledInvoiceReceipts,
              theme: theme,
              bold: bold,
              regular: regular,
              isArabic: isArabic,
              l10n: l10n,
              symbol: statement.currencySymbol,
            ),
          ],

          pw.SizedBox(height: 24),
          _buildSignatureBox(
            theme: theme,
            regular: regular,
            isArabic: isArabic,
            l10n: l10n,
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
    final base = pw.ThemeData.withFont(base: regular, bold: bold);
    if (!rtl) return base;
    return base.copyWith(
      defaultTextStyle: base.defaultTextStyle
          .copyWith(wordSpacing: PdfTextUtils.rtlWordSpacing),
    );
  }

  static pw.Widget _buildHeader({
    required Business business,
    required pw.MemoryImage? logoImage,
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
    required bool isArabic,
    required AppLocalizations l10n,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: theme.primaryColor, width: 2),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Business details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                PdfTextUtils.directionalText(
                  business.name,
                  font: bold,
                  fontSize: theme.fs(16),
                  color: theme.primaryColor,
                ),
                if (business.phone.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  PdfTextUtils.directionalText(
                    '${l10n.phone}: ${business.phone}',
                    font: regular,
                    fontSize: theme.fs(9.5),
                    color: theme.textColor,
                    fallbackDirection: pw.TextDirection.ltr,
                  ),
                ],
                if (business.address.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  PdfTextUtils.directionalText(
                    business.address,
                    font: regular,
                    fontSize: theme.fs(9.5),
                    color: theme.mutedTextColor,
                  ),
                ],
              ],
            ),
          ),
          // Title & Logo
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (logoImage != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  margin: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: PdfTextUtils.directionalText(
                  l10n.customerStatement,
                  font: bold,
                  fontSize: theme.fs(13),
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCustomerInfo({
    required CustomerStatement statement,
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
    required bool isArabic,
    required AppLocalizations l10n,
  }) {
    final contact = statement.contact;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: theme.lightBg,
        border: pw.Border.all(color: theme.borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Customer details
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    PdfTextUtils.directionalText(
                      '${l10n.customer}: ',
                      font: bold,
                      fontSize: theme.fs(10),
                      color: theme.primaryColor,
                    ),
                    PdfTextUtils.directionalText(
                      contact.name,
                      font: bold,
                      fontSize: theme.fs(12),
                      color: theme.textColor,
                    ),
                  ],
                ),
                if (contact.phone != null) ...[
                  pw.SizedBox(height: 3),
                  PdfTextUtils.directionalText(
                    '${l10n.phone}: ${contact.phone}',
                    font: regular,
                    fontSize: theme.fs(9.5),
                    color: theme.textColor,
                    fallbackDirection: pw.TextDirection.ltr,
                  ),
                ],
                if (contact.address != null) ...[
                  pw.SizedBox(height: 2),
                  PdfTextUtils.directionalText(
                    '${l10n.address}: ${contact.address}',
                    font: regular,
                    fontSize: theme.fs(9),
                    color: theme.mutedTextColor,
                  ),
                ],
              ],
            ),
          ),
          // Statement Period & Currency
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                PdfTextUtils.directionalText(
                  '${l10n.statementPeriod}: ${_dateFmt.format(statement.from)} – ${_dateFmt.format(statement.to)}',
                  font: bold,
                  fontSize: theme.fs(9.5),
                  color: theme.textColor,
                  fallbackDirection: pw.TextDirection.ltr,
                ),
                pw.SizedBox(height: 3),
                PdfTextUtils.directionalText(
                  '${l10n.currency}: ${statement.currencyCode} (${statement.currencySymbol})',
                  font: regular,
                  fontSize: theme.fs(9),
                  color: theme.textColor,
                ),
                pw.SizedBox(height: 2),
                PdfTextUtils.directionalText(
                  '${l10n.date}: ${_dateFmt.format(DateTime.now())}',
                  font: regular,
                  fontSize: theme.fs(8.5),
                  color: theme.mutedTextColor,
                  fallbackDirection: pw.TextDirection.ltr,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildWarningBox({
    required List<StatementWarning> warnings,
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
    required bool isArabic,
    required AppLocalizations l10n,
    required String symbol,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF8E1'),
        border: pw.Border.all(color: PdfColor.fromHex('#FFA000')),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 6,
                height: 6,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E65100'),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 4),
              PdfTextUtils.directionalText(
                l10n.statementWarningTitle,
                font: bold,
                fontSize: theme.fs(9.5),
                color: PdfColor.fromHex('#E65100'),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          ...warnings.map(
            (w) => PdfTextUtils.directionalText(
              '• ${l10n.statementWarningDetail(w.invoiceNumber, _numFmt.format(w.discrepancy), symbol)}',
              font: regular,
              fontSize: theme.fs(8.5),
              color: PdfColor.fromHex('#BF360C'),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCards({
    required CustomerStatement statement,
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
    required bool isArabic,
    required AppLocalizations l10n,
  }) {
    final sym = statement.currencySymbol;

    return pw.Row(
      children: [
        _buildStatCard(
          label: l10n.openingBalance,
          value: _numFmt.format(statement.openingBalance),
          symbol: sym,
          theme: theme,
          bold: bold,
          regular: regular,
          color: theme.textColor,
        ),
        pw.SizedBox(width: 6),
        _buildStatCard(
          label: l10n.totalInvoiced,
          value: _numFmt.format(statement.totalInvoiced),
          symbol: sym,
          theme: theme,
          bold: bold,
          regular: regular,
          color: theme.primaryColor,
        ),
        pw.SizedBox(width: 6),
        _buildStatCard(
          label: l10n.totalPaid,
          value: _numFmt.format(statement.totalPaid),
          symbol: sym,
          theme: theme,
          bold: bold,
          regular: regular,
          color: PdfColor.fromHex('#2E7D32'),
        ),
        pw.SizedBox(width: 6),
        _buildStatCard(
          label: l10n.closingBalance,
          value: _numFmt.format(statement.closingBalance),
          symbol: sym,
          theme: theme,
          bold: bold,
          regular: regular,
          color: statement.closingBalance > 0
              ? PdfColor.fromHex('#C62828')
              : PdfColor.fromHex('#2E7D32'),
          isHighlight: true,
        ),
      ],
    );
  }

  static pw.Widget _buildStatCard({
    required String label,
    required String value,
    required String symbol,
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
    required PdfColor color,
    bool isHighlight = false,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: isHighlight
              ? PdfColor(
                  color.red * 0.08 + 0.92,
                  color.green * 0.08 + 0.92,
                  color.blue * 0.08 + 0.92,
                )
              : theme.lightBg,
          border: pw.Border.all(
            color: isHighlight ? color : theme.borderColor,
            width: isHighlight ? 1.5 : 1,
          ),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            PdfTextUtils.directionalText(
              label,
              font: regular,
              fontSize: theme.fs(8.5),
              color: theme.mutedTextColor,
            ),
            pw.SizedBox(height: 3),
            PdfTextUtils.directionalText(
              '$value $symbol',
              font: bold,
              fontSize: theme.fs(10.5),
              color: color,
              fallbackDirection: pw.TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTransactionsTable({
    required CustomerStatement statement,
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
    required bool isArabic,
    required AppLocalizations l10n,
  }) {
    final sym = statement.currencySymbol;
    final headers = [
      l10n.date,
      l10n.transactionDetails,
      '${l10n.debit} (+)',
      '${l10n.credit} (-)',
      l10n.runningBalance,
    ];

    final rows = <List<pw.Widget>>[];

    // Opening balance row
    rows.add([
      _cellText(_dateFmt.format(statement.from), regular, theme,
          fallbackDir: pw.TextDirection.ltr),
      _cellText(l10n.openingBalance, bold, theme),
      _cellText('-', regular, theme, align: pw.TextAlign.center),
      _cellText('-', regular, theme, align: pw.TextAlign.center),
      _cellText(
        '${_numFmt.format(statement.openingBalance)} $sym',
        bold,
        theme,
        align: pw.TextAlign.right,
        fallbackDir: pw.TextDirection.ltr,
      ),
    ]);

    for (final e in statement.entries) {
      final desc = _formatEntryDescription(e, l10n);
      final debitStr = e.debit > 0 ? _numFmt.format(e.debit) : '-';
      final creditStr = e.credit > 0 ? _numFmt.format(e.credit) : '-';
      final balanceStr = '${_numFmt.format(e.runningBalance)} $sym';

      rows.add([
        _cellText(_dateFmt.format(e.date), regular, theme,
            fallbackDir: pw.TextDirection.ltr),
        _cellText(desc, e.isAdjustment ? bold : regular, theme,
            color: e.isAdjustment
                ? PdfColor.fromHex('#C62828')
                : theme.textColor),
        _cellText(
          debitStr,
          regular,
          theme,
          align: pw.TextAlign.right,
          color: e.debit > 0 ? theme.primaryColor : theme.mutedTextColor,
          fallbackDir: pw.TextDirection.ltr,
        ),
        _cellText(
          creditStr,
          regular,
          theme,
          align: pw.TextAlign.right,
          color: e.credit > 0
              ? PdfColor.fromHex('#2E7D32')
              : theme.mutedTextColor,
          fallbackDir: pw.TextDirection.ltr,
        ),
        _cellText(
          balanceStr,
          bold,
          theme,
          align: pw.TextAlign.right,
          color: e.runningBalance > 0
              ? PdfColor.fromHex('#C62828')
              : PdfColor.fromHex('#2E7D32'),
          fallbackDir: pw.TextDirection.ltr,
        ),
      ]);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: theme.borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4), // Date
        1: const pw.FlexColumnWidth(3.2), // Details
        2: const pw.FlexColumnWidth(1.6), // Debit
        3: const pw.FlexColumnWidth(1.6), // Credit
        4: const pw.FlexColumnWidth(2.0), // Balance
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: theme.lightBg),
          children: headers
              .map(
                (h) => pw.Container(
                  alignment: pw.Alignment.center,
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  child: PdfTextUtils.directionalText(
                    h,
                    font: bold,
                    fontSize: theme.fs(9),
                    color: theme.primaryColor,
                  ),
                ),
              )
              .toList(),
        ),
        // Rows
        ...rows.map(
          (row) => pw.TableRow(
            children: row
                .map(
                  (cell) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 4, horizontal: 4),
                    child: cell,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  static pw.Widget _cellText(
    String text,
    pw.Font font,
    PdfTheme theme, {
    pw.TextAlign align = pw.TextAlign.start,
    pw.Alignment? alignment,
    PdfColor? color,
    pw.TextDirection? fallbackDir,
  }) {
    final effectiveAlignment = alignment ??
        (align == pw.TextAlign.center
            ? pw.Alignment.center
            : align == pw.TextAlign.right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft);
    return pw.Container(
      alignment: effectiveAlignment,
      child: PdfTextUtils.directionalText(
        text,
        font: font,
        fontSize: theme.fs(8.5),
        color: color ?? theme.textColor,
        fallbackDirection: fallbackDir,
      ),
    );
  }

  static String _formatEntryDescription(
    StatementEntry e,
    AppLocalizations l10n,
  ) {
    switch (e.type) {
      case StatementEntryType.invoice:
        return '${l10n.invoice} #${e.documentNumber}';
      case StatementEntryType.initialPayment:
        return '${l10n.initialPayment} (#${e.documentNumber})';
      case StatementEntryType.receipt:
        return '${l10n.paymentReceipt} #${e.documentNumber}';
      case StatementEntryType.reconciliationAdjustment:
        return '${l10n.statementAdjustment} (#${e.documentNumber})';
    }
  }

  static pw.Widget _buildCancelledReceiptsSection({
    required List<CancelledInvoiceReceipt> receipts,
    required PdfTheme theme,
    required pw.Font bold,
    required pw.Font regular,
    required bool isArabic,
    required AppLocalizations l10n,
    required String symbol,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          PdfTextUtils.directionalText(
            l10n.cancelledReceiptsTitle,
            font: bold,
            fontSize: theme.fs(9.5),
            color: PdfColor.fromHex('#424242'),
          ),
          pw.SizedBox(height: 2),
          PdfTextUtils.directionalText(
            l10n.cancelledReceiptsSubtitle,
            font: regular,
            fontSize: theme.fs(8),
            color: PdfColor.fromHex('#616161'),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(2.0),
              2: const pw.FlexColumnWidth(2.0),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cellText(l10n.date, bold, theme, align: pw.TextAlign.center),
                  _cellText(l10n.paymentReceipt, bold, theme,
                      align: pw.TextAlign.center),
                  _cellText(l10n.cancelledInvoice, bold, theme,
                      align: pw.TextAlign.center),
                  _cellText(l10n.amount, bold, theme,
                      align: pw.TextAlign.center),
                ],
              ),
              ...receipts.map(
                (r) => pw.TableRow(
                  children: [
                    _cellText(_dateFmt.format(r.date), regular, theme,
                        align: pw.TextAlign.center,
                        fallbackDir: pw.TextDirection.ltr),
                    _cellText(r.receiptNumber, regular, theme,
                        align: pw.TextAlign.center),
                    _cellText('#${r.cancelledInvoiceNumber}', regular, theme,
                        align: pw.TextAlign.center),
                    _cellText(
                      '${_numFmt.format(r.amount)} $symbol',
                      bold,
                      theme,
                      align: pw.TextAlign.right,
                      fallbackDir: pw.TextDirection.ltr,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureBox({
    required PdfTheme theme,
    required pw.Font regular,
    required bool isArabic,
    required AppLocalizations l10n,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 140,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            PdfTextUtils.directionalText(
              l10n.authorizedSignature,
              font: regular,
              fontSize: theme.fs(8.5),
              color: theme.mutedTextColor,
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              width: 140,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            PdfTextUtils.directionalText(
              l10n.customerSignature,
              font: regular,
              fontSize: theme.fs(8.5),
              color: theme.mutedTextColor,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required PdfTheme theme,
    required pw.Font regular,
    required pw.TextDirection textDir,
    required AppLocalizations l10n,
  }) {
    final nowStr = _timeFmt.format(DateTime.now());
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          PdfTextUtils.directionalText(
            '${l10n.generatedAt}: $nowStr',
            font: regular,
            fontSize: theme.fs(8),
            color: theme.mutedTextColor,
            fallbackDirection: pw.TextDirection.ltr,
          ),
          PdfTextUtils.directionalText(
            '${l10n.page} ${context.pageNumber} / ${context.pagesCount}',
            font: regular,
            fontSize: theme.fs(8),
            color: theme.mutedTextColor,
            fallbackDirection: pw.TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
