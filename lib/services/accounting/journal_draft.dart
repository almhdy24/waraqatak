/// In-memory line draft before being persisted.
class JournalLineDraft {
  final String accountCode;
  final int debitMinor;
  final int creditMinor;
  final int? productId;
  final int? contactId;

  const JournalLineDraft({
    required this.accountCode,
    this.debitMinor = 0,
    this.creditMinor = 0,
    this.productId,
    this.contactId,
  });

  bool get isDebit => debitMinor > 0;
  bool get isCredit => creditMinor > 0;

  JournalLineDraft reciprocal() => JournalLineDraft(
    accountCode: accountCode,
    debitMinor: creditMinor,
    creditMinor: debitMinor,
    productId: productId,
    contactId: contactId,
  );

  Map<String, dynamic> toMap(int entryId) => {
    'entry_id': entryId,
    'account_code': accountCode,
    'debit_minor': debitMinor,
    'credit_minor': creditMinor,
    'product_id': productId,
    'contact_id': contactId,
  };
}

/// In-memory journal entry draft before write.
class JournalEntryDraft {
  final String entryNo;
  final DateTime effectiveDate;
  final DateTime postedAt;
  final String sourceType;
  final int? sourceId;
  final int revision;
  final String? memo;
  final int? reversesEntryId;
  final String origin; // 'live' | 'legacy_backfill'
  final List<JournalLineDraft> lines;

  const JournalEntryDraft({
    required this.entryNo,
    required this.effectiveDate,
    required this.postedAt,
    required this.sourceType,
    this.sourceId,
    this.revision = 1,
    this.memo,
    this.reversesEntryId,
    this.origin = 'live',
    required this.lines,
  });

  int get totalDebitMinor =>
      lines.fold<int>(0, (sum, l) => sum + l.debitMinor);

  int get totalCreditMinor =>
      lines.fold<int>(0, (sum, l) => sum + l.creditMinor);

  bool get isBalanced => totalDebitMinor == totalCreditMinor;

  JournalEntryDraft createReversal({
    required String reversalEntryNo,
    required DateTime currentTimestamp,
    int? priorEntryId,
    String? reversalMemo,
  }) {
    return JournalEntryDraft(
      entryNo: reversalEntryNo,
      effectiveDate: effectiveDate, // Dated at original entry effective date (D3)
      postedAt: currentTimestamp,
      sourceType: sourceType,
      sourceId: sourceId,
      revision: revision + 1,
      memo: reversalMemo ?? 'Reversal of entry $entryNo',
      reversesEntryId: priorEntryId ?? reversesEntryId,
      origin: origin,
      lines: lines.map((l) => l.reciprocal()).toList(),
    );
  }

  Map<String, dynamic> toHeaderMap() => {
    'entry_no': entryNo,
    'effective_date': effectiveDate.toIso8601String(),
    'posted_at': postedAt.toIso8601String(),
    'source_type': sourceType,
    'source_id': sourceId,
    'revision': revision,
    'memo': memo,
    'reverses_entry_id': reversesEntryId,
    'origin': origin,
  };
}
