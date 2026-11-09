import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';

void main() {
  group('AppLocalizations Plurals & Bidi', () {
    final l10nAr = AppLocalizations('ar');
    final l10nEn = AppLocalizations('en');

    test('posItemsCount Arabic plurals', () {
      expect(l10nAr.posItemsCount('0'), equals('لا توجد بنود'));
      expect(l10nAr.posItemsCount('1'), equals('بند واحد'));
      expect(l10nAr.posItemsCount('2'), equals('بندان'));
      expect(l10nAr.posItemsCount('3'), equals('3 بنود'));
      expect(l10nAr.posItemsCount('10'), equals('10 بنود'));
      expect(l10nAr.posItemsCount('11'), equals('11 بنداً'));
      expect(l10nAr.posItemsCount('25'), equals('25 بنداً'));
      expect(l10nAr.posItemsCount('99'), equals('99 بنداً'));
      expect(l10nAr.posItemsCount('100'), equals('100 بند'));
      expect(l10nAr.posItemsCount('102'), equals('102 بند'));
    });

    test('posItemsCount English plurals', () {
      expect(l10nEn.posItemsCount('0'), equals('0 items'));
      expect(l10nEn.posItemsCount('1'), equals('1 item'));
      expect(l10nEn.posItemsCount('2'), equals('2 items'));
      expect(l10nEn.posItemsCount('5'), equals('5 items'));
    });

    test('daysRemainingCount Arabic & English', () {
      expect(l10nAr.daysRemainingCount(0), equals('أقل من يوم'));
      expect(l10nAr.daysRemainingCount(1), equals('~يوم واحد'));
      expect(l10nAr.daysRemainingCount(2), equals('~يومان'));
      expect(l10nAr.daysRemainingCount(5), equals('~5 أيام'));
      expect(l10nAr.daysRemainingCount(15), equals('~15 يوماً'));
      expect(l10nAr.daysRemainingCount(100), equals('~100 يوم'));

      expect(l10nEn.daysRemainingCount(1), equals('~1 day'));
      expect(l10nEn.daysRemainingCount(5), equals('~5 days'));
    });

    test('unvaluedSalesNotice Arabic & English', () {
      expect(l10nAr.unvaluedSalesNotice(0), equals('(لا توجد مبيعات)'));
      expect(l10nAr.unvaluedSalesNotice(1), equals('(عملية بيع واحدة)'));
      expect(l10nAr.unvaluedSalesNotice(2), equals('(عمليتا بيع)'));
      expect(l10nAr.unvaluedSalesNotice(4), equals('(4 عمليات بيع)'));
      expect(l10nAr.unvaluedSalesNotice(12), equals('(12 عملية بيع)'));

      expect(l10nEn.unvaluedSalesNotice(1), equals('(1 sale)'));
      expect(l10nEn.unvaluedSalesNotice(3), equals('(3 sales)'));
    });

    test('Bidi isolates in Arabic strings protect Latin tokens', () {
      const fsi = '\u2068';
      const pdi = '\u2069';

      final msg = l10nAr.currencyConfirmMessage('USD');
      expect(msg, contains('$fsi' 'USD' '$pdi'));

      final stockMsg = l10nAr.insufficientStock('MacBook Pro', 2.0, 5.0);
      expect(stockMsg, contains('$fsi' 'MacBook Pro' '$pdi'));
      expect(stockMsg, startsWith('مخزون غير كافٍ'));

      final dateMsg = l10nAr.asOfDate('2026-10-31');
      expect(dateMsg, equals('كما في $fsi' '2026-10-31' '$pdi'));

      final stmtMsg = l10nAr.statementWarningDetail('INV-001', '150.00', 'SAR');
      expect(stmtMsg, contains('#$fsi' 'INV-001' '$pdi'));
      expect(stmtMsg, contains('$fsi' '150.00 SAR' '$pdi'));
    });

    test('English strings do not contain Bidi isolates', () {
      const fsi = '\u2068';
      const pdi = '\u2069';

      final msg = l10nEn.currencyConfirmMessage('USD');
      expect(msg.contains(fsi), isFalse);
      expect(msg.contains(pdi), isFalse);

      final stockMsg = l10nEn.insufficientStock('MacBook Pro', 2.0, 5.0);
      expect(stockMsg.contains(fsi), isFalse);
      expect(stockMsg.contains(pdi), isFalse);
    });
  });
}
