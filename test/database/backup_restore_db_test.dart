// Real SQLite (ffi) integration test for backup restoration.
// Verifies foreign-key integrity, stock movement restoration, backward
// compatibility with older backups without stock movements, and transactional rollback.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/backup_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('backup_restore_db_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test(
    'restoring backup with stock movements onto database with existing stock succeeds',
    () async {
      final db = DatabaseHelper.instance;

      // 1. Seed initial data in database (business, product with opening stock movement, invoice)
      await db.insertBusiness(
        const Business(
          name: 'متجر أولي',
          ownerName: 'أحمد',
          phone: '0912345678',
          address: 'الخرطوم',
          taxRate: 0,
        ),
      );
      final initialBusiness = (await db.getFirstBusiness())!;

      final pid = await ProductService.createProduct(
        name: 'زيت أولي',
        salePrice: 1000,
        purchasePrice: 800,
        stockQuantity: 10,
      );
      expect((await db.getStockMovements(pid)), isNotEmpty);

      await DocumentService.createDocument(
        type: 'invoice',
        business: initialBusiness,
        items: [
          DocumentItemInput(
            description: 'زيت أولي',
            quantity: 2,
            price: 1000,
            productId: pid,
          ),
        ],
        paid: 2000,
      );

      // 2. Prepare a backup payload containing stock movements
      final backupWithStock = {
        'app': 'warqatek',
        'backup_version': 3,
        'database_version': DatabaseHelper.dbVersion,
        'created_at': DateTime.now().toIso8601String(),
        'data': {
          'businesses': [
            {
              'id': 1,
              'name': 'متجر مستعاد',
              'owner_name': 'خالد',
              'phone': '0987654321',
              'address': 'بحري',
              'currency_code': 'SDG',
              'tax_rate': 0.0,
            },
          ],
          'contacts': [
            {
              'id': 1,
              'name': 'عميل مستعاد',
              'phone': '0123456789',
              'type': 'customer',
              'active': 1,
            },
          ],
          'products': [
            {
              'id': 1,
              'name': 'سكر مستعاد',
              'type': 'product',
              'sale_price': 500.0,
              'purchase_price': 400.0,
              'stock_quantity': 25.0,
              'min_stock': 5.0,
              'is_taxable': 1,
              'is_active': 1,
            },
          ],
          'documents': [
            {
              'id': 1,
              'type': 'invoice',
              'document_number': 'INV-001',
              'date': '2026-10-17T12:00:00.000',
              'contact_id': 1,
              'subtotal': 1000.0,
              'total': 1000.0,
              'paid': 1000.0,
              'remaining': 0.0,
              'status': 'paid',
              'currency_code': 'SDG',
            },
          ],
          'document_items': [
            {
              'id': 1,
              'document_id': 1,
              'product_id': 1,
              'description': 'سكر مستعاد',
              'quantity': 2.0,
              'price': 500.0,
              'total': 1000.0,
              'taxable': 1,
            },
          ],
          'document_counters': [
            {'type': 'invoice', 'next_number': 2},
          ],
          'document_payments': [
            {
              'id': 1,
              'document_id': 1,
              'amount': 1000.0,
              'payment_method': 'cash',
              'date': '2026-10-17T12:00:00.000',
            },
          ],
          'stock_movements': [
            {
              'id': 1,
              'product_id': 1,
              'type': StockMovement.typeOpening,
              'quantity': 27.0,
              'reference_document_id': null,
              'date': '2026-10-17T10:00:00.000',
              'notes': null,
            },
            {
              'id': 2,
              'product_id': 1,
              'type': StockMovement.typeSale,
              'quantity': -2.0,
              'reference_document_id': 1,
              'date': '2026-10-17T12:00:00.000',
              'notes': null,
            },
          ],
        },
      };

      // 3. Restore — must not fail with foreign key violation
      final ok = await BackupService.restoreFromJsonMap(backupWithStock);
      expect(ok, isTrue);

      // 4. Verify restored state
      final restoredBusiness = (await db.getFirstBusiness())!;
      expect(restoredBusiness.name, 'متجر مستعاد');

      final restoredProduct = (await db.getProductById(1))!;
      expect(restoredProduct.name, 'سكر مستعاد');
      expect(restoredProduct.stockQuantity, 25.0);

      final movements = await db.getStockMovements(1);
      expect(movements, hasLength(2));
      expect(
        movements.any(
          (m) => m.type == StockMovement.typeOpening && m.quantity == 27.0,
        ),
        isTrue,
      );
      expect(
        movements.any(
          (m) => m.type == StockMovement.typeSale && m.quantity == -2.0,
        ),
        isTrue,
      );
    },
  );

  test(
    'restoring supported older backup without stock_movements table cleans up existing movements without FK error',
    () async {
      final db = DatabaseHelper.instance;

      // Database currently contains restored product with 2 movements from previous test
      expect(await db.getStockMovements(1), hasLength(2));

      // Supported older backup format (version 1: no stock_movements, no document_payments)
      final olderBackup = {
        'app': 'warqatek',
        'backup_version': 1,
        'database_version': 4,
        'created_at': DateTime.now().toIso8601String(),
        'data': {
          'businesses': [
            {
              'id': 1,
              'name': 'متجر قديم',
              'owner_name': 'عمر',
              'phone': '0111222333',
              'address': 'أم درمان',
              'currency_code': 'SDG',
              'tax_rate': 0.0,
            },
          ],
          'contacts': [
            {
              'id': 1,
              'name': 'عميل قديم',
              'phone': '0444555666',
              'type': 'customer',
              'active': 1,
            },
          ],
          'products': [
            {
              'id': 1,
              'name': 'صابون قديم',
              'type': 'product',
              'sale_price': 150.0,
              'purchase_price': 100.0,
              'stock_quantity': 40.0,
              'min_stock': 10.0,
              'is_taxable': 1,
              'is_active': 1,
            },
          ],
          'documents': [],
          'document_items': [],
          'document_counters': [
            {'type': 'invoice', 'next_number': 1},
          ],
        },
      };

      // Restore older backup — must clear old stock movements and restore older data without error
      final ok = await BackupService.restoreFromJsonMap(olderBackup);
      expect(ok, isTrue);

      final biz = (await db.getFirstBusiness())!;
      expect(biz.name, 'متجر قديم');

      final prod = (await db.getProductById(1))!;
      expect(prod.name, 'صابون قديم');
      expect(prod.stockQuantity, 40.0);

      // Old stock movements referencing previous products were deleted; none in this backup
      final movements = await db.getStockMovements(1);
      expect(movements, isEmpty);
    },
  );

  test(
    'failed restoration rolls back transaction leaving database intact',
    () async {
      final db = DatabaseHelper.instance;

      // Pre-condition: current business is 'متجر قديم'
      final before = (await db.getFirstBusiness())!;
      expect(before.name, 'متجر قديم');

      // Invalid backup format: documents is not a List, which causes _convertRows to throw inside the transaction
      final invalidBackup = {
        'app': 'warqatek',
        'backup_version': 3,
        'database_version': DatabaseHelper.dbVersion,
        'created_at': DateTime.now().toIso8601String(),
        'data': {
          'businesses': [
            {
              'id': 1,
              'name': 'متجر تالف',
              'owner_name': 'خطأ',
              'phone': '000',
              'address': 'لا مكان',
            },
          ],
          'contacts': [],
          'products': [],
          'documents': 'NOT_A_LIST',
          'document_items': [],
          'document_counters': [],
        },
      };

      // Expect restore to throw and fail
      expect(
        () => BackupService.restoreFromJsonMap(invalidBackup),
        throwsA(anything),
      );

      // Transaction was rolled back: previous data is completely intact
      final after = (await db.getFirstBusiness())!;
      expect(after.name, 'متجر قديم');
      expect((await db.getProductById(1))!.name, 'صابون قديم');
    },
  );

  test('safety-backup failure aborts restore leaving database intact', () async {
    final db = DatabaseHelper.instance;

    final before = (await db.getFirstBusiness())!;
    expect(before.name, 'متجر قديم');

    // Simulate failure during pre-restore safety backup creation (e.g. disk full)
    BackupService.safetyBackupOverride = () async {
      throw const FileSystemException('Disk full: cannot write safety backup');
    };

    final validPayload = {
      'app': 'warqatek',
      'backup_version': 4,
      'database_version': DatabaseHelper.dbVersion,
      'created_at': DateTime.now().toIso8601String(),
      'data': {
        'businesses': [
          {
            'id': 1,
            'name': 'متجر جديد تجاوز الأمان',
            'owner_name': 'سالم',
            'phone': '123',
            'address': 'الخرطوم',
          },
        ],
        'contacts': [],
        'products': [],
        'documents': [],
        'document_items': [],
        'document_counters': [],
      },
    };

    try {
      await expectLater(
        () => BackupService.restoreFromJsonMap(validPayload),
        throwsA(anyOf(isA<FileSystemException>(), isA<BackupIntegrityException>())),
      );

      // Verify database was untouched because safety backup failed before transaction
      final after = (await db.getFirstBusiness())!;
      expect(after.name, 'متجر قديم');
    } finally {
      BackupService.safetyBackupOverride = null;
    }
  });

  test('backup round-trip preserves stocktake sessions and items', () async {
    final rawDb = await DatabaseHelper.instance.database;

    // Seed stocktake session and item
    final sessionId = await rawDb.insert('stocktake_sessions', {
      'session_number': 'ST-2026-001',
      'status': 'completed',
      'started_at': DateTime.now().toIso8601String(),
      'completed_at': DateTime.now().toIso8601String(),
      'notes': 'جرد دوري',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await rawDb.insert('stocktake_items', {
      'session_id': sessionId,
      'product_id': 1,
      'baseline_quantity': 40.0,
      'counted_quantity': 42.0,
      'reconciled_system_quantity': 42.0,
      'variance': 2.0,
      'unit_cost': 100.0,
      'notes': 'زيادة وحدتين',
      'status': 'reconciled',
    });

    // 1. Export backup (which now includes stocktake tables)
    final localPath = await BackupService.createLocalBackup();
    final backupBytes = await File(localPath).readAsBytes();
    final backupMap =
        jsonDecode(utf8.decode(backupBytes)) as Map<String, dynamic>;

    expect((backupMap['data']['stocktake_sessions'] as List), isNotEmpty);
    expect((backupMap['data']['stocktake_items'] as List), isNotEmpty);

    // 2. Clear current database and restore from the exported backup
    final ok = await BackupService.restoreFromJsonMap(backupMap);
    expect(ok, isTrue);

    // 3. Verify stocktake data is completely restored
    final restoredSessions = await rawDb.query('stocktake_sessions');
    expect(restoredSessions, hasLength(1));
    expect(restoredSessions.first['session_number'], 'ST-2026-001');

    final restoredItems = await rawDb.query('stocktake_items');
    expect(restoredItems, hasLength(1));
    expect(restoredItems.first['counted_quantity'], 42.0);
    expect(restoredItems.first['variance'], 2.0);
  });

  test(
    'old backup compatibility: v1 and v2 backups without stocktake or payments restore cleanly',
    () async {
      final rawDb = await DatabaseHelper.instance.database;

      final legacyV1Backup = {
        'app': 'warqatek',
        'backup_version': 1,
        'database_version': 4,
        'created_at': DateTime(2023, 1, 1).toIso8601String(),
        'data': {
          'businesses': [
            {
              'id': 1,
              'name': 'متجر الإصدار الأول',
              'owner_name': 'عثمان',
              'phone': '0900000000',
              'address': 'بورتسودان',
            },
          ],
          'contacts': [],
          'products': [
            {
              'id': 10,
              'name': 'منتج قديم v1',
              'sale_price': 100.0,
              'purchase_price': 70.0,
              'stock_quantity': 15.0,
            },
          ],
          'documents': [],
          'document_items': [],
          'document_counters': [],
        },
      };

      final ok = await BackupService.restoreFromJsonMap(legacyV1Backup);
      expect(ok, isTrue);

      final biz = (await DatabaseHelper.instance.getFirstBusiness())!;
      expect(biz.name, 'متجر الإصدار الأول');

      final prod = (await DatabaseHelper.instance.getProductById(10))!;
      expect(prod.name, 'منتج قديم v1');
      expect(prod.stockQuantity, 15.0);

      // Stocktake and payments tables are safely empty and uncorrupted
      expect(await rawDb.query('stocktake_sessions'), isEmpty);
      expect(await rawDb.query('stocktake_items'), isEmpty);
      expect(await rawDb.query('document_payments'), isEmpty);
    },
  );

  test(
    'safety-backup filename uniqueness prevents collisions on rapid invocation',
    () async {
      final createdPaths = <String>[];
      try {
        for (var i = 0; i < 10; i++) {
          final path = await BackupService.createSafetyBackup();
          createdPaths.add(path);
          expect(File(path).existsSync(), isTrue);
        }
        expect(
          createdPaths.toSet(),
          hasLength(10),
          reason: 'All 10 safety backup paths must be unique',
        );
      } finally {
        for (final p in createdPaths) {
          try {
            if (File(p).existsSync()) File(p).deleteSync();
          } catch (_) {}
        }
      }
    },
  );

  test(
    'safety-backup promotion never overwrites existing valid backup and cleans up temp file on failure',
    () async {
      File? capturedTemp;
      File? capturedTarget;
      const preExistingContent =
          '{"app":"warqatek","backup_version":4,"existing":true}';

      try {
        BackupService.onBeforePromotion = (tempFile, targetFile) async {
          capturedTemp = tempFile;
          capturedTarget = targetFile;
          // Pre-create the target file to simulate collision with an existing safety backup
          await targetFile.writeAsString(preExistingContent, flush: true);
        };

        await expectLater(
          () => BackupService.createSafetyBackup(),
          throwsA(isA<FileSystemException>()),
        );

        // Verify target file was NOT overwritten
        expect(capturedTarget, isNotNull);
        expect(capturedTarget!.existsSync(), isTrue);
        expect(await capturedTarget!.readAsString(), preExistingContent);

        // Verify temporary staging file was cleaned up and did not linger
        expect(capturedTemp, isNotNull);
        expect(capturedTemp!.existsSync(), isFalse);
      } finally {
        BackupService.onBeforePromotion = null;
        if (capturedTarget != null && capturedTarget!.existsSync()) {
          try {
            capturedTarget!.deleteSync();
          } catch (_) {}
        }
      }
    },
  );

  test(
    'safety-backup promotion failure aborts restore and leaves current database intact',
    () async {
      final db = DatabaseHelper.instance;
      final beforeBiz = (await db.getFirstBusiness())!;
      File? capturedTemp;

      try {
        BackupService.onBeforePromotion = (tempFile, targetFile) async {
          capturedTemp = tempFile;
          throw const FileSystemException('Simulated promotion I/O failure');
        };

        final payload = {
          'app': 'warqatek',
          'backup_version': 4,
          'database_version': DatabaseHelper.dbVersion,
          'created_at': DateTime.now().toIso8601String(),
          'data': {
            'businesses': [
              {
                'id': 1,
                'name': 'متجر لا يجب أن يُكتب',
                'owner_name': 'سارق البيانات',
                'phone': '000',
                'address': 'عدم',
              },
            ],
            'contacts': [],
            'products': [],
            'documents': [],
            'document_items': [],
            'document_counters': [],
          },
        };

        await expectLater(
          () => BackupService.restoreFromJsonMap(payload),
          throwsA(anyOf(isA<FileSystemException>(), isA<BackupIntegrityException>())),
        );

        // Database was untouched because safety backup failed before transaction
        final afterBiz = (await db.getFirstBusiness())!;
        expect(afterBiz.name, beforeBiz.name);

        // Temporary staging file was cleaned up
        expect(capturedTemp, isNotNull);
        expect(capturedTemp!.existsSync(), isFalse);
      } finally {
        BackupService.onBeforePromotion = null;
      }
    },
  );
}
