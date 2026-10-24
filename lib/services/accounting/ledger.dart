import '../../models/document.dart';
import '../../models/document_item.dart';
import '../../models/document_payment.dart';
import '../../models/document_status.dart';
import '../../models/product.dart';
import '../../models/stock_movement.dart';

/// Account classes of the chart of accounts.
enum AccountType { asset, liability, equity, revenue, expense }

class Account {
  final String code;
  final AccountType type;
  const Account(this.code, this.type);

  /// Assets and expenses increase on the debit side.
  bool get debitNormal =>
      type == AccountType.asset || type == AccountType.expense;
}

/// Standard chart of accounts used by the derived ledger. Codes follow the
/// usual 1 assets / 2 liabilities / 3 equity / 4 revenue / 5–6 expenses
/// layout. Names are localized in AppLocalizations.accountName.
class Accounts {
  Accounts._();

  static const cash = Account('1110', AccountType.asset);
  static const bank = Account('1120', AccountType.asset);
  static const receivables = Account('1130', AccountType.asset);
  static const inventory = Account('1140', AccountType.asset);
  static const vatInput = Account('1150', AccountType.asset);
  static const payables = Account('2110', AccountType.liability);
  static const vatOutput = Account('2120', AccountType.liability);
  static const openingEquity = Account('3100', AccountType.equity);
  static const salesRevenue = Account('4100', AccountType.revenue);
  static const otherIncome = Account('4900', AccountType.revenue);
  static const cogs = Account('5100', AccountType.expense);
  static const inventoryAdjustments = Account('5200', AccountType.expense);
  static const operatingExpenses = Account('6100', AccountType.expense);

  static const all = [
    cash,
    bank,
    receivables,
    inventory,
    vatInput,
    payables,
    vatOutput,
    openingEquity,
    salesRevenue,
    otherIncome,
    cogs,
    inventoryAdjustments,
    operatingExpenses,
  ];

  static Account byCode(String code) => all.firstWhere((a) => a.code == code);

  /// Payment method key → cash account. 'cash' is the till; every other
  /// method (bank transfer, wallets, cards…) goes to banks & e-wallets.
  static Account forPaymentMethod(String? method) =>
      method == null || method == 'cash' ? cash : bank;
}

class JournalLine {
  final Account account;
  final double debit;
  final double credit;
  const JournalLine(this.account, {this.debit = 0, this.credit = 0});
}

/// What produced a journal entry.
enum EntrySource {
  invoice,
  invoicePayment,
  receipt,
  purchase,
  purchasePayment,
  expenseVoucher,
  costOfSales,
  openingStock,
  stockAdjustment,
}

class JournalEntry {
  final DateTime date;
  final EntrySource source;
  final int? documentId;
  final String reference;
  final List<JournalLine> lines;
  final bool isCostMissing;

  const JournalEntry({
    required this.date,
    required this.source,
    required this.reference,
    required this.lines,
    this.documentId,
    this.isCostMissing = false,
  });

  double get totalDebit => lines.fold(0, (s, l) => s + l.debit);
  double get totalCredit => lines.fold(0, (s, l) => s + l.credit);
}

/// Everything the ledger is derived from (read-only snapshot).
class LedgerInput {
  final List<Document> documents;
  final Map<int, List<DocumentItem>> itemsByDocument;
  final Map<int, Product> products;
  final List<StockMovement> stockMovements;
  final List<DocumentPayment> payments;

  /// Product prices (purchase price) are in these books' currency. When
  /// false, stock that has no cost in these books is costed at zero and
  /// unrecorded stock is not brought in.
  final bool productPricesApply;

  const LedgerInput({
    required this.documents,
    required this.itemsByDocument,
    required this.products,
    required this.stockMovements,
    this.payments = const [],
    this.productPricesApply = true,
  });
}

