import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/analytics/error_sanitizer.dart';

void main() {
  group('ErrorSanitizer unit tests', () {
    test('redacts international and local phone numbers and 6+ digit numbers', () {
      final msg1 = 'Failed to send SMS to +249912345678 because carrier timeout';
      expect(
        ErrorSanitizer.sanitizeMessage(msg1),
        contains('[number redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg1),
        isNot(contains('+249912345678')),
      );

      final msg2 = 'Customer phone 0912345678 is invalid';
      expect(
        ErrorSanitizer.sanitizeMessage(msg2),
        contains('[number redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg2),
        isNot(contains('0912345678')),
      );

      final msg3 = 'Invoice ID 123456789 cannot be found';
      expect(
        ErrorSanitizer.sanitizeMessage(msg3),
        contains('[number redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg3),
        isNot(contains('123456789')),
      );
    });

    test('redacts email addresses', () {
      final msg = 'Failed delivery to account user.finance@company.co.uk';
      expect(
        ErrorSanitizer.sanitizeMessage(msg),
        contains('[email redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg),
        isNot(contains('user.finance@company.co.uk')),
      );
    });

    test('redacts monetary amounts in base and foreign currencies', () {
      final msg1 = 'Expected total 1,500.50 SDG but got 1,400.00 SDG';
      expect(
        ErrorSanitizer.sanitizeMessage(msg1),
        contains('[amount redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg1),
        isNot(contains('1,500.50 SDG')),
      );

      final msg2 = 'Payment of \$500.00 rejected by gateway';
      expect(
        ErrorSanitizer.sanitizeMessage(msg2),
        contains('[amount redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg2),
        isNot(contains('\$500.00')),
      );

      final msg3 = 'Balance 7500 ج.س overdue';
      expect(
        ErrorSanitizer.sanitizeMessage(msg3),
        contains('[amount redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg3),
        isNot(contains('7500 ج.س')),
      );
    });

    test('truncates strings longer than 255 characters', () {
      final longMsg = 'DatabaseException: ${'A' * 600}';
      final sanitized = ErrorSanitizer.sanitizeMessage(longMsg);
      expect(sanitized.length, lessThanOrEqualTo(255));
    });

    test('redacts user filesystem paths and URIs', () {
      final msg1 =
          'File not found: /data/data/com.termux/files/home/user/receipt.pdf';
      expect(
        ErrorSanitizer.sanitizeMessage(msg1),
        contains('[path redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg1),
        isNot(contains('/data/data/com.termux/files/home/user/receipt.pdf')),
      );

      final msg2 = r'Access denied: C:\Users\JohnDoe\AppData\Local\data.db';
      expect(
        ErrorSanitizer.sanitizeMessage(msg2),
        contains('[path redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg2),
        isNot(contains('JohnDoe')),
      );
    });

    test('redacts auth secrets, bearer tokens, and passwords', () {
      final msg1 = 'Auth error with Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      expect(
        ErrorSanitizer.sanitizeMessage(msg1),
        contains('[secret redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg1),
        isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')),
      );

      final msg2 = 'Login failed for password=superSecretPassword123';
      expect(
        ErrorSanitizer.sanitizeMessage(msg2),
        contains('[secret redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg2),
        isNot(contains('superSecretPassword123')),
      );
    });

    test('redacts license key patterns', () {
      final msg = 'License verification failed for WARA-2026-LIVE-ABCD';
      expect(
        ErrorSanitizer.sanitizeMessage(msg),
        contains('[license redacted]'),
      );
      expect(
        ErrorSanitizer.sanitizeMessage(msg),
        isNot(contains('WARA-2026-LIVE-ABCD')),
      );
    });

    test('sanitizes stack trace and removes user paths', () {
      final stack = '''
#0  DatabaseHelper.open (/data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart:120:5)
#1  Main.init (package:warqatek/main.dart:45:10)
''';
      final sanitized = ErrorSanitizer.sanitizeStackTrace(stack);
      expect(sanitized, isNot(contains('/data/data/com.termux/files/home/')));
      expect(sanitized, contains('.../'));
      expect(sanitized, contains('package:warqatek/main.dart'));
    });

    test('sanitizes exception types safely', () {
      expect(
        ErrorSanitizer.sanitizeExceptionType('FormatException'),
        equals('FormatException'),
      );
      expect(
        ErrorSanitizer.sanitizeExceptionType('Custom_Error:Code.12'),
        equals('Custom_Error:Code.12'),
      );
      expect(
        ErrorSanitizer.sanitizeExceptionType('***!!!***'),
        equals('UnknownException'),
      );
    });
  });
}
