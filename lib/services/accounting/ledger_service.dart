import 'dart:isolate';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/currency.dart';
import '../../models/document_item.dart';
import '../../utils/money_utils.dart';
import 'ledger.dart';

/// The journal of one currency's books.
class LedgerBook {
  final String currencyCode;

  /// Every currency that has documents (the business currency first).
  final List<String> currencies;
  final List<JournalEntry> entries;

  const LedgerBook({
    required this.currencyCode,
    required this.currencies,
    required this.entries,
  });
}

/// Loads the app's financial data and double-entry books.
///
/// When [journal_reports_enabled] setting is 'true', the authoritative persisted
/// double-entry journal (`journal_entries` and `journal_lines`) is loaded.
/// When 'false' (default), or for foreign-currency books, the reference derived ledger
/// ([LedgerBuilder.build]) is used.
class LedgerService {
  LedgerService._();

  static const String settingKeyJournalReportsEnabled = 'journal_reports_enabled';

  /// Returns whether reports read from the persisted journal.
  static Future<bool> isJournalReportsEnabled({DatabaseExecutor? txn}) async {
    final val = await DatabaseHelper.instance.getSetting(
      settingKeyJournalReportsEnabled,
      txn: txn,
    );
    return val == 'true';
  }

  /// Sets the report source flag.
  static Future<void> setJournalReportsEnabled(bool enabled) async {
    await DatabaseHelper.instance.setSetting(
      settingKeyJournalReportsEnabled,
      enabled ? 'true' : 'false',
    );
  }

  /// Always derives double-entry journal on the fly (reference oracle).
  static Future<LedgerBook> buildDerived({
    String? currencyCode,
    DatabaseExecutor? executor,
  }) async {
    final db = DatabaseHelper.instance;
    final business = await db.getFirstBusiness(txn: executor);
    final data = await db.getLedgerData(txn: executor);
    final base = business?.currencyCode ?? 'SDG';

    final currencies = <String>{
      base,
      ...data.documents.map((d) => d.currencyCode),
    }.toList();
    final selected = currencyCode != null && currencies.contains(currencyCode)
        ? currencyCode
        : base;
    final isBase = selected == base;

    final docs = data.documents
        .where((d) => d.currencyCode == selected)
        .toList();
    final ids = {for (final d in docs) d.id};
    final itemsByDocument = <int, List<DocumentItem>>{};
    for (final it in data.items) {
      if (ids.contains(it.documentId)) {
        itemsByDocument.putIfAbsent(it.documentId, () => []).add(it);
      }
    }

    final input = LedgerInput(
      documents: docs,
      itemsByDocument: itemsByDocument,
      products: {
        for (final p in data.products)
          if (p.id != null) p.id!: p,
      },
      stockMovements: isBase ? data.movements : const [],
      payments: data.payments
          .where((p) => ids.contains(p.documentId))
          .toList(),
      productPricesApply: isBase,
    );

    List<JournalEntry> entries;
    try {
      if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
        entries = LedgerBuilder.build(input);
      } else {
        entries = await Isolate.run(() => LedgerBuilder.build(input));
      }
    } catch (_) {
      entries = LedgerBuilder.build(input);
    }

