// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

  // Required overrides — not used by our code.
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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('image_storage_test_');
    PathProviderPlatform.instance = _MockPathProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('ImageStorageService.deleteImage', () {
    test('no-op when path is null', () async {
      await expectLater(ImageStorageService.deleteImage(null), completes);
    });

    test('no-op when path is empty string', () async {
      await expectLater(ImageStorageService.deleteImage(''), completes);
    });

    test('no-op when file does not exist', () async {
      await expectLater(
        ImageStorageService.deleteImage('/nonexistent/path/image.jpg'),
        completes,
      );
    });

    test('deletes existing file', () async {
      final file = File('${tempDir.path}/to_delete.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      expect(file.existsSync(), isTrue);
      await ImageStorageService.deleteImage(file.path);
      expect(file.existsSync(), isFalse);
    });
  });

  group('ImageStorageService.isAvailable', () {
    test('returns false for null', () async {
      expect(await ImageStorageService.isAvailable(null), isFalse);
    });

    test('returns false for empty string', () async {
      expect(await ImageStorageService.isAvailable(''), isFalse);
    });

    test('returns false for nonexistent path', () async {
      expect(
        await ImageStorageService.isAvailable('/no/such/file.jpg'),
        isFalse,
      );
    });

    test('returns true for existing file', () async {
      final file = File('${tempDir.path}/exists.jpg')
        ..writeAsBytesSync([0xFF, 0xD8]);
      expect(await ImageStorageService.isAvailable(file.path), isTrue);
    });
  });

  group('ImageStorageService.imageToBase64', () {
    test('returns null for null path', () async {
      expect(await ImageStorageService.imageToBase64(null), isNull);
    });

    test('returns null for empty string', () async {
      expect(await ImageStorageService.imageToBase64(''), isNull);
    });

    test('returns null for nonexistent file', () async {
      expect(
        await ImageStorageService.imageToBase64('/no/such/file.jpg'),
        isNull,
      );
    });

    test('returns non-empty base64 for valid file', () async {
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02]);
      final b64 = await ImageStorageService.imageToBase64(file.path);
      expect(b64, isNotNull);
      expect(b64, isNotEmpty);
    });
  });

  group('ImageStorageService.base64ToImage', () {
    test('returns null for empty base64', () async {
      expect(await ImageStorageService.base64ToImage('', '1'), isNull);
    });

    test('round-trips: encode then decode', () async {
      // Write a small "image" file.
      final src = File('${tempDir.path}/src.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xAA, 0xBB, 0xCC]);

      final b64 = await ImageStorageService.imageToBase64(src.path);
      expect(b64, isNotNull);

      final restoredPath = await ImageStorageService.base64ToImage(b64!, '42');
      expect(restoredPath, isNotNull);

      final restoredFile = File(restoredPath!);
      expect(restoredFile.existsSync(), isTrue);
      expect(restoredFile.readAsBytesSync(), equals(src.readAsBytesSync()));
    });

    test('rejects unsafe product IDs', () async {
      expect(
        await ImageStorageService.base64ToImage('AQID', '../outside'),
        isNull,
      );
    });

    test('creates product_images subdirectory if absent', () async {
      final b64 = await ImageStorageService.imageToBase64(
        (File('${tempDir.path}/x.jpg')..writeAsBytesSync([1, 2, 3])).path,
      );
      final path = await ImageStorageService.base64ToImage(b64!, '99');
      expect(path, isNotNull);
      expect(path!.contains('product_images'), isTrue);
    });
  });
}
