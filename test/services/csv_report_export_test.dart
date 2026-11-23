import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/csv_service.dart';

void main() {
  group('CsvService.exportReportToCsv Unit Tests', () {
    test(
      'exports UTF-8 BOM, formats cells, handles quotes, commas, dates and numbers',
      () {
        final headers = ['المنتج', 'الكمية', 'السعر', 'تاريخ', 'ملاحظات'];
        final date = DateTime(2026, 11, 23, 12, 30);
        final rows = [
          ['سكر كنانة, 50 كجم', 1500, 45000.5, date, 'سعر "خاص" للعميل'],
          ['=SUM(A1:B1)', -250, 0, null, 'سطر جديد\nفي الملاحظات'],
        ];

        final bytes = CsvService.instance.exportReportToCsv(
          headers: headers,
          rows: rows,
        );

        // Verify UTF-8 BOM (\uFEFF -> EF BB BF)
        expect(bytes.length, greaterThan(3));
        expect(bytes[0], 0xEF);
        expect(bytes[1], 0xBB);
        expect(bytes[2], 0xBF);

        final decoded = utf8.decode(bytes);
        // Decoded string should start with BOM character \uFEFF
        expect(decoded.startsWith('\uFEFF'), isTrue);

        final content = decoded.substring(1);
        final lines = content
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();

        expect(lines.length, 3); // 1 header + 2 data rows

        // Check header row
        expect(lines[0], 'المنتج,الكمية,السعر,تاريخ,ملاحظات\r');

        // Check row 1:
        // 'سكر كنانة, 50 كجم' has comma -> quoted as "سكر كنانة, 50 كجم"
        // 1500 is raw number without thousands separator
        // 45000.5 has decimal, no thousands comma
        // date is ISO8601
        // 'سعر "خاص" للعميل' has double quotes -> quoted as "سعر ""خاص"" للعميل"
        expect(lines[1], contains('"سكر كنانة, 50 كجم"'));
        expect(lines[1], contains(',1500,'));
        expect(lines[1], contains(',45000.5,'));
        expect(lines[1], contains('2026-11-23T12:30:00.000'));
        expect(lines[1], contains('"سعر ""خاص"" للعميل"'));

        // Check row 2 formula injection protection and multiline quote:
        // =SUM(A1:B1) begins with '=' -> prepends single quote: "'=SUM(A1:B1)"
        expect(lines[2], contains("'=SUM(A1:B1)"));
        expect(lines[2], contains(',-250,'));
      },
    );
  });
}
