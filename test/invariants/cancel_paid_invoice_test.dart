import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/backup_service.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;
  late Business business;
  late Contact customer;
  late Contact supplier;
  late Product product;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('cancel_paid_invoice_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    db = DatabaseHelper.instance;
  });

  tearDownAll(() async {
    try {
      await db.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await db.closeDatabase();
    final file = File('${tempDir.path}/warqatek.db');
    if (file.existsSync()) file.deleteSync();

    await db.insertBusiness(
      const Business(
        name: 'متجر تجريبي',
        ownerName: 'المدير',
        phone: '0123456789',
        address: 'الخرطوم',
        currencyCode: 'SDG',
        wholesalePricingEnabled: false,
      ),
    );
    business = (await db.getFirstBusiness())!;

    final cId = await db.insertContact(
      const Contact(name: 'العميل محمد', phone: '0912345678', type: 'customer'),
    );
    customer = (await db.getContactById(cId))!;

    final sId = await db.insertContact(
      const Contact(name: 'المورد أحمد', phone: '0999999999', type: 'supplier'),
    );
    supplier = (await db.getContactById(sId))!;

    final pId = await db.insertProduct(
      const Product(
        name: 'سلعة تجريبية',
        unit: 'قطعة',
        salePrice: 100.0,
        purchasePrice: 60.0,
        stockQuantity: 50.0,
        minStock: 5.0,
      ),
    );
    product = (await db.getProductById(pId))!;
  });

  test('1. Cancel unpaid invoice: behavior unchanged, no refund audit entry', () async {
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      contact: customer,
      items: [
        DocumentItemInput(
          description: product.name,
          productId: product.id,
          quantity: 2,
          price: 100.0,
        ),
      ],
      paid: 0.0,
      date: DateTime.now(),
    );

    // Initial check: stock deducted to 48
    var p = (await db.getProductById(product.id!))!;
    expect(p.stockQuantity, 48.0);

    // Cancel unpaid invoice
    await DocumentService.cancelDocument(invId);

    // Stock reverted back to 50
    p = (await db.getProductById(product.id!))!;
    expect(p.stockQuantity, 50.0);

    final cancelledDoc = (await db.getDocumentById(invId))!;
    expect(cancelledDoc.status, DocumentStatus.cancelled);

    // No refund status entry should exist
    final refundStatus = await DocumentService.getLatestDocumentRefundStatus(invId);
    expect(refundStatus, isNull);
  });

  test('2. Cancel with upfront payment: audit entry written with chosen status', () async {
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      contact: customer,
      items: [
        DocumentItemInput(
          description: product.name,
          productId: product.id,
          quantity: 1,
          price: 100.0,
        ),
      ],
      paid: 100.0,
      date: DateTime.now(),
    );

    // Cancel with refundStatus = 'refunded'
    await DocumentService.cancelDocument(
      invId,
      refundStatus: 'refunded',
      refundNotes: 'Returned in cash',
    );

    final doc = (await db.getDocumentById(invId))!;
    expect(doc.status, DocumentStatus.cancelled);

    final refundStatus = await DocumentService.getLatestDocumentRefundStatus(invId);
    expect(refundStatus, isNotNull);
    expect(refundStatus!['status'], 'refunded');
    expect(refundStatus['amount'], 100.0);
    expect(refundStatus['currency'], 'SDG');
    expect(refundStatus['notes'], 'Returned in cash');
    expect(refundStatus['timestamp'], isNotNull);
  });

  test('3. Later status change: latest entry wins', () async {
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      contact: customer,
      items: [
        DocumentItemInput(
          description: product.name,
          productId: product.id,
          quantity: 1,
          price: 100.0,
        ),
      ],
      paid: 100.0,
      date: DateTime.now(),
    );

    // Cancel initially marked as 'unrefunded'
    await DocumentService.cancelDocument(
      invId,
      refundStatus: 'unrefunded',
    );

    var latest = await DocumentService.getLatestDocumentRefundStatus(invId);
    expect(latest!['status'], 'unrefunded');

    // Update later to 'refunded'
    await DocumentService.updateDocumentRefundStatus(
      documentId: invId,
      status: 'refunded',
      notes: 'Customer collected cash later',
    );

    latest = await DocumentService.getLatestDocumentRefundStatus(invId);
    expect(latest!['status'], 'refunded');
    expect(latest['notes'], 'Customer collected cash later');
  });

  test('4. Report totals remain identical and strictly exclude cancelled documents', () async {
    final from = DateTime.now().subtract(const Duration(days: 1));
    final to = DateTime.now().add(const Duration(days: 1));

    // Baseline: 0 sales, 0 payments
    var summary = await db.getPeriodSummary(from: from, to: to);
    expect(summary['sales'], 0.0);
    expect(summary['paymentsIn'], 0.0);

    // Create paid invoice
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      contact: customer,
      items: [
        DocumentItemInput(
          description: product.name,
          productId: product.id,
          quantity: 1,
          price: 100.0,
        ),
      ],
      paid: 100.0,
      date: DateTime.now(),
    );

    // While issued: 100 sales, 100 payments
    summary = await db.getPeriodSummary(from: from, to: to);
    expect(summary['sales'], 100.0);
    expect(summary['paymentsIn'], 100.0);

    // Cancel with refund status
    await DocumentService.cancelDocument(
      invId,
      refundStatus: 'refunded',
    );

    // After cancellation: back to 0.0 sales and 0.0 payments in reports!
    summary = await db.getPeriodSummary(from: from, to: to);
    expect(summary['sales'], 0.0);
    expect(summary['paymentsIn'], 0.0);

    // Payments report also excludes the cancelled invoice payment
    final paymentReport = await db.getPaymentReport(from: from, to: to);
    expect(paymentReport, isEmpty);
  });

  test('5. Cancel still blocked when active receipt vouchers exist', () async {
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      contact: customer,
      items: [
        DocumentItemInput(
          description: product.name,
          productId: product.id,
          quantity: 1,
          price: 100.0,
        ),
      ],
      paid: 0.0,
      date: DateTime.now(),
    );

    // Record later payment via receipt voucher
    await db.recordPayment(
      documentId: invId,
      amount: 50.0,
      paymentMethod: 'cash',
    );

    // Attempting to cancel parent invoice must throw StateError
    expect(
      () => db.cancelDocument(invId),
      throwsA(isA<StateError>()),
    );
  });

  test('6. Old cancelled document without an audit entry shows neutral state', () async {
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      contact: customer,
      items: [
        DocumentItemInput(
          description: product.name,
          productId: product.id,
          quantity: 1,
          price: 100.0,
        ),
      ],
      paid: 100.0,
      date: DateTime.now(),
    );

    // Cancel without refundStatus (simulating pre-release behavior)
    await db.cancelDocument(invId);

    final status = await DocumentService.getLatestDocumentRefundStatus(invId);
    expect(status, isNull);
  });

  test('7. Audit entries survive backup and restore', () async {
    final invId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      contact: customer,
      items: [
        DocumentItemInput(
          description: product.name,
          productId: product.id,
          quantity: 1,
          price: 100.0,
        ),
      ],
      paid: 100.0,
      date: DateTime.now(),
    );

    await DocumentService.cancelDocument(
      invId,
      refundStatus: 'refunded',
      refundNotes: 'Preserved across backup',
    );

    // Prepare a backup payload with the database state including audit_log
    final rawAudit = await (await db.database).query('audit_log');
    expect(rawAudit.any((e) => e['action'] == 'document_refund_status'), isTrue);

    final backupPayload = {
      'app': 'warqatek',
      'backup_version': 3,
      'database_version': DatabaseHelper.dbVersion,
      'created_at': DateTime.now().toIso8601String(),
      'data': {
        'businesses': await (await db.database).query('businesses'),
        'contacts': await (await db.database).query('contacts'),
        'products': await (await db.database).query('products'),
        'product_units': await (await db.database).query('product_units'),
        'documents': await (await db.database).query('documents'),
        'document_items': await (await db.database).query('document_items'),
        'document_counters': await (await db.database).query('document_counters'),
        'document_payments': await (await db.database).query('document_payments'),
        'stock_movements': await (await db.database).query('stock_movements'),
        'tax_profiles': await (await db.database).query('tax_profiles'),
        'payment_methods': await (await db.database).query('payment_methods'),
        'stocktake_sessions': await (await db.database).query('stocktake_sessions'),
        'stocktake_items': await (await db.database).query('stocktake_items'),
        'audit_log': rawAudit,
      },
    };

    // Reopen and restore backup
    final restoreSuccess = await BackupService.restoreFromJsonMap(backupPayload);
    expect(restoreSuccess, isTrue);

    // Check recovered refund status
    final restoredStatus = await DocumentService.getLatestDocumentRefundStatus(invId);
    expect(restoredStatus, isNotNull);
    expect(restoredStatus!['status'], 'refunded');
    expect(restoredStatus['amount'], 100.0);
    expect(restoredStatus['notes'], 'Preserved across backup');
  });

  test('8. Cancel purchase with upfront payment: audit entry recorded', () async {
    final purchaseId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      contact: supplier,
      items: [
        DocumentItemInput(
          description: product.name,
          productId: product.id,
          quantity: 2,
          price: 60.0,
        ),
      ],
      paid: 120.0,
      date: DateTime.now(),
    );

    await DocumentService.cancelDocument(
      purchaseId,
      refundStatus: 'refunded',
      refundNotes: 'Supplier returned cash to shop',
    );

    final status = await DocumentService.getLatestDocumentRefundStatus(purchaseId);
    expect(status, isNotNull);
    expect(status!['status'], 'refunded');
    expect(status['amount'], 120.0);
    expect(status['notes'], 'Supplier returned cash to shop');
  });
}
