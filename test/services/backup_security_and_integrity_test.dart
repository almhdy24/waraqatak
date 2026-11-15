import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('backup_security_test');
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Phase 1 & 2: Backup Security, Integrity & Retention Tests', () {
    test(
      'Local backup retention prunes older backups keeping at most 7',
      () async {
        final testBackupDir = Directory('${tempDir.path}/local_retention_test')
          ..createSync(recursive: true);
        BackupService.backupDirectoryOverride = () => testBackupDir;

        try {
          final now = DateTime.now();
          for (int i = 0; i < 10; i++) {
            final file = File(
              '${testBackupDir.path}/warqatek_backup_${1000 + i}.waraq',
            );
            file.writeAsStringSync('mock backup content $i');
            file.setLastModifiedSync(now.subtract(Duration(hours: 10 - i)));
          }

          expect(testBackupDir.listSync().whereType<File>().length, 10);

          await BackupService.pruneLocalBackups();

          final remaining = testBackupDir.listSync().whereType<File>().toList();
          expect(remaining.length, 7);

          // The oldest 3 should be deleted (1000, 1001, 1002)
          final names = remaining.map((f) => f.uri.pathSegments.last).toSet();
          expect(names.contains('warqatek_backup_1000.waraq'), isFalse);
          expect(names.contains('warqatek_backup_1001.waraq'), isFalse);
          expect(names.contains('warqatek_backup_1002.waraq'), isFalse);
          expect(names.contains('warqatek_backup_1009.waraq'), isTrue);
        } finally {
          BackupService.backupDirectoryOverride = null;
        }
      },
    );

    test(
      'recordBackupSuccess records timestamp and getLastBackupTime returns it',
      () async {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        await BackupService.recordBackupSuccess();
        final after = DateTime.now().add(const Duration(seconds: 1));

        final lastBackup = await BackupService.getLastBackupTime();
        expect(lastBackup, isNotNull);
        expect(lastBackup!.isAfter(before), isTrue);
        expect(lastBackup.isBefore(after), isTrue);
      },
    );

    test('Typed exceptions thrown on corrupted and unsupported backups', () {
      expect(
        () => BackupService.validateBackup({'app': 'wrong_app'}),
        throwsA(isA<BackupInvalidFormatException>()),
      );

      expect(
        () => BackupService.validateBackup({
          'app': 'warqatek',
          'backup_version': 999,
        }),
        throwsA(isA<BackupUnsupportedVersionException>()),
      );

      expect(
        () => BackupService.validateBackup({
          'app': 'warqatek',
          'backup_version': 1,
          'data': 'not a map',
        }),
        throwsA(isA<BackupInvalidFormatException>()),
      );

      expect(
        () => BackupService.validateBackup({
          'app': 'warqatek',
          'backup_version': 1,
          'data': {
            'businesses': [],
            // missing required tables
          },
        }),
        throwsA(isA<BackupInvalidFormatException>()),
      );
    });
  });
}
