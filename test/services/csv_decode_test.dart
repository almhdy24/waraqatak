import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/csv_service.dart';

void main() {
  group('CsvService.decodeCsvBytes', () {
    test('decodes UTF-8 text correctly', () {
      expect(
        CsvService.decodeCsvBytes(utf8.encode('منتج,السعر')),
        'منتج,السعر',
      );
    });

    test('decodes Windows-1256 product word bytes', () {
      expect(
        CsvService.decodeCsvBytes([0xE3, 0xE4, 0xCA, 0xCC]),
        'منتج',
      );
    });

    test('decodes Windows-1256 price word bytes', () {
      expect(
        CsvService.decodeCsvBytes([0xC7, 0xE1, 0xD3, 0xDA, 0xD1]),
        'السعر',
      );
    });

    test('decodes ASCII CSV bytes', () {
      expect(
        CsvService.decodeCsvBytes('a,b\n1,2'.codeUnits),
        'a,b\n1,2',
      );
    });
  });
}
