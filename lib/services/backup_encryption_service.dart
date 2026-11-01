import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Exceptions thrown during backup encryption and decryption.
abstract class BackupEncryptionException implements Exception {
  final String message;
  const BackupEncryptionException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the password is incorrect or authentication tag verification fails.
class BackupDecryptionException extends BackupEncryptionException {
  const BackupDecryptionException([
    super.message = 'Incorrect password or corrupted backup file',
  ]);
}

/// Thrown when the backup file format version or algorithm is newer than supported.
class BackupUnsupportedVersionException extends BackupEncryptionException {
  final int version;
  const BackupUnsupportedVersionException(
    this.version, [
    super.message = 'Unsupported backup format version. Please update the app.',
  ]);
}

/// Thrown when the backup file has an invalid header, truncated data, or corrupt structure.
class BackupCorruptedFileException extends BackupEncryptionException {
  const BackupCorruptedFileException([
    super.message = 'Corrupted backup file header or structure',
  ]);
}

/// Thrown if in-memory self-verification fails immediately after encryption.
class BackupEncryptionVerificationException extends BackupEncryptionException {
  const BackupEncryptionVerificationException([
    super.message = 'Backup encryption verification failed',
  ]);
}

/// Parameters passed to isolate for pure-Dart PBKDF2 fallback.
class _Pbkdf2FallbackParams {
  final String password;
  final List<int> salt;
  final int iterations;

  const _Pbkdf2FallbackParams({
    required this.password,
    required this.salt,
    required this.iterations,
  });
}

/// Core service for encrypting and decrypting Waraqatak backup files.
///
/// Binary format specification:
/// - Bytes 0..5: ASCII magic header "WRQENC" (6 bytes)
/// - Byte 6: Format version (1 byte, currently 0x01)
/// - Byte 7: KDF algorithm ID (1 byte, 0x01 = PBKDF2-HMAC-SHA256)
/// - Bytes 8..11: KDF iteration count (4 bytes, big-endian uint32, bounds: [100,000, 10,000,000])
/// - Bytes 12..27: Random salt (16 bytes)
/// - Bytes 28..39: Random nonce / IV (12 bytes)
/// - Bytes 40..N-16: AES-256-GCM ciphertext
/// - Bytes N-16..N: AES-256-GCM authentication tag (16 bytes)
///
/// Cryptographic Binding:
/// The entire 40-byte header is authenticated via AES-GCM Additional Authenticated Data (AAD).
/// Any alteration of header fields (including format version, KDF ID, iterations, salt, or nonce)
/// causes GCM tag verification to fail during decryption.
///
/// Total header length = 40 bytes. Minimum valid encrypted file size = 56 bytes.
class BackupEncryptionService {
  /// Magic bytes representing ASCII "WRQENC".
  static const List<int> magicBytes = [
    0x57, // 'W'
    0x52, // 'R'
    0x51, // 'Q'
    0x45, // 'E'
    0x4E, // 'N'
    0x43, // 'C'
  ];

  static const int currentFormatVersion = 1;
  static const int kdfPbkdf2HmacSha256 = 1;
  static const int defaultIterations = 600000;
  static const int minIterations = 100000;
  static const int maxIterations = 10000000;
  static const int minPasswordLength = 8;

  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int tagLength = 16;
  static const int headerLength = 40;
  static const int minEncryptedFileSize = headerLength + tagLength;

  /// Normalizes [password] identically for both encryption and decryption:
  /// 1. Unicode NFKC normalization (via `unorm_dart`).
  /// 2. Maps Arabic-Indic digits (U+0660..U+0669: ٠-٩) to ASCII '0'..'9'.
  /// 3. Maps Eastern Arabic-Indic digits (U+06F0..U+06F9: ۰-۹) to ASCII '0'..'9'.
  /// 4. Does NOT trim whitespace (preserves exact intentional spaces).
  /// 5. Does NOT alter casing (preserves uppercase / lowercase distinctions).
  static String normalizePassword(String password) {
    final nfkc = unorm.nfkc(password);
    final sb = StringBuffer();
    for (final rune in nfkc.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        sb.writeCharCode(0x30 + (rune - 0x0660));
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        sb.writeCharCode(0x30 + (rune - 0x06F0));
      } else {
        sb.writeCharCode(rune);
      }
    }
    return sb.toString();
  }

