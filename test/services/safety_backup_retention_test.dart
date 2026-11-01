import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('safety_retention_test_');
    BackupService.backupDirectoryOverride = () => testDir;
  });

  tearDown(() async {
    BackupService.backupDirectoryOverride = null;
    try {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Safety Backup Retention / Pruning Tests', () {
    test('1. Retains at most 3 most recent safety backups and prunes older ones', () async {
      final files = <File>[];
      final baseTime = DateTime.now().subtract(const Duration(days: 2));

      // Create 5 safety backups with distinct timestamps
      for (var i = 1; i <= 5; i++) {
        final f = File('${testDir.path}/warqatek_safety_pre_restore_${i}_1.waraq');
        await f.writeAsString('safety_$i');
        await f.setLastModified(baseTime.add(Duration(hours: i)));
        files.add(f);
      }

      await BackupService.pruneSafetyBackups();

      // Files 1 and 2 (oldest) must be deleted
      expect(await files[0].exists(), isFalse);
      expect(await files[1].exists(), isFalse);

      // Files 3, 4, 5 (3 newest) must be preserved
      expect(await files[2].exists(), isTrue);
      expect(await files[3].exists(), isTrue);
      expect(await files[4].exists(), isTrue);
    });

    test('2. Deletes safety backups older than 30 days', () async {
      final oldFile = File('${testDir.path}/warqatek_safety_pre_restore_old_1.waraq');
      await oldFile.writeAsString('old_safety');
      // Modified 35 days ago
      await oldFile.setLastModified(DateTime.now().subtract(const Duration(days: 35)));

      final recentFile = File('${testDir.path}/warqatek_safety_pre_restore_recent_1.waraq');
      await recentFile.writeAsString('recent_safety');
      await recentFile.setLastModified(DateTime.now().subtract(const Duration(days: 1)));

      await BackupService.pruneSafetyBackups();

      expect(await oldFile.exists(), isFalse);
      expect(await recentFile.exists(), isTrue);
    });

    test('3. Never deletes preservePath (the one just created)', () async {
      final oldCreated = File('${testDir.path}/warqatek_safety_pre_restore_fresh_1.waraq');
      await oldCreated.writeAsString('just_created');
      await oldCreated.setLastModified(DateTime.now().subtract(const Duration(days: 40)));

      // Pass as preservePath
      await BackupService.pruneSafetyBackups(preservePath: oldCreated.path);

      expect(await oldCreated.exists(), isTrue);
    });

    test('4. Never touches user-chosen backups or non-safety files', () async {
      final userBackup = File('${testDir.path}/warqatek_backup_123456789.waraq');
      await userBackup.writeAsString('user_backup_data');
      await userBackup.setLastModified(DateTime.now().subtract(const Duration(days: 100)));

      final randomFile = File('${testDir.path}/some_other_file.txt');
      await randomFile.writeAsString('other_data');

      await BackupService.pruneSafetyBackups();

      expect(await userBackup.exists(), isTrue);
      expect(await randomFile.exists(), isTrue);
    });

    test('5. Safely handles missing directories or I/O errors without throwing', () async {
      // Point override to a non-existent directory
      final missingDir = Directory('${testDir.path}/non_existent_subdir');
      BackupService.backupDirectoryOverride = () => missingDir;

      expect(
        () async => await BackupService.pruneSafetyBackups(),
        returnsNormally,
      );
    });
  });
}
