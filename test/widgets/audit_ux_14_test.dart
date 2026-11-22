import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/access/sensitive_action_gate.dart';
import 'package:warqatek/widgets/app_snackbar.dart';

Widget _buildTestHost({
  required Widget child,
  Locale locale = const Locale('ar'),
}) {
  return LanguageProvider(
    langCode: locale.languageCode,
    onChangeLanguage: (_) async {},
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    SessionManager.enableInactivityTimer = false;
  });

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('ux14_run_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  testWidgets(
    'UX-14 Regression: confirmOrReauthenticate in single-user mode shows exactly one confirmation dialog',
    (tester) async {
      addTearDown(() => AppSnackBar.resetForTest());
      SessionManager.instance.resetForTesting();

      bool? result;

      await tester.pumpWidget(
        _buildTestHost(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await SensitiveActionGate.confirmOrReauthenticate(
                    context,
                    title: 'تأكيد الحذف',
                    message: 'هل أنت متأكد من الحذف؟',
                    confirmLabel: 'حذف',
                    isDestructive: true,
                  );
                },
                child: const Text('Action'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();

      // Expect exactly one dialog
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('تأكيد الحذف'), findsOneWidget);
      expect(find.text('هل أنت متأكد من الحذف؟'), findsOneWidget);
      // No password field in single-user mode
      expect(find.byType(TextField), findsNothing);

      // Confirm the dialog
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed and no second dialog appeared
      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isTrue);
    },
  );

  testWidgets(
    'UX-14 Regression: confirmOrReauthenticate in multi-user mode shows single re-auth dialog and no duplicate confirm dialog',
    (tester) async {
      addTearDown(() => AppSnackBar.resetForTest());

      final owner = AppUser(
        id: '1',
        workspaceId: 'default',
        username: 'owner',
        displayName: 'Owner User',
        roleId: 'owner',
        isOwner: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      SessionManager.instance.setSessionForTesting(
        owner,
        permissions: PermissionRegistry.all.map((p) => p.key).toSet(),
      );

      bool? result;

      await tester.pumpWidget(
        _buildTestHost(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await SensitiveActionGate.confirmOrReauthenticate(
                    context,
                    title: 'تأكيد استعادة النسخة الاحتياطية',
                    message: 'سيتم استبدال كافة البيانات الحالية',
                    requireOwner: true,
                  );
                },
                child: const Text('RestoreAction'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('RestoreAction'));
      await tester.pumpAndSettle();

      // Expect exactly one dialog containing both the message AND the reauth password field
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('تأكيد استعادة النسخة الاحتياطية'), findsOneWidget);
      expect(find.text('سيتم استبدال كافة البيانات الحالية'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Cancel the dialog
      final l10n = AppLocalizations('ar');
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      // Verify no subsequent dialog appears
      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isFalse);
    },
  );
}
