import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('payment_cash_flow_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر اختبار التدفق المالي',
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
    'getPaymentMethodCashFlow aggregates in/out/net accurately per method',
    () async {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;
      final now = DateTime(2026, 11, 23, 15, 0);

      // Sales Invoice (inflow)
      final saleId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-FLOW-1',
        'date': now.toIso8601String(),
        'subtotal': 10000.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 10000.0,
        'paid': 10000.0,
        'remaining': 0.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      // 6000 cash in on sale
      await rawDb.insert('document_payments', {
        'document_id': saleId,
        'amount': 6000.0,
        'payment_method': 'cash',
        'date': now.toIso8601String(),
      });

      // 4000 bankak in on sale
      await rawDb.insert('document_payments', {
        'document_id': saleId,
        'amount': 4000.0,
        'payment_method': 'bankak',
        'date': now.toIso8601String(),
      });

      // Purchase Invoice (outflow)
      final purchaseId = await rawDb.insert('documents', {
        'type': 'purchase',
        'document_number': 'PUR-FLOW-1',
        'date': now.toIso8601String(),
        'subtotal': 3000.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 3000.0,
        'paid': 3000.0,
        'remaining': 0.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      // 2000 cash out on purchase
      await rawDb.insert('document_payments', {
        'document_id': purchaseId,
        'amount': 2000.0,
        'payment_method': 'cash',
        'date': now.toIso8601String(),
      });

      // Standalone expense voucher (1000 bankak out)
      await rawDb.insert('documents', {
        'type': 'expense_voucher',
        'document_number': 'EXP-FLOW-1',
        'date': now.toIso8601String(),
        'subtotal': 1000.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 1000.0,
        'paid': 1000.0,
        'remaining': 0.0,
        'payment_method': 'bankak',
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      final from = DateTime(2026, 11, 23, 0, 0);
      final to = DateTime(2026, 11, 23, 23, 59, 59);

      final flows = await db.getPaymentMethodCashFlow(from: from, to: to);

      final cashRow = flows.firstWhere((f) => f['method'] == 'cash');
      final bankakRow = flows.firstWhere((f) => f['method'] == 'bankak');

      // Cash: 6000 in, 2000 out, net 4000
      expect(cashRow['in_amount'], equals(6000.0));
      expect(cashRow['out_amount'], equals(2000.0));
      expect(cashRow['net_amount'], equals(4000.0));

      // Bankak: 4000 in, 1000 out, net 3000
      expect(bankakRow['in_amount'], equals(4000.0));
      expect(bankakRow['out_amount'], equals(1000.0));
      expect(bankakRow['net_amount'], equals(3000.0));
    },
  );
}
