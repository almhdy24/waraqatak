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
    tempDir = Directory.systemTemp.createTempSync('daily_closing_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر الخرطوم التجاري',
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

  test(
    'Daily closing summary aggregates sales, collections, and debt properly',
    () async {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;
      final now = DateTime(2026, 11, 23, 14, 0);
      final yesterday = DateTime(2026, 11, 22, 10, 0);

      // 1. Prior sales invoice created yesterday with remaining credit balance
      final priorInvId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-PRIOR-1',
        'date': yesterday.toIso8601String(),
        'subtotal': 10000.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 10000.0,
        'paid': 5000.0,
        'remaining': 5000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      // 2. Sales invoice created today
      final todayInvId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-TODAY-1',
        'date': now.toIso8601String(),
        'subtotal': 20000.0,
        'discount': 2000.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 18000.0,
        'paid': 10000.0,
        'remaining': 8000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      // 3. Cancelled sales invoice today
      await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-CANCELLED-1',
        'date': now.toIso8601String(),
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

      // 4. Payments received today:
      // 4a. 10000 cash on today's invoice
      await rawDb.insert('document_payments', {
        'document_id': todayInvId,
        'amount': 10000.0,
        'payment_method': 'cash',
        'date': now.toIso8601String(),
      });

      // 4b. 5000 bankak collecting debt on yesterday's prior invoice
      await rawDb.insert('document_payments', {
        'document_id': priorInvId,
        'amount': 5000.0,
        'payment_method': 'bankak',
        'date': now.toIso8601String(),
      });

      // 5. Expense voucher today (3000 cash)
      await rawDb.insert('documents', {
        'type': 'expense_voucher',
        'document_number': 'EXP-1',
        'date': now.toIso8601String(),
        'subtotal': 3000.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 3000.0,
        'paid': 3000.0,
        'remaining': 0.0,
        'payment_method': 'cash',
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      final from = DateTime(2026, 11, 23, 0, 0);
      final to = DateTime(2026, 11, 23, 23, 59, 59);

      final summary = await BusinessReportingService.instance
          .getDailyClosingSummary(from: from, to: to);

      // Verify Sales
      expect(summary.invoiceCount, equals(1));
      expect(summary.cancelledInvoiceCount, equals(1));
      expect(summary.grossSales, equals(20000.0));
      expect(summary.totalDiscounts, equals(2000.0));
      expect(summary.netSales, equals(18000.0));
      expect(summary.creditSales, equals(8000.0));

      // Verify Collections
      expect(summary.totalCollected, equals(15000.0));
      expect(summary.collectionsByMethod['cash'], equals(10000.0));
      expect(summary.collectionsByMethod['bankak'], equals(5000.0));
      expect(summary.customerDebtCollected, equals(5000.0));

      // Verify Outflows
      expect(summary.expenseVouchers, equals(3000.0));
      expect(summary.totalDisbursed, equals(3000.0));
      expect(summary.disbursementsByMethod['cash'], equals(3000.0));

      // Verify Net Cash in drawer
      expect(summary.netCashCollected, equals(7000.0)); // 10000 in - 3000 out
    },
  );
}
