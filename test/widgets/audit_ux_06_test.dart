import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/screens/activation_screen.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/activation_key_input_widget.dart';

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
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SessionManager.enableInactivityTimer = false;
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.elmahdi.waraqatak/device'),
          (call) async {
            if (call.method == 'getDeviceModel') return 'Test Android Device';
            return null;
          },
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'wq_device_id': 'test_mock_device_id_12345',
      'wq_device_model_cache': 'Test Android Device',
    });

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
    SessionManager.instance.setSession(
      owner,
      PermissionRegistry.all.map((p) => p.key).toSet(),
    );
  });

  testWidgets(
    'UX-06 Regression: ActivationScreen with initialFocusKeyInput: true shows key input at top and autofocused',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestHost(
          child: const ActivationScreen(initialFocusKeyInput: true),
        ),
      );
      await tester.pumpAndSettle();

      final keyInputFinder = find.byType(ActivationKeyInputWidget);
      expect(keyInputFinder, findsOneWidget);

      // Verify that ActivationKeyInputWidget is visible in the viewport without needing to scroll
      final keyInputTopLeft = tester.getTopLeft(keyInputFinder);
      expect(keyInputTopLeft.dy, lessThan(300.0),
          reason: 'Activation key input should be rendered at the top when initialFocusKeyInput is true');

      // Verify that the text field inside ActivationKeyInputWidget has autofocus enabled
      final textFieldFinder = find.descendant(
        of: keyInputFinder,
        matching: find.byType(TextField),
      );
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.autofocus, isTrue);
    },
  );

  testWidgets(
    'UX-06 Regression: ActivationScreen with initialFocusKeyInput: false presents marketing header first and key input below',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestHost(
          child: const ActivationScreen(initialFocusKeyInput: false),
        ),
      );
      await tester.pumpAndSettle();

      final keyInputFinder = find.byType(ActivationKeyInputWidget);
      // When false, key input is at the bottom, so on a 800px screen it starts far below or offscreen
      final keyInputTopLeft = tester.getTopLeft(keyInputFinder);
      expect(keyInputTopLeft.dy, greaterThan(600.0),
          reason: 'Activation key input should be at the bottom when initialFocusKeyInput is false');

      final textFieldFinder = find.descendant(
        of: keyInputFinder,
        matching: find.byType(TextField),
      );
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.autofocus, isFalse);
    },
  );
}
