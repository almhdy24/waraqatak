import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/screens/customer_detail_screen.dart';
import 'package:warqatek/screens/reports/customer_report_screen.dart';
import 'package:warqatek/screens/reports/sales_report_screen.dart';
import 'package:warqatek/screens/reports/supplier_report_screen.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/inventory_costing_service.dart';
import 'package:warqatek/widgets/app_amount_text.dart';

Widget _buildTestApp({String langCode = 'ar', required Widget child}) {
  return LanguageProvider(
    langCode: langCode,
    onChangeLanguage: (_) async {},
    child: MaterialApp(
      locale: Locale(langCode),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final numFmt = NumberFormat('#,##0.00', 'en_US');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('multi_currency_phase1_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر اختبار العملات',
        ownerName: 'المالك',
        phone: '0123456789',
        address: 'الخرطوم',
        taxRate: 0,
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

  setUp(() async {
    final rawDb = await DatabaseHelper.instance.database;
    await rawDb.delete('documents');
    await rawDb.delete('contacts');
  });

  group('Finding 5 Phase 1 - Customer & Supplier PDF Production Row Building', () {
    test('1. Customer: real getContactBalances result schema matches CustomerReportScreen PDF row extraction and 5-column alignment', () async {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      // Insert customer
      final customerId = await db.insertContact(
        const Contact(
          name: 'محمد أحمد',
          phone: '0912345678',
          type: 'customer',
        ),
      );

      // Insert issued invoice for customer
      await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-CUST-001',
        'date': DateTime.now().toIso8601String(),
        'contact_id': customerId,
        'recipient_name': 'محمد أحمد',
        'recipient_phone': '0912345678',
        'subtotal': 1500.50,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 1500.50,
        'paid': 1000.00,
        'remaining': 500.50,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      // Execute real production query
      final rows = await db.getContactBalances(
        'customer',
        'invoice',
        currencyCode: 'SDG',
      );

      expect(rows, isNotEmpty);
      final customerRow = rows.firstWhere((r) => r['contact_id'] == customerId);

      // Verify real query schema keys
      expect(customerRow.containsKey('contact_id'), isTrue);
      expect(customerRow.containsKey('name'), isTrue);
      expect(customerRow.containsKey('phone'), isTrue);
      expect(customerRow.containsKey('total_amount'), isTrue);
      expect(customerRow.containsKey('total_paid'), isTrue);
      expect(customerRow.containsKey('outstanding'), isTrue);
      expect(customerRow.containsKey('doc_count'), isTrue);

      // Verify production row extraction
      final pdfRow = CustomerReportScreen.buildPdfRow(customerRow, numFmt);
      expect(pdfRow.length, 5, reason: 'Must match the 5 columns of CustomerReportScreen');
      expect(pdfRow[0], 'محمد أحمد');
      expect(pdfRow[1], '0912345678');
      expect(pdfRow[2], '1,500.50'); // total_amount
      expect(pdfRow[3], '1,000.00'); // total_paid
      expect(pdfRow[4], '500.50');   // outstanding

      // Verify production totalsRow alignment
      final totalsRow = CustomerReportScreen.buildTotalsRow(
        totalAmount: (customerRow['total_amount'] as num).toDouble(),
        totalPaid: (customerRow['total_paid'] as num).toDouble(),
        totalOutstanding: (customerRow['outstanding'] as num).toDouble(),
        totalLabel: 'الإجمالي',
        numFmt: numFmt,
      );
      expect(totalsRow.length, 5);
      expect(totalsRow[0], 'الإجمالي');
      expect(totalsRow[1], '');
      expect(totalsRow[2], '1,500.50');
      expect(totalsRow[3], '1,000.00');
      expect(totalsRow[4], '500.50');
    });

    test('2. Supplier: real getContactBalances result schema matches SupplierReportScreen PDF row extraction and 5-column alignment', () async {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      // Insert supplier
      final supplierId = await db.insertContact(
        const Contact(
          name: 'شركة النيل للتوريدات',
          phone: '0112233445',
          type: 'supplier',
        ),
      );

      // Insert issued purchase for supplier
      await rawDb.insert('documents', {
        'type': 'purchase',
        'document_number': 'PUR-SUP-001',
        'date': DateTime.now().toIso8601String(),
        'contact_id': supplierId,
        'recipient_name': 'شركة النيل للتوريدات',
        'recipient_phone': '0112233445',
        'subtotal': 25000.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 25000.0,
        'paid': 20000.0,
        'remaining': 5000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      // Execute real production query
      final rows = await db.getContactBalances(
        'supplier',
        'purchase',
        currencyCode: 'SDG',
      );

      expect(rows, isNotEmpty);
      final supplierRow = rows.firstWhere((r) => r['contact_id'] == supplierId);

      // Verify production row extraction
      final pdfRow = SupplierReportScreen.buildPdfRow(supplierRow, numFmt);
      expect(pdfRow.length, 5, reason: 'Must match the 5 columns of SupplierReportScreen');
      expect(pdfRow[0], 'شركة النيل للتوريدات');
      expect(pdfRow[1], '0112233445');
      expect(pdfRow[2], '25,000.00'); // total_amount
      expect(pdfRow[3], '20,000.00'); // total_paid
      expect(pdfRow[4], '5,000.00');  // outstanding

      // Verify production totalsRow alignment
      final totalsRow = SupplierReportScreen.buildTotalsRow(
        totalAmount: (supplierRow['total_amount'] as num).toDouble(),
        totalPaid: (supplierRow['total_paid'] as num).toDouble(),
        totalPayable: (supplierRow['outstanding'] as num).toDouble(),
        totalLabel: 'الإجمالي',
        numFmt: numFmt,
      );
      expect(totalsRow.length, 5);
      expect(totalsRow[0], 'الإجمالي');
      expect(totalsRow[1], '');
      expect(totalsRow[2], '25,000.00');
      expect(totalsRow[3], '20,000.00');
      expect(totalsRow[4], '5,000.00');
    });
  });

  group('Finding 5 Phase 1 - BusinessReportingService.getPurchasesReport Multi-Currency', () {
    test('3. getPurchasesReport correctly segregates totalsByCurrency with SQLite fixtures and excludes cancelled purchases', () async {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      final now = DateTime.now();

      // Purchase 1: SDG (issued)
      await rawDb.insert('documents', {
        'type': 'purchase',
        'document_number': 'PUR-MULTI-01',
        'date': now.toIso8601String(),
        'subtotal': 200000.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 200000.0,
        'paid': 150000.0,
        'remaining': 50000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      // Purchase 2: USD (issued)
      await rawDb.insert('documents', {
        'type': 'purchase',
        'document_number': 'PUR-MULTI-02',
        'date': now.toIso8601String(),
        'subtotal': 500.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 500.0,
        'paid': 200.0,
        'remaining': 300.0,
        'status': DocumentStatus.issued,
        'currency_code': 'USD',
      });

      // Purchase 3: EUR (cancelled - must be excluded from totalsByCurrency)
      await rawDb.insert('documents', {
        'type': 'purchase',
        'document_number': 'PUR-MULTI-03',
        'date': now.toIso8601String(),
        'subtotal': 150.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 150.0,
        'paid': 150.0,
        'remaining': 0.0,
        'status': DocumentStatus.cancelled,
        'currency_code': 'EUR',
      });

      // Execute production service
      final from = now.subtract(const Duration(days: 1));
      final to = now.add(const Duration(days: 1));
      final summary = await BusinessReportingService.instance.getPurchasesReport(
        from: from,
        to: to,
      );

      // Verify currency set contains all document currencies
      expect(summary.currencies.contains('SDG'), isTrue);
      expect(summary.currencies.contains('USD'), isTrue);
      expect(summary.currencies.contains('EUR'), isTrue);

      // Verify segregated totals in totalsByCurrency
      final sdgTotals = summary.totalsByCurrency['SDG'];
      expect(sdgTotals, isNotNull);
      expect(sdgTotals!.purchases, 200000.0);
      expect(sdgTotals.paid, 150000.0);
      expect(sdgTotals.remaining, 50000.0);

      final usdTotals = summary.totalsByCurrency['USD'];
      expect(usdTotals, isNotNull);
      expect(usdTotals!.purchases, 500.0);
      expect(usdTotals.paid, 200.0);
      expect(usdTotals.remaining, 300.0);

      // Cancelled EUR purchase must be excluded from totalsByCurrency:
      expect(summary.totalsByCurrency.containsKey('EUR'), isFalse);
      expect(summary.cancelledCount, 1);

      // Verify that nominal cross-currency addition was prevented in totalsByCurrency
      expect(sdgTotals.purchases, 200000.0);
      expect(usdTotals.purchases, 500.0);
      expect(sdgTotals.purchases, isNot(equals(summary.totalPurchases)));
    });
  });

  group('Finding 5 Phase 1 - SalesReportScreen.aggregateByCurrency Production Helper', () {
    test('4. aggregateByCurrency groups COGS and trusted profit per currency and isolates incomplete cost flag', () {
      final docSdg = Document(
        id: 501,
        type: 'invoice',
        status: DocumentStatus.issued,
        documentNumber: 'INV-SALE-01',
        date: DateTime(2026, 10, 1),
        currencyCode: 'SDG',
        subtotal: 500000,
        discount: 0,
        taxRate: 0,
        taxAmount: 0,
        total: 500000,
        paid: 300000,
        remaining: 200000,
      );
      final itemSdg = SaleProfitSummary(
        document: docSdg,
        recognizedRevenue: 500000,
        cogs: 350000,
        grossProfit: 150000,
        profitMargin: 30.0,
        isCostReliable: true,
      );

      final docUsdReliable = Document(
        id: 502,
        type: 'invoice',
        status: DocumentStatus.issued,
        documentNumber: 'INV-SALE-02',
        date: DateTime(2026, 10, 2),
        currencyCode: 'USD',
        subtotal: 1000,
        discount: 0,
        taxRate: 0,
        taxAmount: 0,
        total: 1000,
        paid: 1000,
        remaining: 0,
      );
      final itemUsdReliable = SaleProfitSummary(
        document: docUsdReliable,
        recognizedRevenue: 1000,
        cogs: 600,
        grossProfit: 400,
        profitMargin: 40.0,
        isCostReliable: true,
      );

      final docUsdUnreliable = Document(
        id: 503,
        type: 'invoice',
        status: DocumentStatus.issued,
        documentNumber: 'INV-SALE-03',
        date: DateTime(2026, 10, 3),
        currencyCode: 'USD',
        subtotal: 50,
        discount: 0,
        taxRate: 0,
        taxAmount: 0,
        total: 50,
        paid: 50,
        remaining: 0,
      );
      final itemUsdUnreliable = SaleProfitSummary(
        document: docUsdUnreliable,
        recognizedRevenue: 50,
        cogs: 0,
        grossProfit: 50,
        profitMargin: 100.0,
        isCostReliable: false, // Unknown cost
      );

      final docCancelled = Document(
        id: 504,
        type: 'invoice',
        status: DocumentStatus.cancelled,
        documentNumber: 'INV-SALE-04',
        date: DateTime(2026, 10, 4),
        currencyCode: 'EUR',
        subtotal: 200,
        discount: 0,
        taxRate: 0,
        taxAmount: 0,
        total: 200,
        paid: 200,
        remaining: 0,
      );
      final itemCancelled = SaleProfitSummary(
        document: docCancelled,
        recognizedRevenue: 200,
        cogs: 120,
        grossProfit: 80,
        profitMargin: 40.0,
        isCostReliable: true,
      );

      // Execute production method
      final result = SalesReportScreen.aggregateByCurrency([
        itemSdg,
        itemUsdReliable,
        itemUsdUnreliable,
        itemCancelled,
      ]);

      // Cancelled EUR document must be excluded
      expect(result.containsKey('EUR'), isFalse);

      // SDG: reliable cost
      final sdg = result['SDG']!;
      expect(sdg.sales, 500000.0);
      expect(sdg.cogs, 350000.0);
      expect(sdg.trustedProfit, 150000.0);
      expect(sdg.paid, 300000.0);
      expect(sdg.remaining, 200000.0);
      expect(sdg.hasIncompleteCost, isFalse);

      // USD: contains 1 reliable and 1 unreliable invoice
      final usd = result['USD']!;
      expect(usd.sales, 1050.0);
      expect(usd.cogs, 600.0);
      // Unreliable invoice contributes 0.0 to trustedProfit:
      expect(usd.trustedProfit, 400.0);
      expect(usd.paid, 1050.0);
      expect(usd.remaining, 0.0);
      // Flagged as incomplete cost because of itemUsdUnreliable:
      expect(usd.hasIncompleteCost, isTrue);

      // Neither SDG nor USD had their COGS nominally combined
      expect(sdg.cogs, isNot(equals(350600.0)));
    });
  });

  group('Finding 5 Phase 1 - CustomerDetailScreen Document Tile Currency Display', () {
    testWidgets('5. CustomerDetailScreen renders each document tile with its own currency symbol in production UI', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late Contact customer;

      await tester.runAsync(() async {
        final db = DatabaseHelper.instance;
        final rawDb = await db.database;

        final customerId = await db.insertContact(
          const Contact(
            name: 'طارق عبد الله',
            phone: '0999888777',
            type: 'customer',
          ),
        );

        customer = (await db.getContactById(customerId))!;

        // Insert 3 documents with distinct currencies for this contact
        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-TILE-SDG',
          'date': DateTime.now().toIso8601String(),
          'contact_id': customerId,
          'recipient_name': 'طارق عبد الله',
          'recipient_phone': '0999888777',
          'subtotal': 50000.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 50000.0,
          'paid': 30000.0,
          'remaining': 20000.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SDG',
        });

        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-TILE-USD',
          'date': DateTime.now().toIso8601String(),
          'contact_id': customerId,
          'recipient_name': 'طارق عبد الله',
          'recipient_phone': '0999888777',
          'subtotal': 100.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 100.0,
          'paid': 100.0,
          'remaining': 0.0,
          'status': DocumentStatus.issued,
          'currency_code': 'USD',
        });

        await rawDb.insert('documents', {
          'type': 'invoice',
          'document_number': 'INV-TILE-SAR',
          'date': DateTime.now().toIso8601String(),
          'contact_id': customerId,
          'recipient_name': 'طارق عبد الله',
          'recipient_phone': '0999888777',
          'subtotal': 80.0,
          'discount': 0.0,
          'tax_rate': 0.0,
          'tax_amount': 0.0,
          'total': 80.0,
          'paid': 0.0,
          'remaining': 80.0,
          'status': DocumentStatus.issued,
          'currency_code': 'SAR',
        });
      });

      // Pump CustomerDetailScreen in Arabic test app
      await tester.pumpWidget(
        _buildTestApp(
          langCode: 'ar',
          child: CustomerDetailScreen(contact: customer),
        ),
      );

      // Run async load and pump frames to render loaded documents
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify that each document tile renders its own currency symbol and formatted amount
      // via AppAmountText with canonical fullText, semantics, and exact numeric/symbol tokens.
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.byWidgetPredicate(
            (w) => w is AppAmountText && w.fullText == '50,000 ج.س',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.bySemanticsLabel('50,000 ج.س'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('50,000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('ج.س'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.byWidgetPredicate(
            (w) => w is AppAmountText && w.fullText == '100 \$',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.bySemanticsLabel('100 \$'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('100'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('\$'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.byWidgetPredicate(
            (w) => w is AppAmountText && w.fullText == '80 ر.س',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.bySemanticsLabel('80 ر.س'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('80'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('ر.س'),
        ),
        findsOneWidget,
      );
    });
  });
}
