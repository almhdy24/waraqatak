import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_payment.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/journal_entry_entity.dart';
import 'package:warqatek/models/journal_line_entity.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/posting_service.dart';

void main() {
  group('PostingService Unit & Property Tests', () {
    int counter = 1;
    String nextEntryNo(String prefix) => '$prefix-${counter++}';

    setUp(() {
      counter = 1;
    });

    test('Drafts and quotations generate zero journal entries', () {
      final quotation = Document(
        id: 1,
        type: 'quotation',
        documentNumber: 'QUO-001',
        date: DateTime(2026, 1, 1),
        subtotal: 1000,
        discount: 0,
        taxRate: 0,
        taxAmount: 0,
        total: 1000,
        paid: 0,
        remaining: 1000,
      );

      final entries = PostingService.postDocumentIssued(
        doc: quotation,
        items: [],
        products: {},
        nextEntryNo: nextEntryNo,
      );

      expect(entries, isEmpty);
    });

    test('Invoice issuance generates balanced receivable, revenue, tax, and settlement entries', () {
      final doc = Document(
        id: 10,
        type: 'invoice',
        documentNumber: 'INV-1001',
        date: DateTime(2026, 2, 1),
        subtotal: 1000,
        discount: 100,
        taxRate: 15,
        taxAmount: 135,
        total: 1035,
        paid: 400,
        remaining: 635,
        paymentMethod: 'cash',
        contactId: 42,
      );

      final item = DocumentItem(
        id: 101,
        documentId: 10,
        productId: 5,
        description: 'Widget A',
        quantity: 2,
        price: 500,
        total: 1000,
        unitCost: 300,
        totalCost: 600,
      );

      final product = Product(
        id: 5,
        name: 'Widget A',
        salePrice: 500,
        purchasePrice: 300,
        type: Product.typeProduct,
      );

      final drafts = PostingService.postDocumentIssued(
        doc: doc,
        items: [item],
        products: {5: product},
        nextEntryNo: nextEntryNo,
      );

      // Expect 3 entries: Header (INV), Settlement (PAY), and COGS
      expect(drafts.length, 3);

      for (final draft in drafts) {
        expect(draft.isBalanced, isTrue, reason: '${draft.entryNo} must balance');
      }

      // 1. Invoice entry: Dr 1130 (1035.00 -> 103500 minor)
      // Cr 4100 (900.00 -> 90000 minor)
      // Cr 2120 (135.00 -> 13500 minor)
      final invEntry = drafts.firstWhere((d) => d.sourceType == PostingService.sourceInvoice);
      expect(invEntry.lines.length, 3);
      final drReceivable = invEntry.lines.firstWhere((l) => l.accountCode == Accounts.receivables.code);
      final crRevenue = invEntry.lines.firstWhere((l) => l.accountCode == Accounts.salesRevenue.code);
      final crTax = invEntry.lines.firstWhere((l) => l.accountCode == Accounts.vatOutput.code);

      expect(drReceivable.debitMinor, 103500);
      expect(crRevenue.creditMinor, 90000);
      expect(crTax.creditMinor, 13500);

      // 2. Settlement entry: Dr 1110 (40000 minor) / Cr 1130 (40000 minor)
      final payEntry = drafts.firstWhere((d) => d.sourceType == PostingService.sourcePayment);
      expect(payEntry.lines.length, 2);
      expect(payEntry.lines[0].accountCode, Accounts.cash.code);
      expect(payEntry.lines[0].debitMinor, 40000);
      expect(payEntry.lines[1].accountCode, Accounts.receivables.code);
      expect(payEntry.lines[1].creditMinor, 40000);

      // 3. COGS entry: 2 qty * 300 cost = 600.00 (60000 minor)
      final cogsEntry = drafts.firstWhere((d) => d.sourceType == PostingService.sourceCogs);
      expect(cogsEntry.lines.length, 2);
      expect(cogsEntry.lines[0].accountCode, Accounts.cogs.code);
      expect(cogsEntry.lines[0].debitMinor, 60000);
      expect(cogsEntry.lines[1].accountCode, Accounts.inventory.code);
      expect(cogsEntry.lines[1].creditMinor, 60000);
    });

    test('Purchase issuance divides stocked vs expensed lines and balances with payables', () {
      final doc = Document(
        id: 20,
        type: 'purchase',
        documentNumber: 'PUR-2001',
        date: DateTime(2026, 3, 1),
        subtotal: 1000,
        discount: 0,
        taxRate: 10,
        taxAmount: 100,
        total: 1100,
        paid: 1100,
        remaining: 0,
        paymentMethod: 'bank_transfer',
      );

      // Stocked item (600 of 1000 net)
      final stockedItem = DocumentItem(
        id: 201,
        documentId: 20,
        productId: 1,
        description: 'Goods',
        quantity: 6,
        price: 100,
        total: 600,
      );
      // Service item (400 of 1000 net, no product id)
      final serviceItem = DocumentItem(
        id: 202,
        documentId: 20,
        productId: null,
        description: 'Freight service',
        quantity: 1,
        price: 400,
        total: 400,
      );

      final product = Product(
        id: 1,
        name: 'Goods',
        salePrice: 150,
        purchasePrice: 100,
        type: Product.typeProduct,
      );

      final drafts = PostingService.postDocumentIssued(
        doc: doc,
        items: [stockedItem, serviceItem],
        products: {1: product},
        nextEntryNo: nextEntryNo,
      );

      expect(drafts.length, 2); // Purchase header + full upfront settlement
      for (final draft in drafts) {
        expect(draft.isBalanced, isTrue);
      }

      final purEntry = drafts[0];
      // Dr 1140 (Inventory) = 600.00 -> 60000 minor
      // Dr 6100 (Operating Expenses) = 400.00 -> 40000 minor
      // Dr 1150 (VAT Input) = 100.00 -> 10000 minor
      // Cr 2110 (Payables) = 1100.00 -> 110000 minor
      final drInv = purEntry.lines.firstWhere((l) => l.accountCode == Accounts.inventory.code);
      final drExp = purEntry.lines.firstWhere((l) => l.accountCode == Accounts.operatingExpenses.code);
      final drVat = purEntry.lines.firstWhere((l) => l.accountCode == Accounts.vatInput.code);
      final crPay = purEntry.lines.firstWhere((l) => l.accountCode == Accounts.payables.code);

      expect(drInv.debitMinor, 60000);
      expect(drExp.debitMinor, 40000);
      expect(drVat.debitMinor, 10000);
      expect(crPay.creditMinor, 110000);

      // Bank settlement: Dr 2110 / Cr 1120 (Bank) = 110000 minor
      final payEntry = drafts[1];
      expect(payEntry.lines[0].accountCode, Accounts.payables.code);
      expect(payEntry.lines[0].debitMinor, 110000);
      expect(payEntry.lines[1].accountCode, Accounts.bank.code);
      expect(payEntry.lines[1].creditMinor, 110000);
    });

    test('Cancellation generates exact reversal entries dated at original effective date', () {
      final doc = Document(
        id: 30,
        type: 'invoice',
        documentNumber: 'INV-3001',
        date: DateTime(2026, 1, 15),
        subtotal: 500,
        discount: 0,
        taxRate: 0,
        taxAmount: 0,
        total: 500,
        paid: 0,
        remaining: 500,
      );

      final originalEntry = JournalEntryEntity(
        id: 99,
        entryNo: 'JE-INV-1',
        effectiveDate: DateTime(2026, 1, 15),
        postedAt: DateTime(2026, 1, 15, 10, 0),
        sourceType: 'invoice',
        sourceId: 30,
        lines: const [
          JournalLineEntity(
            entryId: 99,
            accountCode: '1130',
            debitMinor: 50000,
            creditMinor: 0,
          ),
          JournalLineEntity(
            entryId: 99,
            accountCode: '4100',
            debitMinor: 0,
            creditMinor: 50000,
          ),
        ],
      );

      final cancelDate = DateTime(2026, 2, 20, 15, 30);
      final reversals = PostingService.postDocumentCancelled(
        doc: doc,
        existingEntries: [originalEntry],
        nextEntryNo: nextEntryNo,
        now: cancelDate,
      );

      expect(reversals.length, 1);
      final rev = reversals.first;
      expect(rev.isBalanced, isTrue);
      // D3: dated at original effective date!
      expect(rev.effectiveDate, DateTime(2026, 1, 15));
      expect(rev.postedAt, cancelDate);
      expect(rev.reversesEntryId, 99);

      // Reversal lines should flip debit and credit
      expect(rev.lines[0].accountCode, '1130');
      expect(rev.lines[0].debitMinor, 0);
      expect(rev.lines[0].creditMinor, 50000);

      expect(rev.lines[1].accountCode, '4100');
      expect(rev.lines[1].debitMinor, 50000);
      expect(rev.lines[1].creditMinor, 0);
    });

    test('Reason-coded stock adjustments post correct account pairs and balance', () {
      final date = DateTime(2026, 4, 1);

      // 1. Opening stock: Dr 1140 / Cr 3100
      final opening = PostingService.postStockAdjusted(
        productId: 1,
        quantity: 10,
        unitCost: 50,
        reason: 'opening_stock',
        decimalDigits: 2,
        date: date,
        nextEntryNo: nextEntryNo,
      )!;
      expect(opening.isBalanced, isTrue);
      expect(opening.lines[0].accountCode, Accounts.inventory.code);
      expect(opening.lines[0].debitMinor, 50000);
      expect(opening.lines[1].accountCode, Accounts.openingEquity.code);
      expect(opening.lines[1].creditMinor, 50000);

      // 2. Count gain: Dr 1140 / Cr 5200
      final gain = PostingService.postStockAdjusted(
        productId: 1,
        quantity: 2,
        unitCost: 50,
        reason: 'count_gain',
        decimalDigits: 2,
        date: date,
        nextEntryNo: nextEntryNo,
      )!;
      expect(gain.isBalanced, isTrue);
      expect(gain.lines[0].accountCode, Accounts.inventory.code);
      expect(gain.lines[0].debitMinor, 10000);
      expect(gain.lines[1].accountCode, Accounts.inventoryAdjustments.code);
      expect(gain.lines[1].creditMinor, 10000);

      // 3. Count loss / damage: Dr 5200 / Cr 1140
      final loss = PostingService.postStockAdjusted(
        productId: 1,
        quantity: -3,
        unitCost: 50,
        reason: 'damage_loss',
        decimalDigits: 2,
        date: date,
        nextEntryNo: nextEntryNo,
      )!;
      expect(loss.isBalanced, isTrue);
      expect(loss.lines[0].accountCode, Accounts.inventoryAdjustments.code);
      expect(loss.lines[0].debitMinor, 15000);
      expect(loss.lines[1].accountCode, Accounts.inventory.code);
      expect(loss.lines[1].creditMinor, 15000);

      // 4. Entry correction does not hit P&L: offsets against equity/opening
      final corr = PostingService.postStockAdjusted(
        productId: 1,
        quantity: -1,
        unitCost: 50,
        reason: 'entry_correction',
        decimalDigits: 2,
        date: date,
        nextEntryNo: nextEntryNo,
      )!;
      expect(corr.isBalanced, isTrue);
      expect(corr.lines[0].accountCode, Accounts.openingEquity.code);
      expect(corr.lines[0].debitMinor, 5000);
      expect(corr.lines[1].accountCode, Accounts.inventory.code);
      expect(corr.lines[1].creditMinor, 5000);
    });
  });
}
