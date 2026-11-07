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
          'database_version': 26,
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
        'database_version': 26,
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
  });
}
