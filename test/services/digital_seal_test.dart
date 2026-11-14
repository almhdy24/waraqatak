import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/digital_seal.dart';
import 'package:warqatek/services/digital_seal_storage_service.dart';
import 'package:warqatek/services/seal_geometry_engine.dart';

void main() {
  group('DigitalSeal Domain Models', () {
    test('DigitalSealAsset serialization & aspect ratio', () {
      final now = DateTime(2026, 11, 14, 12, 0, 0);
      final asset = DigitalSealAsset(
        id: 'stamp_123',
        businessId: 1,
        type: SealType.stamp,
        filename: 'stamp_123.png',
        format: 'png',
        width: 400,
        height: 200,
        bytesLength: 1024,
        createdAt: now,
        isDeleted: false,
      );

      expect(asset.aspectRatio, equals(2.0));
      final map = asset.toMap();
      expect(map['id'], equals('stamp_123'));
      expect(map['business_id'], equals(1));
      expect(map['type'], equals('stamp'));
      expect(map['filename'], equals('stamp_123.png'));
      expect(map['width'], equals(400));
      expect(map['height'], equals(200));

      final restored = DigitalSealAsset.fromMap(map);
      expect(restored.id, equals(asset.id));
      expect(restored.businessId, equals(asset.businessId));
      expect(restored.type, equals(SealType.stamp));
      expect(restored.aspectRatio, equals(2.0));
      expect(restored.isDeleted, isFalse);
    });

    test('DigitalSealConfig serialization & safe defaults', () {
      const config = DigitalSealConfig(
        type: SealType.signature,
        assetId: 'sig_001',
        isEnabled: true,
        startRatio: 0.20,
        topRatio: 0.80,
        widthRatio: 0.30,
        aspectRatio: 1.5,
        opacity: 0.90,
        pageRule: SealPageRule.lastPage,
      );

      final jsonMap = config.toJson();
      expect(jsonMap['type'], equals('signature'));
      expect(jsonMap['asset_id'], equals('sig_001'));
      expect(jsonMap['is_enabled'], isTrue);
      expect(jsonMap['start_ratio'], equals(0.20));
      expect(jsonMap['opacity'], equals(0.90));
      expect(jsonMap['page_rule'], equals('lastPage'));

      final fromJson = DigitalSealConfig.fromJson(jsonMap, SealType.signature);
      expect(fromJson.type, equals(SealType.signature));
      expect(fromJson.assetId, equals('sig_001'));
      expect(fromJson.isEnabled, isTrue);
      expect(fromJson.opacity, equals(0.90));
    });

    test('DigitalSealConfig clamps out-of-range values gracefully', () {
      final invalidMap = {
        'type': 'stamp',
        'is_enabled': 1,
        'start_ratio': -0.5,
        'top_ratio': 2.5,
        'width_ratio': 0.99,
        'opacity': 1.8,
        'aspect_ratio': -1.0,
        'page_rule': 'unknown_rule',
      };

      final config = DigitalSealConfig.fromMap(invalidMap, SealType.stamp);
      expect(config.startRatio, equals(0.0));
      expect(config.topRatio, equals(1.0));
      expect(config.widthRatio, equals(0.60)); // max allowed widthRatio
      expect(config.opacity, equals(1.0));
      expect(config.aspectRatio, equals(1.0)); // fallback from negative
      expect(config.pageRule, equals(SealPageRule.lastPage)); // fallback
    });

    test(
      'DocumentSealSnapshot captures frozen configuration and immutability',
      () {
        const stamp = DigitalSealConfig(
          type: SealType.stamp,
          assetId: 'stamp_abc',
          isEnabled: true,
          startRatio: 0.55,
          topRatio: 0.82,
          widthRatio: 0.22,
        );

        final now = DateTime(2026, 11, 14, 10, 0, 0);
        final rawJson = DocumentSealSnapshot.serializeData(
          businessId: 1,
          issuedAt: now,
          stamp: stamp,
          signature: null,
        );

        final row = {
          'id': 10,
          'document_id': 42,
          'business_id': 1,
          'snapshot_data': rawJson,
          'created_at': now.toIso8601String(),
        };

        final snapshot = DocumentSealSnapshot.fromRow(row);
        expect(snapshot.documentId, equals(42));
        expect(snapshot.businessId, equals(1));
        expect(snapshot.stamp, isNotNull);
        expect(snapshot.stamp!.assetId, equals('stamp_abc'));
        expect(snapshot.stamp!.isEnabled, isTrue);
        expect(snapshot.signature, isNull);
        expect(snapshot.hasActiveSeals, isTrue);
      },
    );

    test('DocumentSealSnapshot handles corrupt JSON without throwing', () {
      final corruptRow = {
        'id': 11,
        'document_id': 43,
        'business_id': 1,
        'snapshot_data': 'NOT_VALID_JSON{{{',
        'created_at': DateTime.now().toIso8601String(),
      };

      final snapshot = DocumentSealSnapshot.fromRow(corruptRow);
      expect(snapshot.documentId, equals(43));
      expect(snapshot.stamp, isNull);
      expect(snapshot.signature, isNull);
      expect(snapshot.hasActiveSeals, isFalse);
    });
  });

  group('DigitalSealStorageService Validation', () {
    test('Validates PNG signature and dimensions', () {
      // Minimal valid PNG header with IHDR: 300x150
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic
        0x00, 0x00, 0x00, 0x0D, // IHDR length
        0x49, 0x48, 0x44, 0x52, // 'IHDR'
        0x00, 0x00, 0x01, 0x2C, // Width = 300
        0x00, 0x00, 0x00, 0x96, // Height = 150
        0x08, 0x06, 0x00, 0x00, 0x00, // 8-bit RGBA
        0x00, 0x00, 0x00, 0x00,
      ]);

      final (width, height, format) =
          DigitalSealStorageService.validateAndInspectImage(pngBytes);
      expect(format, equals('png'));
      expect(width, equals(300));
      expect(height, equals(150));
    });

    test('Validates JPEG header', () {
      // Minimal JPEG header
      final jpegBytes = Uint8List.fromList([
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
      ]);

      final (_, _, format) = DigitalSealStorageService.validateAndInspectImage(
        jpegBytes,
      );
      expect(format, equals('jpeg'));
    });

    test('Rejects invalid file formats', () {
      final invalidBytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // GIF header
      ]);

      expect(
        () => DigitalSealStorageService.validateAndInspectImage(invalidBytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('Rejects empty or oversized bytes', () {
      expect(
        () => DigitalSealStorageService.validateAndInspectImage(Uint8List(0)),
        throwsA(isA<FormatException>()),
      );

      final oversized = Uint8List(
        DigitalSealStorageService.maxFileSizeBytes + 10,
      );
      expect(
        () => DigitalSealStorageService.validateAndInspectImage(oversized),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SealGeometryEngine Calculations', () {
    test('Resolves A4 coordinates in LTR correctly', () {
      const config = DigitalSealConfig(
        type: SealType.signature,
        startRatio: 0.10,
        topRatio: 0.80,
        widthRatio: 0.20,
        aspectRatio: 2.0, // width 2x height
      );

      const containerWidth = 500.0;
      const containerHeight = 800.0;

      final box = SealGeometryEngine.resolve(
        config: config,
        containerWidth: containerWidth,
        containerHeight: containerHeight,
        isRtl: false,
      );

      expect(box.width, equals(100.0)); // 0.20 * 500
      expect(box.height, equals(50.0)); // 100 / 2.0
      expect(box.start, equals(50.0)); // 0.10 * 500
      expect(box.x, equals(50.0)); // LTR: x = start
      expect(box.y, equals(640.0)); // 0.80 * 800
    });

    test('Resolves A4 coordinates in RTL (Arabic) correctly', () {
      const config = DigitalSealConfig(
        type: SealType.stamp,
        startRatio: 0.10,
        topRatio: 0.80,
        widthRatio: 0.20,
        aspectRatio: 1.0, // square
      );

      const containerWidth = 500.0;
      const containerHeight = 800.0;

      final box = SealGeometryEngine.resolve(
        config: config,
        containerWidth: containerWidth,
        containerHeight: containerHeight,
        isRtl: true, // Arabic RTL
      );

      expect(box.width, equals(100.0));
      expect(box.height, equals(100.0));
      expect(box.start, equals(50.0));
      // In RTL, start is right-offset: x = containerWidth - start - width = 500 - 50 - 100 = 350
      expect(box.x, equals(350.0));
      expect(box.y, equals(640.0));
    });

    test('Clamps positions to prevent sliding off page bounds', () {
      const config = DigitalSealConfig(
        type: SealType.stamp,
        startRatio: 0.95, // would overflow right
        topRatio: 0.98, // would overflow bottom
        widthRatio: 0.30,
        aspectRatio: 1.0,
      );

      const containerWidth = 400.0;
      const containerHeight = 600.0;

      final box = SealGeometryEngine.resolve(
        config: config,
        containerWidth: containerWidth,
        containerHeight: containerHeight,
        isRtl: false,
      );

      expect(box.width, equals(120.0)); // 0.30 * 400
      expect(box.height, equals(120.0));
      // Max start should be 400 - 120 = 280
      expect(box.x, equals(280.0));
      // Max top should be 600 - 120 = 480
      expect(box.y, equals(480.0));
      expect(box.x + box.width, lessThanOrEqualTo(containerWidth));
      expect(box.y + box.height, lessThanOrEqualTo(containerHeight));
    });

    test('Update delta methods produce correctly clamped ratios', () {
      const config = DigitalSealConfig(
        type: SealType.signature,
        startRatio: 0.20,
        topRatio: 0.50,
        widthRatio: 0.25,
      );

      // Drag right by 50px, down by 100px
      final moved = SealGeometryEngine.updatePositionFromDelta(
        config: config,
        deltaStart: 50.0,
        deltaTop: 100.0,
        containerWidth: 500.0,
        containerHeight: 1000.0,
      );

      expect(moved.startRatio, closeTo(0.30, 0.01)); // (100 + 50) / 500 = 0.30
      expect(moved.topRatio, closeTo(0.60, 0.01)); // (500 + 100) / 1000 = 0.60

      // Resize width by +25px
      final resized = SealGeometryEngine.updateSizeFromDelta(
        config: config,
        deltaWidth: 25.0,
        containerWidth: 500.0,
      );

      expect(
        resized.widthRatio,
        closeTo(0.30, 0.01),
      ); // (125 + 25) / 500 = 0.30
    });
  });
}