/// Builds a double-entry journal from the app's documents.
///
/// The ledger is *derived*: nothing is stored, so it always matches the
/// documents and can never drift. Posting rules:
/// - Invoice: Dr receivables (total) / Cr sales (net) / Cr output VAT.
///   Payments recorded without an active receipt are posted as
///   Dr cash / Cr receivables on the payment's date with its method; any
///   remaining paid amount (older data) on the invoice date.
/// - Payment receipt: Dr cash or bank (by method) / Cr receivables, or other
///   income when not linked to an invoice.
/// - Purchase: Dr inventory (stocked products) or operating expenses
///   (services, free-text lines) / Dr input VAT / Cr payables; amounts paid
///   at creation: Dr payables / Cr cash.
/// - Expense voucher: Dr payables (linked to a purchase) or operating
///   expenses / Cr cash or bank.
/// - Cost of sales and inventory use the perpetual weighted-average cost
///   method (IAS 2): purchases, opening stock and adjustments are replayed in
///   date order per product; each sale is costed at the running average.
/// - Opening stock: Dr inventory / Cr opening balance equity, at the
///   product's purchase price. Stock that predates movement tracking (current
///   stock not explained by any movement) is treated as opening stock too.
///   Stock adjustments: inventory vs inventory adjustments.
/// Drafts, quotations, custom documents and cancelled documents post
/// nothing (cancelled stock movements are ignored with their documents).
class LedgerBuilder {
  LedgerBuilder._();

  static const _eps = 1e-9;

