import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

class BackupService {
  static const String backupExtension = 'waraq';
  static const int currentBackupVersion = 4;
  static const String appId = 'warqatek';

  @visibleForTesting
  static Future<String> Function()? safetyBackupOverride;

  @visibleForTesting
  static Future<void> Function(File tempFile, File targetFile)?
  onBeforePromotion;

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

  static Future<String> createLocalBackup() async {
    final jsonStr = await _buildBackupJson();
    final fileName =
        'warqatek_backup_${DateTime.now().millisecondsSinceEpoch}.$backupExtension';

    final directory = await _getBackupDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonStr, encoding: utf8);

    return file.path;
  }

  // ============================================================
  // PRE-RESTORE SAFETY BACKUP
  // ============================================================

  /// Creates and validates an automatic safety backup of the current database.
  ///
  /// To ensure that an existing valid safety backup is never overwritten and
  /// that half-written files are never left in place:
  /// 1. A unique filename candidate is determined with a monotonic sequence
  ///    counter and existence checks, preventing same-millisecond collisions.
  /// 2. The backup is written to a uniquely named temporary staging file in the
  ///    same directory and flushed to disk.
  /// 3. The staging file is read back and validated for structural integrity.
  /// 4. The staging file is promoted to its final name using [File.rename]
  ///    after verifying that the destination does not already exist.
  ///    (Note: while rename is atomic on POSIX filesystems within the same
  ///    mount point, platform behaviors differ; this staged approach ensures
  ///    that partial files are cleaned up on failure before any active database
  ///    mutation).
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
  // SAVE BACKUP VIA SYSTEM SAVE DIALOG (bytes-based)
  // ============================================================

  static Future<bool> createBackupUserChosen() async {
    final jsonStr = await _buildBackupJson();
    final fileName =
        'warqatek_backup_${DateTime.now().millisecondsSinceEpoch}.$backupExtension';

    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

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

  static Future<bool> restoreBackup() async {
    final file = await FilePicker.pickFile(type: FileType.any);

    if (file == null) return false;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Empty backup file');
    }

    Map<String, dynamic> jsonMap;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
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
  /// Used by [restoreBackup] and tests.
  @visibleForTesting
  static Future<bool> restoreFromJsonMap(
    Map<String, dynamic> jsonMap, {
    bool createSafetyBackup = true,
  }) async {
    _validateBackup(jsonMap);

    // Create and validate an automatic safety backup of the current database
    // before touching any data. If this fails, restore aborts immediately.
    if (createSafetyBackup) {
      final safetyPath = await BackupService.createSafetyBackup();
      await DatabaseHelper.instance.logAuditEvent(
        'pre_restore_safety_backup_created',
        details: 'path=$safetyPath',
      );
    }

    final data = jsonMap['data'] as Map<String, dynamic>;
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      await txn.delete('document_payments');
      await txn.delete('document_items');
      await txn.delete('stocktake_items');
      await txn.delete('stocktake_sessions');
      await txn.delete('stock_movements');
      await txn.delete('documents');
      await txn.delete('contacts');
      await txn.delete('products');
      await txn.delete('businesses');
      await txn.delete('document_counters');

      for (final row in _convertRows(data['businesses'])) {
        await txn.insert('businesses', row);
      }
      for (final row in _convertRows(data['contacts'])) {
        await txn.insert('contacts', row);
      }
      for (final row in _convertRows(data['products'])) {
        await txn.insert('products', row);
      }

      final docs = _convertRows(data['documents']);
      for (final row in docs) {
        final docRow = Map<String, dynamic>.from(row);
        docRow['related_document_id'] = null;
        await txn.insert('documents', docRow);
      }
      for (final row in _convertRows(data['document_items'])) {
        await txn.insert('document_items', row);
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
        await txn.insert('document_counters', row);
      }
      // document_payments is optional (absent in backups created before Phase 1)
      if (data.containsKey('document_payments') &&
          data['document_payments'] is List) {
        for (final row in _convertRows(data['document_payments'])) {
          await txn.insert('document_payments', row);
        }
      }
      // stock_movements is optional (absent in backups created before Phase 3.4)
      if (data.containsKey('stock_movements') &&
          data['stock_movements'] is List) {
        for (final row in _convertRows(data['stock_movements'])) {
          await txn.insert('stock_movements', row);
        }
      }
      // tax_profiles is optional (absent in backups created before Phase 3.5)
      if (data.containsKey('tax_profiles') && data['tax_profiles'] is List) {
        await txn.delete('tax_profiles');
        for (final row in _convertRows(data['tax_profiles'])) {
          await txn.insert('tax_profiles', row);
        }
      }
      // payment_methods is optional (absent in backups created before Phase 3.6)
      if (data.containsKey('payment_methods') &&
          data['payment_methods'] is List) {
        await txn.delete('payment_methods');
        for (final row in _convertRows(data['payment_methods'])) {
          await txn.insert('payment_methods', row);
        }
      }
      // stocktake_sessions is optional (absent in backups created before v16)
      if (data.containsKey('stocktake_sessions') &&
          data['stocktake_sessions'] is List) {
        for (final row in _convertRows(data['stocktake_sessions'])) {
          await txn.insert('stocktake_sessions', row);
        }
      }
      // stocktake_items is optional (absent in backups created before v16)
      if (data.containsKey('stocktake_items') &&
          data['stocktake_items'] is List) {
        for (final row in _convertRows(data['stocktake_items'])) {
          await txn.insert('stocktake_items', row);
        }
      }
      // audit_log is optional (absent in older backups)
      if (data.containsKey('audit_log') && data['audit_log'] is List) {
        await txn.delete('audit_log');
        for (final row in _convertRows(data['audit_log'])) {
          await txn.insert('audit_log', row);
        }
      }
    });

    await _restoreLogoIfNeeded(jsonMap);
    await DatabaseHelper.instance.logAuditEvent(
      'backup_restored',
      details:
          'version=${jsonMap['backup_version']} db=${jsonMap['database_version']}',
    );
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

  static Future<String> _buildBackupJson() async {
    final db = await DatabaseHelper.instance.database;

    final businesses = await db.query('businesses');
    String? logoBase64;

    if (businesses.isNotEmpty) {
      final logoPath = businesses.first['logo_path']?.toString();
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
      'data': {
        'businesses': businesses,
        'contacts': await db.query('contacts'),
        'products': await db.query('products'),
        'documents': await db.query('documents'),
        'document_items': await db.query('document_items'),
        'document_counters': await db.query('document_counters'),
        'document_payments': await db.query('document_payments'),
        'stock_movements': await db.query('stock_movements'),
        'tax_profiles': await db.query('tax_profiles'),
        'payment_methods': await db.query('payment_methods'),
        'stocktake_sessions': await db.query('stocktake_sessions'),
        'stocktake_items': await db.query('stocktake_items'),
        'audit_log': await db.query('audit_log'),
      },
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
