import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
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
}
