import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/screens/quick_sale_screen.dart';

void main() {
  group('Smart Cash Suggestions Redesign', () {
    test('Exact amount is always index 0 and non-empty for positive total', () {
      final s1 = QuickSaleScreen.computeCashSuggestions(total: 42.50, decimalDigits: 2);
      expect(s1.first, 42.50);

      final s2 = QuickSaleScreen.computeCashSuggestions(total: 100, decimalDigits: 0);
      expect(s2.first, 100.0);
    });

    test('All suggestions are strictly ascending and deduplicated', () {
      final totals = [0.45, 1.20, 7.35, 14.25, 48.0, 105.0, 125.0, 340.0, 1250.0, 23250.0, 125000.0];
      for (final t in totals) {
        final suggestions = QuickSaleScreen.computeCashSuggestions(
          total: t,
          decimalDigits: t < 1000 ? 2 : 0,
        );
        expect(suggestions.isNotEmpty, isTrue, reason: 'Total $t should produce suggestions');
        expect(suggestions.length, lessThanOrEqualTo(4));
        for (var i = 0; i < suggestions.length - 1; i++) {
          expect(
            suggestions[i] < suggestions[i + 1],
            isTrue,
            reason: 'For total $t: ${suggestions[i]} should be strictly less than ${suggestions[i + 1]}',
          );
        }
      }
    });

    test('Decimal currency: does NOT jump to 500/1000 for realistic retail amounts (e.g. 105, 125)', () {
      final s125 = QuickSaleScreen.computeCashSuggestions(total: 125.0, decimalDigits: 2);
      expect(s125.first, 125.0);
      // For $125, suggestions should be practical rounded cash (e.g. 130, 140, 150), NOT 500, 1000, 5000
      expect(s125.last, lessThanOrEqualTo(200.0));
      expect(s125, equals([125.0, 130.0, 140.0, 150.0]));

      final s105 = QuickSaleScreen.computeCashSuggestions(total: 105.0, decimalDigits: 2);
      expect(s105.first, 105.0);
      expect(s105.last, lessThanOrEqualTo(200.0));
      expect(s105, equals([105.0, 110.0, 120.0, 150.0]));
    });

    test('Decimal currency: small and sub-unit amounts produce practical cash coins/bills', () {
      final s075 = QuickSaleScreen.computeCashSuggestions(total: 0.75, decimalDigits: 2);
      expect(s075, equals([0.75, 1.0, 2.0, 5.0]));

      final s425 = QuickSaleScreen.computeCashSuggestions(total: 4.25, decimalDigits: 2);
      expect(s425, equals([4.25, 5.0, 6.0, 10.0]));
    });

    test('Zero-decimal currency: large amounts (e.g. 23,250 and 125,000) scale to standard banknotes', () {
      final s23250 = QuickSaleScreen.computeCashSuggestions(total: 23250.0, decimalDigits: 0);
      expect(s23250.first, 23250.0);
      // Produces meaningful step (e.g. 23500, 24000, 25000)
      expect(s23250, equals([23250.0, 23500.0, 24000.0, 25000.0]));

      final s125000 = QuickSaleScreen.computeCashSuggestions(total: 125000.0, decimalDigits: 0);
      expect(s125000.first, 125000.0);
      // Avoids +500 trivial steps; scales to 130,000, 150,000, 200,000
      expect(s125000, equals([125000.0, 130000.0, 150000.0, 200000.0]));
    });

    test('Edge cases: zero and negative totals return empty list', () {
      expect(QuickSaleScreen.computeCashSuggestions(total: 0, decimalDigits: 2), isEmpty);
      expect(QuickSaleScreen.computeCashSuggestions(total: -10, decimalDigits: 2), isEmpty);
    });
  });
}
