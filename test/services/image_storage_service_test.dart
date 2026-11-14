// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/services/image_storage_service.dart';

// ---------------------------------------------------------------------------
// Minimal path_provider mock
// ---------------------------------------------------------------------------

class _MockPathProvider
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory dir;
  _MockPathProvider(this.dir);

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getTemporaryPath() async => dir.path;
  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
  @override
  Future<String?> getLibraryPath() async => null;
  @override
  Future<String?> getExternalStoragePath() async => null;
  @override
  Future<List<String>?> getExternalCachePaths() async => null;
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => null;
  @override
  Future<String?> getDownloadsPath() async => null;
  @override
  Future<String?> getApplicationCachePath() async => null;
}

void main() {
  late Directory tempDir;
  late Directory imagesDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('image_storage_test_');
    PathProviderPlatform.instance = _MockPathProvider(tempDir);
    imagesDir = Directory(p.join(tempDir.path, 'product_images'));
    await imagesDir.create(recursive: true);
    ImageStorageService.setCachedDirForTesting(imagesDir.path);
    ImageStorageService.resetRestoreCounters();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('Group A1: Dimension calculation & size cap', () {
    test('computeTargetDimensions caps 4000x1000 to longest side <= 1024', () {
      final (w, h) = ImageStorageService.computeTargetDimensions(
        sourceWidth: 4000,
        sourceHeight: 1000,
        maxDimension: 1024,
      );
      expect(w, equals(1024));
      expect(h, equals(256));
      expect(w, lessThanOrEqualTo(1024));
      expect(h, lessThanOrEqualTo(1024));
    });

    test('computeTargetDimensions caps 1000x4000 to longest side <= 1024', () {
      final (w, h) = ImageStorageService.computeTargetDimensions(
        sourceWidth: 1000,
        sourceHeight: 4000,
        maxDimension: 1024,
      );
      expect(w, equals(256));
      expect(h, equals(1024));
      expect(w, lessThanOrEqualTo(1024));
      expect(h, lessThanOrEqualTo(1024));
    });

    test('computeTargetDimensions caps thumbnail to longest side <= 256', () {
      final (w, h) = ImageStorageService.computeTargetDimensions(
        sourceWidth: 4000,
        sourceHeight: 1000,
        maxDimension: 256,
      );
      expect(w, equals(256));
      expect(h, equals(64));
    });

    test('readImageDimensions parses PNG dimensions correctly', () {
      // Minimal 100x50 PNG bytes with IHDR
      final bytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // magic
        0x00, 0x00, 0x00, 0x0D, // IHDR length
        0x49, 0x48, 0x44, 0x52, // IHDR
        0x00, 0x00, 0x00, 0x64, // width = 100
        0x00, 0x00, 0x00, 0x32, // height = 50
        0x08, 0x02, 0x00, 0x00, 0x00,
      ]);
      final dims = ImageStorageService.readImageDimensions(bytes);
      expect(dims, isNotNull);
      expect(dims!.$1, 100);
      expect(dims.$2, 50);
    });
  });

  group('Group A2: Thumbnail naming, pathing & deletion', () {
    test('thumbNameFor produces correct _t filename', () {
      expect(
        ImageStorageService.thumbNameFor('product_123.jpg'),
        'product_123_t.jpg',
      );
      expect(ImageStorageService.thumbNameFor('photo.jpeg'), 'photo_t.jpeg');
    });

    test('thumbPathFor resolves to thumbnail path in images dir', () {
      final thumbPath = ImageStorageService.thumbPathFor('product_abc.jpg');
      expect(thumbPath, isNotNull);
      expect(thumbPath!.endsWith('product_abc_t.jpg'), isTrue);
      expect(thumbPath.contains('product_images'), isTrue);
    });

    test('deleteImage deletes both main file and thumbnail', () async {
      final mainFile = File(p.join(imagesDir.path, 'product_del.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final thumbFile = File(p.join(imagesDir.path, 'product_del_t.jpg'))
        ..writeAsBytesSync([4, 5, 6]);

      expect(await mainFile.exists(), isTrue);
      expect(await thumbFile.exists(), isTrue);

      await ImageStorageService.deleteImage('product_del.jpg');

      expect(await mainFile.exists(), isFalse);
      expect(await thumbFile.exists(), isFalse);
    });
  });

  group('Group A3: Filename storage & synchronous resolve', () {
    test('resolve returns null for null or empty string', () {
      expect(ImageStorageService.resolve(null), isNull);
      expect(ImageStorageService.resolve(''), isNull);
      expect(ImageStorageService.resolve('   '), isNull);
    });

    test('resolve joins bare filename with cached dir', () {
      final resolved = ImageStorageService.resolve('product_99.jpg');
      expect(resolved, equals(p.join(imagesDir.path, 'product_99.jpg')));
    });

    test('resolve preserves legacy absolute path if file exists', () async {
      final legacyFile = File(p.join(tempDir.path, 'legacy_prod.jpg'))
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      final resolved = ImageStorageService.resolve(legacyFile.path);
      expect(resolved, equals(legacyFile.path));
    });

    test(
      'resolve falls back to cached dir if legacy file is missing',
      () async {
        final missingLegacy = '/old/root/product_images/product_999.jpg';
        final cachedFile = File(p.join(imagesDir.path, 'product_999.jpg'))
          ..writeAsBytesSync([0xFF, 0xD8]);

        final resolved = ImageStorageService.resolve(missingLegacy);
        expect(resolved, equals(cachedFile.path));
      },
    );
  });

  group('Group A4: Asynchronous isAvailable', () {
    test('isAvailable returns false for null/empty/nonexistent', () async {
      expect(await ImageStorageService.isAvailable(null), isFalse);
      expect(await ImageStorageService.isAvailable(''), isFalse);
      expect(await ImageStorageService.isAvailable('missing.jpg'), isFalse);
    });

    test('isAvailable returns true for existing bare filename', () async {
      File(p.join(imagesDir.path, 'available.jpg')).writeAsBytesSync([1, 2]);
      expect(await ImageStorageService.isAvailable('available.jpg'), isTrue);
    });
  });

  group('Group A5: Orphan sweep', () {
    test('sweepOrphans removes unreferenced files older than 24h', () async {
      final oldUnreferenced = File(p.join(imagesDir.path, 'product_old.jpg'))
        ..writeAsBytesSync([1]);
      final oldThumb = File(p.join(imagesDir.path, 'product_old_t.jpg'))
        ..writeAsBytesSync([1]);
      final recentUnreferenced = File(
        p.join(imagesDir.path, 'product_recent.jpg'),
      )..writeAsBytesSync([2]);
      final referencedOld = File(p.join(imagesDir.path, 'product_ref.jpg'))
        ..writeAsBytesSync([3]);
      final referencedThumb = File(p.join(imagesDir.path, 'product_ref_t.jpg'))
        ..writeAsBytesSync([3]);

      // Set old modification times (> 25 hours ago)
      final past = DateTime.now().subtract(const Duration(hours: 26));
      await oldUnreferenced.setLastModified(past);
      await oldThumb.setLastModified(past);
      await referencedOld.setLastModified(past);
      await referencedThumb.setLastModified(past);

      // Sweep with 'product_ref.jpg' referenced
      final deleted = await ImageStorageService.sweepOrphans({
        'product_ref.jpg',
      });

      expect(deleted, equals(2));
      expect(await oldUnreferenced.exists(), isFalse);
      expect(await oldThumb.exists(), isFalse);
      expect(await recentUnreferenced.exists(), isTrue);
      expect(await referencedOld.exists(), isTrue);
      expect(await referencedThumb.exists(), isTrue);
    });
  });

  group('Group A6: base64ToImage hardening', () {
    test('rejects empty, invalid, and non-image input', () async {
      expect(await ImageStorageService.base64ToImage('', '123'), isNull);
      expect(ImageStorageService.restoreSkippedCount, equals(1));

      // Non-image bytes (e.g. plain text)
      final plainTextB64 = base64Encode(utf8.encode('Hello World'));
      expect(
        await ImageStorageService.base64ToImage(plainTextB64, '123'),
        isNull,
      );
      expect(ImageStorageService.restoreSkippedCount, equals(2));
    });

    test('rejects base64 data exceeding 5 MB', () async {
      final largeBytes = Uint8List(5 * 1024 * 1024 + 10);
      final largeB64 = base64Encode(largeBytes);
      expect(await ImageStorageService.base64ToImage(largeB64, '123'), isNull);
      expect(ImageStorageService.restoreSkippedCount, equals(1));
    });

    test('accepts valid JPEG bytes and restores filename', () async {
      final validJpeg = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
        0x00,
        0x01,
        0x01,
        0x01,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x00,
        0xFF,
        0xD9,
      ]);
      final b64 = base64Encode(validJpeg);
      final filename = await ImageStorageService.base64ToImage(b64, '456');
      expect(filename, isNotNull);
      expect(filename!.startsWith('product_456_'), isTrue);

      final restoredPath = ImageStorageService.resolve(filename);
      expect(restoredPath, isNotNull);
      expect(await File(restoredPath!).exists(), isTrue);
    });
  });

  group('Group A3: Migration v33 (absolute path -> basename)', () {
    test('migration v33 converts stored absolute paths to basenames', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY,
          name TEXT,
          image_path TEXT
        )
      ''');

      await db.insert('products', {
        'id': 1,
        'name': 'P1',
        'image_path': '/data/user/0/app/product_images/product_101.jpg',
      });
      await db.insert('products', {
        'id': 2,
        'name': 'P2',
        'image_path': 'product_102.jpg',
      });
      await db.insert('products', {'id': 3, 'name': 'P3', 'image_path': null});

      // Run migration
      final helper = DatabaseHelper.instance;
      await helper.upgradeTablesForTest(db, 32, 33);

      final rows = await db.query('products', orderBy: 'id ASC');
      expect(rows[0]['image_path'], equals('product_101.jpg'));
      expect(rows[1]['image_path'], equals('product_102.jpg'));
      expect(rows[2]['image_path'], isNull);

      // Verify idempotency
      await helper.upgradeTablesForTest(db, 32, 33);
      final rows2 = await db.query('products', orderBy: 'id ASC');
      expect(rows2[0]['image_path'], equals('product_101.jpg'));

      await db.close();
    });
  });
}