  static List<JournalEntry> build(LedgerInput input) {
    final entries = <JournalEntry>[];
    final docs = input.documents
        .where(
          (d) =>
              d.status != DocumentStatus.cancelled &&
              d.status != DocumentStatus.draft,
        )
        .toList();
    final byId = {
      for (final d in input.documents)
        if (d.id != null) d.id!: d,
    };

    // Payments posted by active linked receipts/vouchers, per parent doc.
    final linkedPaid = <int, double>{};
    final activeLinkIds = <int>{};
    for (final d in docs) {
      if ((d.type == 'payment_receipt' || d.type == 'expense_voucher') &&
          d.relatedDocumentId != null) {
        linkedPaid.update(
          d.relatedDocumentId!,
          (v) => v + d.total,
          ifAbsent: () => d.total,
        );
        if (d.id != null) activeLinkIds.add(d.id!);
      }
    }
    // Payment rows not covered by an active receipt/voucher, per parent doc.
    final ownPayments = <int, List<DocumentPayment>>{};
    for (final p in input.payments) {
      if (p.receiptDocumentId != null &&
          activeLinkIds.contains(p.receiptDocumentId)) {
        continue;
      }
      ownPayments.putIfAbsent(p.documentId, () => []).add(p);
    }

    for (final d in docs) {
      switch (d.type) {
        case 'invoice':
          _invoice(d, entries);
          _payments(d, linkedPaid[d.id] ?? 0, ownPayments[d.id], entries);
        case 'purchase':
          _purchase(d, input, entries);
          _payments(d, linkedPaid[d.id] ?? 0, ownPayments[d.id], entries);
        case 'payment_receipt':
          _receipt(d, byId, entries);
        case 'expense_voucher':
          _voucher(d, byId, entries);
      }
    }

    _inventory(input, docs, entries);

    // Stable by date: same-date entries keep posting order (a document
    // before its payment and its cost of sales).
    final order = {for (var i = 0; i < entries.length; i++) entries[i]: i};
    entries.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : order[a]!.compareTo(order[b]!);
    });
    return entries;
  }

  static void _invoice(Document d, List<JournalEntry> out) {
    final net = d.total - d.taxAmount;
    out.add(
      JournalEntry(
        date: d.date,
        source: EntrySource.invoice,
        documentId: d.id,
        reference: d.documentNumber,
        lines: [
          JournalLine(Accounts.receivables, debit: d.total),
          if (net.abs() > _eps) JournalLine(Accounts.salesRevenue, credit: net),
          if (d.taxAmount.abs() > _eps)
            JournalLine(Accounts.vatOutput, credit: d.taxAmount),
        ],
      ),
    );
  }

  /// Settlement of an invoice/purchase not already posted by an active
  /// receipt/voucher. The document's `paid` is authoritative: only
  /// `paid - linked` is posted, first from the payment rows (their date and
  /// method), then any rest on the document date — so nothing is counted
  /// twice even for data recorded before receipts were linked.
  static void _payments(
    Document d,
    double linked,
    List<DocumentPayment>? rows,
    List<JournalEntry> out,
  ) {
    var left = d.paid - linked;
    if (left <= _eps) return;
    final sorted = [...?rows]..sort((a, b) => a.date.compareTo(b.date));
    for (final p in sorted) {
      if (left <= _eps) break;
      final amount = p.amount < left ? p.amount : left;
      if (amount <= _eps) continue;
      out.add(_settlement(d, p.date, p.paymentMethod, amount));
      left -= amount;
    }
    if (left > _eps) out.add(_settlement(d, d.date, d.paymentMethod, left));
  }

  static JournalEntry _settlement(
    Document d,
    DateTime date,
    String? method,
    double amount,
  ) {
    final money = Accounts.forPaymentMethod(method);
    final isSale = d.type == 'invoice';
    return JournalEntry(
      date: date,
      source: isSale ? EntrySource.invoicePayment : EntrySource.purchasePayment,
      documentId: d.id,
      reference: d.documentNumber,
      lines: isSale
          ? [
              JournalLine(money, debit: amount),
              JournalLine(Accounts.receivables, credit: amount),
            ]
          : [
              JournalLine(Accounts.payables, debit: amount),
              JournalLine(money, credit: amount),
            ],
    );
  }

  static void _purchase(Document d, LedgerInput input, List<JournalEntry> out) {
    final items = input.itemsByDocument[d.id] ?? const <DocumentItem>[];
    final net = d.total - d.taxAmount;
    double stocked = 0;
    for (final it in items) {
      if (_isStocked(it, input.products)) stocked += _allocatedNet(d, it);
    }
    final expensed = net - stocked;
    out.add(
      JournalEntry(
        date: d.date,
        source: EntrySource.purchase,
        documentId: d.id,
        reference: d.documentNumber,
        lines: [
          if (stocked.abs() > _eps)
            JournalLine(Accounts.inventory, debit: stocked),
          if (expensed.abs() > _eps)
            JournalLine(Accounts.operatingExpenses, debit: expensed),
          if (d.taxAmount.abs() > _eps)
            JournalLine(Accounts.vatInput, debit: d.taxAmount),
          JournalLine(Accounts.payables, credit: d.total),
        ],
      ),
    );
  }

  static void _receipt(
    Document d,
    Map<int, Document> byId,
    List<JournalEntry> out,
  ) {
    if (d.total.abs() <= _eps) return;
    final parent = d.relatedDocumentId == null
        ? null
        : byId[d.relatedDocumentId];
    out.add(
      JournalEntry(
        date: d.date,
        source: EntrySource.receipt,
        documentId: d.id,
        reference: d.documentNumber,
        lines: [
          JournalLine(
            Accounts.forPaymentMethod(d.paymentMethod),
            debit: d.total,
          ),
          JournalLine(
            parent?.type == 'invoice'
                ? Accounts.receivables
                : Accounts.otherIncome,
            credit: d.total,
          ),
        ],
      ),
    );
  }

  static void _voucher(
    Document d,
    Map<int, Document> byId,
    List<JournalEntry> out,
  ) {
    if (d.total.abs() <= _eps) return;
    final parent = d.relatedDocumentId == null
        ? null
        : byId[d.relatedDocumentId];
    out.add(
      JournalEntry(
        date: d.date,
        source: EntrySource.expenseVoucher,
        documentId: d.id,
        reference: d.documentNumber,
        lines: [
          JournalLine(
            parent?.type == 'purchase'
                ? Accounts.payables
                : Accounts.operatingExpenses,
            debit: d.total,
          ),
          JournalLine(
            Accounts.forPaymentMethod(d.paymentMethod),
            credit: d.total,
          ),
        ],
      ),
    );
  }

  static bool _isStocked(DocumentItem it, Map<int, Product> products) {
    final p = it.productId == null ? null : products[it.productId];
    return p != null && p.type == Product.typeProduct && it.quantity > 0;
  }

  /// Item's share of the document's net amount (after discount, before tax).
  static double _allocatedNet(Document d, DocumentItem it) {
    if (d.subtotal.abs() <= _eps) return 0;
    return it.total / d.subtotal * (d.total - d.taxAmount);
  }

  /// Weighted-average inventory replay → cost of sales, opening stock and
  /// adjustment entries.
  static void _inventory(
    LedgerInput input,
    List<Document> postedDocs,
    List<JournalEntry> out,
  ) {
    final events = <_StockEvent>[];
    for (final d in postedDocs) {
      if (d.type != 'invoice' && d.type != 'purchase') continue;
      for (final it in input.itemsByDocument[d.id] ?? const <DocumentItem>[]) {
        if (!_isStocked(it, input.products)) continue;
        if (d.type == 'purchase') {
          events.add(
            _StockEvent(
              d.date,
              it.productId!,
              it.quantity,
              unitCost: _allocatedNet(d, it) / it.quantity,
              doc: d,
            ),
          );
        } else {
          events.add(_StockEvent(
            d.date,
            it.productId!,
            -it.quantity,
            doc: d,
            unitCost: it.unitCost,
          ));
        }
      }
    }
    for (final m in input.stockMovements) {
      final p = input.products[m.productId];
      if (p == null || p.type != Product.typeProduct) continue;
      if (m.type == StockMovement.typeOpening && m.quantity > 0) {
        final openingCost = m.unitCost ??
            (p.costStatus == Product.costStatusKnown ? p.averageCost : null) ??
            (input.productPricesApply && p.purchasePrice > 0 ? p.purchasePrice : null);
        events.add(
          _StockEvent(
            m.date,
            m.productId,
            m.quantity,
            unitCost: openingCost,
            opening: true,
          ),
        );
      } else if (m.type == StockMovement.typeAdjustment && m.quantity != 0) {
        events.add(
          _StockEvent(
            m.date,
            m.productId,
            m.quantity,
            unitCost: m.unitCost,
            adjustment: true,
          ),
        );
      } else if (m.type == StockMovement.typeCancellation && m.quantity > 0) {
        events.add(
          _StockEvent(
            m.date,
            m.productId,
            m.quantity,
            unitCost: m.unitCost,
          ),
        );
      }
    }
    // Stock the records do not explain (e.g. stock entered before movements
    // were tracked) enters as opening stock before the product's first
    // event, so ledger quantities reconcile with the current stock.
    final net = <int, double>{};
    final first = <int, DateTime>{};
    for (final e in events) {
      net.update(
        e.productId,
        (v) => v + e.quantity,
        ifAbsent: () => e.quantity,
      );
      final f = first[e.productId];
      if (f == null || e.date.isBefore(f)) first[e.productId] = e.date;
    }
    for (final p in input.products.values) {
      if (!input.productPricesApply) break;
      if (p.id == null || p.type != Product.typeProduct) continue;
      final unexplained = p.stockQuantity - (net[p.id] ?? 0);
      if (unexplained <= _eps) continue;
      final date =
          first[p.id]?.subtract(const Duration(milliseconds: 1)) ??
          p.createdAt ??
          DateTime(2000);
      final openingCost = (p.costStatus == Product.costStatusKnown ? p.averageCost : null) ??
          (input.productPricesApply && p.purchasePrice > 0 ? p.purchasePrice : null);
      if (openingCost == null || openingCost <= 0) continue;
      events.add(
        _StockEvent(
          date,
          p.id!,
          unexplained,
          unitCost: openingCost,
          opening: true,
        ),
      );
    }

    // Same moment: stock in before stock out, so a sale is costed after a
    // purchase recorded at the same time.
    events.sort((a, b) {
      final c = a.date.compareTo(b.date);
      if (c != 0) return c;
      return (b.quantity > 0 ? 1 : 0).compareTo(a.quantity > 0 ? 1 : 0);
    });

    final qty = <int, double>{};
    final value = <int, double>{};
    for (final e in events) {
      final q = qty[e.productId] ?? 0;
      final v = value[e.productId] ?? 0;
      final p = input.products[e.productId]!;

      double? resolvedAvg;
      if (q > _eps && v > _eps) {
        resolvedAvg = v / q;
      } else if (e.unitCost != null && e.unitCost! > 0) {
        resolvedAvg = e.unitCost!;
      } else if (p.costStatus == Product.costStatusKnown && p.averageCost != null && p.averageCost! > 0) {
        resolvedAvg = p.averageCost!;
      } else if (input.productPricesApply && p.purchasePrice > 0) {
        resolvedAvg = p.purchasePrice;
      }

      final avg = resolvedAvg ?? 0.0;

      if (e.quantity > 0 && e.unitCost != null) {
        // Purchase or opening stock: enters at its own cost.
        final cost = e.quantity * e.unitCost!;
        qty[e.productId] = q + e.quantity;
        value[e.productId] = v + cost;
        if (e.opening && cost.abs() > _eps) {
          out.add(
            JournalEntry(
              date: e.date,
              source: EntrySource.openingStock,
              reference: p.name,
              lines: [
                JournalLine(Accounts.inventory, debit: cost),
                JournalLine(Accounts.openingEquity, credit: cost),
              ],
            ),
          );
        }
        continue;
      }

      // Sale or adjustment: moves at the running average cost.
      final cost = e.quantity.abs() * avg;
      final newQty = q + e.quantity;
      qty[e.productId] = newQty;
      value[e.productId] = newQty.abs() <= _eps
          ? 0
          : v + (e.quantity > 0 ? cost : -cost);

      if (!e.adjustment && cost.abs() <= _eps) {
        // Missing COGS: record an explicit journal entry indicating uncosted sale
        // so the income statement can disclose that cost of sales is incomplete
        // rather than silently presenting 100% gross profit.
        out.add(
          JournalEntry(
            date: e.date,
            source: EntrySource.costOfSales,
            documentId: e.doc?.id,
            reference: e.doc?.documentNumber ?? p.name,
            lines: const [],
            isCostMissing: true,
          ),
        );
        continue;
      }

      if (cost.abs() <= _eps) continue;

      if (e.adjustment) {
        final gain = e.quantity > 0;
        out.add(
          JournalEntry(
            date: e.date,
            source: EntrySource.stockAdjustment,
            reference: p.name,
            lines: gain
                ? [
                    JournalLine(Accounts.inventory, debit: cost),
                    JournalLine(Accounts.inventoryAdjustments, credit: cost),
                  ]
                : [
                    JournalLine(Accounts.inventoryAdjustments, debit: cost),
                    JournalLine(Accounts.inventory, credit: cost),
                  ],
          ),
        );
      } else {
        out.add(
          JournalEntry(
            date: e.date,
            source: EntrySource.costOfSales,
            documentId: e.doc?.id,
            reference: e.doc?.documentNumber ?? p.name,
            lines: [
              JournalLine(Accounts.cogs, debit: cost),
              JournalLine(Accounts.inventory, credit: cost),
            ],
          ),
        );
      }
    }
  }
}

