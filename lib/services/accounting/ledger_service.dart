import '../../database/database_helper.dart';
import '../../models/document_item.dart';
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

/// Loads the app's data and derives the double-entry journal.
///
/// Amounts in different currencies are never added together: each currency
/// is kept as separate books. Stock (opening balances and adjustments) is
/// valued at product prices, which are in the business currency, so it is
/// only part of the business currency's books.
class LedgerService {
  LedgerService._();

  static Future<LedgerBook> load({String? currencyCode}) async {
    final db = DatabaseHelper.instance;
    final business = await db.getFirstBusiness();
    final data = await db.getLedgerData();
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

    final entries = LedgerBuilder.build(
      LedgerInput(
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
      ),
    );

    return LedgerBook(
      currencyCode: selected,
      currencies: currencies,
      entries: entries,
    );
  }
}
