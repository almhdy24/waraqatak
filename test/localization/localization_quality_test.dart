import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';

void main() {
  group('Batch L8: Comprehensive Localization Quality Tests', () {
    late AppLocalizations l10nAr;
    late AppLocalizations l10nEn;

    setUp(() {
      l10nAr = AppLocalizations('ar');
      l10nEn = AppLocalizations('en');
    });

    test('Locale identification is accurate', () {
      expect(l10nAr.isArabic, isTrue);
      expect(l10nAr.langCode, equals('ar'));

      expect(l10nEn.isArabic, isFalse);
      expect(l10nEn.langCode, equals('en'));
    });

    test('App name and brand identity is consistent', () {
      expect(l10nAr.appName, equals('ورقتك'));
      expect(l10nAr.appTitle, equals('ورقتك'));

      expect(l10nEn.appName, equals('Waraqatak'));
      expect(l10nEn.appTitle, equals('Waraqatak'));
    });

    test('Zero empty string values in core getters', () {
      final gettersToAudit = [
        () => (l10nAr.appName, l10nEn.appName),
        () => (l10nAr.home, l10nEn.home),
        () => (l10nAr.invoice, l10nEn.invoice),
        () => (l10nAr.quotation, l10nEn.quotation),
        () => (l10nAr.purchases, l10nEn.purchases),
        () => (l10nAr.inventory, l10nEn.inventory),
        () => (l10nAr.products, l10nEn.products),
        () => (l10nAr.customers, l10nEn.customers),
        () => (l10nAr.suppliers, l10nEn.suppliers),
        () => (l10nAr.reports, l10nEn.reports),
        () => (l10nAr.settings, l10nEn.settings),
        () => (l10nAr.backupRestore, l10nEn.backupRestore),
        () => (l10nAr.financialSettings, l10nEn.financialSettings),
        () => (l10nAr.auditLog, l10nEn.auditLog),
        () => (l10nAr.stocktakeTitle, l10nEn.stocktakeTitle),
        () => (l10nAr.accounting, l10nEn.accounting),
        () => (l10nAr.posQuickSale, l10nEn.posQuickSale),
        () => (l10nAr.pdfTaxIdLabel, l10nEn.pdfTaxIdLabel),
        () => (l10nAr.pdfCommercialRegLabel, l10nEn.pdfCommercialRegLabel),
        () => (l10nAr.pdfBranchLabel, l10nEn.pdfBranchLabel),
        () => (l10nAr.financialSummaryCardTitle, l10nEn.financialSummaryCardTitle),
      ];

      for (final getter in gettersToAudit) {
        final (ar, en) = getter();
        expect(ar.trim().isNotEmpty, isTrue, reason: 'Arabic getter must not be empty');
        expect(en.trim().isNotEmpty, isTrue, reason: 'English getter must not be empty');
        expect(ar, isNot(equals(en)), reason: 'Arabic and English should differ for $ar');
      }
    });

    test('Arabic status labels adhere to masculine gender-neutral agreement', () {
      expect(l10nAr.statusIssued, equals('صادر'));
      expect(l10nAr.statusPaid, equals('مدفوع'));
      expect(l10nAr.statusPartiallyPaid, equals('مدفوع جزئياً'));
      expect(l10nAr.statusCancelled, equals('ملغي'));
      expect(l10nAr.statusDraft, equals('مسودة'));

      expect(l10nEn.statusIssued, equals('Issued'));
      expect(l10nEn.statusPaid, equals('Paid'));
      expect(l10nEn.statusPartiallyPaid, equals('Partially Paid'));
      expect(l10nEn.statusCancelled, equals('Cancelled'));
      expect(l10nEn.statusDraft, equals('Draft'));
    });

    test('Plural rules coverage: Arabic 6 forms and English 2 forms', () {
      // 0 items
      expect(l10nAr.posItemsCount('0'), equals('لا توجد بنود'));
      expect(l10nEn.posItemsCount('0'), equals('0 items'));

      // 1 item
      expect(l10nAr.posItemsCount('1'), equals('بند واحد'));
      expect(l10nEn.posItemsCount('1'), equals('1 item'));

      // 2 items (dual)
      expect(l10nAr.posItemsCount('2'), equals('بندان'));
      expect(l10nEn.posItemsCount('2'), equals('2 items'));

      // 3-10 items (few)
      expect(l10nAr.posItemsCount('3'), equals('3 بنود'));
      expect(l10nAr.posItemsCount('7'), equals('7 بنود'));
      expect(l10nAr.posItemsCount('10'), equals('10 بنود'));
      expect(l10nEn.posItemsCount('3'), equals('3 items'));

      // 11-99 items (many)
      expect(l10nAr.posItemsCount('11'), equals('11 بنداً'));
      expect(l10nAr.posItemsCount('45'), equals('45 بنداً'));
      expect(l10nAr.posItemsCount('99'), equals('99 بنداً'));
      expect(l10nEn.posItemsCount('15'), equals('15 items'));

      // 100+ items (other: exact hundreds / thousands)
      expect(l10nAr.posItemsCount('100'), equals('100 بند'));
      expect(l10nAr.posItemsCount('200'), equals('200 بند'));
      expect(l10nAr.posItemsCount('250'), equals('250 بنداً'));
      expect(l10nEn.posItemsCount('100'), equals('100 items'));
    });

    test('Days remaining plural coverage', () {
      expect(l10nAr.daysRemainingCount(0), equals('أقل من يوم'));
      expect(l10nAr.daysRemainingCount(1), equals('~يوم واحد'));
      expect(l10nAr.daysRemainingCount(2), equals('~يومان'));
      expect(l10nAr.daysRemainingCount(4), equals('~4 أيام'));
      expect(l10nAr.daysRemainingCount(20), equals('~20 يوماً'));
      expect(l10nAr.daysRemainingCount(100), equals('~100 يوم'));

      expect(l10nEn.daysRemainingCount(1), equals('~1 day'));
      expect(l10nEn.daysRemainingCount(10), equals('~10 days'));
    });

    test('Bidi isolate encapsulation in UI strings and WhatsApp messages', () {
      const fsi = '\u2068';
      const pdi = '\u2069';

      // Currency confirm message
      final currAr = l10nAr.currencyConfirmMessage('USD');
      expect(currAr, contains('$fsi' 'USD' '$pdi'));
      final currEn = l10nEn.currencyConfirmMessage('USD');
      expect(currEn, isNot(contains(fsi)));

      // Insufficient stock message
      final stockAr = l10nAr.insufficientStock('iPhone 15 Pro', 1.0, 3.0);
      expect(stockAr, contains('$fsi' 'iPhone 15 Pro' '$pdi'));
      expect(stockAr, contains('مخزون غير كافٍ'));

      // Statement warning detail
      final stmtAr = l10nAr.statementWarningDetail('INV-2026-001', '500', 'SAR');
      expect(stmtAr, contains('#$fsi' 'INV-2026-001' '$pdi'));
      expect(stmtAr, contains('$fsi' '500' '$pdi'));
      expect(stmtAr, contains('$fsi' 'SAR' '$pdi'));

      // WhatsApp statement caption
      final waAr = l10nAr.whatsAppStatementCaption('أحمد', 'مؤسسة النيل', '01/01/2026', '31/01/2026', '1250', 'SDG');
      expect(waAr, contains('$fsi' 'أحمد' '$pdi'));
      expect(waAr, contains('$fsi' 'مؤسسة النيل' '$pdi'));
      expect(waAr, contains('$fsi' '1250' '$pdi'));
      expect(waAr, contains('$fsi' 'SDG' '$pdi'));
    });

    test('PDF labels MUST NOT contain Unicode Bidi isolates', () {
      const fsi = '\u2068';
      const pdi = '\u2069';

      final pdfLabels = [
        l10nAr.pdfTaxIdLabel,
        l10nAr.pdfTaxRegLabel,
        l10nAr.pdfCommercialRegLabel,
        l10nAr.pdfBranchLabel,
        l10nAr.pdfSignature,
        l10nAr.pdfStamp,
        l10nAr.pdfPreview,
        l10nAr.pdfOptions,
      ];

      for (final label in pdfLabels) {
        expect(label.contains(fsi), isFalse, reason: 'PDF label "$label" must not contain FSI');
        expect(label.contains(pdi), isFalse, reason: 'PDF label "$label" must not contain PDI');
      }
    });

    test('Source file audit: No deprecated terminology in AppLocalizations', () {
      final file = File('lib/localization/app_localizations.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();

      // Check deprecated standalone term 'صنف'
      final legacySinfMatches = RegExp(r"['\x22][^'\x22]*?\bصنف\b[^'\x22]*?['\x22]").allMatches(content);
      expect(legacySinfMatches.isEmpty, isTrue,
          reason: 'Found deprecated term "صنف" in user-facing string literals');

      // Check grammatical declension "جاري" when used as adjective/state
      final gariMatches = RegExp(r"['\x22][^'\x22]*?\bجاري\b[^'\x22]*?['\x22]").allMatches(content);
      expect(gariMatches.isEmpty, isTrue,
          reason: 'Found un-declined "جاري" instead of "جارٍ" in string literals');

      // Check legacy three dots
      final threeDotsMatches = RegExp(r"['\x22][^'\x22]*?\.\.\.[^'\x22]*?['\x22]").allMatches(content);
      expect(threeDotsMatches.isEmpty, isTrue,
          reason: 'Found ASCII "..." instead of Unicode ellipsis "…" in string literals');
    });

    test('Source file audit: Zero legacy phase banner comments remain', () {
      final file = File('lib/localization/app_localizations.dart');
      final content = file.readAsStringSync();

      final legacyPhaseMatches = RegExp(r"//\s*=*\s*(PHASE|Milestone|NEW PROMPT|ROUND|STEP)\b", caseSensitive: false)
          .allMatches(content);
      expect(legacyPhaseMatches.isEmpty, isTrue,
          reason: 'Found legacy phase comments in AppLocalizations');
    });
  });
}
