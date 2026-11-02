import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/business.dart';
import '../../models/currency.dart';
import '../../utils/money_utils.dart';
import '../backup_service.dart';
import 'journal_draft.dart';
import 'journal_writer.dart';
import 'ledger.dart';
import 'ledger_service.dart';

/// Diagnostic parity snapshot between the persisted journal and derived ledger.
class ParityStatus {
  final bool isParity;
  final bool isBackfilled;
  final bool reportsFromJournal;
  final int entryCount;
  final String? mismatchReason;

  const ParityStatus({
    required this.isParity,
    required this.isBackfilled,
    required this.reportsFromJournal,
    required this.entryCount,
    this.mismatchReason,
  });
}

/// Authoritative backfill engine that populates the persisted double-entry journal
/// from historical documents and stock movements (P4).
///
/// Backfill copies EXACTLY what the derived ledger produces, including historical quirks,
/// flagged with `origin = 'legacy_backfill'`.
/// If parity fails for any reason, the entire operation is rolled back.
class JournalBackfillService {
  JournalBackfillService._();

  static const String settingKeyBackfilledAt = 'journal_backfilled_at';
  static const String settingKeyBackfillCursor = 'journal_backfill_cursor';
  static const int defaultBatchSize = 100;
  static Future<int>? _activeRun;

  /// Returns true if backfill is actively executing.
  static bool get isRunning => _activeRun != null;

  /// Returns the current backfill checkpoint cursor (0 if not in progress).
  static Future<int> getBackfillCursor({DatabaseExecutor? txn}) async {
    final val = await DatabaseHelper.instance.getSetting(
      settingKeyBackfillCursor,
      txn: txn,
    );
    return val != null ? (int.tryParse(val) ?? 0) : 0;
  }

  /// Returns true if backfill has already been executed.
  static Future<bool> isBackfillCompleted({DatabaseExecutor? txn}) async {
    final val = await DatabaseHelper.instance.getSetting(
      settingKeyBackfilledAt,
      txn: txn,
    );
    return val != null && val.isNotEmpty;
  }