  /// Checks whether [bytes] begins with the encrypted backup magic header "WRQENC".
  static bool isEncrypted(List<int> bytes) {
    if (bytes.length < magicBytes.length) return false;
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) return false;
    }
    return true;
  }

  /// Derives an AES-256 key from [normalizedPassword] and [salt] using PBKDF2-HMAC-SHA256.
  ///
  /// Prefers native Android platform acceleration (`SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")`).
  /// On older platforms (e.g. Android 7.0/7.1 API 24/25 where PBKDF2WithHmacSHA256 is not in the system provider)
  /// or in headless test environments, gracefully falls back to pure-Dart PBKDF2 running strictly
  /// in a background isolate via [compute] so the main UI thread and progress spinner never freeze.
  static Future<SecretKey> _deriveKey({
    required String normalizedPassword,
    required List<int> salt,
    required int iterations,
  }) async {
    try {
      final pbkdf2 = Pbkdf2.hmacSha256(
        bits: 256,
        iterations: iterations,
      );
      return await pbkdf2.deriveKeyFromPassword(
        password: normalizedPassword,
        nonce: salt,
      );
    } catch (_) {
      // Fallback: run pure-Dart PBKDF2 in an isolate to avoid blocking UI
      final keyBytes = await compute(
        _computePureDartPbkdf2,
        _Pbkdf2FallbackParams(
          password: normalizedPassword,
          salt: salt,
          iterations: iterations,
        ),
      );
      return SecretKeyData(keyBytes);
    }
  }

  /// Entry point executed inside a background isolate for pure-Dart PBKDF2 fallback.
  static Future<List<int>> _computePureDartPbkdf2(
    _Pbkdf2FallbackParams params,
  ) async {
    final pureDart = DartPbkdf2(
      macAlgorithm: const DartHmac(DartSha256()),
      bits: 256,
      iterations: params.iterations,
    );
    final secretKey = await pureDart.deriveKeyFromPassword(
      password: params.password,
      nonce: params.salt,
    );
    return await secretKey.extractBytes();
  }

  /// Encrypts [jsonStr] with [password] using PBKDF2-HMAC-SHA256 and AES-256-GCM.
  ///
  /// - Normalizes [password] via [normalizePassword].
  /// - Binds the 40-byte header as AES-GCM Additional Authenticated Data (AAD).
  /// - Automatically validates in-memory before returning bytes to guarantee recovery.
  /// - Throws [ArgumentError] if normalized password is shorter than [minPasswordLength].
  /// - Throws [BackupEncryptionVerificationException] if round-trip validation fails.
  static Future<Uint8List> encryptJson({
    required String jsonStr,
    required String password,
    int iterations = defaultIterations,
  }) async {
    final normalizedPassword = normalizePassword(password);
    if (normalizedPassword.length < minPasswordLength) {
      throw ArgumentError(
        'Password must be at least $minPasswordLength characters long.',
      );
    }

    final clearTextBytes = utf8.encode(jsonStr);

    // 1. Generate cryptographically secure random salt (16 bytes) and nonce (12 bytes)
    final random = Random.secure();
    final salt = Uint8List(saltLength);
    for (var i = 0; i < saltLength; i++) {
      salt[i] = random.nextInt(256);
    }

    final nonce = Uint8List(nonceLength);
    for (var i = 0; i < nonceLength; i++) {
      nonce[i] = random.nextInt(256);
    }

    // 2. Build the 40-byte header
    final header = Uint8List(headerLength);
    final headerView = ByteData.sublistView(header);
    for (var i = 0; i < magicBytes.length; i++) {
      header[i] = magicBytes[i];
    }
    header[6] = currentFormatVersion;
    header[7] = kdfPbkdf2HmacSha256;
    headerView.setUint32(8, iterations, Endian.big);
    header.setRange(12, 12 + saltLength, salt);
    header.setRange(28, 28 + nonceLength, nonce);

    // 3. Derive 256-bit AES key using PBKDF2-HMAC-SHA256
    final secretKey = await _deriveKey(
      normalizedPassword: normalizedPassword,
      salt: salt,
      iterations: iterations,
    );

    // 4. Encrypt cleartext with AES-256-GCM passing the 40-byte header as AAD
    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      clearTextBytes,
      secretKey: secretKey,
      nonce: nonce,
      aad: header,
    );

    // 5. Assemble the binary file: Header (40 bytes) + Ciphertext + GCM Tag (16 bytes)
    final cipherText = secretBox.cipherText;
    final macBytes = secretBox.mac.bytes;
    final totalLength = headerLength + cipherText.length + macBytes.length;
    final output = Uint8List(totalLength);

    output.setRange(0, headerLength, header);
    output.setRange(headerLength, headerLength + cipherText.length, cipherText);
    output.setRange(
      headerLength + cipherText.length,
      totalLength,
      macBytes,
    );

    // 6. In-memory round-trip self-check BEFORE returning
    try {
      final decrypted = await decryptJson(
        encryptedBytes: output,
        password: password,
      );
      if (decrypted != jsonStr) {
        throw const BackupEncryptionVerificationException(
          'In-memory round-trip verification failed: decrypted JSON mismatch.',
        );
      }
    } catch (e) {
      if (e is BackupEncryptionException) rethrow;
      throw BackupEncryptionVerificationException(
        'In-memory round-trip verification failed: $e',
      );
    }

    return output;
  }

  /// Decrypts [encryptedBytes] using [password] and returns the plain JSON string.
  ///
  /// - Normalizes [password] via [normalizePassword].
  /// - Validates magic header and file length.
  /// - Validates iterations within [minIterations, maxIterations] BEFORE key derivation.
  /// - Authenticates the 40-byte header as AAD in AES-256-GCM.
  /// - Throws [BackupUnsupportedVersionException] if format version or KDF is newer.
  /// - Throws [BackupCorruptedFileException] if header structure is invalid or iterations out of bounds.
  /// - Throws [BackupDecryptionException] if password is wrong or data is tampered.
  static Future<String> decryptJson({
    required List<int> encryptedBytes,
    required String password,
  }) async {
    if (!isEncrypted(encryptedBytes)) {
      throw const BackupCorruptedFileException(
        'Not an encrypted Waraqatak backup (missing magic header)',
      );
    }

    if (encryptedBytes.length < minEncryptedFileSize) {
      throw const BackupCorruptedFileException(
        'File is too short to be a valid encrypted backup',
      );
    }

    final bytes = encryptedBytes is Uint8List
        ? encryptedBytes
        : Uint8List.fromList(encryptedBytes);
    final byteData = ByteData.sublistView(bytes);

    // Format version
    final version = bytes[6];
    if (version > currentFormatVersion) {
      throw BackupUnsupportedVersionException(version);
    }

    // KDF ID
    final kdfId = bytes[7];
    if (kdfId != kdfPbkdf2HmacSha256) {
      throw BackupUnsupportedVersionException(version);
    }

    // Iterations (uint32 big-endian).
    // MUST validate bounds BEFORE any key derivation to prevent DoS freezes.
    final iterations = byteData.getUint32(8, Endian.big);
    if (iterations < minIterations || iterations > maxIterations) {
      throw const BackupCorruptedFileException('Invalid iteration count');
    }

    // Extract 40-byte header for AAD authentication
    final header = bytes.sublist(0, headerLength);

    // Extract salt (12..27) and nonce (28..39)
    final salt = bytes.sublist(12, 12 + saltLength);
    final nonce = bytes.sublist(28, 28 + nonceLength);

    // Extract ciphertext (40 .. length - tagLength) and tag (length - tagLength .. length)
    final cipherTextEnd = bytes.length - tagLength;
    final cipherText = bytes.sublist(40, cipherTextEnd);
    final macBytes = bytes.sublist(cipherTextEnd, bytes.length);

    // Derive key using normalized password
    final normalizedPassword = normalizePassword(password);
    final secretKey = await _deriveKey(
      normalizedPassword: normalizedPassword,
      salt: salt,
      iterations: iterations,
    );

    // Decrypt and authenticate passing header as AAD
    final aesGcm = AesGcm.with256bits();
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    List<int> clearTextBytes;
    try {
      clearTextBytes = await aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: header,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupDecryptionException();
    } catch (_) {
      throw const BackupDecryptionException();
    }

    try {
      return utf8.decode(clearTextBytes);
    } catch (_) {
      throw const BackupCorruptedFileException(
        'Decrypted payload is not valid UTF-8 text',
      );
    }
  }
}
