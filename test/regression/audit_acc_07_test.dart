import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/services/accounting/journal_draft.dart';
import 'package:warqatek/services/accounting/journal_writer.dart';
import 'package:warqatek/services/accounting/ledger.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('audit_acc_07_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    db = DatabaseHelper.instance;
  });

  tearDownAll(() async {
    await db.closeDatabase();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await db.closeDatabase();
    if (tempDir.existsSync()) {
      for (final f in tempDir.listSync()) {
        if (f is File) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }

    await db.insertBusiness(
      const Business(
        name: 'ACC-07 Test Business',
        ownerName: 'Test Owner',
        phone: '0123456789',
        address: 'Khartoum',
        currencyCode: 'SDG',
        taxRate: 0.0,
        taxesEnabled: false,
        pricesIncludeTax: false,
      ),
    );
  });

  test('ACC-07 Regression: JournalWriter must rethrow shadow-posting exceptions when journal reports are enabled', () async {
    final rawDb = await db.database;

    // 1. Enable journal reports mode
    await db.setSetting('journal_reports_enabled', 'true');
    expect(await db.isJournalReportsEnabled(), isTrue);

    // 2. Prepare an intentionally unbalanced journal draft (Dr 10,000 != Cr 5,000)
    final unbalancedDraft = JournalEntryDraft(
      entryNo: 'JE-ACC07-UNBALANCED',
      effectiveDate: DateTime(2026, 3, 1),
      postedAt: DateTime.now(),
      sourceType: 'manual',
      sourceId: 999,
      lines: [
        JournalLineDraft(
          accountCode: Accounts.cash.code,
          debitMinor: 10000,
        ),
        JournalLineDraft(
          accountCode: Accounts.salesRevenue.code,
          creditMinor: 5000,
        ),
      ],
    );

    // ACC-07 BUG: In JournalWriter._runIsolatedShadow, when action() fails (here throwing
    // StateError: Unbalanced journal entry), the exception is caught, savepoint is rolled back,
    // journal_reports_enabled is silently set to 'false', and fallback (null) is returned.
    // The exception is NOT rethrown!
    // When journal reports are enabled, shadow exceptions must rethrow so transactions
    // fail atomically instead of corrupting journal parity.
    expect(
      () async => await JournalWriter.postDraftIsolated(
        rawDb,
        unbalancedDraft,
        operation: 'test_posting',
      ),
      throwsA(isA<StateError>()),
      reason: 'ACC-07: When journal_reports_enabled is true, shadow posting errors must rethrow rather than swallowing silently',
    );
  });

  test('ACC-07 Regression: JournalWriter retains shadow fallback when journal reports are disabled', () async {
    final rawDb = await db.database;

    // 1. Ensure journal reports mode is disabled
    await db.setSetting('journal_reports_enabled', 'false');
    expect(await db.isJournalReportsEnabled(), isFalse);

    // 2. Prepare an intentionally unbalanced journal draft
    final unbalancedDraft = JournalEntryDraft(
      entryNo: 'JE-ACC07-UNBALANCED-SHADOW',
      effectiveDate: DateTime(2026, 3, 1),
      postedAt: DateTime.now(),
      sourceType: 'manual',
      sourceId: 998,
      lines: [
        JournalLineDraft(
          accountCode: Accounts.cash.code,
          debitMinor: 10000,
        ),
        JournalLineDraft(
          accountCode: Accounts.salesRevenue.code,
          creditMinor: 5000,
        ),
      ],
    );

    // When journal reports are disabled, shadow mode isolates failure and returns fallback
    final result = await JournalWriter.postDraftIsolated(
      rawDb,
      unbalancedDraft,
      operation: 'test_posting_shadow',
    );
    expect(result, isNull);
  });
}
