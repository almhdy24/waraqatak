import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/services/google_drive_backup_service.dart';

class FakeGoogleDriveClient implements GoogleDriveClient {
  bool signedIn = false;
  String? email;
  final Map<String, Uint8List> storage = {};
  final List<DriveBackupFile> files = [];

  bool throwOnUpload = false;
  bool throwOnDownload = false;
  bool throwOnList = false;
  bool returnFalseOnSignIn = false;
  Exception? throwOnSignIn;

  @override
  String? get currentUserEmail => signedIn ? email : null;

  @override
  Future<bool> isSignedIn() async => signedIn;

  @override
  Future<bool> signIn() async {
    if (throwOnSignIn != null) throw throwOnSignIn!;
    if (returnFalseOnSignIn) return false;
    signedIn = true;
    email = 'merchant@example.com';
    return true;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
    email = null;
  }

  @override
  Future<List<DriveBackupFile>> listBackups() async {
    if (throwOnList) throw Exception('Drive listing failed');
    return List.unmodifiable(files);
  }

  @override
  Future<DriveBackupFile> uploadBackup({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (throwOnUpload) throw Exception('Drive upload failed');
    final existingIndex = files.indexWhere((f) => f.name == fileName);
    if (existingIndex >= 0) {
      final existing = files[existingIndex];
      storage[existing.id] = bytes;
      final updated = DriveBackupFile(
        id: existing.id,
        name: fileName,
        sizeBytes: bytes.length,
        modifiedTime: DateTime.now(),
      );
      files[existingIndex] = updated;
      return updated;
    }

    final id = 'drive_id_${files.length + 1}';
    storage[id] = bytes;
    final file = DriveBackupFile(
      id: id,
      name: fileName,
      sizeBytes: bytes.length,
      modifiedTime: DateTime.now(),
    );
    files.add(file);
    return file;
  }

  @override
  Future<Uint8List> downloadBackup(String fileId) async {
    if (throwOnDownload) throw Exception('Drive download failed');
    final data = storage[fileId];
    if (data == null) throw Exception('File not found on drive');
    return data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late FakeGoogleDriveClient fakeClient;
  final loggedAuditEvents = <String>[];

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('gdrive_backup_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDownAll(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() {
    fakeClient = FakeGoogleDriveClient();
    GoogleDriveBackupService.instance.setClientForTesting(fakeClient);
    loggedAuditEvents.clear();

    GoogleDriveBackupService.logAuditEventOverride = (event, {details}) async {
      loggedAuditEvents.add('$event: $details');
    };

    GoogleDriveBackupService.createLocalBackupOverride = () async {
      final sampleBackupFile = File('${tempDir.path}/warqatek_backup_${DateTime.now().millisecondsSinceEpoch}.waraq');
      await sampleBackupFile.writeAsString(jsonEncode({
        'app': 'warqatek',
        'version': 4,
        'created_at': DateTime.now().toIso8601String(),
        'data': {
          'business': [{'name': 'متجر تجريبي'}],
        },
      }));
      return sampleBackupFile.path;
    };

    GoogleDriveBackupService.restoreFromJsonMapOverride = (jsonMap, {createSafetyBackup = true}) async {
      if (jsonMap['app'] != 'warqatek') {
        throw Exception('Not a valid Warqatek backup file');
      }
      return true;
    };
  });

  tearDown(() {
    GoogleDriveBackupService.createLocalBackupOverride = null;
    GoogleDriveBackupService.logAuditEventOverride = null;
    GoogleDriveBackupService.restoreFromJsonMapOverride = null;
  });

  group('DriveBackupFile formattedSize', () {
    test('formats bytes correctly', () {
      final file = DriveBackupFile(
        id: '1',
        name: 'b.waraq',
        sizeBytes: 512,
        modifiedTime: DateTime.now(),
      );
      expect(file.formattedSize, '512 B');
    });

    test('formats kilobytes correctly', () {
      final file = DriveBackupFile(
        id: '2',
        name: 'b.waraq',
        sizeBytes: 2560,
        modifiedTime: DateTime.now(),
      );
      expect(file.formattedSize, '2.5 KB');
    });

    test('formats megabytes correctly', () {
      final file = DriveBackupFile(
        id: '3',
        name: 'b.waraq',
        sizeBytes: 5242880,
        modifiedTime: DateTime.now(),
      );
      expect(file.formattedSize, '5.0 MB');
    });
  });

  group('GoogleDriveBackupService authentication', () {
    test('reports signed out initially', () async {
      expect(await GoogleDriveBackupService.instance.isSignedIn(), isFalse);
      expect(GoogleDriveBackupService.instance.currentUserEmail, isNull);
    });

    test('signs in successfully and provides user email', () async {
      final ok = await GoogleDriveBackupService.instance.signIn();
      expect(ok, isTrue);
      expect(await GoogleDriveBackupService.instance.isSignedIn(), isTrue);
      expect(GoogleDriveBackupService.instance.currentUserEmail, 'merchant@example.com');
    });

    test('signs out successfully and clears user email', () async {
      await GoogleDriveBackupService.instance.signIn();
      await GoogleDriveBackupService.instance.signOut();
      expect(await GoogleDriveBackupService.instance.isSignedIn(), isFalse);
      expect(GoogleDriveBackupService.instance.currentUserEmail, isNull);
    });
  });

  group('GoogleDriveBackupService upload and list', () {
    test('initially returns empty list when no cloud backups exist', () async {
      await fakeClient.signIn();
      final backups = await GoogleDriveBackupService.instance.listBackups();
      expect(backups, isEmpty);
    });

    test(
      'uploadCurrentBackup creates local backup, uploads to Drive, and logs audit event',
      () async {
        await fakeClient.signIn();
        final uploaded = await GoogleDriveBackupService.instance.uploadCurrentBackup();

        expect(uploaded.id, isNotEmpty);
        expect(uploaded.name, contains('warqatek_backup_'));
        expect(uploaded.sizeBytes, greaterThan(0));

        final backups = await GoogleDriveBackupService.instance.listBackups();
        expect(backups.length, 1);
        expect(backups.first.id, uploaded.id);
        expect(loggedAuditEvents.any((e) => e.contains('google_drive_backup_uploaded')), isTrue);
      },
    );

    test('repeated uploadCurrentBackup on same day updates existing file without duplicates', () async {
      await fakeClient.signIn();
      final upload1 = await GoogleDriveBackupService.instance.uploadCurrentBackup();
      final upload2 = await GoogleDriveBackupService.instance.uploadCurrentBackup();

      expect(upload2.id, upload1.id, reason: 'Repeated upload on same day must update the existing file ID');
      final backups = await GoogleDriveBackupService.instance.listBackups();
      expect(backups.length, 1, reason: 'Must not create duplicate backup entries for the same day');
    });

    test('uploadCurrentBackup cleans up intermediate local file on disk', () async {
      await fakeClient.signIn();
      late String createdPath;
      GoogleDriveBackupService.createLocalBackupOverride = () async {
        final f = File('${tempDir.path}/temp_test_cleanup_${DateTime.now().millisecondsSinceEpoch}.waraq');
        await f.writeAsString('{"app":"warqatek"}');
        createdPath = f.path;
        return createdPath;
      };

      await GoogleDriveBackupService.instance.uploadCurrentBackup();
      expect(File(createdPath).existsSync(), isFalse);
    });
  });

  group('GoogleDriveBackupService restore validation and safety', () {
    test('restoring valid backup succeeds and logs audit event', () async {
      await fakeClient.signIn();
      final uploaded = await GoogleDriveBackupService.instance.uploadCurrentBackup();

      var safetyBackupRequested = false;
      GoogleDriveBackupService.restoreFromJsonMapOverride = (jsonMap, {createSafetyBackup = true}) async {
        safetyBackupRequested = createSafetyBackup;
        return true;
      };

      final success = await GoogleDriveBackupService.instance.restoreFromDrive(uploaded);
      expect(success, isTrue);
      expect(safetyBackupRequested, isTrue, reason: 'Safety backup must be requested before restoring');
      expect(loggedAuditEvents.any((e) => e.contains('google_drive_backup_restored')), isTrue);
    });

    test('restoring corrupt cloud data rejects file before restoration', () async {
      await fakeClient.signIn();
      const corruptId = 'corrupt_drive_file';
      fakeClient.storage[corruptId] = Uint8List.fromList(
        utf8.encode('{"app": "unknown_app"}'),
      );
      final corruptFile = DriveBackupFile(
        id: corruptId,
        name: 'corrupt.waraq',
        sizeBytes: 25,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(
        () => GoogleDriveBackupService.instance.restoreFromDrive(corruptFile),
        throwsA(isA<Exception>()),
      );
    });

    test('restoring truncated non-json data throws format exception and aborts', () async {
      await fakeClient.signIn();
      const truncatedId = 'truncated_file';
      fakeClient.storage[truncatedId] = Uint8List.fromList(
        utf8.encode('{"app": "warqatek", "versio'),
      );
      final truncatedFile = DriveBackupFile(
        id: truncatedId,
        name: 'truncated.waraq',
        sizeBytes: 28,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(
        () => GoogleDriveBackupService.instance.restoreFromDrive(truncatedFile),
        throwsA(isA<FormatException>()),
      );
    });

    test('restoring empty cloud data throws and aborts before restore', () async {
      await fakeClient.signIn();
      const emptyId = 'empty_drive_file';
      fakeClient.storage[emptyId] = Uint8List(0);
      final emptyFile = DriveBackupFile(
        id: emptyId,
        name: 'empty.waraq',
        sizeBytes: 0,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(
        () => GoogleDriveBackupService.instance.restoreFromDrive(emptyFile),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DefaultGoogleDriveClient configuration', () {
    test('defaultServerClientId matches registered Web OAuth client ID', () {
      expect(
        DefaultGoogleDriveClient.defaultServerClientId,
        '357022447272-rr13hjouqhrndd1e9a9de71q4ilpvu6i.apps.googleusercontent.com',
      );
      expect(
        DefaultGoogleDriveClient.serverClientId,
        DefaultGoogleDriveClient.defaultServerClientId,
      );
    });
  });

  group('GoogleDriveBackupService authentication and error handling', () {
    test('signIn succeeds and updates signedIn status and currentUserEmail', () async {
      expect(await GoogleDriveBackupService.instance.isSignedIn(), isFalse);
      expect(GoogleDriveBackupService.instance.currentUserEmail, isNull);

      final success = await GoogleDriveBackupService.instance.signIn();
      expect(success, isTrue);
      expect(await GoogleDriveBackupService.instance.isSignedIn(), isTrue);
      expect(GoogleDriveBackupService.instance.currentUserEmail, 'merchant@example.com');
    });

    test('signIn propagates cancellation exception on user cancellation or credential mismatch', () async {
      fakeClient.throwOnSignIn = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'User canceled or credential manager was canceled by provider',
      );

      expect(
        () => GoogleDriveBackupService.instance.signIn(),
        throwsA(
          isA<GoogleSignInException>().having(
            (e) => e.code,
            'code',
            GoogleSignInExceptionCode.canceled,
          ),
        ),
      );
    });

    test('signIn propagates configuration exception when OAuth client is misconfigured', () async {
      fakeClient.throwOnSignIn = const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'serverClientId must be provided on Android',
      );

      expect(
        () => GoogleDriveBackupService.instance.signIn(),
        throwsA(
          isA<GoogleSignInException>().having(
            (e) => e.code,
            'code',
            GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ),
      );
    });

    test('signIn returns false when authorization is denied without throwing', () async {
      fakeClient.returnFalseOnSignIn = true;
      final result = await GoogleDriveBackupService.instance.signIn();
      expect(result, isFalse);
      expect(await GoogleDriveBackupService.instance.isSignedIn(), isFalse);
    });

    test('signOut clears user email and sign-in state', () async {
      await GoogleDriveBackupService.instance.signIn();
      expect(await GoogleDriveBackupService.instance.isSignedIn(), isTrue);

      await GoogleDriveBackupService.instance.signOut();
      expect(await GoogleDriveBackupService.instance.isSignedIn(), isFalse);
      expect(GoogleDriveBackupService.instance.currentUserEmail, isNull);
    });

    test('localization messages support cancellation and config errors', () {
      final l10nAr = AppLocalizations('ar');
      final l10nEn = AppLocalizations('en');

      expect(l10nAr.googleDriveSignInCancelled, contains('تم إلغاء'));
      expect(l10nEn.googleDriveSignInCancelled, contains('cancelled'));

      expect(l10nAr.googleDriveErrorConfig, contains('Google Cloud'));
      expect(l10nEn.googleDriveErrorConfig, contains('Google Cloud'));
    });
  });
}
