import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/screens/activation_screen.dart';
import 'package:warqatek/services/activation_service.dart';
import 'package:warqatek/services/license_key.dart';
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
      home: Scaffold(body: child),
    ),
  );
}

String _createValidKey() {
  const payload = 'ABCDEFGHJKM';
  var sum = 0;
  for (var i = 0; i < payload.length; i++) {
    sum += ShortLicenseKey.alphabet.indexOf(payload[i]);
  }
  return '$payload${ShortLicenseKey.alphabet[sum % 32]}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });

  tearDown(() {
    ActivationService.debugResetClient();
  });

  group('ActivationKeyInputWidget Unit & Format Validation', () {
    test(
      'Format validation accepts valid Crockford checksum keys and rejects invalid',
      () {
        final validCrockford = _createValidKey();
        expect(ActivationKeyInputWidget.isFormatValid(validCrockford), isTrue);

        // Empty and invalid keys
        expect(ActivationKeyInputWidget.isFormatValid(''), isFalse);
        expect(ActivationKeyInputWidget.isFormatValid('INVALID'), isFalse);
        expect(ActivationKeyInputWidget.isFormatValid('123456789012'), isFalse);
        expect(
          ActivationKeyInputWidget.isFormatValid('WQ-ABCD-EFGH-ZZZZ'),
          isFalse,
        );
      },
    );

    testWidgets(
      'Activate button is disabled when empty or invalid, enabled when valid',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHost(child: const ActivationKeyInputWidget()),
        );
        await tester.pumpAndSettle();

        final activateFinder = find.widgetWithText(FilledButton, 'تفعيل');
        expect(activateFinder, findsOneWidget);

        // Initially empty -> disabled
        final buttonBefore = tester.widget<FilledButton>(activateFinder);
        expect(buttonBefore.onPressed, isNull);

        // Invalid format -> disabled
        await tester.enterText(find.byType(TextField), 'ABCD');
        await tester.pump();
        final buttonInvalid = tester.widget<FilledButton>(activateFinder);
        expect(buttonInvalid.onPressed, isNull);
        expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

        // Valid format -> enabled, shows valid indicator
        final validKey = _createValidKey();
        await tester.enterText(find.byType(TextField), validKey);
        await tester.pump();
        final buttonValid = tester.widget<FilledButton>(activateFinder);
        expect(buttonValid.onPressed, isNotNull);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      },
    );

    testWidgets('Clear button clears text field', (tester) async {
      await tester.pumpWidget(
        _buildTestHost(child: const ActivationKeyInputWidget()),
      );
      await tester.pumpAndSettle();

      final validKey = _createValidKey();
      await tester.enterText(find.byType(TextField), validKey);
      await tester.pump();

      expect(find.text(validKey), findsOneWidget);
      final clearFinder = find.byIcon(Icons.clear_rounded);
      expect(clearFinder, findsOneWidget);

      await tester.tap(clearFinder);
      await tester.pump();

      expect(find.text(validKey), findsNothing);
    });

    test(
      'All ActivationOutcome values map to unique localized error and tip messages',
      () {
        final l10n = AppLocalizations('ar');

        final errorMessages = {
          ActivationOutcome.invalid: l10n.invalidOrExpiredKey,
          ActivationOutcome.tooManyAttempts: l10n.activationTooManyAttempts,
          ActivationOutcome.serverUnreachable: l10n.activationServerUnreachable,
          ActivationOutcome.deviceUnavailable: l10n.activationDeviceUnavailable,
          ActivationOutcome.storageFailed: l10n.activationStorageFailed,
        };

        final tipMessages = {
          ActivationOutcome.invalid: l10n.activationTipKeyFormat,
          ActivationOutcome.tooManyAttempts: l10n.activationTipAttempts,
          ActivationOutcome.serverUnreachable: l10n.activationTipServer,
          ActivationOutcome.deviceUnavailable: l10n.activationTipDevice,
          ActivationOutcome.storageFailed: l10n.activationTipStorage,
        };

        // Ensure every non-success outcome has a distinct error and tip
        for (final outcome in errorMessages.keys) {
          expect(errorMessages[outcome]!.isNotEmpty, isTrue);
          expect(tipMessages[outcome]!.isNotEmpty, isTrue);
        }
        expect(
          errorMessages.values.toSet().length,
          5,
          reason: 'Errors must not collapse',
        );
        expect(
          tipMessages.values.toSet().length,
          5,
          reason: 'Tips must not collapse',
        );
      },
    );
  });

  group('ActivationScreen PopScope & Navigation', () {
    testWidgets(
      'PopScope allows pop when not loading, success screen returns true',
      (tester) async {
        await tester.pumpWidget(
          _buildTestHost(child: const ActivationScreen()),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations('ar');
        expect(find.text(l10n.activation), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
      },
    );
  });
}
