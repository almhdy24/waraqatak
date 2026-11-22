import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_status.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_acc_03_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    db = DatabaseHelper.instance;
  });

  tearDownAll(() async {
    await db.closeDatabase();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await db.closeDatabase();
    if (tempDir.existsSync()) {
      for (final f in tempDir.listSync()) {
        if (f is File) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }

    await db.insertBusiness(
      const Business(
        name: 'ACC-03 Test Business',
        ownerName: 'Test Owner',
        phone: '0123456789',
        address: 'Port Sudan',
        currencyCode: 'SDG',
        taxRate: 0.0,
        taxesEnabled: false,
        pricesIncludeTax: false,
      ),
    );
  });

  test('ACC-03 Regression: Standalone expense vouchers must appear in period summary paymentsOut and payments report', () async {
    final march1 = DateTime(2026, 3, 1);
    final march31 = DateTime(2026, 3, 31);

    // 1. Insert a standalone expense voucher (e.g. Electricity bill: 25,000 SDG)
    final voucher = Document(
      type: 'expense_voucher',
      documentNumber: 'VCH-001',
      date: DateTime(2026, 3, 15),
      subtotal: 25000.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 25000.0,
      paid: 25000.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
      notes: 'Electricity bill',
    );
    await db.insertDocumentWithItems(voucher, const []);

    // 2. Query period summary for March 2026
    final summary = await db.getPeriodSummary(from: march1, to: march31, currencyCode: 'SDG');

    // ACC-03 BUG: getPeriodSummary joins document_payments where type IN ('invoice', 'purchase').
    // Standalone expense vouchers have no row in document_payments, so paymentsOut returns 0.0 instead of 25000.0.
    expect(
      summary['paymentsOut'],
      equals(25000.0),
      reason: 'ACC-03: Standalone expense voucher must be reflected in period summary paymentsOut',
    );

    // 3. Query payments report
    final reportRows = await db.getPaymentReport(from: march1, to: march31, currencyCode: 'SDG');
    expect(
      reportRows.any((r) => r['doc_type'] == 'expense_voucher' && (r['amount'] as num).toDouble() == 25000.0),
      isTrue,
      reason: 'ACC-03: Standalone expense voucher must appear in payment report rows',
    );
  });
}
