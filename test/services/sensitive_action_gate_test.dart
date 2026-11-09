import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/access_admin_service.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/access_seeder.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/access/sensitive_action_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('sensitive_action_gate_test');
    AuditService.instance.setTestingDeviceId('test-device-sensitive-001');
    AuthService.useCompute = false;
    AuthService.testingIterations = 50;
    SessionManager.enableInactivityTimer = false;
  });

  tearDownAll(() async {
    AuthService.useCompute = false;
    AuthService.testingIterations = 50;
    SessionManager.enableInactivityTimer = true;
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Batch 7: Sensitive-Action Re-Authentication Tests', () {
    late Database db;

    setUp(() async {
      AuthService.resetDeviceThrottle();
      AuditService.instance.resetChainLockForTesting();
      SessionManager.instance.resetForTesting();
      await DatabaseHelper.instance.closeDatabase();
      final dir = Directory.systemTemp.createTempSync('sens_run_');
      await databaseFactory.setDatabasesPath(dir.path);
      db = await DatabaseHelper.instance.database;
      await SessionManager.instance.init();
    });

    tearDown(() async {
      AuthService.resetDeviceThrottle();
      AuditService.instance.resetChainLockForTesting();
      SessionManager.instance.resetForTesting();
      await DatabaseHelper.instance.closeDatabase();
    });

    testWidgets('Single-user mode bypasses re-authentication immediately', (tester) async {
      SessionManager.instance.setMultiUserEnabledForTesting(false);
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      final result = await SensitiveActionGate.reauthenticate(
        ctx,
        title: 'Destructive Action',
        requireOwner: true,
      );

      expect(result, isTrue);
    });

    testWidgets('Non-owner cannot reauthenticate when requireOwner is true', (tester) async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);

      final cashier = AppUser(
        id: 'user-cashier-test',
        workspaceId: AccessDao.defaultWorkspaceId,
        username: 'cashier_test',
        displayName: 'Cashier Test',
        roleId: AccessSeeder.roleTemplateSalesperson,
        isOwner: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      SessionManager.instance.setSession(cashier, {});

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      final result = await SensitiveActionGate.reauthenticate(
        ctx,
        title: 'Owner-Only Action',
        requireOwner: true,
      );

      expect(result, isFalse);
    });

    testWidgets('Multi-user mode verifies password and logs audit events', (tester) async {
      await tester.runAsync(() async {
        await SessionManager.instance.setMultiUserEnabled(true);

        final owner = await AccessAdminService.instance.getUserById(AccessDao.ownerUserId, executor: db);
        expect(owner, isNotNull);

        await AuthService.instance.setPassword(
          owner!.id,
          'SecureOwnerPass123',
          executor: db,
        );
        final updatedOwner = await AccessAdminService.instance.getUserById(AccessDao.ownerUserId, executor: db);
        SessionManager.instance.setSession(updatedOwner!, {'*'});
      });

      late BuildContext ctx;
      await tester.pumpWidget(
        LanguageProvider(
          langCode: 'en',
          onChangeLanguage: (_) async {},
          child: MaterialApp(
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      bool? result;
      late Future<void> reauthFuture;
      void launchReauth() {
        reauthFuture = () async {
          result = await SensitiveActionGate.reauthenticate(
            ctx,
            title: 'Database Repair',
            message: 'Fixing corruption',
            requireOwner: true,
          );
        }();
      }

      launchReauth();
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Database Repair'), findsOneWidget);
      expect(find.text('Fixing corruption'), findsOneWidget);

      // 1. Enter WRONG password
      await tester.enterText(find.byType(TextField), 'WrongPassword');
      await tester.tap(find.text('Confirm'));
      await tester.pump();

      bool hasError = false;
      for (int i = 0; i < 25; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        if (find.text('Incorrect password').evaluate().isNotEmpty) {
          hasError = true;
          break;
        }
      }

      // Verification fails, error displayed, dialog stays open
      expect(hasError, isTrue);
      expect(result, isNull);

      // Verify audit logged reauth_failed
      await tester.runAsync(() async {
        final failRows = await db.query(
          'audit_log',
          where: 'action = ?',
          whereArgs: ['reauth_failed'],
        );
        expect(failRows.length, 1);
      });

      // 2. Enter CORRECT password
      await tester.enterText(find.byType(TextField), 'SecureOwnerPass123');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      bool isClosed = false;
      for (int i = 0; i < 50; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(AlertDialog).evaluate().isEmpty) {
          isClosed = true;
          break;
        }
      }
      if (!isClosed) {
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
            break;
          }
        }
        isClosed = find.byType(AlertDialog).evaluate().isEmpty;
      }

      // Dialog closes, result is true
      await reauthFuture;
      expect(isClosed, isTrue);
      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);

      // Verify audit logged reauth_success
      await tester.runAsync(() async {
        final successRows = await db.query(
          'audit_log',
          where: 'action = ?',
          whereArgs: ['reauth_success'],
        );
        expect(successRows.length, 1);
      });
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('SessionManager.setMultiUserEnabled(false) requires Owner session', (tester) async {
      await tester.runAsync(() async {
        await SessionManager.instance.setMultiUserEnabled(true);

        final owner = await AccessAdminService.instance.getUserById(AccessDao.ownerUserId, executor: db);
        expect(owner, isNotNull);

        final cashier = AppUser(
          id: 'user-cashier-disable',
          workspaceId: AccessDao.defaultWorkspaceId,
          username: 'cashier_disable_test',
          displayName: 'Cashier Disable Test',
          roleId: AccessSeeder.roleTemplateSalesperson,
          isOwner: false,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        SessionManager.instance.setSession(cashier, {});

        // Cashier cannot disable multi-user mode
        await expectLater(
          SessionManager.instance.setMultiUserEnabled(false),
          throwsA(isA<PermissionDeniedException>()),
        );

        // Owner CAN disable multi-user mode
        SessionManager.instance.setSession(owner!, {'*'});
        await SessionManager.instance.setMultiUserEnabled(false);
        expect(SessionManager.instance.isMultiUserEnabled, isFalse);
      });
    });
  });
}
