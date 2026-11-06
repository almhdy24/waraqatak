import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../widgets/backup_password_dialog.dart';
import 'backup_encryption_service.dart';
import 'backup_service.dart';

/// Metadata for a Google Drive backup file stored in appDataFolder.
class DriveBackupFile {
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime modifiedTime;

  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.modifiedTime,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Abstract contract for Google Drive operations to allow deterministic unit & widget testing.
abstract class GoogleDriveClient {
  Future<bool> signIn();
  Future<void> signOut();
  Future<bool> isSignedIn();
  String? get currentUserEmail;
  Future<List<DriveBackupFile>> listBackups();
  Future<DriveBackupFile> uploadBackup({
    required Uint8List bytes,
    required String fileName,
  });
  Future<Uint8List> downloadBackup(String fileId);
  Future<void> deleteBackup(String fileId);
}

/// HTTP client that injects fresh Google OAuth authorization headers into every request.
class _GoogleAuthClient extends http.BaseClient {
  final Future<Map<String, String>> Function() _headerSupplier;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headerSupplier);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _headerSupplier();
    request.headers.addAll(headers);
    return _client.send(request).timeout(const Duration(seconds: 90));
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// Standard production implementation of [GoogleDriveClient] using `google_sign_in` and `googleapis`.
class DefaultGoogleDriveClient implements GoogleDriveClient {
  /// Default Web OAuth Client ID registered in Google Cloud Console for Waraqatak.
  static const String defaultServerClientId =
      '357022447272-rr13hjouqhrndd1e9a9de71q4ilpvu6i.apps.googleusercontent.com';

  static const String _envServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Active serverClientId, allowing optional environment override while defaulting to [defaultServerClientId].
  static String get serverClientId =>
      _envServerClientId.isNotEmpty ? _envServerClientId : defaultServerClientId;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;
  GoogleSignInAccount? _account;
  drive.DriveApi? _driveApi;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _googleSignIn.initialize(
        serverClientId: serverClientId,
      );
      _initialized = true;
    }
  }

  @override
  String? get currentUserEmail => _account?.email;

  @override
  Future<bool> isSignedIn() async {
    await _ensureInitialized();
    try {
      _account ??= await _googleSignIn.attemptLightweightAuthentication();
      return _account != null;
    } on GoogleSignInException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _getFreshHeaders() async {
    await _ensureInitialized();
    try {
      _account ??= await _googleSignIn.attemptLightweightAuthentication();
    } catch (_) {
      // Lightweight attempt failed; will trigger interactive authenticate below if needed.
    }
    _account ??= await _googleSignIn.authenticate(
      scopeHint: [drive.DriveApi.driveAppdataScope],
    );
    if (_account == null) {
      throw StateError('Google account sign-in was cancelled or failed.');
    }

    var headers = await _account!.authorizationClient.authorizationHeaders(
      [drive.DriveApi.driveAppdataScope],
      promptIfNecessary: false,
    );
    headers ??= await _account!.authorizationClient.authorizationHeaders(
      [drive.DriveApi.driveAppdataScope],
      promptIfNecessary: true,
    );

    if (headers == null || !headers.containsKey('Authorization')) {
      throw StateError('Failed to obtain Google Drive authorization token.');
    }
    return headers;
  }

  Future<drive.DriveApi> _getDriveApi() async {
    await _ensureInitialized();
    if (_driveApi != null && _account != null) return _driveApi!;
    await _getFreshHeaders();
    _driveApi = drive.DriveApi(_GoogleAuthClient(_getFreshHeaders));
    return _driveApi!;
  }

  @override
  Future<bool> signIn() async {
    try {
      await _ensureInitialized();
      _account = await _googleSignIn.authenticate(
        scopeHint: [drive.DriveApi.driveAppdataScope],
      );
      if (_account != null) {
        final headers = await _account!.authorizationClient.authorizationHeaders(
          [drive.DriveApi.driveAppdataScope],
          promptIfNecessary: true,
        );
        final hasAuthHeader = headers != null && headers.containsKey('Authorization');
        if (hasAuthHeader) {
          _driveApi = drive.DriveApi(_GoogleAuthClient(_getFreshHeaders));
          return true;
        } else {
          return false;
        }
      }
      return false;
    } on GoogleSignInException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();
    } finally {
      _account = null;
      _driveApi = null;
    }
  }

  @override
  Future<List<DriveBackupFile>> listBackups() async {
    final api = await _getDriveApi();
    final allFiles = <DriveBackupFile>[];
    String? pageToken;

    do {
      final fileList = await api.files.list(
        spaces: 'appDataFolder',
        q: "trashed = false and name contains '.waraq'",
        $fields: 'nextPageToken, files(id, name, size, modifiedTime)',
        orderBy: 'modifiedTime desc',
        pageSize: 50,
        pageToken: pageToken,
      );

      final items = fileList.files ?? [];
      for (final f in items) {
        final size = int.tryParse(f.size ?? '0') ?? 0;
        final modified = f.modifiedTime ?? DateTime.now();
        allFiles.add(DriveBackupFile(
          id: f.id ?? '',
          name: f.name ?? 'backup.waraq',
          sizeBytes: size,
          modifiedTime: modified,
        ));
      }
      pageToken = fileList.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return allFiles;
  }

  @override
  Future<DriveBackupFile> uploadBackup({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final api = await _getDriveApi();

    // Escape the file name for use in Drive API query strings.
    final safeName = fileName.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

    // Avoid duplicate files with the same name if possible
    final existing = await api.files.list(
      spaces: 'appDataFolder',
      q: "trashed = false and name = '$safeName'",
      $fields: 'files(id)',
    );

    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/octet-stream',
    );

    final uploadOptions = bytes.length > 5 * 1024 * 1024
        ? drive.ResumableUploadOptions()
        : drive.UploadOptions.defaultOptions;

    drive.File uploaded;
    if (existing.files != null && existing.files!.isNotEmpty) {
      final existingId = existing.files!.first.id!;
      uploaded = await api.files.update(
        drive.File(),
        existingId,
        uploadMedia: media,
        uploadOptions: uploadOptions,
        $fields: 'id, name, size, modifiedTime',
      );
    } else {
      final driveFile = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];
      uploaded = await api.files.create(
        driveFile,
        uploadMedia: media,
        uploadOptions: uploadOptions,
        $fields: 'id, name, size, modifiedTime',
      );
    }

    return DriveBackupFile(
      id: uploaded.id ?? '',
      name: uploaded.name ?? fileName,
      sizeBytes:
          int.tryParse(uploaded.size ?? '${bytes.length}') ?? bytes.length,
      modifiedTime: uploaded.modifiedTime ?? DateTime.now(),
    );
  }

  @override
  Future<Uint8List> downloadBackup(String fileId) async {
    final api = await _getDriveApi();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (media is! drive.Media) {
      throw StateError('Failed to download media content from Google Drive.');
    }

    final bytesBuilder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      bytesBuilder.add(chunk);
    }
    return bytesBuilder.takeBytes();
  }

  @override
  Future<void> deleteBackup(String fileId) async {
    final api = await _getDriveApi();
    await api.files.delete(fileId);
  }
}

