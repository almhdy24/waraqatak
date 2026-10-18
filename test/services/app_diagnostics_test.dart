import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/models/diagnostic_report.dart';
import 'package:warqatek/services/app_diagnostics_service.dart';

void main() {
  group('DiagnosticReport Model Tests', () {
    test('serializes to and from SQLite map accurately', () {
      final now = DateTime.parse('2026-10-18T10:00:00.000Z');
      final report = DiagnosticReport(
        id: 1,
        reportUuid: '550e8400-e29b-41d4-a716-446655440000',
        appVersion: '1.1.1+5',
        platform: 'android',
        osVersion: 'Android 14',
        exceptionType: 'FormatException',
        sanitizedMessage: 'Invalid format detected',
        sanitizedStackTrace: '#0 testStack',
        operation: 'invoice_pdf_generation',
        occurredAt: now,
        createdAt: now,
        retryCount: 1,
      );

      final map = report.toDbMap();
      expect(
        map['report_uuid'],
        equals('550e8400-e29b-41d4-a716-446655440000'),
      );
      expect(map['exception_type'], equals('FormatException'));
      expect(map['operation'], equals('invoice_pdf_generation'));
      expect(map['retry_count'], equals(1));

      final restored = DiagnosticReport.fromDb(map);
      expect(restored.reportUuid, equals(report.reportUuid));
      expect(restored.sanitizedMessage, equals(report.sanitizedMessage));
      expect(restored.operation, equals(report.operation));
      expect(restored.occurredAt, equals(report.occurredAt));
    });

    test('generates strict public API payload format', () {
      final now = DateTime.parse('2026-10-18T10:00:00.000Z');
      final report = DiagnosticReport(
        reportUuid: '550e8400-e29b-41d4-a716-446655440000',
        appVersion: '1.1.1+5',
        platform: 'android',
        osVersion: 'Android 14',
        exceptionType: 'StateError',
        sanitizedMessage: 'Bad state',
        sanitizedStackTrace: '#0 stack trace',
        operation: 'backup_export',
        occurredAt: now,
        createdAt: now,
      );

      final payload = report.toApiPayload();
      expect(
        payload['report_uuid'],
        equals('550e8400-e29b-41d4-a716-446655440000'),
      );
      expect(payload['app_version'], equals('1.1.1+5'));
      expect(payload['platform'], equals('android'));
      expect(payload['exception_type'], equals('StateError'));
      expect(payload['sanitized_message'], equals('Bad state'));
      expect(payload['operation'], equals('backup_export'));
      expect(payload['occurred_at'], equals('2026-10-18T10:00:00.000Z'));
      // Database specific fields MUST NOT be sent in API payload
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('retry_count'), isFalse);
    });
  });

  group('AppDiagnosticsService Sanitization & Privacy Tests', () {
    test('sanitizeExceptionType trims and enforces length cap', () {
      expect(
        AppDiagnosticsService.sanitizeExceptionType('FormatException'),
        equals('FormatException'),
      );
      expect(
        AppDiagnosticsService.sanitizeExceptionType('Custom<Error> (unsafe)'),
        equals('CustomErrorunsafe'),
      );
      expect(
        AppDiagnosticsService.sanitizeExceptionType(''),
        equals('UnknownException'),
      );
      final longType = 'A' * 200;
      expect(
        AppDiagnosticsService.sanitizeExceptionType(longType).length,
        equals(128),
      );
    });

    test('sanitizeMessage redacts absolute Linux and Android paths', () {
      final msg =
          'Failed reading file at /data/data/com.elmahdi.waraqatak/databases/secret.db due to IO';
      final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

      expect(sanitized.contains('/data/data'), isFalse);
      expect(sanitized.contains('[path redacted]'), isTrue);
      expect(
        sanitized,
        equals('Failed reading file at [path redacted] due to IO'),
      );
    });

    test('sanitizeMessage redacts Windows drive paths', () {
      final msg = r'Error loading C:\Users\Admin\Documents\secret_invoice.pdf';
      final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

      expect(sanitized.contains(r'C:\Users'), isFalse);
      expect(sanitized.contains('[path redacted]'), isTrue);
    });

    test('sanitizeMessage redacts email addresses', () {
      final msg =
          'User invoice notification failed for customer.contact@example.com';
      final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

      expect(sanitized.contains('@example.com'), isFalse);
      expect(sanitized.contains('[email redacted]'), isTrue);
    });

    test(
      'sanitizeMessage redacts long numbers (phone numbers / invoice values)',
      () {
        final msg = 'Invoice #2026101899 for phone +249912345678 completed';
        final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

        expect(sanitized.contains('2026101899'), isFalse);
        expect(sanitized.contains('249912345678'), isFalse);
        expect(sanitized.contains('[number redacted]'), isTrue);
      },
    );

    test('sanitizeMessage redacts Bearer tokens and authorization headers', () {
      final msg =
          'API failed with Bearer secret_token_xyz123 and token=abc_999';
      final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

      expect(sanitized.contains('secret_token_xyz123'), isFalse);
      expect(sanitized.contains('abc_999'), isFalse);
      expect(sanitized.contains('[secret redacted]'), isTrue);
    });

    test('sanitizeMessage enforces maximum 255 character limit', () {
      final longMsg = 'Safe error description ' * 20;
      final sanitized = AppDiagnosticsService.sanitizeMessage(longMsg);

      expect(sanitized.length, lessThanOrEqualTo(255));
    });

    test(
      'sanitizeStackTrace redacts user directories and caps at 4000 characters',
      () {
        final rawStack = '''
#0 Database.open (/data/data/com.elmahdi.waraqatak/app_flutter/db.dart:42)
#1 Main.run (/home/builder/projects/waraqatak/lib/main.dart:15)
#2 package:warqatek/services/backup_service.dart:88
''';
        final sanitized = AppDiagnosticsService.sanitizeStackTrace(rawStack);

        expect(
          sanitized.contains('/data/data/com.elmahdi.waraqatak/'),
          isFalse,
        );
        expect(
          sanitized.contains('/home/builder/projects/waraqatak/'),
          isFalse,
        );
        expect(sanitized.contains('.../db.dart:42'), isTrue);
        expect(
          sanitized.contains(
            'package:warqatek/services/backup_service.dart:88',
          ),
          isTrue,
        );

        final massiveStack = 'at package:warqatek/test.dart:10\n' * 300;
        final capped = AppDiagnosticsService.sanitizeStackTrace(massiveStack);
        expect(capped.length, lessThanOrEqualTo(4000));
      },
    );

    test('generateUuidV4 produces valid RFC 4122 version 4 UUIDs', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      for (int i = 0; i < 20; i++) {
        final uuid = AppDiagnosticsService.generateUuidV4();
        expect(
          uuidRegex.hasMatch(uuid),
          isTrue,
          reason: 'Failed for UUID: $uuid',
        );
      }
    });

    test(
      'allowedOperations strictly permits only approved operational slugs',
      () {
        final ops = AppDiagnosticsService.allowedOperations;

        expect(ops.contains('app_launch'), isTrue);
        expect(ops.contains('invoice_pdf_generation'), isTrue);
        expect(ops.contains('receipt_printing'), isTrue);
        expect(ops.contains('backup_export'), isTrue);
        expect(ops.contains('backup_restore'), isTrue);
        expect(ops.contains('db_migration'), isTrue);
        expect(ops.contains('licensing_check'), isTrue);
        expect(ops.contains('ops_sync'), isTrue);
        expect(ops.contains('ui_render'), isTrue);
        expect(ops.contains('unhandled_exception'), isTrue);

        // Dangerous or arbitrary identifiers must not be present
        expect(ops.contains('customer_data_export'), isFalse);
        expect(ops.contains('financial_telemetry'), isFalse);
        expect(ops.contains('arbitrary_event'), isFalse);
      },
    );

    test(
      'adversarial test: redacts international phone numbers and contact refs',
      () {
        final msg =
            'SMS failure for phone: +249912345678 and alt: +249 123456789';
        final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

        expect(sanitized.contains('912345678'), isFalse);
        expect(sanitized.contains('123456789'), isFalse);
        expect(sanitized.contains('[number redacted]'), isTrue);
      },
    );

    test('adversarial test: redacts license keys of various formats', () {
      final msg =
          'Activation failed with key WARA-2026-LIVE-ABCD and fallback 1A2B-3C4D-5E6F';
      final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

      expect(sanitized.contains('WARA-2026-LIVE-ABCD'), isFalse);
      expect(sanitized.contains('1A2B-3C4D-5E6F'), isFalse);
      expect(sanitized.contains('[license redacted]'), isTrue);
    });

    test('adversarial test: redacts financial values and currency codes', () {
      final msg =
          'Payment error: SDG 150000.50 pending; converted from 500.00 USD (also 2500 ج.س)';
      final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

      expect(sanitized.contains('150000.50'), isFalse);
      expect(sanitized.contains('500.00'), isFalse);
      expect(sanitized.contains('2500'), isFalse);
      expect(sanitized.contains('[amount redacted]'), isTrue);
    });

    test('adversarial test: redacts customer and client name markers', () {
      final msg =
          'Failed processing invoice for Customer: Mohamed Ahmed and Client: Sarah Connor';
      final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

      expect(sanitized.contains('Mohamed Ahmed'), isFalse);
      expect(sanitized.contains('Sarah Connor'), isFalse);
      expect(sanitized.contains('[redacted]'), isTrue);
    });

    test('adversarial test: redacts SQL string literals and database values', () {
      final msg =
          "SqliteException: UNIQUE constraint failed: INSERT INTO customers (name) VALUES ('Secret Business Name')";
      final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

      expect(sanitized.contains('Secret Business Name'), isFalse);
      expect(sanitized.contains("'[redacted]'"), isTrue);
    });

    test('adversarial test: redacts content:// and file:// storage URIs', () {
      final msg =
          'Permission denial for content:///data/data/com.elmahdi.waraqatak/invoices/1001.pdf';
      final sanitized = AppDiagnosticsService.sanitizeMessage(msg);

      expect(sanitized.contains('/data/data'), isFalse);
      expect(sanitized.contains('1001.pdf'), isFalse);
      expect(sanitized.contains('[path redacted]'), isTrue);
    });
  });

  group('AppDiagnosticsService Consent & Default State Tests', () {
    test('consent defaults to false when uninitialized or unset', () async {
      SharedPreferences.setMockInitialValues({});
      final consent = await AppDiagnosticsService.instance.isConsentGranted();
      expect(consent, isFalse);
    });

    test(
      'revoking consent updates preference and increments sync generation',
      () async {
        SharedPreferences.setMockInitialValues({
          AppDiagnosticsService.kConsentPrefKey: true,
        });
        expect(await AppDiagnosticsService.instance.isConsentGranted(), isTrue);

        await AppDiagnosticsService.instance.setConsent(false);
        expect(
          await AppDiagnosticsService.instance.isConsentGranted(),
          isFalse,
        );
      },
    );
  });
}
