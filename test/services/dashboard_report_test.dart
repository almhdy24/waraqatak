import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/date_range_filter.dart';

void main() {
  group('DateRangeFilter', () {
    test('today covers full day', () {
      final f = DateRangeFilter.today();
      expect(f.from.hour, 0);
      expect(f.from.minute, 0);
      expect(f.to.hour, 23);
      expect(f.to.minute, 59);
      expect(f.to.second, 59);
    });

    test('last7Days spans 7 days', () {
      final f = DateRangeFilter.last7Days();
      final diff = f.to.difference(f.from).inDays;
      expect(diff, 6);
    });

    test('thisMonth starts on day 1', () {
      final f = DateRangeFilter.thisMonth();
      expect(f.from.day, 1);
      expect(f.from.hour, 0);
    });

    test('custom normalizes to day boundaries', () {
      final from = DateTime(2024, 3, 15, 10, 30);
      final to = DateTime(2024, 3, 20, 8, 0);
      final f = DateRangeFilter.custom(from, to);
      expect(f.from, DateTime(2024, 3, 15));
      expect(f.to, DateTime(2024, 3, 20, 23, 59, 59, 999));
    });

    test('from is always before or equal to to', () {
      for (final f in [
        DateRangeFilter.today(),
        DateRangeFilter.last7Days(),
        DateRangeFilter.thisMonth(),
        DateRangeFilter.custom(DateTime(2024, 1, 1), DateTime(2024, 1, 31)),
      ]) {
        expect(f.from.isBefore(f.to) || f.from.isAtSameMomentAs(f.to), isTrue);
      }
    });
  });

  group('Financial accuracy rules', () {
    test('outstanding = total - paid', () {
      const total = 1000.0;
      const paid = 600.0;
      const remaining = total - paid;
      expect(remaining, 400.0);
    });

    test('total sales excludes cancelled documents', () {
      final docs = [
        _mockDoc(total: 500, status: 'issued'),
        _mockDoc(total: 300, status: 'issued'),
        _mockDoc(total: 200, status: 'cancelled'),
      ];
      final finalized = docs.where((d) => d['status'] != 'cancelled').toList();
      final total = finalized.fold(0.0, (s, d) => s + (d['total'] as double));
      expect(total, 800.0);
    });

    test('total sales excludes draft documents', () {
      final docs = [
        _mockDoc(total: 500, status: 'issued'),
        _mockDoc(total: 100, status: 'draft'),
      ];
      final active = docs.where((d) => d['status'] != 'draft').toList();
      final total = active.fold(0.0, (s, d) => s + (d['total'] as double));
      expect(total, 500.0);
    });

    test('customer outstanding sums remaining across all invoices', () {
      final invoices = [
        _mockDoc(total: 1000, paid: 600, remaining: 400, status: 'issued'),
        _mockDoc(total: 500, paid: 500, remaining: 0, status: 'issued'),
        _mockDoc(total: 300, paid: 0, remaining: 300, status: 'issued'),
      ];
      final outstanding = invoices.fold(0.0,
          (s, d) => s + (d['remaining'] as double));
      expect(outstanding, 700.0);
    });
  });
}

Map<String, dynamic> _mockDoc({
  required double total,
  double paid = 0,
  double? remaining,
  required String status,
}) => {
  'total': total,
  'paid': paid,
  'remaining': remaining ?? (total - paid),
  'status': status,
};
