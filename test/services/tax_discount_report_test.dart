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
    tempDir = Directory.systemTemp.createTempSync('tax_discount_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر اختبار الضرائب',
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

  group('Pure TaxDiscountSummary arithmetic', () {
    test('computes net tax and net discounts correctly', () {
      const summary = TaxDiscountSummary(
        salesTaxCollected: 5000.0,
        purchaseTaxPaid: 2000.0,
        salesDiscountsGiven: 1200.0,
        purchaseDiscountsReceived: 800.0,
        salesDocCount: 10,
        purchaseDocCount: 5,
        salesSubtotal: 50000.0,
        purchaseSubtotal: 20000.0,
        currencyCode: 'SDG',
      );

      expect(summary.netTax, equals(3000.0));
      expect(summary.netDiscounts, equals(-400.0));
    });

    test('handles zero taxes and discounts with zero net values', () {
      const summary = TaxDiscountSummary(
        salesTaxCollected: 0.0,
        purchaseTaxPaid: 0.0,
        salesDiscountsGiven: 0.0,
        purchaseDiscountsReceived: 0.0,
        salesDocCount: 0,
        purchaseDocCount: 0,
        salesSubtotal: 0.0,
        purchaseSubtotal: 0.0,
        currencyCode: 'SDG',
      );

      expect(summary.netTax, equals(0.0));
      expect(summary.netDiscounts, equals(0.0));
    });
  });

  group('getTaxDiscountSummary database query', () {
    test(
      'aggregates taxes and discounts from invoices and purchases in period',
      () async {
        final db = await DatabaseHelper.instance.database;
        final now = DateTime.now();

        // Insert an invoice with tax and discount
        await db.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-TAX-001',
          'contact_id': null,
          'recipient_name': 'عميل تجريبي',
          'date': now.subtract(const Duration(days: 2)).toIso8601String(),
          'subtotal': 10000.0,
          'tax_amount': 1500.0,
          'tax_rate': 15.0,
          'discount': 500.0,
          'total': 11000.0,
          'paid': 11000.0,
          'remaining': 0.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        // Insert a purchase with tax and discount
        await db.insert('documents', {
          'type': 'purchase',
          'document_number': 'PUR-TAX-001',
          'contact_id': null,
          'recipient_name': 'مورد تجريبي',
          'date': now.subtract(const Duration(days: 1)).toIso8601String(),
          'subtotal': 8000.0,
          'tax_amount': 800.0,
          'tax_rate': 10.0,
          'discount': 200.0,
          'total': 8600.0,
          'paid': 8600.0,
          'remaining': 0.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        // Insert a cancelled invoice that should be excluded
        await db.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-TAX-CAN',
          'contact_id': null,
          'recipient_name': 'عميل ملغي',
          'date': now.subtract(const Duration(days: 1)).toIso8601String(),
          'subtotal': 5000.0,
          'tax_amount': 750.0,
          'tax_rate': 15.0,
          'discount': 250.0,
          'total': 5500.0,
          'paid': 0.0,
          'remaining': 5500.0,
          'status': DocumentStatus.cancelled,
          'currency_code': 'SDG',
        });

        final summary = await BusinessReportingService.instance
            .getTaxDiscountSummary(
              from: now.subtract(const Duration(days: 5)),
              to: now.add(const Duration(days: 1)),
            );

        expect(summary.salesTaxCollected, equals(1500.0));
        expect(summary.purchaseTaxPaid, equals(800.0));
        expect(summary.netTax, equals(700.0));
        expect(summary.salesDiscountsGiven, equals(500.0));
        expect(summary.purchaseDiscountsReceived, equals(200.0));
        expect(summary.netDiscounts, equals(-300.0));
        expect(summary.salesDocCount, equals(1));
        expect(summary.purchaseDocCount, equals(1));
        expect(summary.documents.length, equals(2));
      },
    );
  });
}
