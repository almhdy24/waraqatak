import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../localization/app_localizations.dart';
import '../../models/business.dart';
import '../../models/contact.dart';
import '../../models/document.dart';
import '../../models/document_item.dart';
import '../../models/digital_seal.dart';
import '../../database/database_helper.dart';
import '../../utils/currency_utils.dart';
import '../../utils/format_utils.dart';
import '../../utils/pdf_settings.dart';
import '../../utils/print_settings.dart';
import '../digital_seal_storage_service.dart';
import '../seal_geometry_engine.dart';
import '../../core/feature_gate.dart';
import '../feature_access.dart';
import 'pdf_customer_builder.dart';
import 'pdf_font_data.dart';
import 'pdf_fonts.dart';
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
    PdfStyleSettings style = const PdfStyleSettings(),
    DocumentSealSnapshot? sealSnapshot,
    (DigitalSealConfig? stamp, DigitalSealConfig? signature)?
    activeSealsPreview,
  }) async {
    final theme = PdfTheme.fromSettings(style);
    // Load fonts once regardless of paper size
    final (regularData, boldData) = await PdfFontData.load();
    final regular = ArabicTtfFont(regularData);
    final bold = ArabicTtfFont(boldData);

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

    final paymentMethodLabel = doc.paymentMethod != null
        ? await CurrencyUtils.resolvePaymentMethodLabel(
            doc.paymentMethod!,
            l10n,
          )
        : '';

    // Resolve digital seals: from snapshot if available, or preview if in design screen
    DigitalSealConfig? effectiveStamp;
    DigitalSealConfig? effectiveSignature;
    pw.MemoryImage? stampImage;
    pw.MemoryImage? signatureImage;

    DocumentSealSnapshot? snapshot = sealSnapshot;
    if (snapshot == null && doc.id != null && doc.id! > 0) {
      try {
        snapshot = await DatabaseHelper.instance.getDocumentSealSnapshot(
          doc.id!,
        );
      } catch (_) {}
    }

    if (FeatureGate.isAvailable(Feature.digitalSeals)) {
      if (snapshot != null) {
        effectiveStamp = snapshot.stamp;
        effectiveSignature = snapshot.signature;
      } else if (activeSealsPreview != null) {
        effectiveStamp = activeSealsPreview.$1;
        effectiveSignature = activeSealsPreview.$2;
      }
    }

    final businessId = business.id ?? 1;
    if (effectiveStamp != null &&
        effectiveStamp.isEnabled &&
        effectiveStamp.assetId != null) {
      try {
        final asset = await DatabaseHelper.instance.getDigitalAsset(
          effectiveStamp.assetId!,
          businessId: businessId,
        );
        if (asset != null) {
          final bytes = await DigitalSealStorageService.getAssetBytes(
            asset.filename,
          );
          if (bytes != null && bytes.isNotEmpty) {
            stampImage = pw.MemoryImage(bytes);
          }
        }
      } catch (_) {}
    }

    if (effectiveSignature != null &&
        effectiveSignature.isEnabled &&
        effectiveSignature.assetId != null) {
      try {
        final asset = await DatabaseHelper.instance.getDigitalAsset(
          effectiveSignature.assetId!,
          businessId: businessId,
        );
        if (asset != null) {
          final bytes = await DigitalSealStorageService.getAssetBytes(
            asset.filename,
          );
          if (bytes != null && bytes.isNotEmpty) {
            signatureImage = pw.MemoryImage(bytes);
          }
        }
      } catch (_) {}
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
        theme: theme,
        paymentMethodLabel: paymentMethodLabel,
        effectiveStamp: effectiveStamp,
        effectiveSignature: effectiveSignature,
        stampImage: stampImage,
        signatureImage: signatureImage,
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
      theme: theme,
      paymentMethodLabel: paymentMethodLabel,
      effectiveStamp: effectiveStamp,
      effectiveSignature: effectiveSignature,
      stampImage: stampImage,
      signatureImage: signatureImage,
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
    required PdfTheme theme,
    String paymentMethodLabel = '',
    DigitalSealConfig? effectiveStamp,
    DigitalSealConfig? effectiveSignature,
    pw.MemoryImage? stampImage,
    pw.MemoryImage? signatureImage,
  }) async {
    final pdf = pw.Document();
    final style = theme.style;
    final pageFormat = PrintSettings.pageFormatFor(paperSize);
    final margin = paperSize == PaperSize.a5 ? 16.0 : theme.margin;

    final isArabic = l10n.langCode == 'ar';
    final textDir = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final customTitle = business.invoiceTitle?.trim() ?? '';
    final documentTypeLabel = doc.type == 'invoice' && customTitle.isNotEmpty
        ? customTitle
        : _documentTypeLabel(doc.type, l10n);
    final currency = doc.currencyCode;
    final legalFooter = business.legalFooter?.trim() ?? '';
    final footerText = style.footerText.trim();
    final hasFooter =
        legalFooter.isNotEmpty ||
        footerText.isNotEmpty ||
        style.showPageNumbers;

    final availableWidth = pageFormat.width - (margin * 2);
    final availableHeight = pageFormat.height - (margin * 2);

    final pageTheme = pw.PageTheme(
      pageFormat: pageFormat,
      margin: pw.EdgeInsets.all(margin),
      theme: _pageTheme(regular, bold, rtl: isArabic),
      textDirection: textDir,
      buildForeground: (effectiveStamp != null || effectiveSignature != null)
          ? (context) => _buildSealsForeground(
              context: context,
              availableWidth: availableWidth,
              availableHeight: availableHeight,
              isArabic: isArabic,
              stamp: effectiveStamp,
              signature: effectiveSignature,
              stampImage: stampImage,
              signatureImage: signatureImage,
            )
          : null,
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => context.pageNumber == 1
            ? PdfHeaderBuilder.build(
                business: business,
                regular: regular,
                bold: bold,
                theme: theme,
                logoImage: logoImage,
                isArabic: isArabic,
                l10n: l10n,
              )
            : pw.SizedBox(),
        footer: hasFooter
            ? (context) => _buildFooter(
                context: context,
                theme: theme,
                regular: regular,
                textDir: textDir,
                legalFooter: legalFooter,
                footerText: footerText,
              )
            : null,
        build: (context) => [
          pw.SizedBox(height: 12),

          // Document title
          pw.Center(
            child: pw.Directionality(
              // A custom title may be Arabic inside an English document.
              textDirection: PdfTextUtils.hasArabic(documentTypeLabel)
                  ? pw.TextDirection.rtl
                  : textDir,
              child: pw.Text(
                documentTypeLabel,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: theme.fs(22),
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
            fontSize: theme.fs(12),
          ),
          _buildInfoRow(
            label: l10n.date,
            value: DateFormat('dd/MM/yyyy', 'en').format(doc.date),
            bold: bold,
            regular: regular,
            textColor: theme.textColor,
            isArabic: isArabic,
            fontSize: theme.fs(12),
            valueDirection: pw.TextDirection.ltr,
          ),
          if (doc.type == 'quotation' && doc.validUntil != null)
            _buildInfoRow(
              label: l10n.validUntil,
              value: DateFormat('dd/MM/yyyy', 'en').format(doc.validUntil!),
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
              fontSize: theme.fs(12),
              valueDirection: pw.TextDirection.ltr,
            ),
          if ((doc.type == 'payment_receipt' ||
                  doc.type == 'expense_voucher') &&
              doc.paymentMethod != null)
            _buildInfoRow(
              label: l10n.paymentMethod,
              value: paymentMethodLabel,
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
              fontSize: theme.fs(12),
            ),
          if (doc.type == 'payment_receipt' && relatedDocument != null)
            _buildInfoRow(
              label: l10n.relatedInvoice,
              value: relatedDocument.documentNumber,
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
              fontSize: theme.fs(12),
              valueDirection: pw.TextDirection.ltr,
            ),
          if (doc.type == 'invoice' &&
              relatedDocument != null &&
              relatedDocument.type == 'quotation')
            _buildInfoRow(
              label: l10n.sourceQuotation,
              value: relatedDocument.documentNumber,
              bold: bold,
              regular: regular,
              textColor: theme.textColor,
              isArabic: isArabic,
              fontSize: theme.fs(12),
              valueDirection: pw.TextDirection.ltr,
            ),
          pw.SizedBox(height: 12),

          // Customer
          if (style.showCustomer &&
              (contact != null || doc.recipientName != null))
            PdfCustomerBuilder.build(
              contact: contact,
              doc: doc,
              l10n: l10n,
              bold: bold,
              regular: regular,
              theme: theme,
              isArabic: isArabic,
            ),

          if (style.template != PdfTemplate.minimal)
            pw.Divider(color: theme.primaryColor, thickness: 1),
          pw.SizedBox(height: 12),

          // Items
          if (items.isNotEmpty) ...[
            PdfItemsTableBuilder.build(
              items: items,
              l10n: l10n,
              bold: bold,
              regular: regular,
              theme: theme,
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
            theme: theme,
            isArabic: isArabic,
          ),
          pw.SizedBox(height: 16),

          // Notes
          if (style.showNotes &&
              doc.notes != null &&
              doc.notes!.isNotEmpty) ...[
            pw.Directionality(
              textDirection: isArabic
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              child: pw.Text(
                '${l10n.notes}:',
                style: pw.TextStyle(font: bold, color: theme.primaryColor),
              ),
            ),
            pw.SizedBox(height: 4),
            PdfTextUtils.directionalText(
              doc.notes!,
              font: regular,
              fontSize: theme.fs(11),
              color: theme.textColor,
            ),
          ],

          if (style.showSignature || style.effectiveShowStampBox) ...[
            pw.SizedBox(height: 36),
            _buildSignatures(
              l10n: l10n,
              theme: theme,
              regular: regular,
              textDir: textDir,
              showSignatureLine: style.showSignature,
              showStampBox: style.effectiveShowStampBox,
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  /// Base text style for every document.
  ///
  /// Works around a `pdf` package bug: when it mirrors words on RTL lines it
  /// uses each word's ink width instead of its advance width, so letters
  /// whose tail extends past the glyph box (final/isolated ر، ا…) eat the
  /// gap to the next word ("متجرالنيل"). Wider spaces keep Arabic words
  /// visibly separated. LTR documents are unaffected and keep normal spacing.
  static pw.ThemeData _pageTheme(
    pw.Font regular,
    pw.Font bold, {
    required bool rtl,
  }) {
    final base = pw.ThemeData.withFont(base: regular, bold: bold);
    if (!rtl) return base;
    return base.copyWith(
      defaultTextStyle: base.defaultTextStyle.copyWith(
        wordSpacing: PdfTextUtils.rtlWordSpacing,
      ),
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required PdfTheme theme,
    required pw.Font regular,
    required pw.TextDirection textDir,
    required String legalFooter,
    required String footerText,
  }) {
    final style = pw.TextStyle(
      font: regular,
      fontSize: theme.fs(8.5),
      color: theme.mutedTextColor,
    );
    pw.Widget line(String text) => pw.Directionality(
      textDirection: text.isEmpty
          ? textDir
          : PdfTextUtils.detectDirection(text),
      child: pw.Text(text, style: style, textAlign: pw.TextAlign.center),
    );
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: theme.borderColor, width: 0.6),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (footerText.isNotEmpty) line(footerText),
          if (legalFooter.isNotEmpty) line(legalFooter),
          if (theme.style.showPageNumbers && context.pagesCount > 1)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: style,
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatures({
    required AppLocalizations l10n,
    required PdfTheme theme,
    required pw.Font regular,
    required pw.TextDirection textDir,
    bool showSignatureLine = true,
    bool showStampBox = true,
  }) {
    pw.Widget box(String label) => pw.Expanded(
      child: pw.Column(
        children: [
          pw.Container(
            height: 0.8,
            margin: const pw.EdgeInsets.symmetric(horizontal: 18),
            color: theme.textColor,
          ),
          pw.SizedBox(height: 4),
          pw.Directionality(
            textDirection: textDir,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: regular,
                fontSize: theme.fs(10),
                color: theme.mutedTextColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (showSignatureLine && showStampBox) {
      return pw.Row(children: [box(l10n.pdfSignature), box(l10n.pdfStamp)]);
    } else if (showSignatureLine) {
      return pw.Row(children: [box(l10n.pdfSignature), pw.Spacer()]);
    } else if (showStampBox) {
      return pw.Row(children: [pw.Spacer(), box(l10n.pdfStamp)]);
    }
    return pw.SizedBox();
  }

  static pw.Widget _buildInfoRow({
    required String label,
    required String value,
    required pw.Font bold,
    required pw.Font regular,
    required PdfColor textColor,
    required bool isArabic,
    required double fontSize,
    pw.TextDirection? valueDirection,
  }) {
    final labelDirection = isArabic
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
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
                fontSize: fontSize,
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
                  fontSize: fontSize,
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
      'invoice' => l10n.invoice,
      'purchase' => l10n.purchase,
      'quotation' => l10n.quotation,
      'payment_receipt' => l10n.paymentReceipt,
      'expense_voucher' => l10n.expenseVoucher,
      'custom' => l10n.customDocument,
      _ => l10n.documents,
    };
  }

  static pw.Widget _buildSealsForeground({
    required pw.Context context,
    required double availableWidth,
    required double availableHeight,
    required bool isArabic,
    DigitalSealConfig? stamp,
    DigitalSealConfig? signature,
    pw.MemoryImage? stampImage,
    pw.MemoryImage? signatureImage,
  }) {
    final widgets = <pw.Widget>[];

    bool shouldRenderOnPage(SealPageRule rule) => switch (rule) {
      SealPageRule.lastPage => context.pageNumber == context.pagesCount,
      SealPageRule.firstPage => context.pageNumber == 1,
      SealPageRule.allPages => true,
    };

    if (stamp != null &&
        stamp.isEnabled &&
        stampImage != null &&
        shouldRenderOnPage(stamp.pageRule)) {
      final box = SealGeometryEngine.resolve(
        config: stamp,
        containerWidth: availableWidth,
        containerHeight: availableHeight,
        isRtl: isArabic,
      );
      widgets.add(
        pw.PositionedDirectional(
          start: box.start,
          top: box.top,
          child: pw.SizedBox(
            width: box.width,
            height: box.height,
            child: pw.Opacity(
              opacity: stamp.opacity,
              child: pw.Image(stampImage, fit: pw.BoxFit.contain),
            ),
          ),
        ),
      );
    }

    if (signature != null &&
        signature.isEnabled &&
        signatureImage != null &&
        shouldRenderOnPage(signature.pageRule)) {
      final box = SealGeometryEngine.resolve(
        config: signature,
        containerWidth: availableWidth,
        containerHeight: availableHeight,
        isRtl: isArabic,
      );
      widgets.add(
        pw.PositionedDirectional(
          start: box.start,
          top: box.top,
          child: pw.SizedBox(
            width: box.width,
            height: box.height,
            child: pw.Opacity(
              opacity: signature.opacity,
              child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
            ),
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Stack(fit: pw.StackFit.expand, children: widgets);
  }

  // ==================== Thermal 80mm layout ====================

  @visibleForTesting
  static double lineTotalOf(DocumentItem item) => item.total;

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
    required PdfTheme theme,
    String paymentMethodLabel = '',
    DigitalSealConfig? effectiveStamp,
    DigitalSealConfig? effectiveSignature,
    pw.MemoryImage? stampImage,
    pw.MemoryImage? signatureImage,
  }) async {
    final pdf = pw.Document();
    final isArabic = l10n.langCode == 'ar';
    final textDir = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final numFmt = NumberFormat('#,##0.00', 'en');
    final currency = doc.currencyCode;
    const double fontSize = 10;
    const double smallSize = 9;

    pw.Widget txt(
      String s, {
      bool isBold = false,
      double size = fontSize,
      pw.TextAlign align = pw.TextAlign.start,
    }) {
      return pw.Directionality(
        textDirection: s.isEmpty ? textDir : PdfTextUtils.detectDirection(s),
        child: pw.Text(
          s,
          textAlign: align,
          style: pw.TextStyle(
            font: isBold ? bold : regular,
            fontSize: size,
            color: theme.textColor,
          ),
        ),
      );
    }

    // A drawn rule: Tajawal has no box-drawing glyphs (a run of '─' printed
    // as placeholder boxes).
    pw.Widget divider() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Container(height: 0.8, color: PdfColors.grey600),
    );

    final widgets = <pw.Widget>[];

    // Logo
    if (logoImage != null && theme.style.logoShape != PdfLogoShape.hidden) {
      widgets.add(
        pw.Center(
          child: pw.SizedBox(
            width: 48,
            height: 48,
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 4));
    }

    // Header
    widgets.add(
      pw.Center(
        child: txt(
          business.name,
          isBold: true,
          size: 13,
          align: pw.TextAlign.center,
        ),
      ),
    );
    if (business.phone.isNotEmpty) {
      widgets.add(
        pw.Center(
          child: txt(
            business.phone,
            size: smallSize,
            align: pw.TextAlign.center,
          ),
        ),
      );
    }
    if (business.address.isNotEmpty) {
      widgets.add(
        pw.Center(
          child: pw.Directionality(
            textDirection: textDir,
            child: pw.Text(
              business.address,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: regular,
                fontSize: smallSize,
                color: theme.textColor,
              ),
            ),
          ),
        ),
      );
    }
    if (theme.style.showTaxId && business.taxId?.trim().isNotEmpty == true) {
      widgets.add(
        pw.Center(
          child: txt(
            '${l10n.pdfTaxIdLabel} ${business.taxId!}',
            size: smallSize,
            align: pw.TextAlign.center,
          ),
        ),
      );
    }
    widgets.add(divider());

    // Doc info
    widgets.add(
      pw.Center(
        child: txt(
          _documentTypeLabel(doc.type, l10n),
          isBold: true,
          size: 12,
          align: pw.TextAlign.center,
        ),
      ),
    );
    widgets.add(
      txt('${l10n.documentNumber}: ${doc.documentNumber}', size: smallSize),
    );
    widgets.add(
      txt(
        '${l10n.date}: ${DateFormat('dd/MM/yyyy', 'en').format(doc.date)}',
        size: smallSize,
      ),
    );
    if (doc.type == 'quotation' && doc.validUntil != null) {
      widgets.add(
        txt(
          '${l10n.validUntil}: ${DateFormat('dd/MM/yyyy', 'en').format(doc.validUntil!)}',
          size: smallSize,
        ),
      );
    }
    if ((doc.type == 'payment_receipt' || doc.type == 'expense_voucher') &&
        paymentMethodLabel.isNotEmpty) {
      widgets.add(
        txt('${l10n.paymentMethod}: $paymentMethodLabel', size: smallSize),
      );
    }
    if (doc.type == 'payment_receipt' && relatedDocument != null) {
      widgets.add(
        txt(
          '${l10n.relatedInvoice}: ${relatedDocument.documentNumber}',
          size: smallSize,
        ),
      );
    }

    // Contact
    if (theme.style.showCustomer) {
      final contactName = contact?.name ?? doc.recipientName;
      if (contactName != null && contactName.isNotEmpty) {
        widgets.add(
          pw.Directionality(
            textDirection: textDir,
            child: pw.Text(
              '${l10n.customerOrParty}: $contactName',
              style: pw.TextStyle(
                font: regular,
                fontSize: smallSize,
                color: theme.textColor,
              ),
            ),
          ),
        );
      }
      final phone = (contact?.phone ?? doc.recipientPhone)?.trim();
      if (phone != null && phone.isNotEmpty) {
        widgets.add(txt('${l10n.phone}: $phone', size: smallSize));
      }
    }
    widgets.add(divider());

    // Items
    for (final item in items) {
      widgets.add(
        pw.Directionality(
          textDirection: textDir,
          child: pw.Text(
            item.description,
            style: pw.TextStyle(
              font: bold,
              fontSize: fontSize,
              color: theme.textColor,
            ),
          ),
        ),
      );
      final lineTotal = item.total;
      final unitSuffix = item.saleUnit != null && item.saleUnit!.isNotEmpty
          ? ' ${item.saleUnit}'
          : '';
      widgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            txt(
              '${FormatUtils.formatQuantity(item.quantity)}$unitSuffix × ${numFmt.format(item.price)}',
              size: smallSize,
            ),
            txt('${numFmt.format(lineTotal)} $currency', size: smallSize),
          ],
        ),
      );
      widgets.add(pw.SizedBox(height: 2));
    }
    widgets.add(divider());

    // Totals
    void totRow(String label, double value, {bool emph = false}) {
      widgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Directionality(
              textDirection: textDir,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: emph ? bold : regular,
                  fontSize: fontSize,
                ),
              ),
            ),
            pw.Text(
              '${numFmt.format(value)} $currency',
              style: pw.TextStyle(
                font: emph ? bold : regular,
                fontSize: fontSize,
                color: emph ? theme.primaryColor : theme.textColor,
              ),
            ),
          ],
        ),
      );
    }

    if (doc.discount > 0) totRow(l10n.discount, doc.discount);
    if (doc.taxAmount > 0) {
      totRow(
        doc.taxRate > 0
            ? '${l10n.tax} ${FormatUtils.formatTaxRate(doc.taxRate)}'
            : l10n.tax,
        doc.taxAmount,
      );
    }
    totRow(l10n.grandTotal, doc.total, emph: true);
    if ((doc.type == 'invoice' || doc.type == 'purchase') &&
        theme.style.showPaymentSummary) {
      if (doc.paid > 0) totRow(l10n.paid, doc.paid);
      if (doc.remaining > 0) totRow(l10n.remaining, doc.remaining);
    }

    // Notes
    if (theme.style.showNotes && doc.notes != null && doc.notes!.isNotEmpty) {
      widgets.add(divider());
      widgets.add(
        pw.Directionality(
          textDirection: textDir,
          child: pw.Text(
            '${l10n.notes}: ${doc.notes!}',
            style: pw.TextStyle(
              font: regular,
              fontSize: smallSize,
              color: theme.textColor,
            ),
          ),
        ),
      );
    }

    // Digital seals on thermal receipts (sequential footer elements)
    if (effectiveStamp != null &&
        effectiveStamp.isEnabled &&
        stampImage != null) {
      widgets.add(divider());
      const maxThermalWidth = 140.0;
      final thermalWidth = (80 * PdfPageFormat.mm * effectiveStamp.widthRatio)
          .clamp(40.0, maxThermalWidth);
      final aspect = effectiveStamp.aspectRatio > 0
          ? effectiveStamp.aspectRatio
          : 1.0;
      widgets.add(
        pw.Center(
          child: pw.Container(
            width: thermalWidth,
            height: thermalWidth / aspect,
            child: pw.Image(stampImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 4));
    }

    if (effectiveSignature != null &&
        effectiveSignature.isEnabled &&
        signatureImage != null) {
      widgets.add(divider());
      const maxThermalWidth = 150.0;
      final thermalWidth =
          (80 * PdfPageFormat.mm * effectiveSignature.widthRatio).clamp(
            40.0,
            maxThermalWidth,
          );
      final aspect = effectiveSignature.aspectRatio > 0
          ? effectiveSignature.aspectRatio
          : 1.0;
      widgets.add(
        pw.Center(
          child: pw.Container(
            width: thermalWidth,
            height: thermalWidth / aspect,
            child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 4));
    }

    final thermalFooter = [
      theme.style.footerText.trim(),
      business.legalFooter?.trim() ?? '',
    ].where((t) => t.isNotEmpty);
    if (thermalFooter.isNotEmpty) {
      widgets.add(divider());
      for (final t in thermalFooter) {
        widgets.add(
          pw.Center(
            child: txt(t, size: smallSize, align: pw.TextAlign.center),
          ),
        );
      }
    }
    widgets.add(pw.SizedBox(height: 8));

    pdf.addPage(
      pw.Page(
        pageFormat: PrintSettings.pageFormatFor(PaperSize.thermal80mm),
        // RTL so label/amount rows read right-to-left on Arabic receipts.
        textDirection: textDir,
        theme: _pageTheme(regular, bold, rtl: isArabic),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: widgets,
        ),
      ),
    );

    return pdf.save();
  }
}
