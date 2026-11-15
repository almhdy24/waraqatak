import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as fss;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../widgets/backup_password_dialog.dart';
import 'access/access_guard.dart';
import 'access/permission_registry.dart';
import 'accounting/journal_backfill_service.dart';
import 'analytics/analytics_service.dart';
import 'backup_encryption_service.dart';
import 'image_storage_service.dart';
import 'digital_seal_storage_service.dart';

export 'backup_encryption_service.dart'
    show
        BackupException,
        BackupEncryptionException,
        BackupKeyPersistenceException,
        BackupDecryptionException,
        BackupUnsupportedVersionException,
        BackupCorruptedFileException,
        BackupEncryptionVerificationException,
        BackupInvalidFormatException,
        BackupIntegrityException;

class BackupService {
  static const String backupExtension = 'waraq';
  static const int currentBackupVersion = 6;
  static const String appId = 'warqatek';
  static const String settingLastBackupAt = 'last_backup_timestamp';

  static const Set<String> _sensitiveSettingsKeys = {
    'multi_user_enabled',
    'auto_lock_minutes',
    'workspace_id',
    'kdf_calibrated_iterations',
    'owner_recovery_code_hash',
    'owner_recovery_code_salt',
    'owner_recovery_code_iterations',
    'owner_recovery_locked_until',
    'owner_recovery_failed_attempts',
    'owner_recovery_code_unacknowledged',
    'owner_recovery_hash',
    'owner_recovery_salt',
    'last_active_user_id',
  };

  @visibleForTesting
  static Future<String> Function()? safetyBackupOverride;

  static const String _safetyBackupStorageKey = 'warqatek_safety_backup_key';
  static const fss.FlutterSecureStorage _secureStorage =
      fss.FlutterSecureStorage(
        aOptions: fss.AndroidOptions(resetOnError: false),
      );

  static String? _cachedSafetyKey;
  static bool _isRestoreInProgress = false;

  @visibleForTesting
  static String? safetyKeyOverride;

  @visibleForTesting
  static fss.FlutterSecureStorage? secureStorageOverride;

  @visibleForTesting
  static void resetSafetyKeyCacheForTesting() {
    _cachedSafetyKey = null;
    safetyKeyOverride = null;
    secureStorageOverride = null;
    _isRestoreInProgress = false;
  }

  /// Retrieves or generates an authoritative AES-256 key for internal restore safety backups.
  /// The key is stored in platform secure storage (Android Keystore / iOS Keychain).
  ///
  /// FAILS CLOSED: Never creates or returns an ephemeral key if secure storage persistence
  /// fails or cannot be verified. All reads and writes are verified via read-back.
  ///
  /// If [forceStorageVerification] is true (e.g. before creating a new safety backup),
  /// any existing [_cachedSafetyKey] is verified against durable secure storage to ensure
  /// the key has not been invalidated or removed mid-session.
  static Future<String> getSafetyKey({
    bool forceStorageVerification = false,
  }) async {
    if (safetyKeyOverride != null) return safetyKeyOverride!;

    final storage = secureStorageOverride ?? _secureStorage;

    if (_cachedSafetyKey != null) {
      if (!forceStorageVerification) {
        return _cachedSafetyKey!;
      }
      // Verify cached key is still durably present and intact in secure storage
      final String? stored;
      try {
        stored = await storage.read(key: _safetyBackupStorageKey);
      } catch (e) {
        _cachedSafetyKey = null;
        throw BackupKeyPersistenceException(
          'Failed to access secure storage to verify safety backup key: $e',
        );
      }
      if (stored == null) {
        _cachedSafetyKey = null;
        throw const BackupKeyPersistenceException(
          'Safety backup key in secure storage was removed or invalidated',
        );
      }
      if (stored != _cachedSafetyKey) {
        _cachedSafetyKey = null;
        throw const BackupKeyPersistenceException(
          'Safety backup key in secure storage does not match cached key',
        );
      }
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(stored)) {
        _cachedSafetyKey = null;
        throw const BackupKeyPersistenceException(
          'Existing safety backup key in secure storage is malformed',
        );
      }
      return _cachedSafetyKey!;
    }

    // 1. Read existing key from durable secure storage
    final String? stored;
    try {
      stored = await storage.read(key: _safetyBackupStorageKey);
    } catch (e) {
      throw BackupKeyPersistenceException(
        'Failed to access secure storage for safety backup key: $e',
      );
    }

