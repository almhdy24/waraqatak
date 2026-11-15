import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/digital_seal.dart';

class DigitalSealStorageService {
  static const String _subDirectory = 'digital_assets';
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB limit
  static const int maxDimension = 4096; // 4096px limit per side
  static const int maxPixelArea = 16 * 1024 * 1024; // 16MP decompression-bomb guard

  static final RegExp _safeFilenameRegex =
      RegExp(r'^(stamp|sig)_\d+_[0-9a-f]{12}\.(png|jpeg)$');

  static Directory? _cachedDir;

  static File? _resolveSafe(Directory dir, String filename) {
    if (filename != p.basename(filename)) return null;
    if (!_safeFilenameRegex.hasMatch(filename)) return null;
    final resolvedPath = p.normalize(p.join(dir.path, filename));
    if (!p.isWithin(dir.path, resolvedPath)) return null;
    return File(resolvedPath);
  }

  static Future<Directory> getAssetsDir() async {
    if (_cachedDir != null && await _cachedDir!.exists()) {
      return _cachedDir!;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _subDirectory));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedDir = dir;
    return dir;
  }

  /// Validates magic bytes, checks max size, and extracts intrinsic (width, height, format).
  /// Throws [FormatException] if bytes do not represent a valid PNG or JPEG.
  static (int width, int height, String format) validateAndInspectImage(
    Uint8List bytes,
  ) {
    if (bytes.isEmpty) {
      throw const FormatException('Empty file data');
    }
    if (bytes.length > maxFileSizeBytes) {
      throw const FormatException('File exceeds maximum allowed size (10MB)');
    }

    // Check PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      // Validate IHDR chunk tag (bytes 12-15)
      if (bytes[12] != 0x49 ||
          bytes[13] != 0x48 ||
          bytes[14] != 0x44 ||
          bytes[15] != 0x52) {
        throw const FormatException('Invalid PNG: missing IHDR chunk');
      }
      final width =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final height =
          (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      if (width <= 0 || height <= 0) {
        throw const FormatException('Invalid PNG dimensions');
      }
      if (width > maxDimension ||
          height > maxDimension ||
          (width * height) > maxPixelArea) {
        throw const FormatException(
          'Image dimensions exceed maximum allowed limits (max 4096px or 16MP)',
        );
      }
      return (width, height, 'png');
    }

    // Check JPEG: FF D8 FF
    if (bytes.length >= 4 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      int offset = 2;
      while (offset < bytes.length - 8) {
        if (bytes[offset] != 0xFF) {
          offset++;
          continue;
        }
        final marker = bytes[offset + 1];
        // SOF0 (0xC0) through SOF3 (0xC3) or SOF9 (0xC9) through SOF11 (0xCB)
        if ((marker >= 0xC0 && marker <= 0xC3) ||
            (marker >= 0xC9 && marker <= 0xCB)) {
          final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
          final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
          if (width > 0 && height > 0) {
            if (width > maxDimension ||
                height > maxDimension ||
                (width * height) > maxPixelArea) {
              throw const FormatException(
                'Image dimensions exceed maximum allowed limits (max 4096px or 16MP)',
              );
            }
            return (width, height, 'jpeg');
          }
        }
        final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += 2 + length;
      }
      throw const FormatException('Failed to parse JPEG dimensions');
    }

    throw const FormatException(
      'Unsupported image format. Only PNG and JPG are allowed.',
    );
  }

  /// Generates a stable unique identifier.
  static String generateAssetId(SealType type) {
    final random = Random.secure();
    final hexChars = List.generate(
      12,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    final prefix = type == SealType.stamp ? 'stamp' : 'sig';
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$hexChars';
  }

  /// Writes raw bytes directly to disk preserving full PNG alpha channel.
  static Future<DigitalSealAsset> saveAsset({
    required int businessId,
    required SealType type,
    required Uint8List bytes,
  }) async {
    final (width, height, format) = validateAndInspectImage(bytes);
    final assetId = generateAssetId(type);
    final filename = '$assetId.$format';

    final dir = await getAssetsDir();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);

    return DigitalSealAsset(
      id: assetId,
      businessId: businessId,
      type: type,
      filename: filename,
      format: format,
      width: width,
      height: height,
      bytesLength: bytes.length,
      createdAt: DateTime.now(),
      isDeleted: false,
    );
  }

  /// Retrieves raw bytes for an asset by its relative filename.
  static Future<Uint8List?> getAssetBytes(String filename) async {
    try {
      final dir = await getAssetsDir();
      final file = _resolveSafe(dir, filename);
      if (file == null) return null;
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return bytes.isNotEmpty ? bytes : null;
      }
    } catch (_) {}
    return null;
  }

  /// Returns the absolute File object if it exists.
  static Future<File?> getAssetFile(String filename) async {
    try {
      final dir = await getAssetsDir();
      final file = _resolveSafe(dir, filename);
      if (file != null && await file.exists()) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Checks if an asset exists on disk.
  static Future<bool> assetExists(String filename) async {
    try {
      final dir = await getAssetsDir();
      final file = _resolveSafe(dir, filename);
      if (file == null) return false;
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Deletes a file on disk. Best effort.
  static Future<void> deleteAssetFile(String filename) async {
    try {
      final dir = await getAssetsDir();
      final file = _resolveSafe(dir, filename);
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Writes restored binary data directly from base64.
  static Future<bool> restoreAssetFromBase64({
    required String filename,
    required String base64Data,
  }) async {
    try {
      final dir = await getAssetsDir();
      final file = _resolveSafe(dir, filename);
      if (file == null) return false;
      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) return false;
      validateAndInspectImage(bytes);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
