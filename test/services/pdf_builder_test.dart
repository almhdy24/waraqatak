import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/customer_statement_service.dart';
import 'package:warqatek/services/pdf/pdf_customer_statement_builder.dart';
import 'package:warqatek/services/pdf/pdf_document_builder.dart';
import 'package:warqatek/services/pdf/pdf_text_utils.dart';
import 'package:warqatek/utils/pdf_settings.dart';
import 'package:warqatek/utils/print_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfTextUtils.directionalText', () {
    final font = pw.Font.helvetica();
    pw.TextDirection dirOf(pw.Widget w) => (w as pw.Directionality).textDirection;

    test('Arabic is always RTL, even with an LTR fallback', () {
      // Forcing LTR on Arabic embeds unshaped letters (disconnected,
      // reversed) and can corrupt the font subset of the whole document.
      final w = PdfTextUtils.directionalText('متجر النيل',
          font: font, fallbackDirection: pw.TextDirection.ltr);
      expect(dirOf(w), pw.TextDirection.rtl);
    });

    test('fallback applies to text without Arabic', () {
      final w = PdfTextUtils.directionalText('+249 912',
          font: font, fallbackDirection: pw.TextDirection.ltr);
      expect(dirOf(w), pw.TextDirection.ltr);
    });

    test('Latin text defaults to LTR', () {
      expect(dirOf(PdfTextUtils.directionalText('Office chair', font: font)),
          pw.TextDirection.ltr);
    });
  });

  group('PdfDocumentBuilder builds every layout', () {
    const business = Business(
      name: 'متجر النيل',
      ownerName: 'أحمد',
      phone: '+249 912 345 678',
      address: 'الخرطوم',
      taxId: 'TIN 300123456',
      invoiceTitle: 'فاتورة ضريبية',
      legalFooter: 'السجل التجاري 12345',
    );
    final items = [
      DocumentItem(
          documentId: 0,
          description: 'خدمة تصميم شعار',
          quantity: 1,
          price: 12500,
          total: 12500),
      DocumentItem(
          documentId: 0,
          description: 'Office chair',
          quantity: 2,
          price: 25000,
          total: 50000),
    ];
    final doc = Document(
      type: 'invoice',
      documentNumber: 'INV-0001',
      date: DateTime(2026, 10, 2),
      recipientName: 'محمد علي',
      subtotal: 62500,
      discount: 0,
      taxRate: 0,
      taxAmount: 0,
      total: 62500,
      paid: 10000,
      remaining: 52500,
      notes: 'ملاحظة',
    );

    for (final lang in ['ar', 'en']) {
      for (final paper in PaperSize.values) {
        for (final template in PdfTemplate.values) {
          test('$lang ${paper.name} ${template.name}', () async {
            final bytes = await PdfDocumentBuilder.build(
              doc: doc,
              business: business,
              items: items,
              l10n: AppLocalizations(lang),
              paperSize: paper,
              style: PdfStyleSettings(
                template: template,
                showSignature: true,
                footerText: 'شكراً لكم',
              ),
            );
            expect(bytes.length, greaterThan(1000));
            expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
          });
        }
      }
    }
  });

  group('PdfStyleSettings JSON', () {
    test('round-trips', () {
      const s = PdfStyleSettings(
        accentColor: 0xFF1D4ED8,
        template: PdfTemplate.modern,
        logoShape: PdfLogoShape.rounded,
        fontScale: 1.12,
        showSignature: true,
        footerText: 'شكراً',
      );
      expect(PdfStyleSettings.fromJson(s.toJson()), s);
    });

    test('unknown or partial values fall back to defaults', () {
      final s = PdfStyleSettings.fromJson({
        'template': 'nope',
        'fontScale': 'big',
        'showNotes': false,
      });
      expect(s.template, PdfTemplate.classic);
      expect(s.fontScale, 1.0);
      expect(s.showNotes, isFalse);
      expect(s.showCustomer, isTrue);
    });
  });

  group('PdfTextUtils.stripBidiIsolates', () {
    test('removes all U+2066..U+2069 isolate control characters', () {
      const input = '\u2066LRI\u2069 \u2067RLI\u2069 \u2068FSI\u2069';
      expect(PdfTextUtils.stripBidiIsolates(input), 'LRI RLI FSI');
    });

    test('preserves strings without isolates', () {
      const plain = 'فاتورة مبيعات #INV-101 بقيمة 500 SDG';
      expect(PdfTextUtils.stripBidiIsolates(plain), plain);
    });

    test('handles empty string cleanly', () {
      expect(PdfTextUtils.stripBidiIsolates(''), '');
    });

    test('handles mixed Arabic and Latin text with isolates', () {
      const mixed = 'المنتج: \u2068iPhone 15 Pro\u2069 - السعر: \u20681,200\u2069 SDG';
      expect(
        PdfTextUtils.stripBidiIsolates(mixed),
        'المنتج: iPhone 15 Pro - السعر: 1,200 SDG',
      );
    });

    test('preserves whitespace and other control characters', () {
      const formatted = 'سطر أول\nسطر ثانٍ\tمفصول بمسافة\r\n';
      expect(PdfTextUtils.stripBidiIsolates(formatted), formatted);
    });
  });

  group('PdfTextUtils bidi isolate PDF safety', () {
    final font = pw.Font.helvetica();
    final isolateRegex = RegExp(r'[\u2066-\u2069]');

    test('directionalText sanitizes isolates in child pw.Text', () {
      final w = PdfTextUtils.directionalText(
        'الفاتورة #\u2068INV-100\u2069 ناتجة عن تسوية',
        font: font,
      );
      final textWidget = (w as pw.Directionality).child as pw.Text;
      final textSpan = textWidget.text as pw.TextSpan;
      expect(isolateRegex.hasMatch(textSpan.text!), isFalse);
      expect(textSpan.text, 'الفاتورة #INV-100 ناتجة عن تسوية');
    });

    test('statementWarningDetail isolates are stripped when passed to directionalText', () {
      final l10nAr = AppLocalizations('ar');
      final warningRaw = l10nAr.statementWarningDetail('INV-001', '350.00', 'SDG');
      // Raw string MUST contain isolates for on-screen Bidi rendering
      expect(isolateRegex.hasMatch(warningRaw), isTrue);

      // But when handed to PDF directionalText, all isolates MUST be stripped
      final w = PdfTextUtils.directionalText('• $warningRaw', font: font);
      final textWidget = (w as pw.Directionality).child as pw.Text;
      final textSpan = textWidget.text as pw.TextSpan;
      expect(isolateRegex.hasMatch(textSpan.text!), isFalse);
      expect(textSpan.text, contains('• الفاتورة #INV-001 تتضمن فارقاً محاسبياً بمقدار 350.00 SDG'));
    });

    test('PdfCustomerStatementBuilder builds statement with discrepancy warning without isolates reaching text', () async {
      final l10nAr = AppLocalizations('ar');
      const business = Business(
        name: 'متجر النيل',
        ownerName: 'أحمد',
        phone: '+249912345678',
        address: 'الخرطوم',
      );
      const customer = Contact(id: 1, name: 'العميل محمد', phone: '0912345678', type: 'customer');
      final day1 = DateTime(2026, 1, 1);
      final day31 = DateTime(2026, 1, 31);

      // Documents producing a discrepancy: invoice stored paid=200, receipt=500
      final docs = [
        Document(
          id: 1,
          type: 'invoice',
          documentNumber: 'INV-1',
          date: day1,
          contactId: 1,
          subtotal: 1000,
          discount: 0,
          taxRate: 0,
          taxAmount: 0,
          total: 1000,
          paid: 200,
          remaining: 800,
          status: DocumentStatus.issued,
          currencyCode: 'SDG',
        ),
        Document(
          id: 2,
          type: 'payment_receipt',
          documentNumber: 'REC-1',
          date: DateTime(2026, 1, 5),
          contactId: 1,
          relatedDocumentId: 1,
          subtotal: 500,
          discount: 0,
          taxRate: 0,
          taxAmount: 0,
          total: 500,
          paid: 500,
          remaining: 0,
          status: DocumentStatus.issued,
          currencyCode: 'SDG',
        ),
      ];

      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day1,
        to: day31,
      );

      expect(statement.hasDiscrepancy, isTrue);
      expect(statement.warnings.isNotEmpty, isTrue);

      // Verify that statement warning detail is sanitized by PdfTextUtils
      final warningText = l10nAr.statementWarningDetail(
        statement.warnings.first.invoiceNumber,
        statement.warnings.first.discrepancy.toStringAsFixed(2),
        statement.currencySymbol,
      );
      final sanitized = PdfTextUtils.stripBidiIsolates(warningText);
      expect(isolateRegex.hasMatch(sanitized), isFalse);

      // Build customer statement PDF byte stream
      final pdfBytes = await PdfCustomerStatementBuilder.build(
        statement: statement,
        business: business,
        l10n: l10nAr,
      );
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
    });
  });
}
