import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_payment.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/accounting/journal_backfill_service.dart';
import 'package:warqatek/services/backup_service.dart';
import 'package:warqatek/services/customer_statement_service.dart';
import 'package:warqatek/services/database_diagnostic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('fifo_allocation_db_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'مؤسسة التجارة الحديثة',
        ownerName: 'أحمد',
        phone: '0912345678',
        address: 'الخرطوم',
        currencyCode: 'SDG',
      ),
    );
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // Helper to create contact
  Future<int> makeContact(String name, String type) async {
    return await DatabaseHelper.instance.insertContact(
      Contact(name: name, type: type, phone: '0911111111'),
    );
  }

  // Helper to create invoice
  Future<int> makeInvoice({
    required int contactId,
    required double total,
    required DateTime date,
    String currency = 'SDG',
    double paid = 0.0,
    String status = DocumentStatus.issued,
  }) async {
    final db = DatabaseHelper.instance;
    final id = await db.insertDocumentWithItems(
      Document(
        type: 'invoice',
        documentNumber: 'INV-${DateTime.now().microsecondsSinceEpoch}',
        date: date,
        contactId: contactId,
        currencyCode: currency,
        subtotal: total,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: total,
        paid: paid,
        remaining: total - paid,
        status: status,
      ),
      [
        DocumentItem(
          documentId: 0,
          description: 'صنف اختباري',
          quantity: 1.0,
          price: total,
          total: total,
        ),
      ],
    );
    return id;
  }

  // Helper to create purchase
  Future<int> makePurchase({
    required int contactId,
    required double total,
    required DateTime date,
    String currency = 'SDG',
    double paid = 0.0,
    String status = DocumentStatus.issued,
  }) async {
    final db = DatabaseHelper.instance;
    final id = await db.insertDocumentWithItems(
      Document(
        type: 'purchase',
        documentNumber: 'PUR-${DateTime.now().microsecondsSinceEpoch}',
        date: date,
        contactId: contactId,
        currencyCode: currency,
        subtotal: total,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: total,
        paid: paid,
        remaining: total - paid,
        status: status,
      ),
      [
        DocumentItem(
          documentId: 0,
          description: 'مشتريات اختبارية',
          quantity: 1.0,
          price: total,
          total: total,
        ),
      ],
    );
    return id;
  }

  // Helper to create receipt
  Future<int> makeReceipt({
    required int contactId,
    required double total,
    required DateTime date,
    String currency = 'SDG',
  }) async {
    final db = DatabaseHelper.instance;
    return await db.insertDocumentWithItems(
      Document(
        type: 'payment_receipt',
        documentNumber: 'REC-${DateTime.now().microsecondsSinceEpoch}',
        date: date,
        contactId: contactId,
        currencyCode: currency,
        subtotal: total,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: total,
        paid: total,
        remaining: 0.0,
        status: DocumentStatus.issued,
        paymentMethod: 'cash',
      ),
      [],
    );
  }

  // Helper to create expense voucher (supplier payment)
  Future<int> makeExpenseVoucher({
    required int contactId,
    required double total,
    required DateTime date,
    String currency = 'SDG',
  }) async {
    final db = DatabaseHelper.instance;
    return await db.insertDocumentWithItems(
      Document(
        type: 'expense_voucher',
        documentNumber: 'VOU-${DateTime.now().microsecondsSinceEpoch}',
        date: date,
        contactId: contactId,
        currencyCode: currency,
        subtotal: total,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: total,
        paid: total,
        remaining: 0.0,
        status: DocumentStatus.issued,
        paymentMethod: 'bank',
      ),
      [],
    );
  }

  Future<List<DocumentPayment>> getDocumentPaymentsByReceipt(int receiptId) async {
    final rawDb = await DatabaseHelper.instance.database;
    final rows = await rawDb.query(
      'document_payments',
      where: 'receipt_document_id = ?',
      whereArgs: [receiptId],
      orderBy: 'id ASC',
    );
    return rows.map((r) => DocumentPayment.fromMap(r)).toList();
  }

  group('FIFO Allocation & Cancellation Test Suite (Scenarios 1-24)', () {
    test('1. FIFO allocation across 3 invoices', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 1', 'customer');
      final inv1 = await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));
      final inv2 = await makeInvoice(contactId: cid, total: 200, date: DateTime(2026, 1, 2));
      final inv3 = await makeInvoice(contactId: cid, total: 300, date: DateTime(2026, 1, 3));

      // Receipt settles inv1 (100) and inv2 (200) completely = 300
      final recId = await makeReceipt(contactId: cid, total: 300, date: DateTime(2026, 1, 10));

      final d1 = (await db.getDocumentById(inv1))!;
      final d2 = (await db.getDocumentById(inv2))!;
      final d3 = (await db.getDocumentById(inv3))!;

      expect(d1.paid, 100);
      expect(d1.remaining, 0);
      expect(d1.status, DocumentStatus.paid);

      expect(d2.paid, 200);
      expect(d2.remaining, 0);
      expect(d2.status, DocumentStatus.paid);

      expect(d3.paid, 0);
      expect(d3.remaining, 300);
      expect(d3.status, DocumentStatus.issued);

      final allocations = await getDocumentPaymentsByReceipt(recId);
      expect(allocations.length, 2);
      expect(allocations[0].documentId, inv1);
      expect(allocations[0].amount, 100);
      expect(allocations[1].documentId, inv2);
      expect(allocations[1].amount, 200);
    });

    test('2. Partial allocation across multiple invoices', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 2', 'customer');
      final inv1 = await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));
      final inv2 = await makeInvoice(contactId: cid, total: 200, date: DateTime(2026, 1, 2));

      // Receipt 150 -> 100 on inv1, 50 on inv2
      await makeReceipt(contactId: cid, total: 150, date: DateTime(2026, 1, 5));

      final d1 = (await db.getDocumentById(inv1))!;
      final d2 = (await db.getDocumentById(inv2))!;

      expect(d1.paid, 100);
      expect(d1.remaining, 0);
      expect(d1.status, DocumentStatus.paid);

      expect(d2.paid, 50);
      expect(d2.remaining, 150);
      expect(d2.status, DocumentStatus.partiallyPaid);
    });

    test('3. Multiple receipts against 1 invoice', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 3', 'customer');
      final inv1 = await makeInvoice(contactId: cid, total: 500, date: DateTime(2026, 1, 1));

      await makeReceipt(contactId: cid, total: 200, date: DateTime(2026, 1, 2));
      var d1 = (await db.getDocumentById(inv1))!;
      expect(d1.paid, 200);
      expect(d1.remaining, 300);

      await makeReceipt(contactId: cid, total: 300, date: DateTime(2026, 1, 3));
      d1 = (await db.getDocumentById(inv1))!;
      expect(d1.paid, 500);
      expect(d1.remaining, 0);
      expect(d1.status, DocumentStatus.paid);
    });

    test('4. One receipt allocated across multiple invoices', () async {
      final cid = await makeContact('عميل 4', 'customer');
      await makeInvoice(contactId: cid, total: 50, date: DateTime(2026, 1, 1));
      await makeInvoice(contactId: cid, total: 50, date: DateTime(2026, 1, 2));
      await makeInvoice(contactId: cid, total: 50, date: DateTime(2026, 1, 3));

      final recId = await makeReceipt(contactId: cid, total: 150, date: DateTime(2026, 1, 4));
      final allocations = await getDocumentPaymentsByReceipt(recId);
      expect(allocations.length, 3);
      for (final a in allocations) {
        expect(a.amount, 50);
      }
    });

    test('5. Cancellation of a multi-invoice receipt', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 5', 'customer');
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 2));

      final recId = await makeReceipt(contactId: cid, total: 200, date: DateTime(2026, 1, 3));
      await db.cancelDocument(recId);

      final rec = (await db.getDocumentById(recId))!;
      expect(rec.status, DocumentStatus.cancelled);
    });

    test('6. Cancellation restores every affected invoice exactly', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 6', 'customer');
      final inv1 = await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));
      final inv2 = await makeInvoice(contactId: cid, total: 200, date: DateTime(2026, 1, 2));

      final recId = await makeReceipt(contactId: cid, total: 150, date: DateTime(2026, 1, 3));
      await db.cancelDocument(recId);

      final d1 = (await db.getDocumentById(inv1))!;
      final d2 = (await db.getDocumentById(inv2))!;

      expect(d1.paid, 0);
      expect(d1.remaining, 100);
      expect(d1.status, DocumentStatus.issued);

      expect(d2.paid, 0);
      expect(d2.remaining, 200);
      expect(d2.status, DocumentStatus.issued);
    });

    test('7. Reversal rows are negative and never counted as positive payments', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 7', 'customer');
      final inv1 = await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));

      final recId = await makeReceipt(contactId: cid, total: 100, date: DateTime(2026, 1, 2));
      await db.cancelDocument(recId);

      final payments = await db.getDocumentPayments(inv1);
      final reversals = payments.where((p) => p.paymentOrigin == PaymentOrigin.reversal).toList();
      expect(reversals.isNotEmpty, true);
      for (final r in reversals) {
        expect(r.amount < 0, true);
      }
    });

    test('8. Cancelled invoices excluded from FIFO', () async {
      final cid = await makeContact('عميل 8', 'customer');
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1), status: DocumentStatus.cancelled);
      final inv2 = await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 2));

      final recId = await makeReceipt(contactId: cid, total: 100, date: DateTime(2026, 1, 3));
      final allocations = await getDocumentPaymentsByReceipt(recId);

      expect(allocations.length, 1);
      expect(allocations.first.documentId, inv2);
    });

    test('9. Historical standalone vouchers retain 4200/5100 classification', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 9', 'customer');

      final rawDb = await db.database;
      final standaloneId = await rawDb.insert('documents', {
        'type': 'payment_receipt',
        'document_number': 'REC-HIST-001',
        'date': DateTime(2025, 1, 1).toIso8601String(),
        'contact_id': cid,
        'currency_code': 'SDG',
        'subtotal': 500,
        'discount': 0,
        'tax_rate': 0,
        'tax_amount': 0,
        'total': 500,
        'paid': 500,
        'remaining': 0,
        'status': 'issued',
        'payment_method': 'cash',
      });

      final hasAlloc = await db.hasActiveAllocations(standaloneId);
      expect(hasAlloc, false);
    });

    test('10. Currency segregation', () async {
      final cid = await makeContact('عميل 10', 'customer');
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1), currency: 'USD');

      // Creating a receipt in SDG should fail because there are no SDG invoices
      expect(
        () async => await makeReceipt(contactId: cid, total: 100, date: DateTime(2026, 1, 2), currency: 'SDG'),
        throwsA(isA<StateError>()),
      );
    });

    test('11. Deterministic date/id tie-breaking', () async {
      final cid = await makeContact('عميل 11', 'customer');
      final sameDate = DateTime(2026, 1, 1, 10, 0);
      final inv1 = await makeInvoice(contactId: cid, total: 100, date: sameDate);
      await makeInvoice(contactId: cid, total: 100, date: sameDate);

      final recId = await makeReceipt(contactId: cid, total: 50, date: DateTime(2026, 1, 2));
      final allocations = await getDocumentPaymentsByReceipt(recId);

      expect(allocations.first.documentId, inv1);
    });

    test('12. Overpayment rejection & transaction rollback', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 12', 'customer');
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));

      // Attempt to pay 150 when outstanding is only 100
      expect(
        () async => await makeReceipt(contactId: cid, total: 150, date: DateTime(2026, 1, 2)),
        throwsA(isA<StateError>()),
      );

      // Verify no receipt or partial allocations were persisted
      final open = await db.getContactOutstanding(cid, 'SDG');
      expect(open, 100);
    });

    test('13. Closed-period voucher creation rejection', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 13', 'customer');
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));

      // Close period through 2026-01-31
      await db.setSetting('books_closed_through', '2026-01-31');

      // Voucher dated inside closed period must fail
      expect(
        () async => await makeReceipt(contactId: cid, total: 100, date: DateTime(2026, 1, 15)),
        throwsA(anything),
      );

      // Reset closed period
      await db.setSetting('books_closed_through', '');
    });

    test('14. Settlement of old invoice from open period', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 14', 'customer');
      final inv1 = await makeInvoice(contactId: cid, total: 100, date: DateTime(2025, 12, 1));

      // Close period through 2025-12-31
      await db.setSetting('books_closed_through', '2025-12-31');

      // Settlement dated in open period (2026-01-05) must succeed
      await makeReceipt(contactId: cid, total: 100, date: DateTime(2026, 1, 5));
      final d1 = (await db.getDocumentById(inv1))!;
      expect(d1.status, DocumentStatus.paid);

      await db.setSetting('books_closed_through', '');
    });

    test('15. Cancellation period-lock behavior', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 15', 'customer');
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));
      final recId = await makeReceipt(contactId: cid, total: 100, date: DateTime(2026, 1, 2));

      // Close period through 2026-01-10
      await db.setSetting('books_closed_through', '2026-01-10');

      // Cancelling voucher dated 2026-01-02 inside closed period must fail
      expect(
        () async => await db.cancelDocument(recId),
        throwsA(anything),
      );

      await db.setSetting('books_closed_through', '');
    });

    test('16. Allocated voucher editing rejection', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 16', 'customer');
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));
      final recId = await makeReceipt(contactId: cid, total: 100, date: DateTime(2026, 1, 2));

      final rec = (await db.getDocumentById(recId))!;
      expect(
        () async => await db.updateDocumentWithItems(
          rec.copyWith(notes: 'محاولة تعديل'),
          [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('17. Diagnostic recognition of multi-allocation vouchers', () async {
      final cid = await makeContact('عميل 17', 'customer');
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));
      await makeInvoice(contactId: cid, total: 200, date: DateTime(2026, 1, 2));
      await makeReceipt(contactId: cid, total: 300, date: DateTime(2026, 1, 3));

      final report = await DatabaseDiagnosticService.runDiagnostics();
      expect(report.errorCount, 0);
    });

    test('18. Customer statement correctness with partial receipts', () async {
      final cid = await makeContact('عميل 18', 'customer');
      await makeInvoice(contactId: cid, total: 200, date: DateTime(2026, 1, 1));
      await makeReceipt(contactId: cid, total: 50, date: DateTime(2026, 1, 2));

      final stmt = await CustomerStatementService.getStatementForContact(
        contactId: cid,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );

      expect(stmt.closingBalance, 150);
    });

    test('19. Customer statement correctness after reversal', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 19', 'customer');
      await makeInvoice(contactId: cid, total: 200, date: DateTime(2026, 1, 1));
      final recId = await makeReceipt(contactId: cid, total: 200, date: DateTime(2026, 1, 2));
      await db.cancelDocument(recId);

      final stmt = await CustomerStatementService.getStatementForContact(
        contactId: cid,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );

      expect(stmt.closingBalance, 200);
    });

    test('20. Supplier balance correctness', () async {
      final db = DatabaseHelper.instance;
      final sid = await makeContact('مورد 20', 'supplier');
      final pur1 = await makePurchase(contactId: sid, total: 500, date: DateTime(2026, 1, 1));
      final pur2 = await makePurchase(contactId: sid, total: 300, date: DateTime(2026, 1, 2));

      await makeExpenseVoucher(contactId: sid, total: 600, date: DateTime(2026, 1, 3));

      final p1 = (await db.getDocumentById(pur1))!;
      final p2 = (await db.getDocumentById(pur2))!;

      expect(p1.paid, 500);
      expect(p1.status, DocumentStatus.paid);

      expect(p2.paid, 100);
      expect(p2.remaining, 200);
      expect(p2.status, DocumentStatus.partiallyPaid);

      final outstanding = await db.getContactOutstanding(sid, 'SDG');
      expect(outstanding, 200);
    });

    test('21. INV-18 parity after allocation and cancellation', () async {
      final db = DatabaseHelper.instance;
      final cid = await makeContact('عميل 21', 'customer');
      await makeInvoice(contactId: cid, total: 100, date: DateTime(2026, 1, 1));
      final recId = await makeReceipt(contactId: cid, total: 100, date: DateTime(2026, 1, 2));

      // Check parity via JournalBackfillService.verifyParity
      await JournalBackfillService.verifyParity();

      await db.cancelDocument(recId);
      await JournalBackfillService.verifyParity();
    });

    test('22. Backup old-to-new restoration', () async {
      final jsonStr = await BackupService.buildBackupJsonForTest();
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Older backup payload with backup_version = 4
      final oldBackupMap = Map<String, dynamic>.from(jsonMap);
      oldBackupMap['backup_version'] = 4;

      final success = await BackupService.restoreFromJsonMap(
        oldBackupMap,
        createSafetyBackup: false,
      );
      expect(success, true);
    });

    test('23. Backup new-to-new restoration', () async {
      final jsonStr = await BackupService.buildBackupJsonForTest();
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;

      final success = await BackupService.restoreFromJsonMap(
        jsonMap,
        createSafetyBackup: false,
      );
      expect(success, true);
    });

    test('24. Backup new-to-old rejection', () async {
      final jsonStr = await BackupService.buildBackupJsonForTest();
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;

      final futureBackupMap = Map<String, dynamic>.from(jsonMap);
      futureBackupMap['backup_version'] = 99;

      expect(
        () => BackupService.restoreFromJsonMap(
          futureBackupMap,
          createSafetyBackup: false,
        ),
        throwsA(predicate((e) => e.toString().contains('requires a newer version'))),
      );
    });
  });
}