class _StockEvent {
  final DateTime date;
  final int productId;
  final double quantity;
  final double? unitCost;
  final Document? doc;
  final bool opening;
  final bool adjustment;

  _StockEvent(
    this.date,
    this.productId,
    this.quantity, {
    this.unitCost,
    this.doc,
    this.opening = false,
    this.adjustment = false,
  });
}

// ─── Reports ──────────────────────────────────────────────────────────────

class AccountBalance {
  final Account account;
  final double debit;
  final double credit;
  const AccountBalance(this.account, this.debit, this.credit);

  /// Balance on the account's normal side (positive = normal).
  double get balance => account.debitNormal ? debit - credit : credit - debit;
}

class TrialBalance {
  final List<AccountBalance> rows;
  const TrialBalance(this.rows);
  double get totalDebit => rows.fold(0, (s, r) => s + r.debit);
  double get totalCredit => rows.fold(0, (s, r) => s + r.credit);
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.005;
}

class IncomeStatement {
  final double salesRevenue;
  final double otherIncome;
  final double costOfSales;
  final double inventoryAdjustments;
  final double operatingExpenses;
  final bool hasIncompleteCostOfSales;
  final int uncostedSalesCount;

  const IncomeStatement({
    required this.salesRevenue,
    required this.otherIncome,
    required this.costOfSales,
    required this.inventoryAdjustments,
    required this.operatingExpenses,
    this.hasIncompleteCostOfSales = false,
    this.uncostedSalesCount = 0,
  });

