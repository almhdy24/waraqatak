import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Base class for all backup-related exceptions.
abstract class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// Exceptions thrown during backup encryption and decryption.
abstract class BackupEncryptionException extends BackupException {
  const BackupEncryptionException(super.message);
}

/// Thrown when persistent safety backup key retrieval, storage, or verification fails.
class BackupKeyPersistenceException extends BackupEncryptionException {
  const BackupKeyPersistenceException([
    super.message = 'Failed to access or persist durable safety backup key',
  ]);
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

/// Thrown when backup structure or JSON schema is invalid or unrecognized.
class BackupInvalidFormatException extends BackupException {
  const BackupInvalidFormatException([super.message = 'Invalid backup format']);
}

/// Thrown when SQLite database integrity check fails post-restore.
class BackupIntegrityException extends BackupException {
  const BackupIntegrityException([
    super.message = 'Database integrity check failed post-restore',
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
  static const int parityTestIterations = 1000;

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

  /// Compares two byte lists in constant time to prevent timing attacks.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Derives an AES-256 key from [normalizedPassword] and [salt] using PBKDF2-HMAC-SHA256.
  ///
  /// Guarantees cross-platform parity:
  /// Before using the native Android platform implementation (`SecretKeyFactory`),
  /// a cheap runtime parity check (1000 iterations) is executed comparing native output
  /// with the specification-compliant pure-Dart implementation for the user's actual
  /// normalized password and salt.
  /// If outputs match, native acceleration is safely used for the full iteration count.
  /// If native derivation throws (e.g. Android API 24/25) or outputs differ, it falls
  /// back immediately to pure-Dart running inside a background isolate via [compute].
  /// Nothing about the password or derived keys is cached.
  static Future<SecretKey> _deriveKey({
    required String normalizedPassword,
    required List<int> salt,
    required int iterations,
  }) async {
    bool nativeParityPassed = false;
    try {
      // 1. Cheap runtime parity test (1000 iterations)
      final pbkdf2Native = Pbkdf2.hmacSha256(
        bits: 256,
        iterations: parityTestIterations,
      );
      final nativeTestKey = await pbkdf2Native.deriveKeyFromPassword(
        password: normalizedPassword,
        nonce: salt,
      );
      final nativeTestBytes = await nativeTestKey.extractBytes();

      final pureDartTest = DartPbkdf2(
        macAlgorithm: const DartHmac(DartSha256()),
        bits: 256,
        iterations: parityTestIterations,
      );
      final dartTestKey = await pureDartTest.deriveKeyFromPassword(
        password: normalizedPassword,
        nonce: salt,
      );
      final dartTestBytes = await dartTestKey.extractBytes();

      if (_constantTimeEquals(nativeTestBytes, dartTestBytes)) {
        nativeParityPassed = true;
      } else {
        if (kDebugMode) {
          debugPrint(
            'PBKDF2 parity check: Native output differs from pure-Dart specification. Falling back to pure-Dart isolate.',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'PBKDF2 parity check: Native derivation failed ($e). Falling back to pure-Dart isolate.',
        );
      }
      nativeParityPassed = false;
    }

    if (nativeParityPassed) {
      try {
        final pbkdf2Native = Pbkdf2.hmacSha256(
          bits: 256,
          iterations: iterations,
        );
        return await pbkdf2Native.deriveKeyFromPassword(
          password: normalizedPassword,
          nonce: salt,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Native PBKDF2 full derivation failed ($e). Falling back to pure-Dart isolate.',
          );
        }
      }
    }

    // Pure-Dart fallback executing off the UI isolate
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

  /// Exposed for testing: derives key using pure-Dart PBKDF2 in an isolate.
  @visibleForTesting
  static Future<List<int>> deriveKeyPureDart({
    required String password,
    required List<int> salt,
    required int iterations,
  }) async {
    final normalized = normalizePassword(password);
    return _computePureDartPbkdf2(
      _Pbkdf2FallbackParams(
        password: normalized,
        salt: salt,
        iterations: iterations,
      ),
    );
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
    output.setRange(headerLength + cipherText.length, totalLength, macBytes);

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
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

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
