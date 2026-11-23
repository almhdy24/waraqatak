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

  group('Pure AgingBucketSummary logic', () {
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
  });

  group('getAgingReport database aggregation', () {
    test(
      'aggregates receivables aging buckets and excludes cancelled/settled',
      () async {
        final db = DatabaseHelper.instance;
        final rawDb = await db.database;
        final asOf = DateTime(2026, 11, 23, 12, 0);

        // Customer 1: 15 days ago (1000 SDG remaining)
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
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        // Customer 1: 45 days ago (2000 SDG remaining)
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

        // Customer 2: 70 days ago (3000 SDG remaining)
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

        // Customer 2: 100 days ago (4000 SDG remaining)
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

        // Cancelled document (5000 SDG) - should be excluded
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

        // Settled document (remaining = 0) - should be excluded
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

        final report = await BusinessReportingService.instance.getAgingReport(
          documentType: 'invoice',
          asOf: asOf,
        );

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
      },
    );
  });
}
