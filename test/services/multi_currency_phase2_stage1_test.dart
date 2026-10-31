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
import 'package:warqatek/services/business_reporting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('multi_currency_stage1_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر اختبار المرحلة 2',
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
    await rawDb.delete('document_payments');
    await rawDb.delete('document_items');
    await rawDb.delete('documents');
    await rawDb.delete('contacts');
    await rawDb.delete('products');
  });

  group('Finding 5 Phase 2 Stage 1: DatabaseHelper.getPeriodSummary', () {
    test('1. getPeriodSummary segregates currencies, excludes cancellations, and avoids nominal addition', () async {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));
      final to = now.add(const Duration(days: 1));

      // 1. Invoices
      // SDG issued invoice: total 100,000, paid 60,000, remaining 40,000
      final invSdgId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-SDG-01',
        'date': now.toIso8601String(),
        'total': 100000.0,
        'paid': 60000.0,
        'remaining': 40000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });
      // USD issued invoice: total 500, paid 300, remaining 200
      final invUsdId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-USD-01',
        'date': now.toIso8601String(),
        'total': 500.0,
        'paid': 300.0,
        'remaining': 200.0,
        'status': DocumentStatus.issued,
        'currency_code': 'USD',
      });
      // Cancelled SDG invoice: total 50,000 (must be excluded from sales & receivables)
      final invCancelledId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-CANCELLED',
        'date': now.toIso8601String(),
        'total': 50000.0,
        'paid': 50000.0,
        'remaining': 0.0,
        'status': DocumentStatus.cancelled,
        'currency_code': 'SDG',
      });

      // 2. Purchases
      // SDG purchase: total 40,000, paid 30,000, remaining 10,000
      final purSdgId = await rawDb.insert('documents', {
        'type': 'purchase',
        'document_number': 'PUR-SDG-01',
        'date': now.toIso8601String(),
        'total': 40000.0,
        'paid': 30000.0,
        'remaining': 10000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });
      // EUR purchase: total 200, paid 150, remaining 50
      final purEurId = await rawDb.insert('documents', {
        'type': 'purchase',
        'document_number': 'PUR-EUR-01',
        'date': now.toIso8601String(),
        'total': 200.0,
        'paid': 150.0,
        'remaining': 50.0,
        'status': DocumentStatus.issued,
        'currency_code': 'EUR',
      });
      // Cancelled USD purchase: total 100 (must be excluded)
      final purCancelledId = await rawDb.insert('documents', {
        'type': 'purchase',
        'document_number': 'PUR-CANCELLED',
        'date': now.toIso8601String(),
        'total': 100.0,
        'paid': 100.0,
        'remaining': 0.0,
        'status': DocumentStatus.cancelled,
        'currency_code': 'USD',
      });

      // 3. Document Payments (Payments in & out)
      await rawDb.insert('document_payments', {
        'document_id': invSdgId,
        'amount': 60000.0,
        'payment_method': 'cash',
        'date': now.toIso8601String(),
      });
      await rawDb.insert('document_payments', {
        'document_id': invUsdId,
        'amount': 300.0,
        'payment_method': 'bank_transfer',
        'date': now.toIso8601String(),
      });
      // Payment linked to cancelled invoice (must be excluded)
      await rawDb.insert('document_payments', {
        'document_id': invCancelledId,
        'amount': 50000.0,
        'payment_method': 'cash',
        'date': now.toIso8601String(),
      });
      await rawDb.insert('document_payments', {
        'document_id': purSdgId,
        'amount': 30000.0,
        'payment_method': 'cash',
        'date': now.toIso8601String(),
      });
      await rawDb.insert('document_payments', {
        'document_id': purEurId,
        'amount': 150.0,
        'payment_method': 'card',
        'date': now.toIso8601String(),
      });
      // Payment linked to cancelled purchase (must be excluded)
      await rawDb.insert('document_payments', {
        'document_id': purCancelledId,
        'amount': 100.0,
        'payment_method': 'cash',
        'date': now.toIso8601String(),
      });

      // Part A: Explicit currency filter (SDG)
      final sdgSummary = await db.getPeriodSummary(from: from, to: to, currencyCode: 'SDG');
      expect(sdgSummary['sales'], 100000.0);
      expect(sdgSummary['purchases'], 40000.0);
      expect(sdgSummary['paymentsIn'], 60000.0);
      expect(sdgSummary['paymentsOut'], 30000.0);
      expect(sdgSummary['customerOutstanding'], 40000.0);
      expect(sdgSummary['supplierPayable'], 10000.0);
      expect(sdgSummary['hasMultipleCurrencies'], isTrue);

      // Verify foreign currencies are NOT silently erased from totalsByCurrency
      final byCur = sdgSummary['totalsByCurrency'] as Map<String, dynamic>;
      expect(byCur.containsKey('SDG'), isTrue);
      expect(byCur.containsKey('USD'), isTrue);
      expect(byCur.containsKey('EUR'), isTrue);

      final usdTotals = byCur['USD'];
      expect(usdTotals.sales, 500.0);
      expect(usdTotals.paymentsIn, 300.0);
      expect(usdTotals.customerOutstanding, 200.0);

      final eurTotals = byCur['EUR'];
      expect(eurTotals.purchases, 200.0);
      expect(eurTotals.paymentsOut, 150.0);
      expect(eurTotals.supplierPayable, 50.0);

      // Part B: Unfiltered call with multiple currencies
      final unfilteredSummary = await db.getPeriodSummary(from: from, to: to);
      expect(unfilteredSummary['hasMultipleCurrencies'], isTrue);
      // Scalar fields MUST NOT combine 100,000 SDG with 500 USD nominally!
      expect(unfilteredSummary['sales'], 0.0);
      expect(unfilteredSummary['purchases'], 0.0);
      expect(unfilteredSummary['paymentsIn'], 0.0);
      expect(unfilteredSummary['paymentsOut'], 0.0);
      expect(unfilteredSummary['customerOutstanding'], 0.0);
      expect(unfilteredSummary['supplierPayable'], 0.0);
    });
  });

  group('Finding 5 Phase 2 Stage 1: DatabaseHelper.getContactBalances', () {
    test('2. getContactBalances isolates debts per currency and never sums cross-currency nominal amounts', () async {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;
      final now = DateTime.now();

      final custId1 = await db.insertContact(
        const Contact(name: 'عميل العملات المتعددة', phone: '0911111111', type: 'customer'),
      );
      final custId2 = await db.insertContact(
        const Contact(name: 'عميل أجنبي', phone: '0922222222', type: 'customer'),
      );

      // Customer 1 has SDG invoice
      await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-C1-SDG',
        'date': now.toIso8601String(),
        'contact_id': custId1,
        'total': 50000.0,
        'paid': 20000.0,
        'remaining': 30000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });
      // Customer 1 ALSO has USD invoice
      await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-C1-USD',
        'date': now.toIso8601String(),
        'contact_id': custId1,
        'total': 200.0,
        'paid': 50.0,
        'remaining': 150.0,
        'status': DocumentStatus.issued,
        'currency_code': 'USD',
      });
      // Customer 1 has cancelled invoice (must be excluded)
      await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-C1-CANCELLED',
        'date': now.toIso8601String(),
        'contact_id': custId1,
        'total': 10000.0,
        'paid': 0.0,
        'remaining': 10000.0,
        'status': DocumentStatus.cancelled,
        'currency_code': 'SDG',
      });

      // Customer 2 has EUR invoice
      await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-C2-EUR',
        'date': now.toIso8601String(),
        'contact_id': custId2,
        'total': 100.0,
        'paid': 100.0,
        'remaining': 0.0,
        'status': DocumentStatus.issued,
        'currency_code': 'EUR',
      });

      // Filtered to SDG:
      final sdgRows = await db.getContactBalances('customer', 'invoice', currencyCode: 'SDG');
      final c1Sdg = sdgRows.firstWhere((r) => r['contact_id'] == custId1);
      expect(c1Sdg['total_amount'], 50000.0);
      expect(c1Sdg['total_paid'], 20000.0);
      expect(c1Sdg['outstanding'], 30000.0);
      expect(c1Sdg['doc_count'], 1);
      expect(c1Sdg['currency_code'], 'SDG');

      final c2Sdg = sdgRows.firstWhere((r) => r['contact_id'] == custId2);
      expect(c2Sdg['total_amount'], 0.0);
      expect(c2Sdg['outstanding'], 0.0);
      expect(c2Sdg['doc_count'], 0);

      // Unfiltered: MUST group by (contact, currency) and NEVER merge 30,000 SDG with 150 USD into 30,150!
      final allRows = await db.getContactBalances('customer', 'invoice');
      final c1Entries = allRows.where((r) => r['contact_id'] == custId1).toList();
      expect(c1Entries.length, 2, reason: 'Customer 1 must have 2 distinct currency balance rows');

      final c1SdgRow = c1Entries.firstWhere((r) => r['currency_code'] == 'SDG');
      expect(c1SdgRow['total_amount'], 50000.0);
      expect(c1SdgRow['outstanding'], 30000.0);

      final c1UsdRow = c1Entries.firstWhere((r) => r['currency_code'] == 'USD');
      expect(c1UsdRow['total_amount'], 200.0);
      expect(c1UsdRow['outstanding'], 150.0);

      // Nominal cross-currency sum must not occur
      expect(c1SdgRow['outstanding'] + c1UsdRow['outstanding'], isNot(equals(30000.0)));
    });
  });

  group('Finding 5 Phase 2 Stage 1: BusinessReportingService.getProductPerformance', () {
    test('3. getProductPerformance maintains currency consistency for revenue and COGS, never subtracting across currencies', () async {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));
      final to = now.add(const Duration(days: 1));

      // Product 1: Base SDG inventory
      final pid1 = await db.insertProduct(
        const Product(
          name: 'منتج محلي ودولي',
          salePrice: 150.0,
          stockQuantity: 10,
          purchasePrice: 100.0,
          averageCost: 100.0,
          costStatus: Product.costStatusKnown,
          type: 'product',
        ),
      );

      // Product 2: Base SDG inventory, sold in foreign currency
      final pid2 = await db.insertProduct(
        const Product(
          name: 'منتج تصدير',
          salePrice: 20.0,
          stockQuantity: 20,
          purchasePrice: 50.0,
          averageCost: 50.0,
          costStatus: Product.costStatusKnown,
          type: 'product',
        ),
      );

      // Invoice 1 (SDG): 2 units of Product 1 @ 150 SDG each
      final invSdgId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-P-SDG',
        'date': now.toIso8601String(),
        'subtotal': 300.0,
        'discount': 0.0,
        'total': 300.0,
        'paid': 300.0,
        'remaining': 0.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });
      await rawDb.insert('document_items', {
        'document_id': invSdgId,
        'product_id': pid1,
        'description': 'منتج 1',
        'quantity': 2.0,
        'price': 150.0,
        'total': 300.0,
        'unit_cost': 100.0,
        'total_cost': 200.0,
      });

      // Invoice 2 (USD): 1 unit of Product 1 @ 10 USD
      // Note: total_cost in DB is recorded in base currency (100.0 SDG)
      final invUsdId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-P-USD',
        'date': now.toIso8601String(),
        'subtotal': 10.0,
        'discount': 0.0,
        'total': 10.0,
        'paid': 10.0,
        'remaining': 0.0,
        'status': DocumentStatus.issued,
        'currency_code': 'USD',
      });
      await rawDb.insert('document_items', {
        'document_id': invUsdId,
        'product_id': pid1,
        'description': 'منتج 1 دولار',
        'quantity': 1.0,
        'price': 10.0,
        'total': 10.0,
        'unit_cost': 100.0,
        'total_cost': 100.0, // In base currency! Must NOT be subtracted from USD!
      });

      // Invoice 3 (USD): 5 units of Product 2 @ 20 USD = 100 USD
      final invUsdId2 = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-P2-USD',
        'date': now.toIso8601String(),
        'subtotal': 100.0,
        'discount': 0.0,
        'total': 100.0,
        'paid': 100.0,
        'remaining': 0.0,
        'status': DocumentStatus.issued,
        'currency_code': 'USD',
      });
      await rawDb.insert('document_items', {
        'document_id': invUsdId2,
        'product_id': pid2,
        'description': 'منتج 2 دولار',
        'quantity': 5.0,
        'price': 20.0,
        'total': 100.0,
        'unit_cost': 50.0,
        'total_cost': 250.0,
      });

      // Invoice 4 (Cancelled in SDG): 3 units of Product 1 (MUST be excluded)
      final invCancelledId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-CANCELLED',
        'date': now.toIso8601String(),
        'subtotal': 450.0,
        'discount': 0.0,
        'total': 450.0,
        'paid': 450.0,
        'remaining': 0.0,
        'status': DocumentStatus.cancelled,
        'currency_code': 'SDG',
      });
      await rawDb.insert('document_items', {
        'document_id': invCancelledId,
        'product_id': pid1,
        'description': 'منتج 1 ملغي',
        'quantity': 3.0,
        'price': 150.0,
        'total': 450.0,
        'unit_cost': 100.0,
        'total_cost': 300.0,
      });

      // Part A: Explicit SDG filter
      final sdgSummary = await BusinessReportingService.instance.getProductPerformance(
        from: from,
        to: to,
        currencyCode: 'SDG',
      );
      expect(sdgSummary.totalSalesRevenue, 300.0);
      expect(sdgSummary.totalCogs, 200.0);
      expect(sdgSummary.totalGrossProfit, 100.0);
      expect(sdgSummary.totalTrustedGrossProfit, 100.0);

      final p1Sdg = sdgSummary.items.firstWhere((i) => i.productId == pid1);
      expect(p1Sdg.salesQty, 2.0);
      expect(p1Sdg.salesRevenue, 300.0);
      expect(p1Sdg.cogs, 200.0);
      expect(p1Sdg.grossProfit, 100.0);
      expect(p1Sdg.isCostReliable, isTrue);

      final p2Sdg = sdgSummary.items.firstWhere((i) => i.productId == pid2);
      expect(p2Sdg.salesQty, 0.0);
      expect(p2Sdg.salesRevenue, 0.0);

      // Part B: Unfiltered multi-currency summary
      final allSummary = await BusinessReportingService.instance.getProductPerformance(
        from: from,
        to: to,
      );
      expect(allSummary.hasMultipleCurrencies, isTrue);
      // Scalars MUST NOT nominally sum 300 SDG + 110 USD into 410!
      expect(allSummary.totalSalesRevenue, 0.0);
      expect(allSummary.totalCogs, 0.0);

      // Verify segregated breakdown in totalsByCurrency
      final sdgTotals = allSummary.totalsByCurrency['SDG']!;
      expect(sdgTotals.revenue, 300.0);
      expect(sdgTotals.cogs, 200.0);
      expect(sdgTotals.grossProfit, 100.0);
      expect(sdgTotals.trustedProfit, 100.0);
      expect(sdgTotals.hasIncompleteCost, isFalse);

      final usdTotals = allSummary.totalsByCurrency['USD']!;
      expect(usdTotals.revenue, 110.0); // 10 + 100
      // Base-currency COGS was NOT subtracted from USD revenue!
      expect(usdTotals.cogs, 0.0);
      expect(usdTotals.hasIncompleteCost, isTrue);
      expect(usdTotals.trustedProfit, 0.0);

      // Verify Product 1 has segregated salesByCurrency
      final p1All = allSummary.items.firstWhere((i) => i.productId == pid1);
      expect(p1All.salesQty, 3.0); // 2 SDG + 1 USD
      expect(p1All.salesByCurrency.containsKey('SDG'), isTrue);
      expect(p1All.salesByCurrency.containsKey('USD'), isTrue);
      expect(p1All.salesByCurrency['SDG']!.revenue, 300.0);
      expect(p1All.salesByCurrency['SDG']!.cogs, 200.0);
      expect(p1All.salesByCurrency['USD']!.revenue, 10.0);
      expect(p1All.salesByCurrency['USD']!.cogs, 0.0);
    });
  });
}
