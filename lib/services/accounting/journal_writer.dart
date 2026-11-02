import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/document.dart';
import '../../models/document_item.dart';
import '../../models/document_payment.dart';
import '../../models/document_status.dart';
import '../../models/journal_entry_entity.dart';
import '../../models/journal_line_entity.dart';
import '../../models/product.dart';
import 'journal_draft.dart';
import 'posting_service.dart';

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

  static int _spCounter = 0;

  static Future<T> _runIsolatedShadow<T>(
    DatabaseExecutor txn, {
    required Future<T> Function() action,
    required T fallback,
    required String operation,
  }) async {
    final shadowEnabled =
        await DatabaseHelper.instance.isJournalShadowWriteEnabled(txn: txn);
    if (!shadowEnabled) return fallback;

    final spName =
        'sp_shadow_${DateTime.now().microsecondsSinceEpoch}_${++_spCounter}';
    await txn.execute('SAVEPOINT $spName');

    try {
      final result = await action();
      await txn.execute('RELEASE SAVEPOINT $spName');
      return result;
    } catch (e) {
      if (e is PeriodClosedException) {
        try {
          await txn.execute('ROLLBACK TO SAVEPOINT $spName');
          await txn.execute('RELEASE SAVEPOINT $spName');
        } catch (_) {}
        rethrow;
      }

      try {
        await txn.execute('ROLLBACK TO SAVEPOINT $spName');
        await txn.execute('RELEASE SAVEPOINT $spName');
      } catch (_) {}

      try {
        await DatabaseHelper.instance.logAuditEvent(
          'shadow_posting_failure',
          details: 'op=$operation error=$e',
          txn: txn,
        );
      } catch (_) {}

      try {
        await DatabaseHelper.instance.setSetting(
          'journal_parity_failed_at',
          DateTime.now().toIso8601String(),
          txn: txn,
        );
        await DatabaseHelper.instance.setSetting(
          'journal_parity_failure_reason',
          'Shadow posting failed on $operation: $e',
          txn: txn,
        );
      } catch (_) {}

      try {
        final reportsEnabled =
            await DatabaseHelper.instance.isJournalReportsEnabled(txn: txn);
        if (reportsEnabled) {
          await DatabaseHelper.instance.setSetting(
            'journal_reports_enabled',
            'false',
            txn: txn,
          );
        }
      } catch (_) {}

      return fallback;
    }
  }

  /// Writes a draft isolated in a savepoint, protecting caller from shadow posting failures.
  static Future<int?> postDraftIsolated(
    DatabaseExecutor txn,
    JournalEntryDraft draft, {
    required String operation,
    DateTime? lockDateOverride,
  }) async {
    return await _runIsolatedShadow(
      txn,
      fallback: null,
      operation: operation,
      action: () async {
        return await write(txn, draft, lockDateOverride: lockDateOverride);
      },
    );
  }

  /// Generates and persists journal entries for an issued document (invoice, purchase, receipt, voucher).
  static Future<List<int>> postDocumentIssued(
    DatabaseExecutor txn,
    Document doc,
    List<DocumentItem> items, {
    Document? parentDoc,
    DateTime? now,
    String origin = 'live',
  }) async {
    return await _runIsolatedShadow(
      txn,
      fallback: const <int>[],
      operation: 'document_issued',
      action: () async {
        if (doc.status == DocumentStatus.draft ||
            doc.status == DocumentStatus.cancelled ||
            doc.type == 'quotation') {
          return const <int>[];
        }

        final productIds =
            items.map((i) => i.productId).whereType<int>().toSet();
        final products = <int, Product>{};
        if (productIds.isNotEmpty) {
          final placeholders = List.filled(productIds.length, '?').join(',');
          final pRows = await txn.query(
            'products',
            where: 'id IN ($placeholders)',
            whereArgs: productIds.toList(),
          );
          for (final r in pRows) {
            final p = Product.fromMap(r);
            if (p.id != null) products[p.id!] = p;
          }
        }

        Document? effectiveParentDoc = parentDoc;
        if (effectiveParentDoc == null && doc.relatedDocumentId != null) {
          final pDocRows = await txn.query(
            'documents',
            where: 'id = ?',
            whereArgs: [doc.relatedDocumentId],
          );
          if (pDocRows.isNotEmpty) {
            effectiveParentDoc = Document.fromMap(pDocRows.first);
          }
        }

        var entrySeq = 1;
        final drafts = PostingService.postDocumentIssued(
          doc: doc,
          items: items,
          products: products,
          parentDoc: effectiveParentDoc,
          nextEntryNo: (prefix) =>
              '$prefix-${doc.id ?? 0}-${DateTime.now().microsecondsSinceEpoch}-${entrySeq++}',
          now: now,
          origin: origin,
        );

        final ids = <int>[];
        for (final draft in drafts) {
          final id = await write(txn, draft);
          ids.add(id);
        }
        return ids;
      },
    );
  }

  /// Generates and persists a journal entry for an unlinked payment on an issued document.
  static Future<int?> postPaymentRecorded(
    DatabaseExecutor txn, {
    required DocumentPayment payment,
    required Document parentDoc,
    DateTime? now,
    String origin = 'live',
  }) async {
    return await _runIsolatedShadow(
      txn,
      fallback: null,
      operation: 'payment_recorded',
      action: () async {
        final timestamp = now ?? DateTime.now();
        final draft = PostingService.postPaymentRecorded(
          payment: payment,
          parentDoc: parentDoc,
          nextEntryNo: (prefix) =>
              '$prefix-PAY-${payment.id ?? 0}-${timestamp.microsecondsSinceEpoch}',
          now: timestamp,
          origin: origin,
        );

        return await write(txn, draft);
      },
    );
  }

  /// Authoritatively reverses all active journal entries for a document (D3).
  /// Reversals are effective-dated at the original entry's effective_date.
  static Future<List<int>> reverseDocument(
    DatabaseExecutor txn,
    int documentId, {
    DateTime? now,
    String? memo,
  }) async {
    return await _runIsolatedShadow(
      txn,
      fallback: const <int>[],
      operation: 'document_reversed',
      action: () async {
        final timestamp = now ?? DateTime.now();

        final entryRows = await txn.rawQuery('''
      SELECT e.* FROM journal_entries e
      WHERE (e.source_id = ? AND e.source_type IN ('invoice', 'purchase', 'receipt', 'voucher', 'cogs', 'payment'))
         OR (e.source_type = 'payment' AND e.source_id IN (
              SELECT id FROM document_payments WHERE document_id = ?
            ))
      ORDER BY e.id ASC
    ''', [documentId, documentId]);

        if (entryRows.isEmpty) return const <int>[];

        final existingEntries = <JournalEntryEntity>[];
        for (final r in entryRows) {
          final eId = r['id'] as int;
          final lineRows = await txn.query(
            'journal_lines',
            where: 'entry_id = ?',
            whereArgs: [eId],
            orderBy: 'id ASC',
          );
          final lines =
              lineRows.map((lr) => JournalLineEntity.fromMap(lr)).toList();
          existingEntries.add(JournalEntryEntity.fromMap(r, lines: lines));
        }

        final reversedIds = existingEntries
            .where((e) => e.reversesEntryId != null)
            .map((e) => e.reversesEntryId!)
            .toSet();

        final reversalIds = <int>[];
        var seq = 1;
        for (final e in existingEntries) {
          if (reversedIds.contains(e.id)) continue;
          if (e.reversesEntryId != null) continue;

          final revLines = e.lines
              .map(
                (l) => JournalLineDraft(
                  accountCode: l.accountCode,
                  debitMinor: l.creditMinor,
                  creditMinor: l.debitMinor,
                  productId: l.productId,
                  contactId: l.contactId,
                ),
              )
              .toList();

          final revDraft = JournalEntryDraft(
            entryNo:
                'JE-REV-${e.id}-${timestamp.microsecondsSinceEpoch}-${seq++}',
            effectiveDate:
                e.effectiveDate, // D3: dated at original entry's effective date
            postedAt: timestamp,
            sourceType: e.sourceType,
            sourceId: e.sourceId,
            revision: e.revision + 1,
            memo: memo ?? 'Reversal of entry ${e.entryNo}',
            reversesEntryId: e.id,
            origin: 'live',
            lines: revLines,
          );

          final revId = await write(txn, revDraft);
          reversalIds.add(revId);
        }

        return reversalIds;
      },
    );
  }
}
