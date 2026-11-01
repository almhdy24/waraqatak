import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/backup_encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPassword = 'StrongPassword123!';
  const testJson = '{"app_id":"warqatek","schema_version":4,"data":{"businesses":[],"documents":[{"id":10,"status":"cancelled"}],"audit_log":[{"id":1,"event_type":"document_cancelled","details":"refund_status:refunded"}]}}';

  group('BackupEncryptionService Core Tests', () {
    test('1. Round trip encrypt and decrypt succeeds with identical content', () async {
      // Use low iteration count in unit tests for speed while preserving exact logic
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: testPassword,
        iterations: 10000,
      );

      expect(encryptedBytes, isNotNull);
      expect(BackupEncryptionService.isEncrypted(encryptedBytes), isTrue);
      expect(encryptedBytes.length, greaterThan(BackupEncryptionService.headerLength));

      // Decrypt
      final decrypted = await BackupEncryptionService.decryptJson(
        encryptedBytes: encryptedBytes,
        password: testPassword,
      );

      expect(decrypted, equals(testJson));
    });

    test('2. Wrong password throws BackupDecryptionException', () async {
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: testPassword,
        iterations: 10000,
      );

      expect(
        () async => await BackupEncryptionService.decryptJson(
          encryptedBytes: encryptedBytes,
          password: 'WrongPassword999!',
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });

    test('3. Tampered ciphertext throws BackupDecryptionException', () async {
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: testPassword,
        iterations: 10000,
      );

      // Mutate a byte in the ciphertext portion (offset 45)
      final tamperedBytes = Uint8List.fromList(encryptedBytes);
      tamperedBytes[45] ^= 0xFF;

      expect(
        () async => await BackupEncryptionService.decryptJson(
          encryptedBytes: tamperedBytes,
          password: testPassword,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });

    test('4. Tampered authentication tag throws BackupDecryptionException', () async {
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: testPassword,
        iterations: 10000,
      );

      // Mutate the last byte (part of the 16-byte GCM tag)
      final tamperedBytes = Uint8List.fromList(encryptedBytes);
      tamperedBytes[tamperedBytes.length - 1] ^= 0x55;

      expect(
        () async => await BackupEncryptionService.decryptJson(
          encryptedBytes: tamperedBytes,
          password: testPassword,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });

    test('5. Short password (< 8 chars) is rejected on encryption', () async {
      expect(
        () async => await BackupEncryptionService.encryptJson(
          jsonStr: testJson,
          password: 'short',
          iterations: 10000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('6. Truncated file or file shorter than header throws BackupCorruptedFileException', () async {
      // Magic header only (6 bytes)
      final shortBytes = Uint8List.fromList(BackupEncryptionService.magicBytes);
      expect(BackupEncryptionService.isEncrypted(shortBytes), isTrue);

      expect(
        () async => await BackupEncryptionService.decryptJson(
          encryptedBytes: shortBytes,
          password: testPassword,
        ),
        throwsA(isA<BackupCorruptedFileException>()),
      );
    });

    test('7. Legacy plain JSON file is not detected as encrypted and cannot be decrypted directly', () async {
      final plainBytes = utf8.encode(testJson);
      expect(BackupEncryptionService.isEncrypted(plainBytes), isFalse);

      expect(
        () async => await BackupEncryptionService.decryptJson(
          encryptedBytes: plainBytes,
          password: testPassword,
        ),
        throwsA(isA<BackupCorruptedFileException>()),
      );
    });

    test('8. Newer format version throws BackupUnsupportedVersionException', () async {
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: testPassword,
        iterations: 10000,
      );

      // Change format version from 1 to 99
      final futureVersionBytes = Uint8List.fromList(encryptedBytes);
      futureVersionBytes[6] = 99;

      expect(
        () async => await BackupEncryptionService.decryptJson(
          encryptedBytes: futureVersionBytes,
          password: testPassword,
        ),
        throwsA(isA<BackupUnsupportedVersionException>()),
      );
    });

    test('9. Encrypted backup with cancelled invoice and refund audit_log round-trips cleanly', () async {
      const complexBackupJson = '''
      {
        "app_id": "warqatek",
        "schema_version": 4,
        "backup_version": 4,
        "data": {
          "businesses": [{"id": 1, "name": "Test Store"}],
          "documents": [
            {
              "id": 101,
              "type": "sale_invoice",
              "number": "INV-101",
              "status": "cancelled",
              "paid": 250.0,
              "notes": "Cancelled invoice"
            }
          ],
          "audit_log": [
            {
              "id": 1,
              "event_type": "document_cancelled",
              "entity_type": "document",
              "entity_id": 101,
              "details": "refund_status:refunded",
              "created_at": "2026-11-01T15:00:00.000Z"
            }
          ]
        }
      }
      ''';

      final encrypted = await BackupEncryptionService.encryptJson(
        jsonStr: complexBackupJson,
        password: testPassword,
        iterations: 10000,
      );

      final decrypted = await BackupEncryptionService.decryptJson(
        encryptedBytes: encrypted,
        password: testPassword,
      );

      final parsed = jsonDecode(decrypted) as Map<String, dynamic>;
      expect(parsed['app_id'], equals('warqatek'));
      final data = parsed['data'] as Map<String, dynamic>;
      final docs = data['documents'] as List<dynamic>;
      expect(docs.first['status'], equals('cancelled'));

      final auditLog = data['audit_log'] as List<dynamic>;
      expect(auditLog.first['event_type'], equals('document_cancelled'));
      expect(auditLog.first['details'], contains('refund_status:refunded'));
    });

    test('10. Legacy backup without audit_log key parses safely after decryption', () async {
      const legacyBackupWithoutAudit = '''
      {
        "app_id": "warqatek",
        "schema_version": 4,
        "backup_version": 3,
        "data": {
          "businesses": [{"id": 1, "name": "Old Store"}],
          "documents": []
        }
      }
      ''';

      final encrypted = await BackupEncryptionService.encryptJson(
        jsonStr: legacyBackupWithoutAudit,
        password: testPassword,
        iterations: 10000,
      );

      final decrypted = await BackupEncryptionService.decryptJson(
        encryptedBytes: encrypted,
        password: testPassword,
      );

      final parsed = jsonDecode(decrypted) as Map<String, dynamic>;
      final data = parsed['data'] as Map<String, dynamic>;
      expect(data.containsKey('audit_log'), isFalse);
    });
  });
}
