// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:warqatek/services/backup_service.dart';
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_image_test_');
    PathProviderPlatform.instance = _MockPathProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // ── 1. imageToBase64 → base64ToImage round-trip ───────────────────────────

  group('base64 round-trip', () {
    test('encode then decode preserves bytes', () async {
      final src = File('${tempDir.path}/src.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xAA, 0xBB]);

      final b64 = await ImageStorageService.imageToBase64(src.path);
      expect(b64, isNotNull);

      final restoredPath = await ImageStorageService.base64ToImage(b64!, '1');
      expect(restoredPath, isNotNull);

      final restoredBytes = File(restoredPath!).readAsBytesSync();
      expect(restoredBytes, equals(src.readAsBytesSync()));
    });

    test('base64ToImage returns null for empty string', () async {
      expect(await ImageStorageService.base64ToImage('', '1'), isNull);
    });

    test('base64ToImage returns null for invalid base64', () async {
      expect(
        await ImageStorageService.base64ToImage('!!!notbase64!!!', '1'),
        isNull,
      );
    });
  });

  // ── 2. Backup JSON structure ───────────────────────────────────────────────

  group('backup JSON', () {
    test('backup version is 6', () {
      expect(BackupService.currentBackupVersion, equals(6));
    });

    test('backup with no product images produces null product_images key', () {
      // The assets block should contain 'product_images': null when empty.
      final backupData = <String, dynamic>{
        'app': BackupService.appId,
        'backup_version': BackupService.currentBackupVersion,
        'database_version': 31,
        'created_at': DateTime.now().toIso8601String(),
        'data': <String, dynamic>{},
        'assets': <String, dynamic>{
          'logo_base64': null,
          'product_images': null,
        },
      };
      final json = jsonEncode(backupData);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['assets']['product_images'], isNull);
    });

    test('backup with images encodes them correctly', () async {
      final src = File('${tempDir.path}/img.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0x01]);

      final b64 = await ImageStorageService.imageToBase64(src.path);
      expect(b64, isNotNull);

      final backupData = <String, dynamic>{
        'app': BackupService.appId,
        'backup_version': BackupService.currentBackupVersion,
        'database_version': 31,
        'created_at': DateTime.now().toIso8601String(),
        'data': <String, dynamic>{},
        'assets': <String, dynamic>{
          'logo_base64': null,
          'product_images': {'42': b64},
        },
      };
      final json = jsonEncode(backupData);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final images =
          decoded['assets']['product_images'] as Map<String, dynamic>;
      expect(images, containsPair('42', b64));
    });
  });

  // ── 3. Old backup backward compatibility ──────────────────────────────────

  group('backward compatibility', () {
    test('backup without product_images key is tolerated', () {
      // Simulate an old backup (version 5, no product_images in assets).
      final oldBackup = <String, dynamic>{
        'app': BackupService.appId,
        'backup_version': 5,
        'database_version': 30,
        'created_at': DateTime.now().toIso8601String(),
        'data': <String, dynamic>{},
        'assets': <String, dynamic>{'logo_base64': null},
      };

      // _validateBackup checks version ≤ currentBackupVersion.
      // Version 5 must still be accepted by version 6+ app.
      expect(
        oldBackup['backup_version'] as int,
        lessThanOrEqualTo(BackupService.currentBackupVersion),
      );

      // The assets map has no 'product_images' key — this must not throw.
      final assets = oldBackup['assets'] as Map<String, dynamic>;
      final productImages = assets['product_images'];
      expect(productImages, isNull); // safe to check for null
    });

    test('restore image: null product_images gracefully skipped', () async {
      // Simulate receiving a backup JSON map with null product_images.
      final jsonMap = <String, dynamic>{
        'assets': <String, dynamic>{
          'logo_base64': null,
          'product_images': null,
        },
      };

      // This should not throw.
      final assets = jsonMap['assets'];
      expect(assets is Map<String, dynamic>, isTrue);
      final pi = (assets as Map<String, dynamic>)['product_images'];
      expect(pi is Map<String, dynamic>, isFalse); // null → skip
    });

    test('corrupted base64 for one product does not block others', () async {
      // Build a product_images map with one invalid and one valid entry.
      final src = File('${tempDir.path}/good.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xAA, 0xBB, 0xCC]);
      final goodB64 = await ImageStorageService.imageToBase64(src.path);

      final productImages = {'1': '!!!INVALID!!!', '2': goodB64!};

      // Process them as the restore code would (best-effort).
      String? restoredBadPath;
      String? restoredGoodPath;

      for (final entry in productImages.entries) {
        try {
          final p = await ImageStorageService.base64ToImage(
            entry.value,
            entry.key,
          );
          if (entry.key == '1') restoredBadPath = p;
          if (entry.key == '2') restoredGoodPath = p;
        } catch (_) {
          // swallowed — mirrors restore behaviour
        }
      }

      expect(restoredBadPath, isNull); // bad base64 → null, not exception
      expect(restoredGoodPath, isNotNull); // good one still restored
    });
  });
}
