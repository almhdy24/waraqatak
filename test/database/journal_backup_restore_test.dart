import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/currency.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/journal_draft.dart';
import 'package:warqatek/services/accounting/journal_writer.dart';
import 'package:warqatek/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('journal_backup_restore_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('Round-trip export and restore with journal tables preserves all entries and settings', () async {
    final db = DatabaseHelper.instance;

    // 1. Seed business, product, and journal entries
    await db.insertBusiness(
      const Business(
        name: 'متجر الخرطوم',
        ownerName: 'محمد',
        phone: '0912345678',
        address: 'الخرطوم',
        currencyCode: 'SDG',
      ),
    );

    final rawDb = await db.database;
    await rawDb.transaction((txn) async {
      await JournalWriter.write(
        txn,
        JournalEntryDraft(
          entryNo: 'JE-BK-001',
          effectiveDate: DateTime(2026, 4, 1),
          postedAt: DateTime(2026, 4, 1, 10, 0),
          sourceType: 'invoice',
          sourceId: 1,
          memo: 'Backup test invoice',
          lines: const [
            JournalLineDraft(accountCode: '1130', debitMinor: 15000),
            JournalLineDraft(accountCode: '4100', creditMinor: 15000),
          ],
        ),
      );
    });

    await db.setSetting('test_custom_setting', 'sample_value');

    // 2. Export database JSON
    final jsonStr = await BackupService.buildBackupJsonForTest();
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    final data = jsonMap['data'] as Map<String, dynamic>;

    expect(data.containsKey('accounts'), isTrue);
    expect(data.containsKey('journal_entries'), isTrue);
    expect(data.containsKey('journal_lines'), isTrue);
    expect(data.containsKey('app_settings'), isTrue);

    final exportedEntries = data['journal_entries'] as List;
    expect(exportedEntries.length, 1);
    expect(exportedEntries.first['entry_no'], 'JE-BK-001');

    // 3. Clear data and restore
    final success = await BackupService.restoreFromJsonMap(
      jsonMap,
      createSafetyBackup: false,
    );
    expect(success, isTrue);

    // 4. Verify restored state
    final restoredEntries = await rawDb.query('journal_entries');
    expect(restoredEntries.length, 1);
    expect(restoredEntries.first['entry_no'], 'JE-BK-001');

    final restoredLines = await rawDb.query('journal_lines');
    expect(restoredLines.length, 2);

    final customSetting = await db.getSetting('test_custom_setting');
    expect(customSetting, 'sample_value');
  });

  test('Restoring legacy backup without journal tables succeeds, seeds accounts, and triggers hook', () async {
    final db = DatabaseHelper.instance;
    final rawDb = await db.database;

    // Construct a legacy backup JSON (no accounts, journal_entries, journal_lines, app_settings)
    final legacyData = {
      'app': BackupService.appId,
      'backup_version': 4,
      'database_version': 24,
      'created_at': DateTime(2025, 12, 1).toIso8601String(),
      'data': {
        'businesses': [
          {
            'name': 'متجر قديم',
            'owner_name': 'عثمان',
            'phone': '0123456789',
            'address': 'أم درمان',
            'currency_code': 'SDG',
          }
        ],
        'contacts': [],
        'products': [
          {
            'name': 'صابون',
            'sale_price': 100.0,
            'purchase_price': 80.0,
            'stock_quantity': 20.0,
          }
        ],
        'product_units': [],
        'documents': [],
        'document_items': [],
        'document_counters': [],
        'document_payments': [],
        'stock_movements': [],
        'tax_profiles': [],
        'payment_methods': [],
        'stocktake_sessions': [],
        'stocktake_items': [],
        'audit_log': [],
      },
    };

    bool legacyHookTriggered = false;
    BackupService.onLegacyBackupRestored = () async {
      legacyHookTriggered = true;
    };

    final success = await BackupService.restoreFromJsonMap(
      legacyData,
      createSafetyBackup: false,
    );
    expect(success, isTrue);
    expect(legacyHookTriggered, isTrue);

    // Verify system accounts were seeded
    final accounts = await rawDb.query('accounts');
    expect(accounts.length, 13);

    // Verify default settings were seeded
    final shadowWrite = await db.isJournalShadowWriteEnabled();
    expect(shadowWrite, isTrue);
    final reportsEnabled = await db.isJournalReportsEnabled();
    expect(reportsEnabled, isFalse);

    // Verify journal tables are clean
    final entries = await rawDb.query('journal_entries');
    expect(entries, isEmpty);

    // Clean up hook
    BackupService.onLegacyBackupRestored = null;
  });
}
