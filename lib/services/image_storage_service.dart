import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages local storage of product images.
///
/// Images are stored in `<appDocuments>/product_images/` as JPEG files,
/// compressed and resized to at most [_maxDimension] pixels on the longest
/// side. Paths (not base64) are persisted in the SQLite products table.
class ImageStorageService {
  static const String _subdir = 'product_images';
  static const int _maxDimension = 1024;
  static const int _quality = 85;

  // ── Directory ──────────────────────────────────────────────────────────────

  static Future<Directory> _imagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _subdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Compress [sourcePath] and save to the product images directory.
  ///
  /// Returns the absolute path of the stored file.
  /// Throws if compression or file operations fail.
  static Future<String> saveImage(String sourcePath) async {
    final dir = await _imagesDir();
    final filename = 'product_${_uniqueId()}.jpg';
    final destPath = p.join(dir.path, filename);

    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      destPath,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      quality: _quality,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      // Do not save uncompressed PNG/HEIC bytes with a .jpg extension.
      try {
        final partial = File(destPath);
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
      throw StateError('Unable to compress product image');
    }

    return result.path;
  }

  /// Deletes the image file at [path]. No-op if [path] is null or missing.
  static Future<void> deleteImage(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort; never throw on delete.
    }
  }

  /// Returns `true` if [path] is non-null, non-empty, and the file exists.
  static Future<bool> isAvailable(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  // ── Backup / Restore ───────────────────────────────────────────────────────

  /// Encodes the file at [path] as a base64 string for backup embedding.
  ///
  /// Returns `null` if the file is missing, empty, or unreadable.
  static Future<String?> imageToBase64(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Decodes [base64Data] and writes the result to the product images directory.
  ///
  /// [productId] is used as a suffix for the filename to aid debugging.
  /// Returns the absolute path of the written file, or `null` on error.
  static Future<String?> base64ToImage(
    String base64Data,
    String productId,
  ) async {
    try {
      if (!RegExp(r'^[0-9]+$').hasMatch(productId)) return null;

      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) return null;
      final dir = await _imagesDir();
      final filename =
          'product_${productId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(p.join(dir.path, filename));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static final _rng = Random.secure();

  /// Generates a unique identifier from timestamp + random bytes.
  static String _uniqueId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = _rng.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${ts}_$rand';
  }
}
