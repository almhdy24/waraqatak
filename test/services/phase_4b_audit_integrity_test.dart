import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/database/reference_pricing_dao.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4B: Audit Log Integrity & Hash Chain Tests', () {
    late Directory tempDir;
    late DatabaseHelper db;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tempDir = Directory.systemTemp.createTempSync('phase_4b_test');
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
          name: 'Test Audit Business',
          ownerName: 'Owner',
          phone: '123456789',
          address: 'Sana\'a',
          currencyCode: 'YER',
        ),
      );
    });

    test('4B-1: ReferencePricingDao.writeAudit creates hashed audit rows within transaction', () async {
      final sqlDb = await db.database;
      await sqlDb.transaction((txn) async {
        await ReferencePricingDao.writeAudit(
          txn,
          action: 'test_pricing_action',
          entityType: 'exchange_rate',
          details: {'test_key': 'test_val'},
        );
      });

      final rows = await sqlDb.rawQuery(
        'SELECT * FROM audit_log WHERE action = ?',
        ['test_pricing_action'],
      );
      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['hash'], isNotNull);
      expect((row['hash'] as String).length, equals(64)); // SHA-256
      expect(row['prev_hash'], isNotNull);

      final verification = await AuditService.instance.verifyChain(db: sqlDb);
      expect(verification.isValid, isTrue);
    });

    test('4B-2: stocktake_started and stocktake_cancelled produce tamper-evident chained audit rows', () async {
      await ProductService.createProduct(
        name: 'Stocktake Item',
        salePrice: 100,
        stockQuantity: 10,
      );

      // Start stocktake
      final session = await db.createStocktakeSession();
      final startRows = await (await db.database).rawQuery(
        'SELECT * FROM audit_log WHERE action = ? AND entity_id = ?',
        ['stocktake_started', session.id],
      );
      expect(startRows.length, equals(1));
      expect(startRows.first['hash'], isNotNull);
      expect(startRows.first['prev_hash'], isNotNull);

      // Cancel stocktake
      await db.cancelStocktakeSession(session.id!);
      final cancelRows = await (await db.database).rawQuery(
        'SELECT * FROM audit_log WHERE action = ? AND entity_id = ?',
        ['stocktake_cancelled', session.id],
      );
      expect(cancelRows.length, equals(1));
      expect(cancelRows.first['hash'], isNotNull);
      expect(cancelRows.first['prev_hash'], equals(startRows.first['hash']));

      final verification = await AuditService.instance.verifyChain();
      expect(verification.isValid, isTrue);
    });

    test('4B-3: Concurrent logEvent calls and transaction write preserve hash chain integrity', () async {
      final sqlDb = await db.database;

      // Reset chain lock to ensure fresh test state
      AuditService.instance.resetChainLockForTesting();

      // Fire 10 concurrent logEvent calls on non-transaction path + 1 inside a separate transaction
      final futures = <Future<void>>[];
      for (int i = 0; i < 10; i++) {
        futures.add(
          AuditService.instance.logEvent(
            sqlDb,
            'concurrent_event_$i',
            entityType: 'test',
            details: 'payload_$i',
          ),
        );
      }

      // Add a concurrent transaction write
      futures.add(
        sqlDb.transaction((txn) async {
          await AuditService.instance.logEvent(
            txn,
            'txn_event',
            entityType: 'test',
            details: 'txn_payload',
          );
        }),
      );

      await Future.wait(futures);

      final verification = await AuditService.instance.verifyChain(db: sqlDb);
      expect(verification.isValid, isTrue, reason: verification.error);
      expect(verification.verifiedCount, greaterThanOrEqualTo(11));
    });

    test('4B-4: verifyChain rejects forged audit_chain_genesis with forged prev_hash', () async {
      final testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE audit_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              action TEXT,
              entity_type TEXT,
              entity_id INTEGER,
              details TEXT,
              timestamp TEXT,
              user_id TEXT,
              user_name TEXT,
              device_id TEXT,
              workspace_id TEXT,
              prev_hash TEXT,
              hash TEXT
            )
          ''');
        },
      );

      try {
        // Compute forged genesis row with invalid prev_hash
        const forgedPrevHash =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        final now = DateTime.now().toIso8601String();
        final hash = await AuditService.instance.computeHash(
          action: 'audit_chain_genesis',
          entityType: 'system',
          entityId: null,
          details: 'forged genesis details',
          timestamp: now,
          userId: 'system',
          userName: null,
          deviceId: 'dev1',
          prevHash: forgedPrevHash,
        );

        await testDb.rawInsert('''
          INSERT INTO audit_log (
            action, entity_type, details, timestamp,
            user_id, device_id, workspace_id, prev_hash, hash
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          'audit_chain_genesis',
          'system',
          'forged genesis details',
          now,
          'system',
          'dev1',
          AccessDao.defaultWorkspaceId,
          forgedPrevHash,
          hash,
        ]);

        final result = await AuditService.instance.verifyChain(db: testDb);
        expect(result.isValid, isFalse);
        expect(result.error, contains('prev_hash mismatch'));
      } finally {
        await testDb.close();
      }
    });
  });
}