/// Service managing cloud backup export and restore to Google Drive appDataFolder.
class GoogleDriveBackupService {
  GoogleDriveBackupService._();
  static final GoogleDriveBackupService instance = GoogleDriveBackupService._();

  GoogleDriveClient _client = DefaultGoogleDriveClient();

  @visibleForTesting
  static Future<String> Function()? createLocalBackupOverride;

  @visibleForTesting
  static Future<void> Function(String event, {String? details})?
      logAuditEventOverride;

  @visibleForTesting
  static Future<bool> Function(
    Map<String, dynamic> jsonMap, {
    bool createSafetyBackup,
  })? restoreFromJsonMapOverride;

  @visibleForTesting
  void setClientForTesting(GoogleDriveClient client) {
    _client = client;
  }

  Future<bool> isSignedIn() => _client.isSignedIn();
  Future<bool> signIn() => _client.signIn();
  Future<void> signOut() => _client.signOut();
  Future<void> deleteBackup(String fileId) async {
    await _client.deleteBackup(fileId);
    try {
      if (logAuditEventOverride != null) {
        await logAuditEventOverride!(
          'google_drive_backup_deleted',
          details: 'file_id: $fileId',
        );
      } else {
        await DatabaseHelper.instance.logAuditEvent(
          'google_drive_backup_deleted',
          details: 'file_id: $fileId',
        );
      }
    } catch (e) {
      // Cloud deletion already succeeded on Google Drive; do not report failure
      // if writing the local audit log entry fails.
      debugPrint('Cloud backup deleted, but failed to log audit event: $e');
    }
  }
  String? get currentUserEmail => _client.currentUserEmail;

