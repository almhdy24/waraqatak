import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/business_reporting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('debt_aging_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر اختبار الديون',
        ownerName: 'المالك',
        phone: '0912345678',
        address: 'الخرطوم',
        currencyCode: 'SDG',
      ),
    );
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Pure AgingBucketSummary logic & Boundary Days Tests', () {
    test('correctly places amounts in respective buckets', () {
      var summary = const AgingBucketSummary();
      summary = summary.copyWithAdded(daysOld: 15, amount: 100);
      summary = summary.copyWithAdded(daysOld: 45, amount: 200);
      summary = summary.copyWithAdded(daysOld: 75, amount: 300);
      summary = summary.copyWithAdded(daysOld: 120, amount: 400);

      expect(summary.current0To30, equals(100));
      expect(summary.days31To60, equals(200));
      expect(summary.days61To90, equals(300));
      expect(summary.days90Plus, equals(400));
      expect(summary.total, equals(1000));
    });

    test('validates exact boundary days 30, 31, 60, 61, 90, 91', () {
      var summary = const AgingBucketSummary();

      // Day 0: 0-30 bucket
      summary = summary.copyWithAdded(daysOld: 0, amount: 10);
      // Day 30: 0-30 bucket boundary
      summary = summary.copyWithAdded(daysOld: 30, amount: 20);
      expect(summary.current0To30, equals(30));

      // Day 31: 31-60 bucket boundary
      summary = summary.copyWithAdded(daysOld: 31, amount: 40);
      // Day 60: 31-60 bucket boundary
      summary = summary.copyWithAdded(daysOld: 60, amount: 50);
      expect(summary.days31To60, equals(90));

      // Day 61: 61-90 bucket boundary
      summary = summary.copyWithAdded(daysOld: 61, amount: 70);
      // Day 90: 61-90 bucket boundary
      summary = summary.copyWithAdded(daysOld: 90, amount: 80);
      expect(summary.days61To90, equals(150));

      // Day 91: 90+ bucket boundary
      summary = summary.copyWithAdded(daysOld: 91, amount: 100);
      expect(summary.days90Plus, equals(100));

      expect(summary.total, equals(370));
    });
  });

  group('getAgingReport database aggregation', () {
    test(
      'aggregates receivables aging buckets, handles partial payments, and excludes draft, cancelled, settled, and quotations',
      () async {
        final db = DatabaseHelper.instance;
        final rawDb = await db.database;
        final asOf = DateTime(2026, 11, 23, 12, 0);

        // Clear existing documents to isolate test assertions
        await rawDb.delete('documents');

        // 1. Customer 1: 15 days ago with partial payment (1500 total, 500 paid, 1000 remaining)
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-AGE-1',
          'date': asOf.subtract(const Duration(days: 15)).toIso8601String(),
          'recipient_name': 'أحمد إبراهيم',
          'recipient_phone': '0911111111',
          'subtotal': 1500.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 1500.0,
          'paid': 500.0,
          'remaining': 1000.0,
          'status': DocumentStatus.partiallyPaid,
          'currency_code': 'SDG',
        });

        // 2. Customer 1: 45 days ago (2000 SDG remaining)
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-AGE-2',
          'date': asOf.subtract(const Duration(days: 45)).toIso8601String(),
          'recipient_name': 'أحمد إبراهيم',
          'recipient_phone': '0911111111',
          'subtotal': 2000.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 2000.0,
          'paid': 0.0,
          'remaining': 2000.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        // 3. Customer 2: 70 days ago (3000 SDG remaining)
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-AGE-3',
          'date': asOf.subtract(const Duration(days: 70)).toIso8601String(),
          'recipient_name': 'عثمان موسى',
          'subtotal': 3000.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 3000.0,
          'paid': 0.0,
          'remaining': 3000.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        // 4. Customer 2: 100 days ago (4000 SDG remaining)
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-AGE-4',
          'date': asOf.subtract(const Duration(days: 100)).toIso8601String(),
          'recipient_name': 'عثمان موسى',
          'subtotal': 4000.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 4000.0,
          'paid': 0.0,
          'remaining': 4000.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        // 5. Draft invoice (6000 SDG remaining) - MUST BE EXCLUDED
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-DRAFT',
          'date': asOf.subtract(const Duration(days: 10)).toIso8601String(),
          'recipient_name': 'مسودة عميل',
          'subtotal': 6000.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 6000.0,
          'paid': 0.0,
          'remaining': 6000.0,
          'status': DocumentStatus.draft,
          'currency_code': 'SDG',
        });

        // 6. Cancelled document (5000 SDG) - MUST BE EXCLUDED
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-CANCELLED',
          'date': asOf.subtract(const Duration(days: 15)).toIso8601String(),
          'recipient_name': 'ملغي',
          'subtotal': 5000.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 5000.0,
          'paid': 0.0,
          'remaining': 5000.0,
          'status': DocumentStatus.cancelled,
          'currency_code': 'SDG',
        });

        // 7. Settled document (remaining = 0) - MUST BE EXCLUDED
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-PAID',
          'date': asOf.subtract(const Duration(days: 20)).toIso8601String(),
          'recipient_name': 'مسدد',
          'subtotal': 1000.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 1000.0,
          'paid': 1000.0,
          'remaining': 0.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        // 8. Quotation document with remaining balance - MUST BE EXCLUDED
        await rawDb.insert('documents', {
          'type': 'quotation',
          'document_number': 'QUO-100',
          'date': asOf.subtract(const Duration(days: 25)).toIso8601String(),
          'recipient_name': 'عرض سعر',
          'subtotal': 8000.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 8000.0,
          'paid': 0.0,
          'remaining': 8000.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        final report = await BusinessReportingService.instance.getAgingReport(
          documentType: 'invoice',
          asOf: asOf,
        );

        // Verification: draft (6000), cancelled (5000), paid (0), quotation (8000) are all excluded!
        expect(report.overall.current0To30, equals(1000.0));
        expect(report.overall.days31To60, equals(2000.0));
        expect(report.overall.days61To90, equals(3000.0));
        expect(report.overall.days90Plus, equals(4000.0));
        expect(report.overall.total, equals(10000.0));

        expect(report.contactItems.length, equals(2));
        // First contact sorted by total remaining descending: عثمان موسى (7000)
        expect(report.contactItems[0].contactName, equals('عثمان موسى'));
        expect(report.contactItems[0].buckets.total, equals(7000.0));
        expect(report.contactItems[0].openDocumentCount, equals(2));

        // Second contact: أحمد إبراهيم (3000)
        expect(report.contactItems[1].contactName, equals('أحمد إبراهيم'));
        expect(report.contactItems[1].buckets.total, equals(3000.0));
        expect(report.contactItems[1].openDocumentCount, equals(2));
        expect(report.hasLegacyForeignCurrency, isFalse);
      },
    );

    test(
      'getAgingReport excludes legacy foreign currency (USD) documents and sets hasLegacyForeignCurrency',
      () async {
        final db = DatabaseHelper.instance;
        final rawDb = await db.database;
        final asOf = DateTime(2026, 11, 23, 12, 0);

        await rawDb.delete('documents');

        // 1. SDG invoice (10 days old, 1500 remaining)
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-SDG-1',
          'date': asOf.subtract(const Duration(days: 10)).toIso8601String(),
          'recipient_name': 'عميل محلي',
          'subtotal': 1500.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 1500.0,
          'paid': 0.0,
          'remaining': 1500.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        // 2. Legacy USD invoice (10 days old, 500 remaining)
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-USD-1',
          'date': asOf.subtract(const Duration(days: 10)).toIso8601String(),
          'recipient_name': 'عميل دولي',
          'subtotal': 500.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 500.0,
          'paid': 0.0,
          'remaining': 500.0,
          'status': DocumentStatus.issued,
          'currency_code': 'USD',
        });

        final report = await BusinessReportingService.instance.getAgingReport(
          documentType: 'invoice',
          asOf: asOf,
        );

        // USD amount is excluded from SDG bucket
        expect(report.overall.current0To30, equals(1500.0));
        expect(report.overall.total, equals(1500.0));
        expect(report.contactItems.length, equals(1));
        expect(report.contactItems[0].contactName, equals('عميل محلي'));

        // Flag indicates legacy foreign currency documents exist
        expect(report.hasLegacyForeignCurrency, isTrue);
      },
    );
  });
}
