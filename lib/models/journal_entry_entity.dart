import 'journal_line_entity.dart';

/// Domain model for an immutable journal entry header.
class JournalEntryEntity {
  final int? id;
  final String entryNo;
  final DateTime effectiveDate;
  final DateTime postedAt;
  final String sourceType;
  final int? sourceId;
  final int revision;
  final String? memo;
  final int? reversesEntryId;
  final String origin; // 'live' | 'legacy_backfill'
  final List<JournalLineEntity> lines;

  const JournalEntryEntity({
    this.id,
    required this.entryNo,
    required this.effectiveDate,
    required this.postedAt,
    required this.sourceType,
    this.sourceId,
    this.revision = 1,
    this.memo,
    this.reversesEntryId,
    this.origin = 'live',
    this.lines = const [],
  });

  int get totalDebitMinor =>
      lines.fold<int>(0, (sum, line) => sum + line.debitMinor);

  int get totalCreditMinor =>
      lines.fold<int>(0, (sum, line) => sum + line.creditMinor);

  bool get isBalanced => totalDebitMinor == totalCreditMinor;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
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

  factory JournalEntryEntity.fromMap(
    Map<String, dynamic> map, {
    List<JournalLineEntity> lines = const [],
  }) => JournalEntryEntity(
    id: map['id'] as int?,
    entryNo: map['entry_no'] as String,
    effectiveDate: DateTime.parse(map['effective_date'] as String),
    postedAt: DateTime.parse(map['posted_at'] as String),
    sourceType: map['source_type'] as String,
    sourceId: map['source_id'] as int?,
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    memo: map['memo'] as String?,
    reversesEntryId: map['reverses_entry_id'] as int?,
    origin: (map['origin'] as String?) ?? 'live',
    lines: lines,
  );
}
