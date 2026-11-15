import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/digital_seal.dart';
import 'package:warqatek/services/digital_seal_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Synthetic 1x1 valid PNG
  Uint8List createValidPng({int width = 100, int height = 100}) {
    final b = Uint8List(24);
    // PNG signature
    b[0] = 0x89;
    b[1] = 0x50;
    b[2] = 0x4E;
    b[3] = 0x47;
    b[4] = 0x0D;
    b[5] = 0x0A;
    b[6] = 0x1A;
    b[7] = 0x0A;
    // Chunk length
    b[8] = 0x00;
    b[9] = 0x00;
    b[10] = 0x00;
    b[11] = 0x0D;
    // Chunk type 'IHDR'
    b[12] = 0x49;
    b[13] = 0x48;
    b[14] = 0x44;
    b[15] = 0x52;
    // Width (big endian)
    b[16] = (width >> 24) & 0xFF;
    b[17] = (width >> 16) & 0xFF;
    b[18] = (width >> 8) & 0xFF;
    b[19] = width & 0xFF;
    // Height (big endian)
    b[20] = (height >> 24) & 0xFF;
    b[21] = (height >> 16) & 0xFF;
    b[22] = (height >> 8) & 0xFF;
    b[23] = height & 0xFF;
    return b;
  }

  // Synthetic valid JPEG with SOF0
  Uint8List createValidJpeg({int width = 100, int height = 100}) {
    final b = Uint8List(14);
    // SOI
    b[0] = 0xFF;
    b[1] = 0xD8;
    // SOF0 marker
    b[2] = 0xFF;
    b[3] = 0xC0;
    // Marker segment length: 10 bytes
    b[4] = 0x00;
    b[5] = 0x0A;
    // Precision
    b[6] = 0x08;
    // Height (big endian)
    b[7] = (height >> 8) & 0xFF;
    b[8] = height & 0xFF;
    // Width (big endian)
    b[9] = (width >> 8) & 0xFF;
    b[10] = width & 0xFF;
    // Component count
    b[11] = 0x03;
    // Dummy trailer
    b[12] = 0xFF;
    b[13] = 0xD9;
    return b;
  }

  group('Phase 4C: Digital Seal Storage and Validation', () {
    test('4C-1: Path traversal attacks are rejected across all methods', () async {
      final validPng = createValidPng();
      final validBase64 = base64Encode(validPng);

      final traversalNames = [
        '../x.png',
        '/etc/x.png',
        'a\\b.png',
        'stamp_1_aaaaaaaaaaaa.png/../../x',
        '..\\..\\malicious.png',
        'sig_1234_abc.png', // too short hex
        'stamp_1234_123456789012.exe', // bad extension
      ];

      for (final badName in traversalNames) {
        expect(await DigitalSealStorageService.getAssetBytes(badName), isNull,
            reason: 'getAssetBytes should return null for $badName');
        expect(await DigitalSealStorageService.getAssetFile(badName), isNull,
            reason: 'getAssetFile should return null for $badName');
        expect(await DigitalSealStorageService.assetExists(badName), isFalse,
            reason: 'assetExists should return false for $badName');

        // deleteAssetFile should be a safe no-op
        await DigitalSealStorageService.deleteAssetFile(badName);

        // restoreAssetFromBase64 should reject
        final restored = await DigitalSealStorageService.restoreAssetFromBase64(
          filename: badName,
          base64Data: validBase64,
        );
        expect(restored, isFalse,
            reason: 'restoreAssetFromBase64 should reject $badName');
      }
    });

    test('4C-1: restoreAssetFromBase64 rejects non-image or truncated data', () async {
      const validName = 'stamp_1234567890123_0123456789ab.png';
      final badData = base64Encode(utf8.encode('this is not an image'));

      final restored = await DigitalSealStorageService.restoreAssetFromBase64(
        filename: validName,
        base64Data: badData,
      );
      expect(restored, isFalse);
    });

    test('4C-2: Image validation bomb guards and chunk checks', () {
      // 1. Valid PNG
      final validPng = createValidPng(width: 800, height: 600);
      final (pw, ph, pfmt) =
          DigitalSealStorageService.validateAndInspectImage(validPng);
      expect(pw, 800);
      expect(ph, 600);
      expect(pfmt, 'png');

      // 2. PNG with missing IHDR chunk
      final badChunkPng = createValidPng();
      badChunkPng[12] = 0x58; // 'X'
      expect(
        () => DigitalSealStorageService.validateAndInspectImage(badChunkPng),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing IHDR'),
        )),
      );

      // 3. PNG exceeding max dimension (4097 px)
      final oversizePngDim = createValidPng(width: 4097, height: 100);
      expect(
        () => DigitalSealStorageService.validateAndInspectImage(oversizePngDim),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('dimensions exceed maximum'),
        )),
      );

      // 4. PNG exceeding max pixel area (> 16MP: 4000 x 4200 = 16.8MP)
      final oversizePngArea = createValidPng(width: 4000, height: 4200);
      expect(
        () => DigitalSealStorageService.validateAndInspectImage(oversizePngArea),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('dimensions exceed maximum'),
        )),
      );

      // 5. Valid JPEG
      final validJpeg = createValidJpeg(width: 1024, height: 768);
      final (jw, jh, jfmt) =
          DigitalSealStorageService.validateAndInspectImage(validJpeg);
      expect(jw, 1024);
      expect(jh, 768);
      expect(jfmt, 'jpeg');

      // 6. JPEG exceeding max dimension (4097 px)
      final oversizeJpegDim = createValidJpeg(width: 100, height: 4097);
      expect(
        () => DigitalSealStorageService.validateAndInspectImage(oversizeJpegDim),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('dimensions exceed maximum'),
        )),
      );

      // 7. JPEG without parseable SOF marker throws FormatException instead of fallback
      final noSofJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x02]);
      expect(
        () => DigitalSealStorageService.validateAndInspectImage(noSofJpeg),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Failed to parse JPEG dimensions'),
        )),
      );
    });

    test('4C-4: DigitalSealConfig copyWith supports clearing assetId', () {
      const config = DigitalSealConfig(
        type: SealType.stamp,
        assetId: 'stamp_123456_abcdef012345',
        isEnabled: true,
      );
      expect(config.hasAsset, isTrue);
      expect(config.assetId, isNotNull);

      // Standard copyWith preserves assetId when assetId is null and clearAssetId is false
      final preserved = config.copyWith(isEnabled: false);
      expect(preserved.assetId, 'stamp_123456_abcdef012345');

      // copyWith with clearAssetId: true clears assetId
      final cleared = config.copyWith(clearAssetId: true, isEnabled: false);
      expect(cleared.assetId, isNull);
      expect(cleared.hasAsset, isFalse);
      expect(cleared.isEnabled, isFalse);

      final map = cleared.toMap();
      expect(map['asset_id'], isNull);
      expect(map['is_enabled'], 0);
    });
  });
}
