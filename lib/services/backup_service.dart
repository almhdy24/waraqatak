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
  static const int currentBackupVersion = 3;
  static const String appId = 'warqatek';

  static const List<String> _requiredTables = [
    'businesses',
    'contacts',
    'products',
    'documents',
    'document_items',
    'document_counters',
  ];

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

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonStr, encoding: utf8);

    return file.path;
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
    final file = await FilePicker.pickFile(
      type: FileType.any,
    );

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
  static Future<bool> restoreFromJsonMap(Map<String, dynamic> jsonMap) async {
    _validateBackup(jsonMap);

    final data = jsonMap['data'] as Map<String, dynamic>;
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      await txn.delete('document_payments');
      await txn.delete('document_items');
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
      if (data.containsKey('document_payments') && data['document_payments'] is List) {
        for (final row in _convertRows(data['document_payments'])) {
          await txn.insert('document_payments', row);
        }
      }
      // stock_movements is optional (absent in backups created before Phase 3.4)
      if (data.containsKey('stock_movements') && data['stock_movements'] is List) {
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
      if (data.containsKey('payment_methods') && data['payment_methods'] is List) {
        await txn.delete('payment_methods');
        for (final row in _convertRows(data['payment_methods'])) {
          await txn.insert('payment_methods', row);
        }
      }
    });

    await _restoreLogoIfNeeded(jsonMap);
    await DatabaseHelper.instance.logAuditEvent('backup_restored',
        details: 'version=${jsonMap['backup_version']} db=${jsonMap['database_version']}');
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
      },
      'assets': {
        'logo_base64': logoBase64,
      },
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
      final fileName = 'business_logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(logoBytes, flush: true);

      final business = await DatabaseHelper.instance.getFirstBusiness();
      if (business == null) return;

      await DatabaseHelper.instance
          .updateBusiness(business.copyWith(logoPath: file.path));
    } catch (_) {
      // Do not fail restore due to logo
    }
  }
}