  /// Trusted gross profit only when all sales have known cost of sales; null otherwise.
  double? get trustedGrossProfit => hasIncompleteCostOfSales ? null : grossProfit;

  double get grossProfit => salesRevenue - costOfSales;
  double get netProfit =>
      grossProfit + otherIncome - inventoryAdjustments - operatingExpenses;
}

class BalanceSheet {
  final Map<Account, double> assets;
  final Map<Account, double> liabilities;
  final Map<Account, double> equity;

  /// Cumulative profit up to the report date (not yet closed to equity).
  final double retainedEarnings;

  const BalanceSheet({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.retainedEarnings,
  });

  double get totalAssets => assets.values.fold(0, (s, v) => s + v);
  double get totalLiabilities => liabilities.values.fold(0, (s, v) => s + v);
  double get totalEquity =>
      equity.values.fold(0.0, (s, v) => s + v) + retainedEarnings;
  bool get isBalanced =>
      (totalAssets - totalLiabilities - totalEquity).abs() < 0.005;
}

class LedgerLine {
  final JournalEntry entry;
  final double debit;
  final double credit;
  final double runningBalance;
  const LedgerLine(this.entry, this.debit, this.credit, this.runningBalance);
}

class GeneralLedger {
  final Account account;
  final double openingBalance;
  final List<LedgerLine> lines;
  const GeneralLedger(this.account, this.openingBalance, this.lines);
  double get closingBalance =>
      lines.isEmpty ? openingBalance : lines.last.runningBalance;
}

