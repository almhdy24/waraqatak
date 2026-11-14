import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Structured error codes for image storage operations.
enum ImageStorageError {
  invalidImage,
  tooLarge,
  diskFull,
  permissionDenied,
  unexpected,
}

/// Typed exception representing an image storage or compression failure.
class ImageStorageException implements Exception {
  final ImageStorageError error;
  final String? message;
  final Object? cause;

  const ImageStorageException(this.error, [this.message, this.cause]);

  @override
  String toString() => 'ImageStorageException($error, $message)';
}

/// Manages local storage of product images and thumbnails.
///
/// Images are stored in `<appDocuments>/product_images/` as normalized JPEG files,
/// resized so the longest side is at most [_maxDimension] pixels.
/// Filenames (not absolute paths) are persisted in the SQLite products table.
class ImageStorageService {
  static const String _subdir = 'product_images';
  static const int _maxDimension = 1024;
  static const int _quality = 85;

  static const int _thumbMaxDimension = 256;
  static const int _thumbQuality = 80;

  static const int maxRestoreSizeBytes = 5 * 1024 * 1024; // 5 MB

  static String? _cachedImagesDirPath;

  static int restoreSkippedCount = 0;
  static void resetRestoreCounters() => restoreSkippedCount = 0;

  // ── Initialization & Directory ─────────────────────────────────────────────

  /// Initializes the product images directory once at startup and caches the path
  /// so that subsequent calls to [resolve] are synchronous.
  static Future<void> init() async {
    final dir = await _imagesDir();
    _cachedImagesDirPath = dir.path;
  }

  @visibleForTesting
  static void setCachedDirForTesting(String? path) {
    _cachedImagesDirPath = path;
  }

  @visibleForTesting
  static String? get cachedDirForTesting => _cachedImagesDirPath;

  static Future<Directory> _imagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _subdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Path Resolution & Naming Helpers ────────────────────────────────────────

  /// Returns the thumbnail filename corresponding to [mainFilename].
  /// Example: 'product_123.jpg' -> 'product_123_t.jpg'
  static String thumbNameFor(String mainFilename) {
    final ext = p.extension(mainFilename);
    final withoutExt = p.withoutExtension(mainFilename);
    return '${withoutExt}_t$ext';
  }

  /// Returns the absolute path to the thumbnail of [stored] (filename or legacy path).
  static String? thumbPathFor(String? stored) {
    final resolved = resolve(stored);
    if (resolved == null) return null;
    final dir = p.dirname(resolved);
    final thumbName = thumbNameFor(p.basename(resolved));
    return p.join(dir, thumbName);
  }

  /// Synchronously resolves [stored] (a bare filename or legacy absolute path)
  /// to an absolute filesystem path.
  ///
  /// - null or empty -> null
  /// - bare filename -> joined with the cached images directory
  /// - legacy absolute path -> returned as is if exists; otherwise if the basename
  ///   exists in the cached images directory, returns the cached path.
  static String? resolve(String? stored) {
    if (stored == null || stored.trim().isEmpty) return null;
    final clean = stored.trim();

    if (p.isAbsolute(clean)) {
      final file = File(clean);
      if (file.existsSync()) {
        return clean;
      }
      final base = p.basename(clean);
      if (_cachedImagesDirPath != null) {
        final fallback = p.join(_cachedImagesDirPath!, base);
        if (File(fallback).existsSync()) {
          return fallback;
        }
        return fallback;
      }
      return clean;
    }

    if (_cachedImagesDirPath != null) {
      return p.join(_cachedImagesDirPath!, clean);
    }
    return clean;
  }

  // ── Dimension Math & Image Format Detection ────────────────────────────────

