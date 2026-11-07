import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/backup_service.dart';

void main() {
  group('Backup Version Validation Tests (Batch 10)', () {
    test(
      '1. Future backup version is rejected with exact upgrade instruction',
      () async {
        final futureBackupMap = {
          'app': 'warqatek',
          'backup_version': 99,
          'database_version': 27,
          'data': {
            'businesses': [],
            'contacts': [],
            'products': [],
            'documents': [],
            'document_items': [],
            'document_counters': [],
            'document_payments': [],
          },
        };

        expect(
          () => BackupService.restoreFromJsonMap(
            futureBackupMap,
            createSafetyBackup: false,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'Backup version 99 requires a newer version of the application. Please update the app.',
              ),
            ),
          ),
        );
      },
    );

    test('2. Unsupported non-positive version is rejected', () async {
      final invalidBackupMap = {
        'app': 'warqatek',
        'backup_version': 0,
        'database_version': 27,
        'data': {},
      };

      expect(
        () => BackupService.restoreFromJsonMap(
          invalidBackupMap,
          createSafetyBackup: false,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unsupported backup version: 0'),
          ),
        ),
      );
    });

    test('3. Non-Waraqatak backup is rejected', () async {
      final strangerBackupMap = {
        'app': 'other_app',
        'backup_version': 5,
        'data': {},
      };

      expect(
        () => BackupService.restoreFromJsonMap(
          strangerBackupMap,
          createSafetyBackup: false,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Not a Warqatek backup'),
          ),
        ),
      );
    });

    test(
      '4. Atomic write failure leaves previous backup byte-identical and cleans up .tmp',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'atomic_backup_test_',
        );
        try {
          final targetFile = File('${tempDir.path}/test_backup.waraq');
          final initialBytes = [1, 2, 3, 4, 5, 6, 7, 8];
          await targetFile.writeAsBytes(initialBytes, flush: true);

          // Configure backup generator override to return valid JSON
          BackupService.buildBackupJsonOverride = () async => jsonEncode({
            'app': 'warqatek',
            'backup_version': 5,
            'database_version': 27,
            'data': {
              'businesses': [],
              'contacts': [],
              'products': [],
              'product_units': [],
              'documents': [],
              'document_items': [],
              'document_counters': [],
              'document_payments': [],
              'stock_movements': [],
              'tax_profiles': [],
              'payment_methods': [],
              'stocktake_sessions': [],
              'stocktake_items': [],
              'audit_log': [],
              'accounts': [],
              'journal_entries': [],
              'journal_lines': [],
              'app_settings': [],
            },
          });

          // Simulate a promotion failure (e.g. disk full or IO error before rename)
          BackupService.onBeforeLocalPromotion = (temp, target) async {
            throw const FileSystemException('Simulated disk failure');
          };

          await expectLater(
            BackupService.createLocalBackup(targetPath: targetFile.path),
            throwsA(isA<FileSystemException>()),
          );

          // Target file must still exist and be 100% byte-identical
          expect(await targetFile.exists(), isTrue);
          final postBytes = await targetFile.readAsBytes();
          expect(postBytes, equals(initialBytes));

          // Temporary file must be cleaned up
          final tmpFile = File('${targetFile.path}.tmp');
          expect(await tmpFile.exists(), isFalse);
        } finally {
          BackupService.buildBackupJsonOverride = null;
          BackupService.onBeforeLocalPromotion = null;
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        }
      },
    );
  });
}
