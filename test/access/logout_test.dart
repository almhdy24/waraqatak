import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/screens/settings_screen.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('logout_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    AuditService.instance.setTestingDeviceId('test-device-logout-001');
    SessionManager.enableInactivityTimer = false;
  });

  tearDownAll(() async {
    SessionManager.enableInactivityTimer = true;
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  tearDown(() {
    SessionManager.instance.resetForTesting();
  });

  final testUser = AppUser(
    id: 'usr-cashier-test',
    workspaceId: AccessDao.defaultWorkspaceId,
    username: 'cashier_sam',
    displayName: 'سامي المحاسب',
    roleId: 'role-template-salesperson',
    isOwner: false,
    isActive: true,
    setupComplete: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget buildTestWidget(Widget child) {
    return LanguageProvider(
      langCode: 'ar',
      onChangeLanguage: (_) async {},
      child: MaterialApp(
        navigatorKey: SessionManager.navigatorKey,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Multi-User Logout Button Visibility & Gating', () {
    testWidgets('Hidden completely when multi-user mode is OFF', (tester) async {
      SessionManager.instance.setMultiUserEnabledForTesting(false);

      await tester.pumpWidget(buildTestWidget(const CurrentUserProfileCard()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('logout_button')), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.text('تسجيل الخروج'), findsNothing);
    });

    testWidgets('Visible with user details when multi-user mode is ON', (tester) async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testUser, {PermissionRegistry.salesCreate});

      await tester.pumpWidget(buildTestWidget(const CurrentUserProfileCard()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('logout_button')), findsOneWidget);
      expect(find.text('سامي المحاسب'), findsOneWidget);
      expect(find.textContaining('cashier_sam'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });

    test('logout() is a no-op when multi-user is OFF', () async {
      SessionManager.instance.setMultiUserEnabledForTesting(false);
      final initialOwner = SessionManager.instance.currentUser;
      expect(initialOwner, isNotNull);

      await SessionManager.instance.logout();

      // In single-user mode, currentUser remains the implicit owner and isLocked is false
      expect(SessionManager.instance.currentUser, equals(initialOwner));
      expect(SessionManager.instance.isLocked, isFalse);
    });
  });

  group('Logout Confirmation Dialog & Session Clearing', () {
    testWidgets('Shows confirmation dialog with warning about unsaved forms', (tester) async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testUser, {PermissionRegistry.salesCreate});

      await tester.pumpWidget(buildTestWidget(const CurrentUserProfileCard()));
      await tester.pumpAndSettle();

      // Tap logout button
      await tester.tap(find.byKey(const ValueKey('logout_button')));
      await tester.pumpAndSettle();

      // Verify dialog is presented with Arabic warning message
      final l10n = AppLocalizations('ar');
      expect(find.text(l10n.logoutConfirmMessage), findsOneWidget);
      expect(find.text(l10n.cancel), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      // User session must remain active
      expect(SessionManager.instance.currentUser, equals(testUser));
      expect(SessionManager.instance.isLocked, isFalse);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isTrue);
    });

    testWidgets('Confirming logout locks session, clears user and permissions', (tester) async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testUser, {PermissionRegistry.salesCreate});

      await tester.pumpWidget(buildTestWidget(const CurrentUserProfileCard()));
      await tester.pumpAndSettle();

      // Tap logout
      await tester.tap(find.byKey(const ValueKey('logout_button')));
      await tester.pumpAndSettle();

      // Tap confirm button in dialog (the last 'تسجيل الخروج' button which is inside the dialog)
      final confirmButtons = find.widgetWithText(FilledButton, 'تسجيل الخروج');
      expect(confirmButtons, findsOneWidget);
      await tester.tap(confirmButtons);
      await tester.pumpAndSettle();

      // Session must be cleared and locked
      expect(SessionManager.instance.currentUser, isNull);
      expect(SessionManager.instance.cachedPermissions, isEmpty);
      expect(SessionManager.instance.isLocked, isTrue);
      expect(SessionManager.instance.can(PermissionRegistry.salesCreate), isFalse);
    });
  });

  group('Audit Log Persistence & Non-Destructive Invariant', () {
    test('Logs user_logout event into audit_log and preserves database records', () async {
      await DatabaseHelper.instance.closeDatabase();
      final dir = Directory.systemTemp.createTempSync('logout_audit_run_');
      await databaseFactory.setDatabasesPath(dir.path);
      final db = await DatabaseHelper.instance.database;

      try {
        SessionManager.instance.setMultiUserEnabledForTesting(true);
        SessionManager.instance.setSession(testUser, {PermissionRegistry.salesCreate});

        // Insert a dummy record in users table to verify it is NOT deleted on logout
        await db.insert('users', {
          'id': testUser.id,
          'workspace_id': testUser.workspaceId,
          'username': testUser.username,
          'display_name': testUser.displayName,
          'role_id': testUser.roleId,
          'is_owner': 0,
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Execute logout with audit logging
        await SessionManager.instance.logout(executor: db);

        // Verify session cleared
        expect(SessionManager.instance.currentUser, isNull);
        expect(SessionManager.instance.isLocked, isTrue);

        // Verify audit log entry
        final auditRows = await db.query(
          'audit_log',
          where: 'action = ?',
          whereArgs: ['user_logout'],
        );
        expect(auditRows, hasLength(1));
        final log = auditRows.first;
        expect(log['action'], 'user_logout');
        expect(log['user_id'], testUser.id);
        expect(log['user_name'], testUser.displayName);
        expect((log['details'] as String).contains('user=cashier_sam'), isTrue);

        // Invariant: Do NOT delete any data
        final usersAfter = await db.query('users', where: 'id = ?', whereArgs: [testUser.id]);
        expect(usersAfter, hasLength(1), reason: 'User record must NOT be deleted on logout');
      } finally {
        await DatabaseHelper.instance.closeDatabase();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });

    test('auto-lock keeps currentUser while logout clears currentUser', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testUser, {PermissionRegistry.salesCreate});

      // Auto-lock flow
      SessionManager.instance.lock();
      expect(SessionManager.instance.isLocked, isTrue);
      expect(SessionManager.instance.currentUser, equals(testUser),
          reason: 'Lock keeps current user for quick PIN resume');

      // Logout flow
      SessionManager.instance.logout();
      expect(SessionManager.instance.isLocked, isTrue);
      expect(SessionManager.instance.currentUser, isNull,
          reason: 'Logout explicitly removes user credentials');
    });
  });
}