    return LedgerBook(
      currencyCode: selected,
      currencies: currencies,
      entries: entries,
    );
  }

  /// Loads double-entry books.
  /// If [forceDerived] is true, bypasses the persisted journal regardless of setting.
  static Future<LedgerBook> load({
    String? currencyCode,
    bool forceDerived = false,
  }) async {
    final db = DatabaseHelper.instance;
    final business = await db.getFirstBusiness();
    final base = business?.currencyCode ?? 'SDG';

    final rawDb = await db.database;
    final docCurrencyRows = await rawDb.rawQuery('SELECT DISTINCT currency_code FROM documents');
    final currencies = <String>{
      base,
      ...docCurrencyRows
          .map((r) => r['currency_code'] as String?)
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>(),
    }.toList();

    final selected = currencyCode != null && currencies.contains(currencyCode)
        ? currencyCode
        : base;
    final isBase = selected == base;

    final reportsEnabled = forceDerived
        ? false
        : (await isJournalReportsEnabled(txn: rawDb));

    // Foreign currencies and non-journal mode always use derived ledger
    if (!reportsEnabled || !isBase) {
      return buildDerived(currencyCode: selected, executor: rawDb);
    }

    // Load persisted journal entries for base currency
    final decimalDigits = Currency.decimalDigitsForCode(base);
    final rows = await rawDb.rawQuery('''
      SELECT 
        e.id as entry_id,
        e.entry_no,
        e.effective_date,
        e.source_type,
        e.source_id,
        e.memo,
        l.id as line_id,
        l.account_code,
        l.debit_minor,
        l.credit_minor
      FROM journal_entries e
      LEFT JOIN journal_lines l ON e.id = l.entry_id
      ORDER BY e.effective_date ASC, e.id ASC, l.id ASC
    ''');

    final entryMap = <int, _EntryAccumulator>{};
    for (final r in rows) {
      final entryId = (r['entry_id'] as num).toInt();
      final acc = entryMap.putIfAbsent(
        entryId,
        () => _EntryAccumulator(
          id: entryId,
          entryNo: (r['entry_no'] as String?) ?? '',
          effectiveDate: (r['effective_date'] as String?) ?? '',
          sourceType: (r['source_type'] as String?) ?? '',
          sourceId: r['source_id'] as int?,
          memo: r['memo'] as String?,
        ),
      );

      final accountCode = r['account_code'] as String?;
      if (accountCode != null) {
        final acct = Accounts.all.firstWhere(
          (a) => a.code == accountCode,
          orElse: () => Accounts.operatingExpenses,
        );
        final drMinor = (r['debit_minor'] as num?)?.toInt() ?? 0;
        final crMinor = (r['credit_minor'] as num?)?.toInt() ?? 0;
        acc.lines.add(JournalLine(
          acct,
          debit: MoneyUtils.fromMinorUnits(drMinor, decimalDigits),
          credit: MoneyUtils.fromMinorUnits(crMinor, decimalDigits),
        ));
      }
    }

    final entries = <JournalEntry>[];
    for (final acc in entryMap.values) {
      DateTime date;
      try {
        date = DateTime.parse(acc.effectiveDate);
      } catch (_) {
        date = DateTime.now();
      }

      entries.add(JournalEntry(
        date: date,
        source: _mapSourceType(acc.sourceType),
        reference: acc.entryNo.isNotEmpty ? acc.entryNo : (acc.memo ?? 'JE-${acc.id}'),
        documentId: acc.sourceId,
        lines: acc.lines,
      ));
    }

    return LedgerBook(
      currencyCode: selected,
      currencies: currencies,
      entries: entries,
    );
  }

  static EntrySource _mapSourceType(String sourceType) {
    switch (sourceType) {
      case 'invoice':
        return EntrySource.invoice;
      case 'payment':
      case 'invoice_payment':
        return EntrySource.invoicePayment;
      case 'receipt':
        return EntrySource.receipt;
      case 'purchase':
        return EntrySource.purchase;
      case 'purchase_payment':
        return EntrySource.purchasePayment;
      case 'voucher':
      case 'expense_voucher':
        return EntrySource.expenseVoucher;
      case 'cogs':
      case 'cost_of_sales':
        return EntrySource.costOfSales;
      case 'opening_stock':
        return EntrySource.openingStock;
      case 'stock_adjustment':
      case 'stocktake':
      default:
        return EntrySource.stockAdjustment;
    }
  }
}

class _EntryAccumulator {
  final int id;
  final String entryNo;
  final String effectiveDate;
  final String sourceType;
  final int? sourceId;
  final String? memo;
  final List<JournalLine> lines = [];

  _EntryAccumulator({
    required this.id,
    required this.entryNo,
    required this.effectiveDate,
    required this.sourceType,
    this.sourceId,
    this.memo,
  });
}
