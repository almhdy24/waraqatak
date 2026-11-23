import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/utils/phone_utils.dart';

void main() {
  group('normalizeSudanPhone', () {
    test('returns null for null, empty, or whitespace strings', () {
      expect(normalizeSudanPhone(null), isNull);
      expect(normalizeSudanPhone(''), isNull);
      expect(normalizeSudanPhone('   '), isNull);
      expect(normalizeSudanPhone('  - ()  '), isNull);
    });

    test('normalizes 10-digit local Sudanese numbers starting with 0', () {
      // Zain / MTN (starts with 09)
      expect(normalizeSudanPhone('0912345678'), equals('249912345678'));
      // Sudani (starts with 01)
      expect(normalizeSudanPhone('0123456789'), equals('249123456789'));
      // Formatted with spaces and dashes
      expect(normalizeSudanPhone('09-123-45678'), equals('249912345678'));
      expect(normalizeSudanPhone('01 234 56789'), equals('249123456789'));
    });

    test('normalizes 9-digit local Sudanese numbers starting with 9 or 1', () {
      expect(normalizeSudanPhone('912345678'), equals('249912345678'));
      expect(normalizeSudanPhone('123456789'), equals('249123456789'));
      expect(normalizeSudanPhone('912-345-678'), equals('249912345678'));
    });

    test('normalizes international Sudanese numbers with +249 or 00249', () {
      expect(normalizeSudanPhone('+249912345678'), equals('249912345678'));
      expect(normalizeSudanPhone('+249 912 345 678'), equals('249912345678'));
      expect(normalizeSudanPhone('00249912345678'), equals('249912345678'));
      expect(normalizeSudanPhone('00249-123-456-789'), equals('249123456789'));
    });

    test('preserves full 12-digit Sudanese numbers (249 + 9 digits)', () {
      expect(normalizeSudanPhone('249912345678'), equals('249912345678'));
      expect(normalizeSudanPhone('249123456789'), equals('249123456789'));
    });

    test('handles valid international non-Sudanese numbers', () {
      // UAE (+971)
      expect(normalizeSudanPhone('+971501234567'), equals('971501234567'));
      // Saudi Arabia (00966)
      expect(normalizeSudanPhone('00966501234567'), equals('966501234567'));
    });

    test('rejects invalid or too short/long strings', () {
      expect(normalizeSudanPhone('123'), isNull);
      expect(normalizeSudanPhone('not-a-number'), isNull);
      expect(normalizeSudanPhone('0912abc678'), isNull);
      expect(normalizeSudanPhone('123456789012345678'), isNull); // > 15 digits
    });
  });
}
