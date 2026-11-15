import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/services/pdf/pdf_customer_statement_builder.dart';
import 'package:warqatek/services/pdf/pdf_document_builder.dart';
import 'package:warqatek/services/pdf/pdf_report_builder.dart';
import 'package:warqatek/services/pdf/pdf_text_utils.dart';
import 'package:warqatek/utils/format_utils.dart';
import 'package:warqatek/utils/print_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  group('Phase 1 - PDF Text Utils & Bidi', () {
    test('stripBidiIsolates removes LRM and other bidi controls', () {
      expect(PdfTextUtils.stripBidiIsolates('abc\u200Ex'), 'abcx');
    });

    test('hasArabic detects Arabic presentation forms such as Lam-Alef', () {
      expect(PdfTextUtils.hasArabic('ﻻ'), isTrue);
    });
  });

  group('Phase 1 - Safe File Name', () {
    test(
      'safeFileName sanitizes forbidden characters and collapses underscores',
      () {
        expect(safeFileName('INV/2026:001 "x"'), 'INV_2026_001_x');
      },
    );

    test('safeFileName returns document when sanitized result is empty', () {
      expect(safeFileName(''), 'document');
      expect(safeFileName(':::***'), 'document');
    });

    test('safeFileName preserves Arabic characters', () {
      expect(safeFileName('فاتورة_المبيعات_001'), 'فاتورة_المبيعات_001');
    });
  });

  group('Phase 1 - RTL Table Column Ordering', () {
    test('orderedColumnIndexes reverses for RTL / Arabic', () {
      expect(PdfReportBuilder.orderedColumnIndexes(3, false), [0, 1, 2]);
      expect(PdfReportBuilder.orderedColumnIndexes(3, true), [2, 1, 0]);
    });
  });

  group('Phase 1 - Thermal & Totals', () {
    test(
      'Thermal build smoke test: item total is used and builder succeeds',
      () async {
        const business = Business(
          name: 'متجر الاختبار',
          ownerName: 'أحمد',
          phone: '123456789',
          address: 'الرياض',
          taxId: '3000000000',
        );
        final item = DocumentItem(
          documentId: 1,
          description: 'منتج مخصص',
          quantity: 2,
          price: 10,
          total: 15, // item.total != quantity * price
        );
        expect(PdfDocumentBuilder.lineTotalOf(item), 15.0);

        final doc = Document(
          id: 1,
          type: 'invoice',
          documentNumber: 'INV-1001',
          date: DateTime(2026, 11, 15),
          recipientName: 'عميل تجريبي',
          recipientPhone: '0500000000',
          subtotal: 15,
          discount: 0,
          taxRate: 0,
          taxAmount: 0,
          total: 15,
          paid: 15,
          remaining: 0,
        );

        final bytes = await PdfDocumentBuilder.build(
          doc: doc,
          business: business,
          contact: const Contact(
            id: 1,
            name: 'عميل تجريبي',
            phone: '0500000000',
          ),
          items: [item],
          l10n: AppLocalizations('ar'),
          paperSize: PaperSize.thermal80mm,
        );

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      },
    );
  });

  group('Phase 1 - Customer Statement Warnings', () {
    test(
      'Internal warnings are hidden by default even if hasDiscrepancy is true',
      () {
        expect(
          PdfCustomerStatementBuilder.shouldShowWarnings(
            showInternalWarnings: false,
            hasDiscrepancy: true,
          ),
          isFalse,
        );

        expect(
          PdfCustomerStatementBuilder.shouldShowWarnings(
            showInternalWarnings: true,
            hasDiscrepancy: true,
          ),
          isTrue,
        );

        expect(
          PdfCustomerStatementBuilder.shouldShowWarnings(
            showInternalWarnings: true,
            hasDiscrepancy: false,
          ),
          isFalse,
        );
      },
    );
  });
}
