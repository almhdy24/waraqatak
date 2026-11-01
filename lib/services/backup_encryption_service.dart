import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

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

/// Core service for encrypting and decrypting Waraqatak backup files.
///
/// Binary format specification:
/// - Bytes 0..5: ASCII magic header "WRQENC" (6 bytes)
/// - Byte 6: Format version (1 byte, currently 0x01)
/// - Byte 7: KDF algorithm ID (1 byte, 0x01 = PBKDF2-HMAC-SHA256)
/// - Bytes 8..11: KDF iteration count (4 bytes, big-endian uint32, e.g. 600,000)
/// - Bytes 12..27: Random salt (16 bytes)
/// - Bytes 28..39: Random nonce / IV (12 bytes)
/// - Bytes 40..N-16: AES-256-GCM ciphertext
/// - Bytes N-16..N: AES-256-GCM authentication tag (16 bytes)
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
  static const int minIterations = 10000;
  static const int minPasswordLength = 8;

  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int tagLength = 16;
  static const int headerLength = 40;
  static const int minEncryptedFileSize = headerLength + tagLength;

  /// Checks whether [bytes] begins with the encrypted backup magic header "WRQENC".
  static bool isEncrypted(List<int> bytes) {
    if (bytes.length < magicBytes.length) return false;
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) return false;
    }
    return true;
  }

  /// Encrypts [jsonStr] with [password] using PBKDF2-HMAC-SHA256 and AES-256-GCM.
  ///
  /// Automatically validates in-memory before returning bytes to guarantee recovery.
  /// Throws [ArgumentError] if password is shorter than [minPasswordLength].
  /// Throws [BackupEncryptionVerificationException] if round-trip validation fails.
  static Future<Uint8List> encryptJson({
    required String jsonStr,
    required String password,
    int iterations = defaultIterations,
  }) async {
    if (password.length < minPasswordLength) {
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

    // 2. Derive 256-bit AES key using PBKDF2-HMAC-SHA256
    final pbkdf2 = Pbkdf2.hmacSha256(
      bits: 256,
      iterations: iterations,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    // 3. Encrypt cleartext with AES-256-GCM
    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      clearTextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 4. Assemble the binary file
    final cipherText = secretBox.cipherText;
    final macBytes = secretBox.mac.bytes;
    final totalLength = headerLength + cipherText.length + macBytes.length;
    final output = Uint8List(totalLength);
    final byteData = ByteData.sublistView(output);

    // Magic bytes (0..5)
    for (var i = 0; i < magicBytes.length; i++) {
      output[i] = magicBytes[i];
    }
    // Format version (6)
    output[6] = currentFormatVersion;
    // KDF ID (7)
    output[7] = kdfPbkdf2HmacSha256;
    // Iterations (8..11, big-endian uint32)
    byteData.setUint32(8, iterations, Endian.big);
    // Salt (12..27)
    output.setRange(12, 12 + saltLength, salt);
    // Nonce (28..39)
    output.setRange(28, 28 + nonceLength, nonce);
    // Ciphertext (40 .. 40 + cipherText.length)
    output.setRange(40, 40 + cipherText.length, cipherText);
    // Authentication tag (40 + cipherText.length .. end)
    output.setRange(
      40 + cipherText.length,
      40 + cipherText.length + macBytes.length,
      macBytes,
    );

    // 5. In-memory round-trip self-check BEFORE returning
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
  /// Throws [BackupUnsupportedVersionException] if format version or KDF is newer.
  /// Throws [BackupCorruptedFileException] if header structure is invalid.
  /// Throws [BackupDecryptionException] if password is wrong or data is tampered.
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

    // Iterations (uint32 big-endian)
    final iterations = byteData.getUint32(8, Endian.big);
    if (iterations < minIterations) {
      throw const BackupCorruptedFileException('Invalid iteration count');
    }

    // Extract salt (12..27) and nonce (28..39)
    final salt = bytes.sublist(12, 12 + saltLength);
    final nonce = bytes.sublist(28, 28 + nonceLength);

    // Extract ciphertext (40 .. length - tagLength) and tag (length - tagLength .. length)
    final cipherTextEnd = bytes.length - tagLength;
    final cipherText = bytes.sublist(40, cipherTextEnd);
    final macBytes = bytes.sublist(cipherTextEnd, bytes.length);

    // Derive key
    final pbkdf2 = Pbkdf2.hmacSha256(
      bits: 256,
      iterations: iterations,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    // Decrypt and authenticate
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