  /// Pure helper computing target width and height such that the longest side
  /// is strictly <= [maxDimension] while preserving the aspect ratio.
  @visibleForTesting
  static (int targetWidth, int targetHeight) computeTargetDimensions({
    required int sourceWidth,
    required int sourceHeight,
    required int maxDimension,
  }) {
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return (maxDimension, maxDimension);
    }
    if (sourceWidth <= maxDimension && sourceHeight <= maxDimension) {
      return (sourceWidth, sourceHeight);
    }
    if (sourceWidth >= sourceHeight) {
      final targetWidth = maxDimension;
      final targetHeight = max(
        1,
        (sourceHeight * maxDimension / sourceWidth).round(),
      );
      return (targetWidth, targetHeight);
    } else {
      final targetHeight = maxDimension;
      final targetWidth = max(
        1,
        (sourceWidth * maxDimension / sourceHeight).round(),
      );
      return (targetWidth, targetHeight);
    }
  }

  /// Inspects magic bytes and returns format identifier ('jpeg', 'png', 'webp')
  /// or null if unsupported.
  static String? detectImageFormat(Uint8List bytes) {
    if (bytes.length < 2) return null;
    // JPEG: FF D8
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'jpeg';
    }
    // PNG: 89 50 4E 47
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    // WEBP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  /// Reads image dimensions directly from image header bytes without full decode.
  static (int width, int height)? readImageDimensions(Uint8List bytes) {
    if (bytes.length < 8) return null;

    // PNG: IHDR chunk has width at 16..19, height at 20..23
    if (bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      final width =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final height =
          (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      if (width > 0 && height > 0) return (width, height);
    }

    // JPEG markers: search for SOF0 (0xC0), SOF2 (0xC2), etc.
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      int offset = 2;
      while (offset < bytes.length - 8) {
        if (bytes[offset] != 0xFF) {
          offset++;
          continue;
        }
        final marker = bytes[offset + 1];
        if ((marker >= 0xC0 && marker <= 0xC3) ||
            (marker >= 0xC9 && marker <= 0xCB)) {
          final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
          final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
          if (width > 0 && height > 0) return (width, height);
        }
        final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += 2 + length;
      }
    }

    // WEBP VP8 / VP8L
    if (bytes.length >= 30 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      // VP8 (lossy)
      if (bytes[12] == 0x56 &&
          bytes[13] == 0x50 &&
          bytes[14] == 0x38 &&
          bytes[15] == 0x20) {
        final width = (bytes[26] | (bytes[27] << 8)) & 0x3FFF;
        final height = (bytes[28] | (bytes[29] << 8)) & 0x3FFF;
        if (width > 0 && height > 0) return (width, height);
      }
    }

    return null;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Compress [sourcePath] and save to the product images directory as a normalized JPEG.
  /// Also generates a companion thumbnail with longest side 256.
  ///
  /// Returns the bare filename (e.g. 'product_123456_abcdef.jpg').
  /// Throws [ImageStorageException] if compression or file operations fail.
  static Future<String> saveImage(String sourcePath) async {
    final srcFile = File(sourcePath);
    if (!await srcFile.exists()) {
      throw const ImageStorageException(
        ImageStorageError.invalidImage,
        'Source image file does not exist',
      );
    }

    Uint8List srcBytes;
    try {
      srcBytes = await srcFile.readAsBytes();
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode == 13 ||
          e.message.toLowerCase().contains('permission')) {
        throw ImageStorageException(
          ImageStorageError.permissionDenied,
          e.message,
          e,
        );
      }
      throw ImageStorageException(ImageStorageError.unexpected, e.message, e);
    }

    if (srcBytes.isEmpty) {
      throw const ImageStorageException(
        ImageStorageError.invalidImage,
        'Source image is empty',
      );
    }

    final format = detectImageFormat(srcBytes);
    if (format == null) {
      throw const ImageStorageException(
        ImageStorageError.invalidImage,
        'Unsupported image format. Allowed: JPG, PNG, WEBP',
      );
    }

    final dir = await _imagesDir();
    final filename = 'product_${_uniqueId()}.jpg';
    final destPath = p.join(dir.path, filename);
    final thumbFilename = thumbNameFor(filename);
    final thumbDestPath = p.join(dir.path, thumbFilename);

    final dims = readImageDimensions(srcBytes);
    final targetDims = computeTargetDimensions(
      sourceWidth: dims?.$1 ?? 800,
      sourceHeight: dims?.$2 ?? 800,
      maxDimension: _maxDimension,
    );

    XFile? result;
    try {
      result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        destPath,
        minWidth: targetDims.$1,
        minHeight: targetDims.$2,
        quality: _quality,
        format: CompressFormat.jpeg,
      );
    } on FileSystemException catch (e) {
      await _deleteIfExists(destPath);
      if (e.osError?.errorCode == 28 ||
          e.message.toLowerCase().contains('space') ||
          e.message.toLowerCase().contains('full')) {
        throw ImageStorageException(ImageStorageError.diskFull, e.message, e);
      }
      if (e.osError?.errorCode == 13 ||
          e.message.toLowerCase().contains('permission')) {
        throw ImageStorageException(
          ImageStorageError.permissionDenied,
          e.message,
          e,
        );
      }
      throw ImageStorageException(ImageStorageError.unexpected, e.message, e);
    } catch (e) {
      await _deleteIfExists(destPath);
      throw ImageStorageException(
        ImageStorageError.unexpected,
        e.toString(),
        e,
      );
    }

    if (result == null) {
      await _deleteIfExists(destPath);
      throw const ImageStorageException(
        ImageStorageError.invalidImage,
        'Unable to compress product image',
      );
    }

    // Create thumbnail (A2)
    try {
      final thumbDims = computeTargetDimensions(
        sourceWidth: dims?.$1 ?? 800,
        sourceHeight: dims?.$2 ?? 800,
        maxDimension: _thumbMaxDimension,
      );
      await FlutterImageCompress.compressAndGetFile(
        destPath,
        thumbDestPath,
        minWidth: thumbDims.$1,
        minHeight: thumbDims.$2,
        quality: _thumbQuality,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      // Best-effort thumbnail creation; never fails main save (A2)
      debugPrint('Thumbnail creation skipped/failed: $e');
    }

    return filename;
  }

  /// Deletes the main image and its thumbnail at [stored].
  /// No-op if [stored] is null or missing. Never throws.
  static Future<void> deleteImage(String? stored) async {
    if (stored == null || stored.isEmpty) return;
    try {
      final mainPath = resolve(stored);
      if (mainPath != null) {
        await _deleteIfExists(mainPath);
      }
    } catch (_) {
      // Best-effort
    }

    try {
      final thumbPath = thumbPathFor(stored);
      if (thumbPath != null) {
        await _deleteIfExists(thumbPath);
      }
    } catch (_) {
      // Best-effort
    }
  }

  /// Returns `true` if [stored] is non-null, non-empty, and the resolved file exists.
  /// Asynchronous, avoiding synchronous IO.
  static Future<bool> isAvailable(String? stored) async {
    if (stored == null || stored.isEmpty) return false;
    try {
      final path = resolve(stored);
      if (path == null) return false;
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  // ── Lazy Thumbnail Backfill (A2) ───────────────────────────────────────────

  static final Set<String> _pendingThumbBackfills = <String>{};
  static bool _isBackfillProcessing = false;
  static final List<String> _backfillQueue = <String>[];

  /// Queues a background lazy thumbnail creation if the thumbnail does not exist.
  /// Single-flight, non-blocking, and de-duplicated.
  static void requestThumbnailBackfill(String? stored) {
    if (stored == null || stored.isEmpty) return;
    final filename = p.basename(stored);
    if (_pendingThumbBackfills.contains(filename)) return;
    _pendingThumbBackfills.add(filename);
    _backfillQueue.add(stored);
    _processBackfillQueue();
  }

  static Future<void> _processBackfillQueue() async {
    if (_isBackfillProcessing) return;
    _isBackfillProcessing = true;
    try {
      while (_backfillQueue.isNotEmpty) {
        final nextStored = _backfillQueue.removeAt(0);
        final filename = p.basename(nextStored);
        try {
          final mainPath = resolve(nextStored);
          final thumbPath = thumbPathFor(nextStored);
          if (mainPath != null && thumbPath != null) {
            final thumbFile = File(thumbPath);
            final mainFile = File(mainPath);
            if (!await thumbFile.exists() && await mainFile.exists()) {
              final mainBytes = await mainFile.readAsBytes();
              final dims = readImageDimensions(mainBytes);
              final targetDims = computeTargetDimensions(
                sourceWidth: dims?.$1 ?? 800,
                sourceHeight: dims?.$2 ?? 800,
                maxDimension: _thumbMaxDimension,
              );
              await FlutterImageCompress.compressAndGetFile(
                mainPath,
                thumbPath,
                minWidth: targetDims.$1,
                minHeight: targetDims.$2,
                quality: _thumbQuality,
                format: CompressFormat.jpeg,
              );
            }
          }
        } catch (e) {
          debugPrint('Thumbnail backfill failed for $filename: $e');
        } finally {
          _pendingThumbBackfills.remove(filename);
        }
      }
    } finally {
      _isBackfillProcessing = false;
    }
  }

  // ── Orphan Sweep (A5) ──────────────────────────────────────────────────────

  /// Sweeps the product images directory and deletes any unreferenced files
  /// (both main files and thumbnails) whose modified timestamp is older than 24 hours.
  /// Never throws.
  static Future<int> sweepOrphans(Set<String> referencedFilenames) async {
    int deletedCount = 0;
    try {
      final dir = await _imagesDir();
      if (!await dir.exists()) return 0;

      final now = DateTime.now();
      const olderThan = Duration(hours: 24);

      final normalizedReferenced = referencedFilenames
          .map((f) => p.basename(f).toLowerCase())
          .toSet();

      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final basename = p.basename(entity.path);
        final lowerName = basename.toLowerCase();

        String mainFilename = basename;
        if (lowerName.contains('_t.')) {
          final ext = p.extension(basename);
          final baseWithoutExt = p.withoutExtension(basename);
          if (baseWithoutExt.endsWith('_t')) {
            mainFilename =
                '${baseWithoutExt.substring(0, baseWithoutExt.length - 2)}$ext';
          }
        }

        final isReferenced = normalizedReferenced.contains(
          mainFilename.toLowerCase(),
        );
        if (isReferenced) continue;

        try {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > olderThan) {
            await entity.delete();
            deletedCount++;
          }
        } catch (_) {
          // Continue sweeping
        }
      }
      debugPrint('Orphan sweep completed: deleted $deletedCount files');
    } catch (e) {
      debugPrint('Orphan sweep failed: $e');
    }
    return deletedCount;
  }

  // ── Backup / Restore ───────────────────────────────────────────────────────

  /// Encodes the main image file at [stored] as a base64 string for backup embedding.
  /// Returns `null` if the file is missing, empty, or unreadable.
  static Future<String?> imageToBase64(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    try {
      final path = resolve(stored);
      if (path == null) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Decodes [base64Data] and restores it into the product images directory.
  /// Re-encodes through the compressor and creates a companion thumbnail.
  ///
  /// Increments [restoreSkippedCount] and returns `null` on failure.
  /// Returns the bare filename on success.
  static Future<String?> base64ToImage(
    String base64Data,
    String productId,
  ) async {
    try {
      if (!RegExp(r'^[0-9]+$').hasMatch(productId)) {
        restoreSkippedCount++;
        return null;
      }
      if (base64Data.trim().isEmpty) {
        restoreSkippedCount++;
        return null;
      }

      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty || bytes.length > maxRestoreSizeBytes) {
        restoreSkippedCount++;
        return null;
      }

      final format = detectImageFormat(bytes);
      if (format == null) {
        restoreSkippedCount++;
        return null;
      }

      final dir = await _imagesDir();
      final filename = 'product_${productId}_${_uniqueId()}.jpg';
      final destPath = p.join(dir.path, filename);
      final thumbFilename = thumbNameFor(filename);
      final thumbDestPath = p.join(dir.path, thumbFilename);

      final tempPath = p.join(dir.path, 'temp_restore_${_uniqueId()}');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);

      try {
        final dims = readImageDimensions(bytes);
        final targetDims = computeTargetDimensions(
          sourceWidth: dims?.$1 ?? 800,
          sourceHeight: dims?.$2 ?? 800,
          maxDimension: _maxDimension,
        );

        XFile? result;
        try {
          result = await FlutterImageCompress.compressAndGetFile(
            tempPath,
            destPath,
            minWidth: targetDims.$1,
            minHeight: targetDims.$2,
            quality: _quality,
            format: CompressFormat.jpeg,
          );
        } catch (_) {
          result = null;
        }

        if (result == null) {
          if (format == 'jpeg') {
            await File(destPath).writeAsBytes(bytes, flush: true);
          } else {
            restoreSkippedCount++;
            return null;
          }
        }

        // Generate thumbnail
        try {
          final thumbDims = computeTargetDimensions(
            sourceWidth: dims?.$1 ?? 800,
            sourceHeight: dims?.$2 ?? 800,
            maxDimension: _thumbMaxDimension,
          );
          await FlutterImageCompress.compressAndGetFile(
            destPath,
            thumbDestPath,
            minWidth: thumbDims.$1,
            minHeight: thumbDims.$2,
            quality: _thumbQuality,
            format: CompressFormat.jpeg,
          );
        } catch (_) {
          // Best effort
        }

        return destPath;
      } finally {
        await _deleteIfExists(tempPath);
      }
    } catch (_) {
      restoreSkippedCount++;
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static final _rng = Random.secure();

  static String _uniqueId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = _rng.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${ts}_$rand';
  }

  static Future<void> _deleteIfExists(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