  /// Creates a local backup and uploads it to the appDataFolder on Google Drive.
  Future<DriveBackupFile> uploadCurrentBackup({String? password}) async {
    final localBackupPath = createLocalBackupOverride != null
        ? await createLocalBackupOverride!()
        : await BackupService.createLocalBackup(password: password);
    final localFile = File(localBackupPath);
    try {
      final bytes = await localFile.readAsBytes();
      final n = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
      final cloudFileName = 'warqatek_backup_$stamp.waraq';
      final uploaded = await _client.uploadBackup(
        bytes: bytes,
        fileName: cloudFileName,
      );

      if (logAuditEventOverride != null) {
        await logAuditEventOverride!(
          'google_drive_backup_uploaded',
          details: 'file_id=${uploaded.id}; name=${uploaded.name}',
        );
      } else {
        await DatabaseHelper.instance.logAuditEvent(
          'google_drive_backup_uploaded',
          details: 'file_id=${uploaded.id}; name=${uploaded.name}',
        );
      }

      // Retention: keep newest 7 backups, delete the rest.
      try {
        final all = await _client.listBackups(); // already sorted newest first
        final mine = all
            .where((f) =>
                f.name.startsWith('warqatek_backup_') &&
                f.name.endsWith('.waraq'))
            .toList()
          ..sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
        for (final old in mine.skip(7)) {
          if (old.id == uploaded.id) continue;
          try {
            await _client.deleteBackup(old.id);
          } catch (e) {
            debugPrint('Drive retention: failed to delete ${old.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('Drive retention skipped: $e');
      }

      return uploaded;
    } finally {
      try {
        if (await localFile.exists()) {
          await localFile.delete();
        }
      } catch (_) {}
    }
  }

  /// Lists available backup files in Google Drive appDataFolder.
  Future<List<DriveBackupFile>> listBackups() async {
    return _client.listBackups();
  }

  /// Downloads and restores a backup from Google Drive.
  ///
  /// Steps:
  /// 1. Download to temporary file.
  /// 2. If encrypted, prompt for password and decrypt in memory.
  /// 3. Validate JSON structure, application ID, and schema compatibility.
  /// 4. Create a safety backup of the active database before any mutation.
  /// 5. Restore data within SQLite transaction.
  /// 6. Clean up temporary download file.
  Future<bool> restoreFromDrive(
    DriveBackupFile backupFile, {
    BuildContext? context,
    String? password,
    Future<String?> Function(List<int> bytes)? passwordPrompt,
  }) async {
    final bytes = await _client.downloadBackup(backupFile.id);
    if (bytes.isEmpty) {
      throw Exception('Empty backup file received from cloud storage.');
    }

    final tempDir = await getTemporaryDirectory();
    final tempFilePath =
        '${tempDir.path}/drive_restore_${DateTime.now().millisecondsSinceEpoch}.waraq';
    final tempFile = File(tempFilePath);
    await tempFile.writeAsBytes(bytes, flush: true);

    try {
      String content;
      if (BackupEncryptionService.isEncrypted(bytes)) {
        if (password != null && password.isNotEmpty) {
          content = await BackupEncryptionService.decryptJson(
            encryptedBytes: bytes,
            password: password,
          );
        } else if (passwordPrompt != null) {
          final result = await passwordPrompt(bytes);
          if (result == null) return false;
          content = result;
        } else if (context != null && context.mounted) {
          final result = await BackupPasswordPromptDialog.show(
            context,
            encryptedBytes: bytes,
          );
          if (result == null) return false;
          content = result;
        } else {
          throw const BackupDecryptionException(
            'Password is required for encrypted backup',
          );
        }
      } else {
        content = await tempFile.readAsString(encoding: utf8);
      }

      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid cloud backup format');
      }

      // Validates schema and triggers safety backup before modifying local SQLite database
      final success = restoreFromJsonMapOverride != null
          ? await restoreFromJsonMapOverride!(
              decoded,
              createSafetyBackup: true,
            )
          : await BackupService.restoreFromJsonMap(
              decoded,
              createSafetyBackup: true,
            );

      if (success) {
        if (logAuditEventOverride != null) {
          await logAuditEventOverride!(
            'google_drive_backup_restored',
            details: 'file_id=${backupFile.id}; name=${backupFile.name}',
          );
        } else {
          await DatabaseHelper.instance.logAuditEvent(
            'google_drive_backup_restored',
            details: 'file_id=${backupFile.id}; name=${backupFile.name}',
          );
        }
      }
      return success;
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }
}
