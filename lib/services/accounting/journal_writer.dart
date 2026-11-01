import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import 'journal_draft.dart';

/// Exception thrown when an attempt is made to post or modify records in a closed period.
class PeriodClosedException implements Exception {
  final DateTime date;
  final DateTime lockDate;
  final String message;

  PeriodClosedException({
    required this.date,
    required this.lockDate,
    String? message,
  }) : message = message ??
            'Cannot record transactions on or before closed period date (${lockDate.toIso8601String().substring(0, 10)})';

  @override
  String toString() => message;
}

/// The sole authoritative writer for persisted double-entry journal entries and lines.
/// Enforces immutability, period lock, and exact debit-credit balance in minor units.
class JournalWriter {
  JournalWriter._();

  /// Writes a balanced [JournalEntryDraft] to the database inside the caller's transaction.
  /// Throws [PeriodClosedException] if the entry date falls within a closed accounting period.
  /// Throws [StateError] if the entry lines are unbalanced or empty.
  static Future<int> write(
    DatabaseExecutor txn,
    JournalEntryDraft draft, {
    DateTime? lockDateOverride,
  }) async {
    // 1. Period lock validation
    if (draft.origin != 'legacy_backfill') {
      final DateTime? lockDate;
      if (lockDateOverride != null) {
        lockDate = lockDateOverride;
      } else {
        final lockStr = await DatabaseHelper.instance.getSetting(
          'books_closed_through',
          txn: txn,
        );
        lockDate = lockStr != null && lockStr.isNotEmpty
            ? DateTime.tryParse(lockStr)
            : null;
      }

      if (lockDate != null) {
        // Truncate to dates for comparison (inclusive check: <= lockDate)
        final entryDay = DateTime(
          draft.effectiveDate.year,
          draft.effectiveDate.month,
          draft.effectiveDate.day,
        );
        final lockDay = DateTime(
          lockDate.year,
          lockDate.month,
          lockDate.day,
        );

        if (!entryDay.isAfter(lockDay)) {
          throw PeriodClosedException(
            date: draft.effectiveDate,
            lockDate: lockDate,
          );
        }
      }
    }

    // 2. Double-entry balance validation in integer minor units
    if (draft.lines.isEmpty) {
      throw StateError('Cannot write journal entry with zero lines: ${draft.entryNo}');
    }

    if (!draft.isBalanced) {
      throw StateError(
        'Unbalanced journal entry ${draft.entryNo}: debits=${draft.totalDebitMinor}, credits=${draft.totalCreditMinor}',
      );
    }

    // 3. Insert journal entry header
    final entryId = await txn.insert(
      'journal_entries',
      draft.toHeaderMap(),
    );

    // 4. Batch insert journal lines
    for (final line in draft.lines) {
      await txn.insert(
        'journal_lines',
        line.toMap(entryId),
      );
    }

    return entryId;
  }
}
