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
          ['=SUM(A1:B1)', -250, -12.75, '+249912345678', '-cmd|calc'],
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
            .split('\r\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();

        expect(lines.length, 3); // 1 header + 2 data rows

        // Check header row (Arabic preserved)
        expect(lines[0], 'المنتج,الكمية,السعر,تاريخ,ملاحظات');

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

        // Check row 2:
        // =SUM(A1:B1) begins with '=' -> prepends single quote: "'=SUM(A1:B1)"
        // -250 is raw num -> stays -250 without apostrophe
        // -12.75 is raw num -> stays -12.75 without apostrophe
        // +249912345678 is numeric String -> stays +249912345678 without apostrophe
        // -cmd|calc is non-numeric text with '-' -> gets apostrophe: "'-cmd|calc"
        expect(lines[2], contains("'=SUM(A1:B1)"));
        expect(lines[2], contains(',-250,'));
        expect(lines[2], contains(',-12.75,'));
        expect(lines[2], contains(',+249912345678,'));
        expect(lines[2], contains("'-cmd|calc"));
      },
    );

    test('handles multiline cells with RFC 4180 quotes and CRLF', () {
      final headers = ['العنوان', 'الوصف'];
      final rows = [
        ['ملاحظة', 'سطر أول\r\nسطر ثان'],
      ];

      final bytes = CsvService.instance.exportReportToCsv(
        headers: headers,
        rows: rows,
      );

      final decoded = utf8.decode(bytes).substring(1);
      expect(decoded, contains('"سطر أول\r\nسطر ثان"'));
    });

    test(
      'sanitizeCell behaves correctly for injection, numeric and escaping',
      () {
        // Real numbers as strings
        expect(CsvService.sanitizeCell('-250'), '-250');
        expect(CsvService.sanitizeCell('-250.75'), '-250.75');
        expect(CsvService.sanitizeCell('+249912345678'), '+249912345678');
        expect(CsvService.sanitizeCell('100'), '100');

        // Formula injection
        expect(CsvService.sanitizeCell('=SUM(A1:A2)'), "'=SUM(A1:A2)");
        expect(CsvService.sanitizeCell('+cmd|calc'), "'+cmd|calc");
        expect(CsvService.sanitizeCell('-cmd|calc'), "'-cmd|calc");
        expect(CsvService.sanitizeCell('@evil'), "'@evil");
        expect(CsvService.sanitizeCell('\tcmd'), "'\tcmd");

        // RFC 4180 escaping
        expect(CsvService.sanitizeCell('hello, world'), '"hello, world"');
        expect(
          CsvService.sanitizeCell('text with "quotes"'),
          '"text with ""quotes"""',
        );
        expect(CsvService.sanitizeCell('multi\nline'), '"multi\nline"');
      },
    );
  });
}