  /// Runs backfill if not already completed and historical data exists.
  /// Deduplicates concurrent invocations by sharing the in-flight Future.
  /// Returns the number of entries backfilled, or 0 if skipped.
  static Future<int> backfillIfNeeded({
    Database? dbOverride,
    int batchSize = defaultBatchSize,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (_activeRun != null) {
      return await _activeRun!;
    }

    final completer = Completer<int>();
    _activeRun = completer.future;

    try {
      final db = dbOverride ?? await DatabaseHelper.instance.database;

      final isDone = await isBackfillCompleted(txn: db);
      if (isDone) {
        completer.complete(0);
        return 0;
      }

      // Check if any documents or movements exist
      final docCountRows = await db.rawQuery(
        "SELECT COUNT(*) as count FROM documents WHERE status != 'draft' AND status != 'cancelled'",
      );
      final docCount = (docCountRows.first['count'] as num?)?.toInt() ?? 0;

      final movCountRows = await db.rawQuery(
        'SELECT COUNT(*) as count FROM stock_movements',
      );
      final movCount = (movCountRows.first['count'] as num?)?.toInt() ?? 0;

      if (docCount == 0 && movCount == 0) {
        // Clean slate; mark as backfilled immediately
        await DatabaseHelper.instance.setSetting(
          settingKeyBackfilledAt,
          DateTime.now().toIso8601String(),
          txn: db,
        );
        completer.complete(0);
        return 0;
      }

      final count = await runBackfill(db, batchSize: batchSize, onProgress: onProgress);
      completer.complete(count);
      return count;
    } catch (e, st) {
      completer.completeError(e, st);
      try {
        final db = dbOverride ?? await DatabaseHelper.instance.database;
        await DatabaseHelper.instance.setSetting(
          'journal_parity_failed_at',
          DateTime.now().toIso8601String(),
          txn: db,
        );
        await DatabaseHelper.instance.setSetting(
          'journal_parity_failure_reason',
          'Backfill failure: $e',
          txn: db,
        );
        await DatabaseHelper.instance.logAuditEvent(
          'backfill_failed',
          details: 'error=$e',
        );
      } catch (_) {}
      rethrow;
    } finally {
      _activeRun = null;
    }
  }

  /// Core backfill transaction:
  /// 1. Reads derived ledger output for business base currency.
  /// 2. Converts each derived [JournalEntry] into a balanced [JournalEntryDraft] with `origin = 'legacy_backfill'`.
  /// 3. Writes drafts in bounded, atomic, checkpointed batches.
  /// 4. Rigorously verifies account-by-account parity against derived trial balance upon completion.
  /// 5. If parity fails, throws [StateError] which aborts without marking completed.
  /// 6. Marks backfill completed and clears cursor.
  static Future<int> runBackfill(
    Database db, {
    int batchSize = defaultBatchSize,
    void Function(int processed, int total)? onProgress,
  }) async {
    try {
      final cursorVal = await DatabaseHelper.instance.getSetting(
        settingKeyBackfillCursor,
        txn: db,
      );
      var cursor = cursorVal != null ? (int.tryParse(cursorVal) ?? 0) : 0;

      // Invariant: automatic safety backup before modifying historical data (first start only)
      if (cursor == 0) {
        try {
          await BackupService.createSafetyBackup();
        } catch (_) {}

        // When starting fresh (cursor == 0), purge ALL journal lines and journal entries completely
        await db.delete('journal_lines');
        await db.delete('journal_entries');
      }

      final bRows = await db.query('businesses', limit: 1);
      final business = bRows.isNotEmpty ? Business.fromMap(bRows.first) : null;
      final baseCurrency = business?.currencyCode ?? 'SDG';
      final decimalDigits = Currency.decimalDigitsForCode(baseCurrency);

      // Derive ledger entries for the base currency (offloaded to worker isolate in LedgerService)
      final book = await LedgerService.buildDerived(
        currencyCode: baseCurrency,
        executor: db,
      );
      final derivedEntries = book.entries;
      final total = derivedEntries.length;

      var backfilledCount = 0;

      // Process in bounded, atomic, checkpointed batches
      while (cursor < total) {
        final end = (cursor + batchSize < total) ? cursor + batchSize : total;
        final batch = derivedEntries.sublist(cursor, end);

        await db.transaction((txn) async {
          var seq = cursor + 1;
          for (final e in batch) {
            if (e.lines.isEmpty) {
              seq++;
              continue; // skip zero-line uncosted placeholders
            }

            final lines = <JournalLineDraft>[];
            var totalDebit = 0;
            var totalCredit = 0;

            for (final l in e.lines) {
              final drMinor = MoneyUtils.toMinorUnits(l.debit, decimalDigits);
              final crMinor = MoneyUtils.toMinorUnits(l.credit, decimalDigits);
              totalDebit += drMinor;
              totalCredit += crMinor;
              lines.add(
                JournalLineDraft(
                  accountCode: l.account.code,
                  debitMinor: drMinor,
                  creditMinor: crMinor,
                ),
              );
            }

            // Guarantee exact integer minor unit balance
            final diff = totalDebit - totalCredit;
            if (diff != 0 && lines.isNotEmpty) {
              final firstCredit = lines.firstWhere(
                (l) => l.creditMinor > 0,
                orElse: () => lines.first,
              );
              final idx = lines.indexOf(firstCredit);
              if (firstCredit.creditMinor > 0) {
                lines[idx] = JournalLineDraft(
                  accountCode: firstCredit.accountCode,
                  debitMinor: firstCredit.debitMinor,
                  creditMinor: firstCredit.creditMinor + diff,
                  productId: firstCredit.productId,
                  contactId: firstCredit.contactId,
                );
              } else {
                lines[0] = JournalLineDraft(
                  accountCode: lines[0].accountCode,
                  debitMinor: lines[0].debitMinor - diff,
                  creditMinor: lines[0].creditMinor,
                  productId: lines[0].productId,
                  contactId: lines[0].contactId,
                );
              }
            }

            final sourceType = _mapSourceType(e.source);
            final draft = JournalEntryDraft(
              entryNo: 'JE-BACKFILL-$seq',
              effectiveDate: e.date,
              postedAt: DateTime.now(),
              sourceType: sourceType,
              sourceId: e.documentId,
              origin: 'legacy_backfill',
              memo: e.reference,
              lines: lines,
            );
            seq++;

            await JournalWriter.write(txn, draft, lockDateOverride: e.date);
            backfilledCount++;
          }

          // Atomically commit checkpoint cursor with the batch
          await DatabaseHelper.instance.setSetting(
            settingKeyBackfillCursor,
            end.toString(),
            txn: txn,
          );
        });

        cursor = end;
        onProgress?.call(cursor, total);

        // Yield to the event loop so UI / compositor never starves or drops frames
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Rigorous account-by-account parity check across full derived trial balance
      await verifyParity(executor: db, currencyCode: baseCurrency);

      // Parity verified: mark backfill completed and clear cursor
      await db.transaction((txn) async {
        await DatabaseHelper.instance.setSetting(
          settingKeyBackfilledAt,
          DateTime.now().toIso8601String(),
          txn: txn,
        );
        await DatabaseHelper.instance.setSetting(
          settingKeyBackfillCursor,
          null,
          txn: txn,
        );
      });

      await DatabaseHelper.instance.logAuditEvent(
        'backfill_completed',
        details: 'entries=$total',
      );

      return backfilledCount;
    } catch (e) {
      // If verifyParity fails or any exception occurs, clean up any incomplete/corrupted entries
      // and reset journal_backfill_cursor so the database does not stay in a corrupted double-counted state.
      try {
        await db.delete('journal_lines');
        await db.delete('journal_entries');
        await DatabaseHelper.instance.setSetting(
          settingKeyBackfillCursor,
          null,
          txn: db,
        );
      } catch (_) {}
      rethrow;
    }
  }

  /// Executes a full, clean journal rebuild:
  /// 1. Clears journal_lines and journal_entries completely.
  /// 2. Clears journal_backfilled_at and journal_backfill_cursor in app_settings.
  /// 3. Re-runs runBackfill(db).
  /// 4. Asserting that verifyParity succeeds with 100% match.
  static Future<int> rebuildJournal({
    Database? dbOverride,
    int batchSize = defaultBatchSize,
    void Function(int processed, int total)? onProgress,
  }) async {
    final db = dbOverride ?? await DatabaseHelper.instance.database;

    // 1. Clearing journal_lines and journal_entries
    await db.delete('journal_lines');
    await db.delete('journal_entries');

    // 2. Clearing journal_backfilled_at and journal_backfill_cursor in app_settings
    await DatabaseHelper.instance.setSetting(
      settingKeyBackfilledAt,
      null,
      txn: db,
    );
    await DatabaseHelper.instance.setSetting(
      settingKeyBackfillCursor,
      null,
      txn: db,
    );

    // 3. Re-running JournalBackfillService.runBackfill(db)
    final count = await runBackfill(
      db,
      batchSize: batchSize,
      onProgress: onProgress,
    );

    // 4. Asserting that verifyParity succeeds with 100% match
    await verifyParity(executor: db);

    return count;
  }

  /// Verifies parity between persisted journal and derived ledger on an existing database.
  /// Throws [StateError] if any discrepancy is found.
  static Future<void> verifyParity({
    DatabaseExecutor? executor,
    String? currencyCode,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final bRows = await db.query('businesses', limit: 1);
    final business = bRows.isNotEmpty ? Business.fromMap(bRows.first) : null;
    final base = business?.currencyCode ?? 'SDG';
    final selectedCurrency = currencyCode ?? base;
    final decimalDigits = Currency.decimalDigitsForCode(selectedCurrency);

    // Always compare against derived reference
    final book = await LedgerService.buildDerived(
      currencyCode: selectedCurrency,
      executor: db,
    );
    final derivedTB = AccountingReports.trialBalance(book.entries);

    final journalRows = await db.rawQuery('''
      SELECT 
        l.account_code,
        COALESCE(SUM(l.debit_minor), 0) as dr,
        COALESCE(SUM(l.credit_minor), 0) as cr
      FROM journal_lines l
      JOIN journal_entries e ON l.entry_id = e.id
      GROUP BY l.account_code
    ''');

    final journalMap = <String, int>{};
    for (final r in journalRows) {
      final code = r['account_code'] as String;
      final dr = (r['dr'] as num).toInt();
      final cr = (r['cr'] as num).toInt();
      final acct = Accounts.byCode(code);
      journalMap[code] = acct.debitNormal ? (dr - cr) : (cr - dr);
    }

    for (final acct in Accounts.all) {
      final dBal = derivedTB.rows
          .firstWhere(
            (r) => r.account.code == acct.code,
            orElse: () => AccountBalance(acct, 0, 0),
          )
          .balance;
      final derivedMinor = MoneyUtils.toMinorUnits(dBal, decimalDigits);
      final journalMinor = journalMap[acct.code] ?? 0;

      if (derivedMinor != journalMinor) {
        throw StateError(
          'Parity mismatch on account ${acct.code}: derived=$derivedMinor, journal=$journalMinor',
        );
      }
    }
  }

  /// Diagnostic check returning full parity status, entry count, and flags.
  static Future<ParityStatus> checkParityStatus({
    DatabaseExecutor? executor,
    String? currencyCode,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final isBackfilled = await isBackfillCompleted(txn: db);
    final isReports = await LedgerService.isJournalReportsEnabled(txn: db);

    int count = 0;
    try {
      final res = await db.rawQuery('SELECT COUNT(*) as c FROM journal_entries');
      if (res.isNotEmpty) {
        count = (res.first['c'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    try {
      await verifyParity(executor: db, currencyCode: currencyCode);
      return ParityStatus(
        isParity: true,
        isBackfilled: isBackfilled,
        reportsFromJournal: isReports,
        entryCount: count,
      );
    } catch (e) {
      return ParityStatus(
        isParity: false,
        isBackfilled: isBackfilled,
        reportsFromJournal: isReports,
        entryCount: count,
        mismatchReason: e.toString(),
      );
    }
  }

  static String _mapSourceType(EntrySource source) {
    switch (source) {
      case EntrySource.invoice:
        return 'invoice';
      case EntrySource.invoicePayment:
      case EntrySource.purchasePayment:
        return 'payment';
      case EntrySource.purchase:
        return 'purchase';
      case EntrySource.receipt:
        return 'receipt';
      case EntrySource.expenseVoucher:
        return 'voucher';
      case EntrySource.costOfSales:
        return 'cogs';
      case EntrySource.stockAdjustment:
        return 'stock_adjustment';
      case EntrySource.openingStock:
        return 'opening_stock';
    }
  }
}