class AccountingReports {
  AccountingReports._();

  static bool _inRange(DateTime d, DateTime? from, DateTime? to) =>
      (from == null || !d.isBefore(from)) && (to == null || !d.isAfter(to));

  static Map<Account, (double, double)> _sums(Iterable<JournalEntry> entries) {
    final m = <Account, (double, double)>{};
    for (final e in entries) {
      for (final l in e.lines) {
        final (d, c) = m[l.account] ?? (0.0, 0.0);
        m[l.account] = (d + l.debit, c + l.credit);
      }
    }
    return m;
  }

  static TrialBalance trialBalance(
    List<JournalEntry> entries, {
    DateTime? from,
    DateTime? to,
  }) {
    final sums = _sums(entries.where((e) => _inRange(e.date, from, to)));
    return TrialBalance([
      for (final a in Accounts.all)
        if (sums[a] != null) AccountBalance(a, sums[a]!.$1, sums[a]!.$2),
    ]);
  }

  static IncomeStatement incomeStatement(
    List<JournalEntry> entries, {
    DateTime? from,
    DateTime? to,
  }) {
    final tb = trialBalance(entries, from: from, to: to);
    double bal(Account a) =>
        tb.rows
            .where((r) => r.account == a)
            .map((r) => r.balance)
            .firstOrNull ??
        0;
    final inRange = entries.where((e) => _inRange(e.date, from, to));
    final uncosted = inRange.where((e) => e.source == EntrySource.costOfSales && e.isCostMissing).length;
    return IncomeStatement(
      salesRevenue: bal(Accounts.salesRevenue),
      otherIncome: bal(Accounts.otherIncome),
      costOfSales: bal(Accounts.cogs),
      inventoryAdjustments: bal(Accounts.inventoryAdjustments),
      operatingExpenses: bal(Accounts.operatingExpenses),
      hasIncompleteCostOfSales: uncosted > 0,
      uncostedSalesCount: uncosted,
    );
  }

  static BalanceSheet balanceSheet(
    List<JournalEntry> entries, {
    DateTime? asOf,
  }) {
    final tb = trialBalance(entries, to: asOf);
    final assets = <Account, double>{};
    final liabilities = <Account, double>{};
    final equity = <Account, double>{};
    double earnings = 0;
    for (final r in tb.rows) {
      switch (r.account.type) {
        case AccountType.asset:
          assets[r.account] = r.balance;
        case AccountType.liability:
          liabilities[r.account] = r.balance;
        case AccountType.equity:
          equity[r.account] = r.balance;
        case AccountType.revenue:
          earnings += r.balance;
        case AccountType.expense:
          earnings -= r.balance;
      }
    }
    return BalanceSheet(
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      retainedEarnings: earnings,
    );
  }

  static GeneralLedger generalLedger(
    List<JournalEntry> entries,
    Account account, {
    DateTime? from,
    DateTime? to,
  }) {
    double signed(JournalLine l) =>
        account.debitNormal ? l.debit - l.credit : l.credit - l.debit;
    double opening = 0;
    final lines = <LedgerLine>[];
    for (final e in entries) {
      for (final l in e.lines.where((l) => l.account == account)) {
        if (from != null && e.date.isBefore(from)) {
          opening += signed(l);
        } else if (_inRange(e.date, from, to)) {
          final prev = lines.isEmpty ? opening : lines.last.runningBalance;
          lines.add(LedgerLine(e, l.debit, l.credit, prev + signed(l)));
        }
      }
    }
    return GeneralLedger(account, opening, lines);
  }
}
