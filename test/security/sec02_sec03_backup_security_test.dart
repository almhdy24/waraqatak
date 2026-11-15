import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/backup_encryption_service.dart';
import 'package:warqatek/services/backup_service.dart';

class MockFailingSecureStorage extends FlutterSecureStorage {
  final bool failRead;
  final bool failWrite;
  final bool readBackMismatch;
  final String? overrideReadValue;
  final Map<String, String> backing;
  int readCount = 0;

  MockFailingSecureStorage({
    this.failRead = false,
    this.failWrite = false,
    this.readBackMismatch = false,
    this.overrideReadValue,
    Map<String, String>? initialData,
  }) : backing = initialData != null ? Map.from(initialData) : {},
       super();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    readCount++;
    if (failRead) throw Exception('Simulated KeyStore read failure');
    if (readBackMismatch && readCount > 1) {
      return 'mismatched_readback_key_1111222233334444555566667777888899990000';
    }
    if (overrideReadValue != null) return overrideReadValue;
    return backing[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) throw Exception('Simulated KeyStore write failure');
    if (value != null) {
      backing[key] = value;
    } else {
      backing.remove(key);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory mockBackupDir;
  late Directory mockCacheDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('sec02_sec03_test_');
    mockBackupDir = Directory('${tempDir.path}/mock_backups')
      ..createSync(recursive: true);
    mockCacheDir = Directory('${tempDir.path}/mock_cache')
      ..createSync(recursive: true);

    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    BackupService.resetSafetyKeyCacheForTesting();
    BackupService.safetyBackupOverride = null;
    BackupService.backupDirectoryOverride = () => mockBackupDir;
    await DatabaseHelper.instance.closeDatabase();

    final runDir = Directory.systemTemp.createTempSync('sec_run_');
    await databaseFactory.setDatabasesPath(runDir.path);
    await AccessGuard.runAsSystem(() async {
      await DatabaseHelper.instance.insertBusiness(
        const Business(
          name: 'SEC Business',
          ownerName: 'Owner',
          phone: '0123456789',
          address: 'Khartoum',
          currencyCode: 'SDG',
        ),
      );
    });
  });

  tearDown(() async {
    BackupService.resetSafetyKeyCacheForTesting();
    BackupService.safetyBackupOverride = null;
    BackupService.backupDirectoryOverride = null;
    await DatabaseHelper.instance.closeDatabase();
  });

  group('SEC-02: Safety Backup Key Lifecycle & Persistence', () {
    test(
      'Successful secure-storage write followed by successful read-back persists key durably',
      () async {
        final mockStorage = MockFailingSecureStorage();
        BackupService.secureStorageOverride = mockStorage;

        final key = await BackupService.getSafetyKey();
        expect(key.length, 64);
        expect(RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(key), isTrue);
        expect(mockStorage.backing['warqatek_safety_backup_key'], key);

        // Clear in-memory cache to simulate app restart
        BackupService.resetSafetyKeyCacheForTesting();
        BackupService.secureStorageOverride = mockStorage;

        final keyAfterRestart = await BackupService.getSafetyKey();
        expect(keyAfterRestart, key);
      },
    );

    test(
      'Secure-storage read failure throws BackupKeyPersistenceException and prevents key use',
      () async {
        final mockStorage = MockFailingSecureStorage(failRead: true);
        BackupService.secureStorageOverride = mockStorage;

        expect(
          () => BackupService.getSafetyKey(),
          throwsA(isA<BackupKeyPersistenceException>()),
        );

        expect(
          () => BackupService.createSafetyBackup(),
          throwsA(isA<BackupKeyPersistenceException>()),
        );
      },
    );

    test(
      'Secure-storage write failure throws BackupKeyPersistenceException and prevents safety-backup creation',
      () async {
        final mockStorage = MockFailingSecureStorage(failWrite: true);
        BackupService.secureStorageOverride = mockStorage;

        expect(
          () => BackupService.getSafetyKey(),
          throwsA(isA<BackupKeyPersistenceException>()),
        );

        expect(
          () => BackupService.createSafetyBackup(),
          throwsA(isA<BackupKeyPersistenceException>()),
        );
      },
    );

    test(
      'Read-back mismatch throws BackupKeyPersistenceException and prevents safety-backup creation',
      () async {
        final mockStorage = MockFailingSecureStorage(readBackMismatch: true);
        BackupService.secureStorageOverride = mockStorage;

        expect(
          () => BackupService.createSafetyBackup(),
          throwsA(isA<BackupKeyPersistenceException>()),
        );
      },
    );

    test(
      'Malformed existing key in secure storage throws BackupKeyPersistenceException without overwriting',
      () async {
        final mockStorage = MockFailingSecureStorage(
          initialData: {'warqatek_safety_backup_key': 'corrupted_short_key'},
        );
        BackupService.secureStorageOverride = mockStorage;

        expect(
          () => BackupService.getSafetyKey(),
          throwsA(isA<BackupKeyPersistenceException>()),
        );

        // Must not overwrite the existing corrupted key automatically
        expect(
          mockStorage.backing['warqatek_safety_backup_key'],
          'corrupted_short_key',
        );
      },
    );

    test(
      'Failed key persistence prevents restore operation from modifying database data',
      () async {
        final mockStorage = MockFailingSecureStorage(failWrite: true);
        BackupService.secureStorageOverride = mockStorage;

        final bizBefore = await DatabaseHelper.instance.getFirstBusiness();
        expect(bizBefore?.name, 'SEC Business');

        final restorePayload = {
          'app': 'warqatek',
          'backup_version': BackupService.currentBackupVersion,
          'database_version': DatabaseHelper.dbVersion,
          'data': {
            'businesses': [
              {
                'id': 1,
                'name': 'Overwritten Name Should Not Persist',
                'owner_name': 'Owner',
                'phone': '123',
                'address': 'KRT',
                'currency_code': 'SDG',
              },
            ],
            'contacts': [],
            'products': [],
            'documents': [],
            'document_items': [],
            'document_counters': [],
          },
        };

        expect(
          () => BackupService.restoreFromJsonMap(
            restorePayload,
            createSafetyBackup: true,
          ),
          throwsA(isA<BackupKeyPersistenceException>()),
        );

        // Database data must be 100% untouched
        final bizAfter = await DatabaseHelper.instance.getFirstBusiness();
        expect(bizAfter?.name, 'SEC Business');
      },
    );

    test(
      'createSafetyBackup creates encrypted file and NOT readable plaintext',
      () async {
        final safetyPath = await BackupService.createSafetyBackup();
        final file = File(safetyPath);
        expect(file.existsSync(), isTrue);

        final bytes = await file.readAsBytes();
        // Must have encrypted magic header WRQENC
        expect(BackupEncryptionService.isEncrypted(bytes), isTrue);

        // Raw content MUST NOT be readable JSON plaintext
        expect(() => jsonDecode(utf8.decode(bytes)), throwsFormatException);

        // Can be decrypted using the safety key
        final key = await BackupService.getSafetyKey();
        final decryptedJson = await BackupEncryptionService.decryptJson(
          encryptedBytes: bytes,
          password: key,
        );
        final decoded = jsonDecode(decryptedJson) as Map<String, dynamic>;
        expect(decoded['app'], 'warqatek');
        expect(decoded['data'], isA<Map<String, dynamic>>());
      },
    );

    test(
      'Rollback successfully decrypts safety backup when restore fails',
      () async {
        final bizBefore = await DatabaseHelper.instance.getFirstBusiness();
        expect(bizBefore?.name, 'SEC Business');

        final failingBackupPayload = {
          'app': 'warqatek',
          'backup_version': BackupService.currentBackupVersion,
          'database_version': DatabaseHelper.dbVersion,
          'schema_version': DatabaseHelper.dbVersion,
          'data': {
            'businesses': [
              {
                'id': 1,
                'name': 'Corrupted Restored Business',
                'owner_name': 'Owner',
                'phone': '123',
                'address': 'KRT',
                'currency_code': 'SDG',
              },
            ],
            'contacts': [],
            'products': [],
            'documents': [],
            'document_items': [],
            'document_counters': [],
            'stocktake_sessions': [],
            'stocktake_items': [],
            'document_payments': [
              {'id': 9999, 'document_id': -999999, 'amount': -100.0},
            ],
          },
        };

        try {
          await BackupService.restoreFromJsonMap(
            failingBackupPayload,
            createSafetyBackup: true,
          );
        } catch (e) {
          expect(e, isA<BackupException>());
        }

        final bizAfter = await DatabaseHelper.instance.getFirstBusiness();
        expect(bizAfter?.name, 'SEC Business');
      },
    );

    test(
      'Corrupted encrypted safety backup or wrong key fails rollback safely without leaking plaintext',
      () async {
        BackupService.safetyKeyOverride = 'WrongKeyThatFailsAuth123456!';

        final failingPayload = {
          'app': 'warqatek',
          'backup_version': BackupService.currentBackupVersion,
          'database_version': DatabaseHelper.dbVersion,
          'data': {
            'businesses': [],
            'contacts': [],
            'products': [],
            'documents': [],
            'document_items': [],
            'document_counters': [],
            'document_payments': [
              {'id': 1, 'document_id': 99999999, 'amount': 500.0},
            ],
          },
        };

        try {
          await BackupService.restoreFromJsonMap(
            failingPayload,
            createSafetyBackup: true,
          );
        } catch (e) {
          expect(e, isA<BackupException>());
        }

        for (final entity in mockBackupDir.listSync()) {
          if (entity is File && entity.path.endsWith('.waraq')) {
            final bytes = entity.readAsBytesSync();
            expect(BackupEncryptionService.isEncrypted(bytes), isTrue);
          }
        }
      },
    );

    test(
      'Legacy plaintext safety backups are safely pruned and cleaned up',
      () async {
        final now = DateTime.now();
        final legacyFile = File(
          '${mockBackupDir.path}/warqatek_safety_pre_restore_100_1.waraq',
        );
        legacyFile.writeAsStringSync('{"app":"warqatek","data":{}}');
        legacyFile.setLastModifiedSync(now.subtract(const Duration(days: 1)));

        final encPath = await BackupService.createSafetyBackup();
        final encFile = File(encPath);

        expect(legacyFile.existsSync(), isTrue);
        expect(encFile.existsSync(), isTrue);

        await BackupService.pruneSafetyBackups(preservePath: encFile.path);

        expect(legacyFile.existsSync(), isFalse);
        expect(encFile.existsSync(), isTrue);
      },
    );

    test(
      'Existing unencrypted and encrypted user backups remain compatible',
      () async {
        final plainUserBackup = {
          'app': 'warqatek',
          'backup_version': BackupService.currentBackupVersion,
          'database_version': DatabaseHelper.dbVersion,
          'data': {
            'businesses': [
              {
                'id': 1,
                'name': 'Plain User Restored',
                'owner_name': 'Owner',
                'phone': '0123456789',
                'address': 'Khartoum',
                'currency_code': 'SDG',
              },
            ],
            'contacts': [],
            'products': [],
            'documents': [],
            'document_items': [],
            'document_counters': [],
          },
        };
        final plainRestored = await BackupService.restoreFromJsonMap(
          plainUserBackup,
          createSafetyBackup: false,
        );
        expect(plainRestored, isTrue);
        var biz = await DatabaseHelper.instance.getFirstBusiness();
        expect(biz?.name, 'Plain User Restored');

        final encBytes = await BackupEncryptionService.encryptJson(
          jsonStr: jsonEncode({
            'app': 'warqatek',
            'backup_version': BackupService.currentBackupVersion,
            'database_version': DatabaseHelper.dbVersion,
            'data': {
              'businesses': [
                {
                  'id': 1,
                  'name': 'Encrypted User Restored',
                  'owner_name': 'Owner',
                  'phone': '0123456789',
                  'address': 'Khartoum',
                  'currency_code': 'SDG',
                },
              ],
              'contacts': [],
              'products': [],
              'documents': [],
              'document_items': [],
              'document_counters': [],
            },
          }),
          password: 'UserPassword123!',
        );

        final decrypted = await BackupEncryptionService.decryptJson(
          encryptedBytes: encBytes,
          password: 'UserPassword123!',
        );
        final encRestored = await BackupService.restoreFromJsonMap(
          jsonDecode(decrypted) as Map<String, dynamic>,
          createSafetyBackup: false,
        );
        expect(encRestored, isTrue);
        biz = await DatabaseHelper.instance.getFirstBusiness();
        expect(biz?.name, 'Encrypted User Restored');
      },
    );

    test(
      'createSafetyBackup verifies cached key against storage and fails closed if storage was invalidated',
      () async {
        final mockStorage = MockFailingSecureStorage();
        BackupService.secureStorageOverride = mockStorage;

        // Populate valid key and cache
        final validKey = await BackupService.getSafetyKey();
        expect(validKey.length, 64);

        // Simulate subsequent secure-storage invalidation/removal while key is still cached in memory
        mockStorage.backing.remove('warqatek_safety_backup_key');

        // createSafetyBackup must verify against storage, detect key invalidation, fail closed, and throw
        expect(
          () => BackupService.createSafetyBackup(),
          throwsA(isA<BackupKeyPersistenceException>()),
        );
      },
    );

    test(
      'restoreFromJsonMap prevents concurrent restore operations from racing',
      () async {
        final validBackup = {
          'app': 'warqatek',
          'backup_version': BackupService.currentBackupVersion,
          'database_version': DatabaseHelper.dbVersion,
          'data': {
            'businesses': [
              {
                'id': 1,
                'name': 'Concurrent Test Business',
                'owner_name': 'Owner',
                'phone': '0123456789',
                'address': 'Khartoum',
                'currency_code': 'SDG',
              },
            ],
            'contacts': [],
            'products': [],
            'documents': [],
            'document_items': [],
            'document_counters': [],
          },
        };

        // When a restore is in progress, any concurrent call to restoreFromJsonMap throws StateError
        final future1 = BackupService.restoreFromJsonMap(
          validBackup,
          createSafetyBackup: false,
        );

        // Attempting a second restore concurrently
        expect(
          () => BackupService.restoreFromJsonMap(
            validBackup,
            createSafetyBackup: false,
          ),
          throwsStateError,
        );

        await future1;

        // After completion, the lock is released and a subsequent restore succeeds
        final subsequent = await BackupService.restoreFromJsonMap(
          validBackup,
          createSafetyBackup: false,
        );
        expect(subsequent, isTrue);
      },
    );
  });

  group('SEC-03: Namespaced Temporary Backup Cleanup', () {
    test(
      'Stale app-owned temporary backups are removed while recent, unrelated, and user files are preserved',
      () async {
        final now = DateTime.now();

        // 1. Stale temporary share backup (> 1 hour old) -> MUST BE DELETED
        final staleShare =
            File('${mockCacheDir.path}/warqatek_share_1111.waraq')
              ..writeAsStringSync('stale share')
              ..setLastModifiedSync(now.subtract(const Duration(hours: 2)));

        // 2. Stale temporary restore backup (> 1 hour old) -> MUST BE DELETED
        final staleRestore =
            File('${mockCacheDir.path}/drive_restore_2222.waraq')
              ..writeAsStringSync('stale restore')
              ..setLastModifiedSync(now.subtract(const Duration(hours: 2)));

        // 3. Stale app-owned staging tmp file (> 1 hour old) -> MUST BE DELETED
        final staleAppTmp = File('${mockCacheDir.path}/warqatek_staging.tmp')
          ..writeAsStringSync('stale app tmp')
          ..setLastModifiedSync(now.subtract(const Duration(hours: 2)));

        // 4. Stale UNRELATED .tmp file (> 1 hour old) -> MUST BE PRESERVED (un-namespaced)
        final staleUnrelatedTmp =
            File('${mockCacheDir.path}/camera_cache_123.tmp')
              ..writeAsStringSync('unrelated plugin tmp')
              ..setLastModifiedSync(now.subtract(const Duration(hours: 2)));

        // 5. Recent temporary share backup (< 1 hour old, e.g. 5 minutes ago) -> MUST BE PRESERVED
        final recentShare =
            File('${mockCacheDir.path}/warqatek_share_3333.waraq')
              ..writeAsStringSync('recent share')
              ..setLastModifiedSync(now.subtract(const Duration(minutes: 5)));

        // 6. Recent app-owned tmp file (< 1 hour old) -> MUST BE PRESERVED
        final recentAppTmp = File('${mockCacheDir.path}/warqatek_recent.tmp')
          ..writeAsStringSync('recent app tmp')
          ..setLastModifiedSync(now.subtract(const Duration(minutes: 5)));

        // 7. Unrelated cache file (image or fonts cache) -> MUST BE PRESERVED
        final unrelatedFile = File('${mockCacheDir.path}/cached_image_123.png')
          ..writeAsStringSync('image png')
          ..setLastModifiedSync(now.subtract(const Duration(hours: 48)));

        // 8. User-chosen backup in backupDir -> MUST BE PRESERVED
        final userBackup =
            File('${mockBackupDir.path}/warqatek_backup_9999.waraq')
              ..writeAsStringSync('user chosen backup')
              ..setLastModifiedSync(now.subtract(const Duration(hours: 48)));

        // 9. Active restore safety backup -> MUST BE PRESERVED
        final activeSafety =
            File('${mockBackupDir.path}/warqatek_safety_pre_restore_active.tmp')
              ..writeAsStringSync('active safety staging')
              ..setLastModifiedSync(now.subtract(const Duration(hours: 48)));

        await BackupService.cleanupTemporaryBackups(
          maxAge: const Duration(hours: 1),
          activeSafetyPath: activeSafety.path,
          tempDirOverride: mockCacheDir,
          backupDirOverride: mockBackupDir,
        );

        // Stale app-owned temporary files MUST be deleted
        expect(staleShare.existsSync(), isFalse);
        expect(staleRestore.existsSync(), isFalse);
        expect(staleAppTmp.existsSync(), isFalse);

        // Stale UNRELATED .tmp file MUST be preserved
        expect(staleUnrelatedTmp.existsSync(), isTrue);

        // Recent temporary files MUST be preserved
        expect(recentShare.existsSync(), isTrue);
        expect(recentAppTmp.existsSync(), isTrue);

        // Unrelated cache file MUST be preserved
        expect(unrelatedFile.existsSync(), isTrue);

        // User backup MUST be preserved
        expect(userBackup.existsSync(), isTrue);

        // Active safety file MUST be preserved
        expect(activeSafety.existsSync(), isTrue);
      },
    );
  });
}
