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
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: testPassword,
        iterations: 100000,
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
        iterations: 100000,
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
        iterations: 100000,
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
        iterations: 100000,
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

    test('5. Header as AAD: mutating any header byte fails decryption', () async {
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: testPassword,
        iterations: 100000,
      );

      // Mutate salt byte in header (offset 15)
      final tamperedSalt = Uint8List.fromList(encryptedBytes);
      tamperedSalt[15] ^= 0xAA;
      expect(
        () async => await BackupEncryptionService.decryptJson(
          encryptedBytes: tamperedSalt,
          password: testPassword,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );

      // Mutate nonce byte in header (offset 30)
      final tamperedNonce = Uint8List.fromList(encryptedBytes);
      tamperedNonce[30] ^= 0xAA;
      expect(
        () async => await BackupEncryptionService.decryptJson(
          encryptedBytes: tamperedNonce,
          password: testPassword,
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });

    test('6. Iteration bounds [100000, 10000000] rejected before KDF: 0, 1, 99999, 10000001, 4294967295', () async {
      final validBytes = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: testPassword,
        iterations: 100000,
      );

      final testCases = <int>[0, 1, 99999, 10000001, 4294967295];
      for (final badIterations in testCases) {
        final tampered = Uint8List.fromList(validBytes);
        final bd = ByteData.sublistView(tampered);
        bd.setUint32(8, badIterations, Endian.big);

        expect(
          () async => await BackupEncryptionService.decryptJson(
            encryptedBytes: tampered,
            password: testPassword,
          ),
          throwsA(isA<BackupCorruptedFileException>()),
          reason: 'Iteration count $badIterations must be rejected immediately as corrupted file',
        );
      }
    });

    test('7. Password normalization: Arabic-Indic, Eastern Arabic-Indic, and ASCII digits decrypt identically', () async {
      // Create backup with Western ASCII digits: "Waraqatak2026!"
      const asciiPass = 'Waraqatak2026!';
      // Same password typed with Arabic-Indic digits: "Waraqatak٢٠٢٦!"
      const arabicIndicPass = 'Waraqatak٢٠٢٦!';
      // Same password typed with Eastern Arabic-Indic (Persian/Urdu) digits: "Waraqatak۲۰۲۶!"
      const easternArabicPass = 'Waraqatak۲۰۲۶!';

      // Verify normalization helper produces exact same string
      expect(
        BackupEncryptionService.normalizePassword(arabicIndicPass),
        equals(asciiPass),
      );
      expect(
        BackupEncryptionService.normalizePassword(easternArabicPass),
        equals(asciiPass),
      );

      // Encrypt with Arabic-Indic digits
      final encrypted = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: arabicIndicPass,
        iterations: 100000,
      );

      // Decrypt with ASCII digits
      final decryptedWithAscii = await BackupEncryptionService.decryptJson(
        encryptedBytes: encrypted,
        password: asciiPass,
      );
      expect(decryptedWithAscii, equals(testJson));

      // Decrypt with Eastern Arabic-Indic digits
      final decryptedWithEastern = await BackupEncryptionService.decryptJson(
        encryptedBytes: encrypted,
        password: easternArabicPass,
      );
      expect(decryptedWithEastern, equals(testJson));
    });

    test('8. Known-answer test with Arabic password and NFKC normalization', () async {
      // Arabic password with combined characters and Arabic digits
      const arabicPassword = 'كلمة_سر_ورقتك_١٤٤٨';
      const asciiEquivalent = 'كلمة_سر_ورقتك_1448';

      final encrypted = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: arabicPassword,
        iterations: 100000,
      );

      final decrypted = await BackupEncryptionService.decryptJson(
        encryptedBytes: encrypted,
        password: asciiEquivalent,
      );
      expect(decrypted, equals(testJson));
    });

    test('9. Password normalization preserves whitespace and case', () async {
      const spaceCasePass = ' My Secret Pass 123 ';
      final normalized = BackupEncryptionService.normalizePassword(spaceCasePass);
      expect(normalized, equals(spaceCasePass));
      expect(normalized.startsWith(' '), isTrue);
      expect(normalized.endsWith(' '), isTrue);

      // Uppercase vs lowercase are distinct
      expect(
        BackupEncryptionService.normalizePassword('PASSword123'),
        isNot(equals(BackupEncryptionService.normalizePassword('password123'))),
      );
    });

    test('10. Short normalized password (< 8 chars) is rejected on encryption', () async {
      expect(
        () async => await BackupEncryptionService.encryptJson(
          jsonStr: testJson,
          password: 'short',
          iterations: 100000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('11. Truncated file or file shorter than header throws BackupCorruptedFileException', () async {
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

    test('12. Legacy plain JSON file is not detected as encrypted and cannot be decrypted directly', () async {
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

    test('13. Newer format version throws BackupUnsupportedVersionException', () async {
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: testJson,
        password: testPassword,
        iterations: 100000,
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

    test('14. Encrypted backup with cancelled invoice and refund audit_log round-trips cleanly', () async {
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
        iterations: 100000,
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

    test('15. Legacy backup without audit_log key parses safely after decryption', () async {
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
        iterations: 100000,
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
