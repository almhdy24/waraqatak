import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/pdf/pdf_theme.dart';
import 'package:warqatek/services/pdf/pdf_totals_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('cross_layer_consistency_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر التدقيق الشامل',
        ownerName: 'المدقق',
        phone: '0123456789',
        address: 'الخرطوم',
        taxRate: 15.0,
        taxesEnabled: true,
        pricesIncludeTax: false,
        currencyCode: 'SDG',
      ),
    );
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.closeDatabase();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('Cross-layer consistency verification across all 5 architectural layers', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    // 1. Seed customer and products
    final customerId = await db.insertContact(
      const Contact(name: 'العميل الأول', phone: '0912345678', type: 'customer'),
    );
    final contact = (await db.getContactById(customerId))!;

    final p1Id = await db.insertProduct(
      const Product(
        name: 'سلعة أ',
        salePrice: 100.0,
        purchasePrice: 60.0,
        stockQuantity: 100,
        isTaxable: true,
      ),
    );
    final p2Id = await db.insertProduct(
      const Product(
        name: 'سلعة ب',
        salePrice: 40.0,
        purchasePrice: 25.0,
        stockQuantity: 100,
        isTaxable: true,
      ),
    );

    final items = [
      DocumentItemInput(
        description: 'سلعة أ',
        quantity: 10,
        price: 100.0,
        productId: p1Id,
        taxable: true,
      ),
      DocumentItemInput(
        description: 'سلعة ب',
        quantity: 5,
        price: 40.0,
        productId: p2Id,
        taxable: true,
      ),
    ];
    const discount = 50.0;
    const paid = 500.0;

    // ─── Layer 1: DocumentService.calculateInvoiceTotals ───
    final totalsL1 = DocumentService.calculateInvoiceTotals(
      items: items,
      discount: discount,
      taxRate: 15.0,
      pricesIncludeTax: false,
      decimalDigits: 2,
    );

    expect(totalsL1.subtotal, 1200.0);
    expect(totalsL1.taxAmount, 172.50);
    expect(totalsL1.total, 1322.50);

    // ─── Layer 2: Persistence in Database ───
    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      contact: contact,
      items: items,
      discount: discount,
      paid: paid,
      date: DateTime(2026, 11, 1),
    );

    final docL2 = (await db.getDocumentById(docId))!;
    final itemsL2 = await db.getDocumentItems(docId);

    expect(docL2.subtotal, totalsL1.subtotal);
    expect(docL2.discount, discount);
    expect(docL2.taxAmount, totalsL1.taxAmount);
    expect(docL2.total, totalsL1.total);
    expect(docL2.paid, paid);
    expect(docL2.remaining, 822.50);

    final itemSumL2 = itemsL2.fold<double>(0.0, (s, it) => s + it.total);
    expect(itemSumL2, docL2.subtotal);

    // ─── Layer 3: Rendered PDF Totals Builder ───
    final l10n = AppLocalizations('ar');
    final pdfTheme = PdfTheme.defaultTheme();
    final font = pw.Font.courier();

    final pdfWidget = PdfTotalsBuilder.build(
      doc: docL2,
      currency: 'ج.س',
      l10n: l10n,
      bold: font,
      regular: font,
      theme: pdfTheme,
      isArabic: true,
    );
    expect(pdfWidget, isNotNull);

    // ─── Layer 4: Reporting Aggregate (Period Summary) ───
    final summaryL4 = await db.getPeriodSummary(
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 2),
      currencyCode: 'SDG',
    );

    expect(summaryL4['sales'], docL2.total);
    expect(summaryL4['paymentsIn'], docL2.paid);
    expect(summaryL4['customerOutstanding'], docL2.remaining);

    // ─── Layer 5: Derived Double-Entry General Ledger ───
    final ledgerBook = await LedgerService.load(currencyCode: 'SDG');
    final invoiceEntry = ledgerBook.entries.firstWhere((e) => e.documentId == docId && e.source == EntrySource.invoice);

    final recLine = invoiceEntry.lines.firstWhere((l) => l.account == Accounts.receivables);
    final salesLine = invoiceEntry.lines.firstWhere((l) => l.account == Accounts.salesRevenue);
    final vatLine = invoiceEntry.lines.firstWhere((l) => l.account == Accounts.vatOutput);

    expect(recLine.debit, docL2.total);
    expect(salesLine.credit, docL2.total - docL2.taxAmount);
    expect(vatLine.credit, docL2.taxAmount);

    // Check payment posting in ledger
    final payEntry = ledgerBook.entries.firstWhere(
      (e) => e.documentId == docId && (e.source == EntrySource.invoicePayment || e.source == EntrySource.receipt),
    );
    final payLine = payEntry.lines.firstWhere(
      (l) => l.account == Accounts.cash || l.account == Accounts.bank,
    );
    expect(payLine.debit, docL2.paid);

    // Trial balance must balance across all entries
    final tb = AccountingReports.trialBalance(ledgerBook.entries);
    expect(tb.isBalanced, isTrue);

    // Receivables balance in General Ledger
    final recGl = AccountingReports.generalLedger(ledgerBook.entries, Accounts.receivables);
    expect(recGl.closingBalance, docL2.remaining);
  });
}
