import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/services/accounting/journal_draft.dart';
import 'package:warqatek/services/accounting/journal_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('journal_writer_test');
    final dbPath = '${tempDir.path}/test_writer.db';
    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseHelper.dbVersion,
        onCreate: (db, version) async {
          await DatabaseHelper.instance.createTablesForTest(db);
        },
      ),
    );
  });

  tearDownAll(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('JournalWriter Invariants & Validations', () {
    test('Balanced entry writes successfully and inserts headers and lines', () async {
      await db.transaction((txn) async {
        final draft = JournalEntryDraft(
          entryNo: 'JE-TEST-001',
          effectiveDate: DateTime(2026, 5, 10),
          postedAt: DateTime(2026, 5, 10, 12, 0),
          sourceType: 'invoice',
          sourceId: 101,
          memo: 'Test Invoice',
          lines: const [
            JournalLineDraft(
              accountCode: '1130',
              debitMinor: 25000,
            ),
            JournalLineDraft(
              accountCode: '4100',
              creditMinor: 25000,
            ),
          ],
        );

        final entryId = await JournalWriter.write(txn, draft);
        expect(entryId, isPositive);

        final entries = await txn.query('journal_entries', where: 'id = ?', whereArgs: [entryId]);
        expect(entries.length, 1);
        expect(entries.first['entry_no'], 'JE-TEST-001');

        final lines = await txn.query('journal_lines', where: 'entry_id = ?', whereArgs: [entryId]);
        expect(lines.length, 2);
        expect(lines[0]['debit_minor'], 25000);
        expect(lines[1]['credit_minor'], 25000);
      });
    });

    test('Unbalanced entry throws StateError and aborts write', () async {
      final draft = JournalEntryDraft(
        entryNo: 'JE-UNBALANCED-001',
        effectiveDate: DateTime(2026, 5, 11),
        postedAt: DateTime(2026, 5, 11, 12, 0),
        sourceType: 'invoice',
        sourceId: 102,
        memo: 'Unbalanced',
        lines: const [
          JournalLineDraft(
            accountCode: '1130',
            debitMinor: 25000,
          ),
          JournalLineDraft(
            accountCode: '4100',
            creditMinor: 24000, // 1000 minor disparity!
          ),
        ],
      );

      await expectLater(
        () => db.transaction((txn) async {
          await JournalWriter.write(txn, draft);
        }),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unbalanced journal entry'),
        )),
      );

      final check = await db.query('journal_entries', where: 'entry_no = ?', whereArgs: ['JE-UNBALANCED-001']);
      expect(check, isEmpty);
    });

    test('Zero lines entry throws StateError', () async {
      final draft = JournalEntryDraft(
        entryNo: 'JE-EMPTY-001',
        effectiveDate: DateTime(2026, 5, 11),
        postedAt: DateTime(2026, 5, 11, 12, 0),
        sourceType: 'invoice',
        lines: const [],
      );

      await expectLater(
        () => db.transaction((txn) async {
          await JournalWriter.write(txn, draft);
        }),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('zero lines'),
        )),
      );
    });

    test('Period lock rejects entries dated on or before lock date', () async {
      final lockDate = DateTime(2026, 6, 30);

      // 1. Entry on lock date throws PeriodClosedException
      final lockedDraft = JournalEntryDraft(
        entryNo: 'JE-LOCKED-001',
        effectiveDate: DateTime(2026, 6, 30),
        postedAt: DateTime(2026, 7, 5),
        sourceType: 'invoice',
        lines: const [
          JournalLineDraft(accountCode: '1130', debitMinor: 1000),
          JournalLineDraft(accountCode: '4100', creditMinor: 1000),
        ],
      );

      await expectLater(
        () => db.transaction((txn) async {
          await JournalWriter.write(txn, lockedDraft, lockDateOverride: lockDate);
        }),
        throwsA(isA<PeriodClosedException>()),
      );

      // 2. Entry prior to lock date throws PeriodClosedException
      final priorDraft = JournalEntryDraft(
        entryNo: 'JE-LOCKED-002',
        effectiveDate: DateTime(2026, 6, 15),
        postedAt: DateTime(2026, 7, 5),
        sourceType: 'invoice',
        lines: const [
          JournalLineDraft(accountCode: '1130', debitMinor: 1000),
          JournalLineDraft(accountCode: '4100', creditMinor: 1000),
        ],
      );

      await expectLater(
        () => db.transaction((txn) async {
          await JournalWriter.write(txn, priorDraft, lockDateOverride: lockDate);
        }),
        throwsA(isA<PeriodClosedException>()),
      );

      // 3. Entry after lock date succeeds
      final openDraft = JournalEntryDraft(
        entryNo: 'JE-OPEN-001',
        effectiveDate: DateTime(2026, 7, 1),
        postedAt: DateTime(2026, 7, 5),
        sourceType: 'invoice',
        lines: const [
          JournalLineDraft(accountCode: '1130', debitMinor: 1000),
          JournalLineDraft(accountCode: '4100', creditMinor: 1000),
        ],
      );

      final openId = await db.transaction((txn) async {
        return await JournalWriter.write(txn, openDraft, lockDateOverride: lockDate);
      });
      expect(openId, isPositive);

      // 4. Origin legacy_backfill bypasses period lock
      final backfillDraft = JournalEntryDraft(
        entryNo: 'JE-BACKFILL-001',
        effectiveDate: DateTime(2026, 5, 1),
        postedAt: DateTime(2026, 7, 5),
        sourceType: 'invoice',
        origin: 'legacy_backfill',
        lines: const [
          JournalLineDraft(accountCode: '1130', debitMinor: 1000),
          JournalLineDraft(accountCode: '4100', creditMinor: 1000),
        ],
      );

      final backfillId = await db.transaction((txn) async {
        return await JournalWriter.write(txn, backfillDraft, lockDateOverride: lockDate);
      });
      expect(backfillId, isPositive);
    });

    test('Shadow isolation savepoint catches journal crash and allows transaction commit when reports are OFF', () async {
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      final doc = Document(
        id: 777,
        type: 'invoice',
        documentNumber: 'INV-ISOLATE-001',
        date: DateTime(2026, 4, 1),
        subtotal: 100.0,
        discount: 0.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        total: 100.0,
        paid: 0.0,
        remaining: 100.0,
        currencyCode: 'SDG',
      );

      // Force journal entries table to fail on insert
      await rawDb.execute('''
        CREATE TRIGGER fail_shadow_entries BEFORE INSERT ON journal_entries
        BEGIN
          SELECT RAISE(ABORT, 'Simulated shadow engine crash');
        END;
      ''');

      try {
        final result = await rawDb.transaction((txn) async {
          // Shadow posting should isolate the error, rollback to savepoint, log audit, and return empty list
          final ids = await JournalWriter.postDocumentIssued(
            txn,
            doc,
            const [],
          );
          return ids;
        });

        expect(result, isEmpty, reason: 'Failed shadow write must return fallback empty list');

        // Verify parity failure was flagged in settings
        final failureReason = await db.getSetting('journal_parity_failure_reason');
        expect(failureReason, contains('Shadow posting failed on document_issued'));
      } finally {
        await rawDb.execute('DROP TRIGGER fail_shadow_entries');
      }
    });
  });
}
