import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../widgets/backup_password_dialog.dart';
import 'accounting/journal_backfill_service.dart';
import 'backup_encryption_service.dart';

class BackupService {
  static const String backupExtension = 'waraq';
  static const int currentBackupVersion = 4;
  static const String appId = 'warqatek';

  @visibleForTesting
  static Future<String> Function()? safetyBackupOverride;

  @visibleForTesting
  static Directory Function()? backupDirectoryOverride;

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

  static Future<void> createBackup() async {
    final jsonStr = await _buildBackupJson();
    await SharePlus.instance.share(
      ShareParams(text: jsonStr, subject: 'Warqatek Backup'),
    );
  }

  // ============================================================
  // SAVE LOCAL BACKUP (App Documents Directory)
  // ============================================================

  static Future<String> createLocalBackup({String? password}) async {
    final jsonStr = await _buildBackupJson();
    final fileName =
        'warqatek_backup_${DateTime.now().millisecondsSinceEpoch}.$backupExtension';

    final directory = await _getBackupDirectory();
    final file = File('${directory.path}/$fileName');
    if (password != null && password.isNotEmpty) {
      final encryptedBytes = await BackupEncryptionService.encryptJson(
        jsonStr: jsonStr,
        password: password,
      );
      await file.writeAsBytes(encryptedBytes, flush: true);
    } else {
      await file.writeAsString(jsonStr, encoding: utf8);
    }

    return file.path;
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
      await tempFile.writeAsString(jsonStr, encoding: utf8, flush: true);

      // Validate the safety backup immediately from disk
      final readBackBytes = await tempFile.readAsBytes();
      if (readBackBytes.isEmpty) {
        throw const FileSystemException('Created safety backup is empty');
      }
      final decoded = jsonDecode(utf8.decode(readBackBytes));
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
        final isSafety = name.startsWith('warqatek_safety_pre_restore_') &&
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
          filesWithTime.add(
            (file: file, mtime: DateTime.fromMillisecondsSinceEpoch(0)),
          );
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
    } catch (_) {
      // Pruning failure must never fail restore or repair
    }
  }

  // ============================================================
  // SAVE BACKUP VIA SYSTEM SAVE DIALOG (bytes-based)
  // ============================================================

  static Future<bool> createBackupUserChosen({
    String? password,
    bool Function()? isCancelled,
  }) async {
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

    return uri != null;
  }

  // ============================================================
  // RESTORE BACKUP (content-based validation, not extension)
  // ============================================================

  static Future<bool> restoreBackup({
    BuildContext? context,
    String? password,
    Future<String?> Function(List<int> bytes)? passwordPrompt,
  }) async {
    final file = await FilePicker.pickFile(type: FileType.any);

    if (file == null) return false;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Empty backup file');
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
        throw Exception('Invalid backup format');
      }
      jsonMap = decoded;
    } catch (_) {
      throw Exception('Invalid backup file');
    }

    return restoreFromJsonMap(jsonMap);
  }

  /// Restores database content from parsed backup JSON.
  /// Used by [restoreBackup], [GoogleDriveBackupService], and tests.
  static Future<bool> restoreFromJsonMap(
    Map<String, dynamic> jsonMap, {
    bool createSafetyBackup = true,
  }) async {
    _validateBackup(jsonMap);

    // Create and validate an automatic safety backup of the current database
    // before touching any data. If this fails, restore aborts immediately.
    String? safetyPath;
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
      ) =>
          Map.fromEntries(row.entries.where((e) => cols.contains(e.key)));

      if (await tableExists('journal_lines')) await txn.delete('journal_lines');
      if (await tableExists('journal_entries')) await txn.delete('journal_entries');
      if (await tableExists('accounts')) await txn.delete('accounts');
      if (await tableExists('app_settings')) await txn.delete('app_settings');
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
        await txn.insert('products', sanitizeRow(row, productCols));
      }
      if (data.containsKey('product_units') &&
          data['product_units'] is List) {
        final puCols = await getTableCols('product_units');
        for (final row in _convertRows(data['product_units'])) {
          await txn.insert('product_units', sanitizeRow(row, puCols));
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
      // audit_log is optional (absent in older backups)
      if (data.containsKey('audit_log') && data['audit_log'] is List) {
        await txn.delete('audit_log');
        final alCols = await getTableCols('audit_log');
        for (final row in _convertRows(data['audit_log'])) {
          await txn.insert('audit_log', sanitizeRow(row, alCols));
        }
      }

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
        if (data.containsKey('app_settings') && data['app_settings'] is List) {
          final setCols = await getTableCols('app_settings');
          for (final row in _convertRows(data['app_settings'])) {
            final sanitized = sanitizeRow(row, setCols);
            // Invariant: after any restore, journal_reports_enabled is forced OFF
            if (sanitized['key'] == 'journal_reports_enabled') {
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
        await txn.insert(
          'app_settings',
          {
            'key': 'journal_reports_enabled',
            'value': 'false',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
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

      await DatabaseHelper.backfillCurrencyLockIfNeeded(txn);
    });

    await _restoreLogoIfNeeded(jsonMap);
    await DatabaseHelper.instance.logAuditEvent(
      'backup_restored',
      details:
          'version=${jsonMap['backup_version']} db=${jsonMap['database_version']}',
    );

    // If legacy backup lacked journal tables, invoke backfill
    final isLegacy = !data.containsKey('journal_entries') ||
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

    // Prune older safety backups beyond retention limits
    if (createSafetyBackup) {
      await pruneSafetyBackups(preservePath: safetyPath);
    }

    return true;
  }

  // ============================================================
  // VALIDATE BACKUP CONTENT
  // ============================================================

  static void _validateBackup(Map<String, dynamic> jsonMap) {
    if (jsonMap['app'] != appId) {
      throw Exception('Not a Warqatek backup');
    }

    final backupVersion = jsonMap['backup_version'];
    if (backupVersion is! int || backupVersion > currentBackupVersion) {
      throw Exception('Unsupported backup version: $backupVersion');
    }

    final data = jsonMap['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid backup data');
    }

    for (final table in _requiredTables) {
      if (!data.containsKey(table) || data[table] is! List) {
        throw Exception('Missing or invalid table: $table');
      }
    }
  }

  // ============================================================
  // ROW CONVERSION
  // ============================================================

  static List<Map<String, dynamic>> _convertRows(dynamic value) {
    if (value is! List) {
      throw Exception('Invalid row data');
    }
    return value.map<Map<String, dynamic>>((row) {
      if (row is! Map) {
        throw Exception('Invalid row entry');
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
        'products': await txn.query('products'),
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
        'audit_log': await txn.query('audit_log'),
        'accounts': await txn.query('accounts'),
        'journal_entries': await txn.query('journal_entries'),
        'journal_lines': await txn.query('journal_lines'),
        'app_settings': await txn.query('app_settings'),
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

    final backupData = <String, dynamic>{
      'app': appId,
      'backup_version': currentBackupVersion,
      'database_version': DatabaseHelper.dbVersion,
      'created_at': DateTime.now().toIso8601String(),
      'data': snapshot,
      'assets': {'logo_base64': logoBase64},
    };

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  // ============================================================
  // RESTORE LOGO
  // ============================================================

  static Future<void> _restoreLogoIfNeeded(Map<String, dynamic> jsonMap) async {
    final assets = jsonMap['assets'];
    if (assets is! Map<String, dynamic>) return;

    final logoBase64 = assets['logo_base64'] as String?;
    if (logoBase64 == null || logoBase64.isEmpty) return;

    try {
      final logoBytes = base64Decode(logoBase64);
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'business_logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(logoBytes, flush: true);

      final business = await DatabaseHelper.instance.getFirstBusiness();
      if (business == null) return;

      await DatabaseHelper.instance.updateBusiness(
        business.copyWith(logoPath: file.path),
      );
    } catch (_) {
      // Do not fail restore due to logo
    }
  }
}