    // 2. If an existing key is present, validate its format
    if (stored != null) {
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(stored)) {
        throw const BackupKeyPersistenceException(
          'Existing safety backup key in secure storage is malformed',
        );
      }
      _cachedSafetyKey = stored;
      return stored;
    }

    // 3. Generate new 256-bit cryptographically secure key (64 hex characters)
    final rand = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    final newKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // 4. Persist to secure storage
    try {
      await storage.write(key: _safetyBackupStorageKey, value: newKey);
    } catch (e) {
      throw BackupKeyPersistenceException(
        'Failed to persist safety backup key to secure storage: $e',
      );
    }

    // 5. Read back and verify exact persistence before caching or using
    final String? readBack;
    try {
      readBack = await storage.read(key: _safetyBackupStorageKey);
    } catch (e) {
      throw BackupKeyPersistenceException(
        'Failed to read back safety backup key from secure storage: $e',
      );
    }

    if (readBack != newKey) {
      throw const BackupKeyPersistenceException(
        'Safety backup key persistence verification failed (read-back mismatch)',
      );
    }

    _cachedSafetyKey = newKey;
    return newKey;
  }

  @visibleForTesting
  static Directory Function()? backupDirectoryOverride;
  @visibleForTesting
  static Future<String> Function()? buildBackupJsonOverride;
  @visibleForTesting
  static Future<void> Function(File temp, File target)? onBeforeLocalPromotion;

  @visibleForTesting
  static Future<void> Function(File tempFile, File targetFile)?
  onBeforePromotion;

  /// Hook triggered after restoring a legacy backup that lacks persisted journal entries.
  /// Typically invokes the backfill process in P4.
  static Future<void> Function()? onLegacyBackupRestored;

  static int _safetyBackupSequence = 0;

  static const List<String> _requiredTables = [
    'businesses',
    'contacts',
    'products',
    'documents',
    'document_items',
    'document_counters',
  ];

  static Future<Directory> _getBackupDirectory() async {
    if (backupDirectoryOverride != null) {
      return backupDirectoryOverride!();
    }
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      try {
        final db = await DatabaseHelper.instance.database;
        if (db.path.isNotEmpty && db.path != ':memory:') {
          return File(db.path).parent;
        }
      } catch (_) {}
      return Directory.systemTemp;
    }
  }

  // ============================================================
  // SHARE BACKUP
  // ============================================================

  /// Shares an exported backup file via system share sheet.
  /// Also available as [shareBackup].
  static Future<void> createBackup({String? password}) async {
    AccessGuard.require(PermissionRegistry.backupCreate);
    await cleanupTemporaryBackups();

    final jsonStr = await _buildBackupJson();
    final dir = await getTemporaryDirectory();
    final name =
        'warqatek_share_${DateTime.now().millisecondsSinceEpoch}.$backupExtension';
    final file = File('${dir.path}/$name');

    try {
      if (password != null && password.isNotEmpty) {
        final enc = await BackupEncryptionService.encryptJson(
          jsonStr: jsonStr,
          password: password,
        );
        await file.writeAsBytes(enc, flush: true);
      } else {
        await file.writeAsString(jsonStr, encoding: utf8, flush: true);
      }
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Warqatek Backup'),
      );
      await recordBackupSuccess();
    } catch (e) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Alias for [createBackup] to share backup files.
  static Future<void> shareBackup({String? password}) =>
      createBackup(password: password);

  // ============================================================
  // SAVE LOCAL BACKUP (App Documents Directory)
  // ============================================================

  static Future<String> createLocalBackup({
    String? password,
    String? targetPath,
  }) async {
    AccessGuard.require(PermissionRegistry.backupCreate);
    final jsonStr = buildBackupJsonOverride != null
        ? await buildBackupJsonOverride!()
        : await _buildBackupJson();

    final File targetFile;
    if (targetPath != null) {
      targetFile = File(targetPath);
    } else {
      final fileName =
          'warqatek_backup_${DateTime.now().millisecondsSinceEpoch}.$backupExtension';
      final directory = await _getBackupDirectory();
      targetFile = File('${directory.path}/$fileName');
    }

    final tempFile = File('${targetFile.path}.tmp');

    try {
      if (password != null && password.isNotEmpty) {
        final encryptedBytes = await BackupEncryptionService.encryptJson(
          jsonStr: jsonStr,
          password: password,
        );
        await tempFile.writeAsBytes(encryptedBytes, flush: true);

        // Verify non-empty and matching encrypted bytes written
        final readBackBytes = await tempFile.readAsBytes();
        if (readBackBytes.isEmpty) {
          throw const FileSystemException('Created backup is empty');
        }
        if (!BackupEncryptionService.isEncrypted(readBackBytes)) {
          throw const FormatException(
            'Created backup missing valid encryption header',
          );
        }
        if (readBackBytes.length != encryptedBytes.length) {
          throw const FileSystemException(
            'Created backup byte length mismatch on disk',
          );
        }
        bool match = true;
        for (int i = 0; i < 32 && i < readBackBytes.length; i++) {
          if (readBackBytes[i] != encryptedBytes[i]) {
            match = false;
            break;
          }
        }
        if (!match) {
          throw const FileSystemException(
            'Created backup header byte mismatch on disk',
          );
        }
      } else {
        await tempFile.writeAsString(jsonStr, encoding: utf8, flush: true);

        // Verify non-empty and parsable header/JSON
        final readBackBytes = await tempFile.readAsBytes();
        if (readBackBytes.isEmpty) {
          throw const FileSystemException('Created backup is empty');
        }
        final decoded = jsonDecode(utf8.decode(readBackBytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'Created backup has invalid JSON structure',
          );
        }
        _validateBackup(decoded);
      }

      if (onBeforeLocalPromotion != null) {
        await onBeforeLocalPromotion!(tempFile, targetFile);
      }

      await tempFile.rename(targetFile.path);
      await pruneLocalBackups(preservePath: targetFile.path);
      await recordBackupSuccess();
      try {
        AnalyticsService.instance.track(AnalyticsEvent.backupCreated, {
          'destination': 'local',
          'encrypted': password != null && password.isNotEmpty,
        });
      } catch (_) {}
      return targetFile.path;
    } catch (e) {
      try {
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }

  // ============================================================
  // PRE-RESTORE SAFETY BACKUP
  // ============================================================

  /// Creates and validates an automatic safety backup of the current database.
  ///
  /// Safeguards against data loss and partial writes:
  /// 1. A unique filename candidate is determined with timestamp, monotonic
  ///    in-process sequence counter, and loop existence checks to prevent
  ///    in-process same-millisecond collisions.
  /// 2. The backup is written to a uniquely named temporary staging file in the
  ///    same directory and flushed to disk.
  /// 3. The staging file is read back and validated for structural integrity.
  /// 4. The destination path is checked via [File.existsSync] immediately before
  ///    promotion. If it exists, promotion is refused, an exception is thrown,
  ///    the temporary staging file is deleted, and the existing backup is preserved.
  /// 5. The staging file is promoted via [File.rename].
  ///
  /// Platform limitation notice:
  /// Standard `dart:io` does not expose atomic non-replacing rename flags
  /// (e.g. Linux `renameat2(..., RENAME_NOREPLACE)`). On POSIX platforms,
  /// [File.rename] replaces the destination if it exists at the moment of the
  /// syscall. While the monotonic counter, timestamp, and pre-promotion existence
  /// check prevent collisions in all standard single-process operations, a theoretical
  /// cross-process race (TOCTOU) between `existsSync()` and `rename()` cannot be
  /// strictly guaranteed against overwrite at the OS level without native bindings.
  /// If promotion fails for any reason, restore is aborted before active data mutation.
  ///
  /// Throws an exception if creation, writing, validation, or promotion fails,
  /// ensuring that restore does not proceed on an unsafe state.
  static Future<String> createSafetyBackup() async {
    if (safetyBackupOverride != null) {
      return await safetyBackupOverride!();
    }

    final jsonStr = await _buildBackupJson();
    final directory = await _getBackupDirectory();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final seq = ++_safetyBackupSequence;

    var candidateName =
        'warqatek_safety_pre_restore_${timestamp}_$seq.$backupExtension';
    var targetFile = File('${directory.path}/$candidateName');
    int collisionCounter = 0;
    while (targetFile.existsSync()) {
      collisionCounter++;
      candidateName =
          'warqatek_safety_pre_restore_${timestamp}_${seq}_$collisionCounter.$backupExtension';
      targetFile = File('${directory.path}/$candidateName');
    }

    final tempName =
        '.$candidateName.${DateTime.now().microsecondsSinceEpoch}_$seq.tmp';
    final tempFile = File('${directory.path}/$tempName');

    try {
      final key = await getSafetyKey(forceStorageVerification: true);
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: jsonStr,
        password: key,
        iterations: BackupEncryptionService.minIterations,
      );
      await tempFile.writeAsBytes(encryptedBytes, flush: true);

      // Validate the safety backup immediately from disk
      final readBackBytes = await tempFile.readAsBytes();
      if (readBackBytes.isEmpty) {
        throw const FileSystemException('Created safety backup is empty');
      }
      if (!BackupEncryptionService.isEncrypted(readBackBytes)) {
        throw const FormatException(
          'Created safety backup missing encryption header',
        );
      }
      final decryptedJson = await BackupEncryptionService.decryptJson(
        encryptedBytes: readBackBytes,
        password: key,
      );
      final decoded = jsonDecode(decryptedJson);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Created safety backup has invalid format');
      }
      _validateBackup(decoded);

      if (onBeforePromotion != null) {
        await onBeforePromotion!(tempFile, targetFile);
      }

      // Safely promote to final name: refuse to overwrite an existing backup
      if (targetFile.existsSync()) {
        throw FileSystemException(
          'Target safety backup already exists, will not overwrite',
          targetFile.path,
        );
      }
      await tempFile.rename(targetFile.path);

      return targetFile.path;
    } finally {
      try {
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }
      } catch (_) {
        // Best-effort cleanup of temporary file
      }
    }
  }

  // ============================================================
  // SAFETY BACKUP RETENTION / PRUNING
  // ============================================================

  /// Prunes old safety backups in application documents directory:
  /// - Deletes safety backups (`warqatek_safety_pre_restore_*`) older than 30 days.
  /// - Retains at most the 3 most recent safety backups.
  /// - NEVER deletes [preservePath] (the safety backup just created).
  /// - NEVER deletes or touches user-chosen backups (`warqatek_backup_*`).
  /// - Suppresses all errors internally so pruning failure never fails restore or repair.
  static Future<void> pruneSafetyBackups({String? preservePath}) async {
    try {
      final directory = await _getBackupDirectory();
      if (!await directory.exists()) return;

      final entities = await directory.list().toList();
      final safetyFiles = <File>[];
      final now = DateTime.now();
      const maxAge = Duration(days: 30);

      for (final entity in entities) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';

        // Strict match on safety backups only
        final isSafety =
            name.startsWith('warqatek_safety_pre_restore_') &&
            name.endsWith('.$backupExtension');
        if (!isSafety) continue;

        // Never touch the freshly created safety backup
        if (preservePath != null && entity.path == preservePath) continue;

        safetyFiles.add(entity);
      }

      // Read modification times and sort newest first
      final filesWithTime = <({File file, DateTime mtime})>[];
      for (final file in safetyFiles) {
        try {
          final mtime = await file.lastModified();
          filesWithTime.add((file: file, mtime: mtime));
        } catch (_) {
          filesWithTime.add((
            file: file,
            mtime: DateTime.fromMillisecondsSinceEpoch(0),
          ));
        }
      }
      filesWithTime.sort((a, b) => b.mtime.compareTo(a.mtime));

      // Collect files to delete:
      // 1. Any file older than 30 days
      // 2. Any file beyond the 3 most recent
      final toDelete = <File>[];
      final kept = <File>[];

      for (final item in filesWithTime) {
        final age = now.difference(item.mtime);
        if (age > maxAge) {
          toDelete.add(item.file);
        } else if (kept.length < 3) {
          kept.add(item.file);
        } else {
          toDelete.add(item.file);
        }
      }

      for (final file in toDelete) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Best-effort cleanup; never throw
        }
      }

      // Safe cleanup of app-owned legacy plaintext safety backups created by previous versions
      for (final file in kept) {
        if (preservePath != null && file.path == preservePath) continue;
        try {
          if (await file.exists()) {
            final headerBytes = await file.openRead(0, 16).first;
            if (!BackupEncryptionService.isEncrypted(headerBytes)) {
              await file.delete();
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      // Pruning failure must never fail restore or repair
    }
  }

  // ============================================================
  // TEMPORARY BACKUP CLEANUP
  // ============================================================

  /// Cleans up stale app-owned temporary backup files from the cache directory
  /// and temporary staging files from the documents directory.
  ///
  /// Safeguards:
  /// - Age-based check: only deletes files older than [maxAge] (default: 1 hour).
  /// - Strict ownership check: only matches app-owned patterns (`warqatek_share_*`,
  ///   `drive_restore_*`, `*.tmp`, `.*.tmp`, `warqatek_safety_pre_restore_*.tmp`).
  /// - NEVER touches user-chosen backups (`warqatek_backup_*`).
  /// - NEVER deletes [activeSafetyPath] (the safety backup for an active restore/rollback).
  /// - NEVER touches unrelated cache or document files.
  static Future<void> cleanupTemporaryBackups({
    Duration maxAge = const Duration(hours: 1),
    String? activeSafetyPath,
    Directory? tempDirOverride,
    Directory? backupDirOverride,
  }) async {
    final now = DateTime.now();

    // 1. Clean stale temporary share/restore files from cache/temporary directory
    try {
      final tempDir = tempDirOverride ?? await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entities = await tempDir.list().toList();
        for (final entity in entities) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : '';

          final isAppTemp =
              name.startsWith('warqatek_share_') ||
              name.startsWith('drive_restore_') ||
              (name.startsWith('warqatek_') && name.endsWith('.tmp')) ||
              (name.startsWith('.') &&
                  name.contains('warqatek_') &&
                  name.endsWith('.tmp'));
          if (!isAppTemp) continue;

          if (activeSafetyPath != null && entity.path == activeSafetyPath) {
            continue;
          }

          try {
            final mtime = await entity.lastModified();
            if (now.difference(mtime) >= maxAge) {
              await entity.delete();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 2. Clean stale temporary staging files from documents backup directory
    try {
      final docDir = backupDirOverride ?? await _getBackupDirectory();
      if (await docDir.exists()) {
        final entities = await docDir.list().toList();
        for (final entity in entities) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : '';

          final isStagingTmp =
              (name.startsWith('warqatek_') && name.endsWith('.tmp')) ||
              (name.startsWith('.') &&
                  name.contains('warqatek_') &&
                  name.endsWith('.tmp'));
          if (!isStagingTmp) continue;

          if (activeSafetyPath != null && entity.path == activeSafetyPath) {
            continue;
          }

          try {
            final mtime = await entity.lastModified();
            if (now.difference(mtime) >= maxAge) {
              await entity.delete();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Prunes old user-created local backups, keeping at most the newest 7.
  static Future<void> pruneLocalBackups({String? preservePath}) async {
    try {
      final directory = await _getBackupDirectory();
      if (!await directory.exists()) return;

      final entities = await directory.list().toList();
      final backupFiles = <File>[];

      for (final entity in entities) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';

        final isUserBackup =
            name.startsWith('warqatek_backup_') &&
            name.endsWith('.$backupExtension');
        if (!isUserBackup) continue;

        if (preservePath != null && entity.path == preservePath) continue;

        backupFiles.add(entity);
      }

      final filesWithTime = <({File file, DateTime mtime})>[];
      for (final file in backupFiles) {
        try {
          final mtime = await file.lastModified();
          filesWithTime.add((file: file, mtime: mtime));
        } catch (_) {
          filesWithTime.add((
            file: file,
            mtime: DateTime.fromMillisecondsSinceEpoch(0),
          ));
        }
      }
      filesWithTime.sort((a, b) => b.mtime.compareTo(a.mtime));

      for (final item in filesWithTime.skip(7)) {
        try {
          if (await item.file.exists()) {
            await item.file.delete();
          }
        } catch (_) {}
      }
    } catch (_) {
      // Best-effort pruning; never throw
    }
  }

  /// Records the timestamp of a successful backup creation in settings and preferences.
  static Future<void> recordBackupSuccess() async {
    final nowIso = DateTime.now().toIso8601String();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(settingLastBackupAt, nowIso);
    } catch (_) {}
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('app_settings', {
        'key': settingLastBackupAt,
        'value': nowIso,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  /// Returns the DateTime of the latest successful backup, if any.
  static Future<DateTime?> getLastBackupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefVal = prefs.getString(settingLastBackupAt);
      if (prefVal != null && prefVal.isNotEmpty) {
        return DateTime.tryParse(prefVal);
      }
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [settingLastBackupAt],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final val = rows.first['value']?.toString();
        if (val != null && val.isNotEmpty) {
          return DateTime.tryParse(val);
        }
      }
    } catch (_) {}
    return null;
  }

  // ============================================================
  // SAVE BACKUP VIA SYSTEM SAVE DIALOG (bytes-based)
  // ============================================================

  static Future<bool> createBackupUserChosen({
    String? password,
    bool Function()? isCancelled,
  }) async {
    AccessGuard.require(PermissionRegistry.backupCreate);
    final jsonStr = await _buildBackupJson();
    if (isCancelled != null && isCancelled()) return false;
    final fileName =
        'warqatek_backup_${DateTime.now().millisecondsSinceEpoch}.$backupExtension';

    Uint8List bytes;
    if (password != null && password.isNotEmpty) {
      bytes = await BackupEncryptionService.encryptJson(
        jsonStr: jsonStr,
        password: password,
      );
      if (isCancelled != null && isCancelled()) return false;
    } else {
      bytes = Uint8List.fromList(utf8.encode(jsonStr));
    }

    final uri = await FilePicker.saveFile(
      dialogTitle: 'Save Backup',
      fileName: fileName,
      bytes: bytes,
      type: FileType.any,
    );

    final success = uri != null;
    if (success) {
      await recordBackupSuccess();
      try {
        AnalyticsService.instance.track(AnalyticsEvent.backupCreated, {
          'destination': 'user_chosen',
          'encrypted': password != null && password.isNotEmpty,
        });
      } catch (_) {}
    }

    return success;
  }

  // ============================================================
  // RESTORE BACKUP (content-based validation, not extension)
  // ============================================================

  static Future<bool> restoreBackup({
    BuildContext? context,
    String? password,
    Future<String?> Function(List<int> bytes)? passwordPrompt,
  }) async {
    AccessGuard.require(PermissionRegistry.backupRestore);
    final file = await FilePicker.pickFile(type: FileType.any);

    if (file == null) return false;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const BackupCorruptedFileException('Empty backup file');
    }

    String jsonStr;
    if (BackupEncryptionService.isEncrypted(bytes)) {
      if (password != null && password.isNotEmpty) {
        jsonStr = await BackupEncryptionService.decryptJson(
          encryptedBytes: bytes,
          password: password,
        );
      } else if (passwordPrompt != null) {
        final result = await passwordPrompt(bytes);
        if (result == null) return false;
        jsonStr = result;
      } else if (context != null && context.mounted) {
        final result = await BackupPasswordPromptDialog.show(
          context,
          encryptedBytes: bytes,
        );
        if (result == null) return false;
        jsonStr = result;
      } else {
        throw const BackupDecryptionException(
          'Password is required for encrypted backup',
        );
      }
    } else {
      jsonStr = utf8.decode(bytes);
    }

    Map<String, dynamic> jsonMap;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupInvalidFormatException('Invalid backup format');
      }
      jsonMap = decoded;
    } catch (e) {
      if (e is BackupException) rethrow;
      try {
        AnalyticsService.instance.track(AnalyticsEvent.backupRestored, {
          'ok': false,
        });
        AnalyticsService.instance.track(AnalyticsEvent.errorCaught, {
          'area': 'restore',
          'kind': 'format',
        });
      } catch (_) {}
      throw const BackupInvalidFormatException('Invalid backup file');
    }

    if (context != null && context.mounted) {
      return await BackupProgressDialog.show(
        context,
        title: AppLocalizations.of(context).backupRestore,
        message: AppLocalizations.of(context).backupDecrypting,
        operation: (isCancelled) => restoreFromJsonMap(jsonMap),
      );
    }

    return restoreFromJsonMap(jsonMap);
  }

  /// Restores database content from parsed backup JSON.
  /// Used by [restoreBackup], [GoogleDriveBackupService], and tests.
  static Future<bool> restoreFromJsonMap(
    Map<String, dynamic> jsonMap, {
    bool createSafetyBackup = true,
    bool isRollback = false,
  }) async {
    AccessGuard.require(PermissionRegistry.backupRestore);
    _validateBackup(jsonMap);

    if (_isRestoreInProgress && !isRollback) {
      throw StateError('A restore operation is already in progress.');
    }

    final bool isOuter = !_isRestoreInProgress;
    if (isOuter) {
      _isRestoreInProgress = true;
    }

    String? safetyPath;
    try {
      // Create and validate an automatic safety backup of the current database
      // before touching any data. If this fails, restore aborts immediately.
      if (createSafetyBackup) {
        safetyPath = await BackupService.createSafetyBackup();
        await DatabaseHelper.instance.logAuditEvent(
          'pre_restore_safety_backup_created',
          details: 'path=$safetyPath',
        );
      }

      final data = jsonMap['data'] as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        Future<Set<String>> getTableCols(String table) async {
          final info = await txn.rawQuery('PRAGMA table_info($table)');
          return info.map((c) => c['name'] as String).toSet();
        }

        Future<bool> tableExists(String table) async {
          final tables = await txn.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
            [table],
          );
          return tables.isNotEmpty;
        }

        Map<String, dynamic> sanitizeRow(
          Map<String, dynamic> row,
          Set<String> cols,
        ) => Map.fromEntries(row.entries.where((e) => cols.contains(e.key)));

        if (await tableExists('journal_lines')) {
          await txn.delete('journal_lines');
        }
        if (await tableExists('journal_entries')) {
          await txn.delete('journal_entries');
        }
        if (await tableExists('accounts')) {
          await txn.delete('accounts');
        }
        List<Map<String, dynamic>> savedAccessSettings = [];
        if (await tableExists('app_settings')) {
          savedAccessSettings = await txn.query(
            'app_settings',
            where:
                "key IN (${_sensitiveSettingsKeys.map((k) => "'$k'").join(',')})",
          );
          await txn.delete('app_settings');
        }
        if (await tableExists('exchange_rates')) {
          await txn.delete('exchange_rates');
        }
        if (await tableExists('document_seal_snapshot_assets')) {
          await txn.delete('document_seal_snapshot_assets');
        }
        if (await tableExists('document_seal_snapshots')) {
          await txn.delete('document_seal_snapshots');
        }
        if (await tableExists('business_seal_configs')) {
          await txn.delete('business_seal_configs');
        }
        if (await tableExists('digital_assets')) {
          await txn.delete('digital_assets');
        }
        await txn.delete('document_payments');
        await txn.delete('document_items');
        await txn.delete('stocktake_items');
        await txn.delete('stocktake_sessions');
        await txn.delete('stock_movements');
        await txn.delete('documents');
        await txn.delete('contacts');
        await txn.delete('product_units');
        await txn.delete('products');
        await txn.delete('businesses');
        await txn.delete('document_counters');

        final businessCols = await getTableCols('businesses');
        final contactCols = await getTableCols('contacts');
        final productCols = await getTableCols('products');
        final docCols = await getTableCols('documents');
        final itemCols = await getTableCols('document_items');
        final counterCols = await getTableCols('document_counters');

        for (final row in _convertRows(data['businesses'])) {
          await txn.insert('businesses', sanitizeRow(row, businessCols));
        }
        for (final row in _convertRows(data['contacts'])) {
          await txn.insert('contacts', sanitizeRow(row, contactCols));
        }
        for (final row in _convertRows(data['products'])) {
          final productRow = Map<String, dynamic>.from(row)
            ..remove('image_path');
          await txn.insert('products', sanitizeRow(productRow, productCols));
        }
        if (data.containsKey('product_units') &&
            data['product_units'] is List) {
          final puCols = await getTableCols('product_units');
          for (final row in _convertRows(data['product_units'])) {
            await txn.insert('product_units', sanitizeRow(row, puCols));
          }
        }
        if (data.containsKey('exchange_rates') &&
            data['exchange_rates'] is List) {
          final erCols = await getTableCols('exchange_rates');
          for (final row in _convertRows(data['exchange_rates'])) {
            await txn.insert('exchange_rates', sanitizeRow(row, erCols));
          }
        }

        final docs = _convertRows(data['documents']);
        for (final row in docs) {
          final docRow = sanitizeRow(row, docCols);
          docRow['related_document_id'] = null;
          await txn.insert('documents', docRow);
        }
        for (final row in _convertRows(data['document_items'])) {
          await txn.insert('document_items', sanitizeRow(row, itemCols));
        }
        for (final row in docs) {
          final docId = row['id'];
          final relatedId = row['related_document_id'];
          if (docId != null && relatedId != null) {
            await txn.update(
              'documents',
              {'related_document_id': relatedId},
              where: 'id = ?',
              whereArgs: [docId],
            );
          }
        }
        for (final row in _convertRows(data['document_counters'])) {
          await txn.insert('document_counters', sanitizeRow(row, counterCols));
        }
        // document_payments is optional (absent in backups created before Phase 1)
        if (data.containsKey('document_payments') &&
            data['document_payments'] is List) {
          final payCols = await getTableCols('document_payments');
          for (final row in _convertRows(data['document_payments'])) {
            await txn.insert('document_payments', sanitizeRow(row, payCols));
          }
        }
        // stock_movements is optional (absent in backups created before Phase 3.4)
        if (data.containsKey('stock_movements') &&
            data['stock_movements'] is List) {
          final smCols = await getTableCols('stock_movements');
          for (final row in _convertRows(data['stock_movements'])) {
            await txn.insert('stock_movements', sanitizeRow(row, smCols));
          }
        }
        // tax_profiles is optional (absent in backups created before Phase 3.5)
        if (data.containsKey('tax_profiles') && data['tax_profiles'] is List) {
          await txn.delete('tax_profiles');
          final taxCols = await getTableCols('tax_profiles');
          for (final row in _convertRows(data['tax_profiles'])) {
            await txn.insert('tax_profiles', sanitizeRow(row, taxCols));
          }
        }
        // payment_methods is optional (absent in backups created before Phase 3.6)
        if (data.containsKey('payment_methods') &&
            data['payment_methods'] is List) {
          await txn.delete('payment_methods');
          final pmCols = await getTableCols('payment_methods');
          for (final row in _convertRows(data['payment_methods'])) {
            await txn.insert('payment_methods', sanitizeRow(row, pmCols));
          }
        }
        // stocktake_sessions is optional (absent in backups created before v16)
        if (data.containsKey('stocktake_sessions') &&
            data['stocktake_sessions'] is List) {
          final ssCols = await getTableCols('stocktake_sessions');
          for (final row in _convertRows(data['stocktake_sessions'])) {
            await txn.insert('stocktake_sessions', sanitizeRow(row, ssCols));
          }
        }
        // stocktake_items is optional (absent in backups created before v16)
        if (data.containsKey('stocktake_items') &&
            data['stocktake_items'] is List) {
          final siCols = await getTableCols('stocktake_items');
          for (final row in _convertRows(data['stocktake_items'])) {
            await txn.insert('stocktake_items', sanitizeRow(row, siCols));
          }
        }
        // audit_log is protected by SQLite triggers, is tamper-evident and append-only.
        // It is preserved locally and never wiped during restore (INV-15 / D7).

        // Accounts: restore or re-seed
        if (await tableExists('accounts')) {
          if (data.containsKey('accounts') && data['accounts'] is List) {
            final accCols = await getTableCols('accounts');
            for (final row in _convertRows(data['accounts'])) {
              await txn.insert(
                'accounts',
                sanitizeRow(row, accCols),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          } else {
            await DatabaseHelper.seedAccounts(txn);
          }
        }

        // Settings: restore or re-seed
        if (await tableExists('app_settings')) {
          if (data.containsKey('app_settings') &&
              data['app_settings'] is List) {
            final setCols = await getTableCols('app_settings');
            for (final row in _convertRows(data['app_settings'])) {
              final sanitized = sanitizeRow(row, setCols);
              final key = sanitized['key']?.toString();
              // Never import security-sensitive access settings from backup
              if (_sensitiveSettingsKeys.contains(key)) {
                continue;
              }
              // Invariant: after any restore, journal_reports_enabled is forced OFF
              if (key == 'journal_reports_enabled') {
                sanitized['value'] = 'false';
              }
              await txn.insert(
                'app_settings',
                sanitized,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          } else {
            await DatabaseHelper.seedDefaultSettings(txn);
          }
          // Invariant: force journal_reports_enabled = false regardless of backup content
          await txn.insert('app_settings', {
            'key': 'journal_reports_enabled',
            'value': 'false',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          // Restore preserved multi-user and access settings
          if (savedAccessSettings.isNotEmpty) {
            for (final s in savedAccessSettings) {
              await txn.insert(
                'app_settings',
                s,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          } else {
            // If no local access settings existed (e.g. clean install), ensure multi-user is disabled
            await txn.insert('app_settings', {
              'key': 'multi_user_enabled',
              'value': '0',
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Journal entries & lines (Phase 1)
        if (await tableExists('journal_entries') &&
            data.containsKey('journal_entries') &&
            data['journal_entries'] is List) {
          final jeCols = await getTableCols('journal_entries');
          for (final row in _convertRows(data['journal_entries'])) {
            await txn.insert('journal_entries', sanitizeRow(row, jeCols));
          }
        }

        if (await tableExists('journal_lines') &&
            data.containsKey('journal_lines') &&
            data['journal_lines'] is List) {
          final jlCols = await getTableCols('journal_lines');
          for (final row in _convertRows(data['journal_lines'])) {
            await txn.insert('journal_lines', sanitizeRow(row, jlCols));
          }
        }

        if (await tableExists('digital_assets') &&
            data.containsKey('digital_assets') &&
            data['digital_assets'] is List) {
          final cols = await getTableCols('digital_assets');
          for (final row in _convertRows(data['digital_assets'])) {
            await txn.insert('digital_assets', sanitizeRow(row, cols));
          }
        }

        if (await tableExists('business_seal_configs') &&
            data.containsKey('business_seal_configs') &&
            data['business_seal_configs'] is List) {
          final cols = await getTableCols('business_seal_configs');
          for (final row in _convertRows(data['business_seal_configs'])) {
            await txn.insert('business_seal_configs', sanitizeRow(row, cols));
          }
        }

        if (await tableExists('document_seal_snapshots') &&
            data.containsKey('document_seal_snapshots') &&
            data['document_seal_snapshots'] is List) {
          final cols = await getTableCols('document_seal_snapshots');
          for (final row in _convertRows(data['document_seal_snapshots'])) {
            await txn.insert('document_seal_snapshots', sanitizeRow(row, cols));
          }
        }

        if (await tableExists('document_seal_snapshot_assets') &&
            data.containsKey('document_seal_snapshot_assets') &&
            data['document_seal_snapshot_assets'] is List) {
          final cols = await getTableCols('document_seal_snapshot_assets');
          for (final row in _convertRows(
            data['document_seal_snapshot_assets'],
          )) {
            await txn.insert(
              'document_seal_snapshot_assets',
              sanitizeRow(row, cols),
            );
          }
        }

        await DatabaseHelper.backfillCurrencyLockIfNeeded(txn);

        await DatabaseHelper.instance.logAuditEvent(
          'backup_restored',
          details:
              'version=${jsonMap['backup_version']} db=${jsonMap['database_version']} schema_version=${jsonMap['schema_version'] ?? 'unknown'}',
          txn: txn,
        );
      });

      // Verify database integrity post-restore
      final integrity = await db.rawQuery('PRAGMA integrity_check');
      final integrityResult = integrity.isNotEmpty
          ? integrity.first.values.first?.toString()
          : null;
      if (integrityResult?.toLowerCase() != 'ok') {
        throw BackupIntegrityException(
          'Database integrity check failed post-restore: $integrityResult',
        );
      }

      await _restoreLogoIfNeeded(jsonMap);
      await _restoreProductImagesIfNeeded(jsonMap);
      await _restoreDigitalAssetsIfNeeded(jsonMap);

      // If legacy backup lacked journal tables, invoke backfill
      final isLegacy =
          !data.containsKey('journal_entries') ||
          data['journal_entries'] == null ||
          (data['journal_entries'] as List).isEmpty;
      if (isLegacy) {
        if (onLegacyBackupRestored != null) {
          try {
            await onLegacyBackupRestored!();
          } catch (_) {}
        } else {
          await JournalBackfillService.backfillIfNeeded();
        }
      } else {
        // New backup includes journal: verify parity safely
        try {
          await JournalBackfillService.verifyParity();
        } catch (e) {
          await DatabaseHelper.instance.setSetting(
            'journal_parity_failed_at',
            DateTime.now().toIso8601String(),
          );
          await DatabaseHelper.instance.setSetting(
            'journal_parity_failure_reason',
            'Post-restore parity mismatch: $e',
          );
          await DatabaseHelper.instance.logAuditEvent(
            'post_restore_parity_failed',
            details: 'error=$e',
          );
        }
      }

      // Prune older safety backups beyond retention limits and clean stale temporary backups
      if (createSafetyBackup) {
        await pruneSafetyBackups(preservePath: safetyPath);
        await cleanupTemporaryBackups();
      }

      try {
        AnalyticsService.instance.track(AnalyticsEvent.backupRestored, {
          'ok': true,
        });
      } catch (_) {}

      return true;
    } catch (e) {
      if (createSafetyBackup && safetyPath != null) {
        try {
          final safetyFile = File(safetyPath);
          if (await safetyFile.exists()) {
            final safetyBytes = await safetyFile.readAsBytes();
            final String safetyJsonStr;
            if (BackupEncryptionService.isEncrypted(safetyBytes)) {
              final key = await getSafetyKey();
              safetyJsonStr = await BackupEncryptionService.decryptJson(
                encryptedBytes: safetyBytes,
                password: key,
              );
            } else {
              safetyJsonStr = utf8.decode(safetyBytes);
            }
            final safetyData =
                jsonDecode(safetyJsonStr) as Map<String, dynamic>;
            await restoreFromJsonMap(
              safetyData,
              createSafetyBackup: false,
              isRollback: true,
            );
            await DatabaseHelper.instance.logAuditEvent(
              'restore_safety_rollback_completed',
              details: 'path=$safetyPath; reason=$e',
            );
          }
        } catch (rollbackErr) {
          await DatabaseHelper.instance.logAuditEvent(
            'restore_safety_rollback_failed',
            details: 'rollback_error=$rollbackErr; original_error=$e',
          );
        }
      }
      if (e is BackupException) rethrow;
      throw BackupIntegrityException(e.toString());
    } finally {
      if (isOuter) {
        _isRestoreInProgress = false;
      }
    }
  }

  // ============================================================
  // VALIDATE BACKUP CONTENT
  // ============================================================

  static void _validateBackup(Map<String, dynamic> jsonMap) {
    if (jsonMap['app'] != appId) {
      throw const BackupInvalidFormatException('Not a Warqatek backup');
    }

    final backupVersion = jsonMap['backup_version'];
    if (backupVersion is! int || backupVersion < 1) {
      throw BackupUnsupportedVersionException(
        backupVersion is int ? backupVersion : 0,
        'Unsupported backup version: $backupVersion',
      );
    }
    if (backupVersion > currentBackupVersion) {
      throw BackupUnsupportedVersionException(
        backupVersion,
        'Backup version $backupVersion requires a newer version of the application. Please update the app.',
      );
    }

    final data = jsonMap['data'];
    if (data is! Map<String, dynamic>) {
      throw const BackupInvalidFormatException('Invalid backup data');
    }

    for (final table in _requiredTables) {
      if (!data.containsKey(table) || data[table] is! List) {
        throw BackupInvalidFormatException('Missing or invalid table: $table');
      }
    }
  }

  /// Public validation helper used before restore operations.
  static void validateBackup(Map<String, dynamic> jsonMap) =>
      _validateBackup(jsonMap);

  // ============================================================
  // ROW CONVERSION
  // ============================================================

  static List<Map<String, dynamic>> _convertRows(dynamic value) {
    if (value is! List) {
      throw const BackupInvalidFormatException('Invalid row data');
    }
    return value.map<Map<String, dynamic>>((row) {
      if (row is! Map) {
        throw const BackupInvalidFormatException('Invalid row entry');
      }
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  // ============================================================
  // BUILD BACKUP JSON (including logo as base64)
  // ============================================================

  @visibleForTesting
  static Future<String> buildBackupJsonForTest() => _buildBackupJson();

  static Future<String> _buildBackupJson() async {
    final db = await DatabaseHelper.instance.database;

    final snapshot = await db.transaction((txn) async {
      return <String, List<Map<String, Object?>>>{
        'businesses': await txn.query('businesses'),
        'contacts': await txn.query('contacts'),
        'products': (await txn.query(
          'products',
        )).map((row) => Map<String, Object?>.from(row)).toList(),
        'product_units': await txn.query('product_units'),
        'documents': await txn.query('documents'),
        'document_items': await txn.query('document_items'),
        'document_counters': await txn.query('document_counters'),
        'document_payments': await txn.query('document_payments'),
        'stock_movements': await txn.query('stock_movements'),
        'tax_profiles': await txn.query('tax_profiles'),
        'payment_methods': await txn.query('payment_methods'),
        'stocktake_sessions': await txn.query('stocktake_sessions'),
        'stocktake_items': await txn.query('stocktake_items'),
        'audit_log': const <Map<String, Object?>>[],
        'accounts': await txn.query('accounts'),
        'journal_entries': await txn.query('journal_entries'),
        'journal_lines': await txn.query('journal_lines'),
        'app_settings': (await txn.query(
          'app_settings',
        )).where((r) => !_sensitiveSettingsKeys.contains(r['key'])).toList(),
        'exchange_rates': await txn.query('exchange_rates'),
        'digital_assets': await txn.query('digital_assets'),
        'business_seal_configs': await txn.query('business_seal_configs'),
        'document_seal_snapshots': await txn.query('document_seal_snapshots'),
        'document_seal_snapshot_assets': await txn.query(
          'document_seal_snapshot_assets',
        ),
      };
    });

    String? logoBase64;
    if (snapshot['businesses']!.isNotEmpty) {
      final logoPath = snapshot['businesses']!.first['logo_path']?.toString();
      if (logoPath != null && logoPath.isNotEmpty) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          try {
            final logoBytes = await logoFile.readAsBytes();
            if (logoBytes.isNotEmpty) {
              logoBase64 = base64Encode(logoBytes);
            }
          } catch (_) {
            // Ignore logo read errors
          }
        }
      }
    }

    // Collect product images as base64, keyed by product id string.
    final productImages = <String, String>{};
    for (final row in snapshot['products']!) {
      final id = row['id']?.toString();
      final imgPath = row['image_path'] as String?;
      if (id != null && imgPath != null && imgPath.isNotEmpty) {
        final b64 = await ImageStorageService.imageToBase64(imgPath);
        if (b64 != null) productImages[id] = b64;
      }
    }

    // Collect digital seal assets as base64, keyed by asset id string.
    final digitalAssets = <String, String>{};
    if (snapshot.containsKey('digital_assets')) {
      for (final row in snapshot['digital_assets']!) {
        final id = row['id']?.toString();
        final filename = row['filename']?.toString();
        if (id != null && filename != null && filename.isNotEmpty) {
          final bytes = await DigitalSealStorageService.getAssetBytes(filename);
          if (bytes != null && bytes.isNotEmpty) {
            digitalAssets[id] = base64Encode(bytes);
          }
        }
      }
    }

    // Device-local paths are not portable. The image bytes are stored
    // separately in assets.product_images.
    for (final row in snapshot['products']!) {
      row['image_path'] = null;
    }

    final backupData = <String, dynamic>{
      'app': appId,
      'backup_version': currentBackupVersion,
      'database_version': DatabaseHelper.dbVersion,
      'created_at': DateTime.now().toIso8601String(),
      'data': snapshot,
      'assets': {
        'logo_base64': logoBase64,
        'product_images': productImages.isEmpty ? null : productImages,
        'digital_assets': digitalAssets.isEmpty ? null : digitalAssets,
      },
    };

    return jsonEncode(backupData);
  }

  // ============================================================
  // RESTORE LOGO
  // ============================================================

  static Future<void> _clearMissingLogoPath() async {
    try {
      final business = await DatabaseHelper.instance.getFirstBusiness();
      if (business != null &&
          business.logoPath != null &&
          business.logoPath!.isNotEmpty) {
        final file = File(business.logoPath!);
        if (!await file.exists()) {
          await DatabaseHelper.instance.updateBusiness(
            business.copyWith(logoPath: null),
          );
        }
      }
    } catch (_) {
      // Best-effort cleanup: never throw
    }
  }

  static Future<void> _restoreLogoIfNeeded(Map<String, dynamic> jsonMap) async {
    final assets = jsonMap['assets'];
    bool restored = false;
    if (assets is Map<String, dynamic>) {
      final logoBase64 = assets['logo_base64'] as String?;
      if (logoBase64 != null && logoBase64.isNotEmpty) {
        try {
          final logoBytes = base64Decode(logoBase64);
          final directory = await getApplicationDocumentsDirectory();
          final fileName =
              'business_logo_${DateTime.now().millisecondsSinceEpoch}.png';
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(logoBytes, flush: true);

          final business = await DatabaseHelper.instance.getFirstBusiness();
          if (business != null) {
            final oldLogoPath = business.logoPath;
            await DatabaseHelper.instance.updateBusiness(
              business.copyWith(logoPath: file.path),
            );
            restored = true;
            if (oldLogoPath != null &&
                oldLogoPath.isNotEmpty &&
                oldLogoPath != file.path) {
              try {
                final oldFile = File(oldLogoPath);
                if (await oldFile.exists()) {
                  await oldFile.delete();
                }
              } catch (_) {}
            }
          }
        } catch (_) {
          // Do not fail restore due to logo
        }
      }
    }

    if (!restored) {
      await _clearMissingLogoPath();
    }
  }

  // ============================================================
  // RESTORE PRODUCT IMAGES
  // ============================================================

  static Future<void> _restoreProductImagesIfNeeded(
    Map<String, dynamic> jsonMap,
  ) async {
    // Old backups without product_images are silently skipped.
    final assets = jsonMap['assets'];
    if (assets is! Map<String, dynamic>) return;
    final productImages = assets['product_images'];
    if (productImages is! Map<String, dynamic>) return;
    if (productImages.isEmpty) return;

    final db = await DatabaseHelper.instance.database;

    for (final entry in productImages.entries) {
      final productId = int.tryParse(entry.key);
      final b64 = entry.value;

      if (productId == null ||
          productId <= 0 ||
          b64 is! String ||
          b64.isEmpty) {
        continue;
      }

      try {
        final products = await db.query(
          'products',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (products.isEmpty) continue;

        final imagePath = await ImageStorageService.base64ToImage(
          b64,
          entry.key,
        );
        if (imagePath == null) continue;

        await db.update(
          'products',
          {'image_path': p.basename(imagePath)},
          where: 'id = ?',
          whereArgs: [productId],
        );
      } catch (_) {
        // Never fail restore due to a single product image error.
      }
    }
  }

  // ============================================================
  // RESTORE DIGITAL SEAL ASSETS
  // ============================================================

  static Future<void> _restoreDigitalAssetsIfNeeded(
    Map<String, dynamic> jsonMap,
  ) async {
    final assets = jsonMap['assets'];
    if (assets is! Map<String, dynamic>) return;
    final digitalAssets = assets['digital_assets'];
    if (digitalAssets is! Map<String, dynamic>) return;
    if (digitalAssets.isEmpty) return;

    final db = await DatabaseHelper.instance.database;

    for (final entry in digitalAssets.entries) {
      final assetId = entry.key;
      final b64 = entry.value;
      if (b64 is! String || b64.isEmpty) continue;

      try {
        final rows = await db.query(
          'digital_assets',
          columns: ['filename'],
          where: 'id = ?',
          whereArgs: [assetId],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        final filename = rows.first['filename'] as String;

        await DigitalSealStorageService.restoreAssetFromBase64(
          filename: filename,
          base64Data: b64,
        );
      } catch (_) {
        // Never fail restore due to a single digital seal error.
      }
    }
  }
}
