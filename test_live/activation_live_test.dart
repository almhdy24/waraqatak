// LIVE end-to-end test against api.almhdy24.com. Not part of `flutter test`
// (lives outside test/). Run with:
//   LIVE_LICENSE_ID=1 ADMIN_TOKEN=... flutter test test_live/
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/screens/activation_screen.dart';
import 'package:warqatek/services/activation_service.dart';
import 'package:warqatek/services/feature_access.dart';
import 'package:warqatek/services/license_key.dart';
import 'package:warqatek/services/license_service.dart';

const api = 'https://api.almhdy24.com/api/v1';

class _RealNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..findProxy = HttpClient.findProxyFromEnvironment;
}

/// In-memory stand-in for Android EncryptedSharedPreferences.
final storage = <String, String>{};

/// Stand-in for the Android ID hash returned by MainActivity.
String androidIdHash = 'a1' * 32;

Future<Map<String, dynamic>> admin(String method, String path,
    [Map<String, dynamic>? body]) async {
  final req = http.Request(method, Uri.parse('$api/admin/pay/$path'))
    ..headers.addAll({
      'Authorization': 'Bearer ${Platform.environment['ADMIN_TOKEN']}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    })
    ..body = jsonEncode(body ?? {});
  final res = await http.Response.fromStream(await req.send());
  expect(res.statusCode, 200, reason: '$method $path → ${res.body}');
  return jsonDecode(res.body) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final lid = Platform.environment['LIVE_LICENSE_ID'] ?? '1';

  setUpAll(() {
    HttpOverrides.global = _RealNetwork();
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
      final args = (call.arguments as Map?) ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return storage[key];
        case 'write':
          storage[key!] = args['value'] as String;
          return null;
        case 'delete':
          storage.remove(key);
          return null;
        case 'containsKey':
          return storage.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(storage);
        case 'deleteAll':
          storage.clear();
          return null;
      }
      return null;
    });
    m.setMockMethodCallHandler(
        const MethodChannel('com.elmahdi.waraqatak/device'),
        (call) async => androidIdHash);
  });

  /// Simulates uninstall: wipes app storage (Keystore prefs are deleted).
  void uninstall() {
    storage.clear();
    LicenseService.instance.invalidateCache();
  }

  /// Opens the activation screen, pastes [text] like a user and taps
  /// Activate. Returns the field's error text, or null on success.
  Future<String?> activateViaUi(WidgetTester tester, String text) async {
    await tester.pumpWidget(const SizedBox()); // fresh screen each time
    await tester.pumpWidget(LanguageProvider(
      langCode: 'ar',
      onChangeLanguage: (_) async {},
      child: const MaterialApp(home: ActivationScreen()),
    ));
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    // Tap inside runAsync so the activation request runs on the real event
    // loop (the test-body zone blocks network I/O).
    await tester.runAsync(() async => tester.tap(find.byType(FilledButton)));
    await tester.pump();
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    final ar = AppLocalizations('ar');
    if (find.text(ar.activationSuccessTitle).evaluate().isNotEmpty) return null;
    final field = tester.widget<TextField>(find.byType(TextField));
    return field.decoration?.errorText ?? '(no success, no error)';
  }

  testWidgets('live end-to-end activation', (tester) async {
    final ar = AppLocalizations('ar');
    late String key;

    await tester.runAsync(() async {
      final lic = (await admin('GET', 'licenses/$lid'))['data'] as Map;
      expect(lic['machine_id'], isNull, reason: 'license must start unactivated');
      key = lic['license_key'] as String;
    });
    final claims = LicenseKeyClaims.tryParse(key)!;
    expect(claims.appSlug, ActivationService.appSlug);
    print('Key: ${key.length} chars, slug=${claims.appSlug}, expires=${claims.expiresAt}');

    try {
      // 1. First activation, key pasted with whitespace/newlines around it.
      expect(await activateViaUi(tester, '  \n$key\n '), isNull);
      expect(storage['wq_license_key'], key, reason: 'stored key intact');
      expect(storage['wq_license_status'], 'active');
      final deviceA = storage['wq_device_id']!;
      expect(deviceA, LicenseService.uuidFromHash(androidIdHash));
      late EntitlementState e;
      await tester.runAsync(() async =>
          e = await LicenseService.instance.checkEntitlement(force: true));
      expect(e.status, EntitlementStatus.licensed);
      expect(FeatureAccess.canAccess(Feature.advancedReports, e), isTrue);
      print('✅ 1 first activation via UI → licensed, Pro unlocked, device=$deviceA');

      // 2. Uninstall + reinstall on the same phone → same Android ID.
      uninstall();
      expect(await activateViaUi(tester, key), isNull);
      expect(storage['wq_device_id'], deviceA);
      print('✅ 2 reinstall on same phone → re-activated, same machine_id');

      // 3. Another phone → refused.
      uninstall();
      androidIdHash = 'b2' * 32;
      expect(await activateViaUi(tester, key), ar.invalidOrExpiredKey);
      expect(storage['wq_license_key'], isNull, reason: 'nothing stored');
      print('✅ 3 other phone → "${ar.invalidOrExpiredKey}", nothing stored');

      // 4. Garbage key → refused by server.
      uninstall();
      expect(await activateViaUi(tester, 'abc.def'), ar.invalidOrExpiredKey);
      print('✅ 4 forged key → refused');

      // 5. Expired in DB → refused even on the activated phone.
      uninstall();
      androidIdHash = 'a1' * 32;
      await tester.runAsync(() =>
          admin('PUT', 'licenses/$lid', {'expires_at': '2020-01-01 00:00:00'}));
      expect(await activateViaUi(tester, key), ar.invalidOrExpiredKey);
      print('✅ 5 license expired on server → refused on the same phone');
    } finally {
      await tester.runAsync(() async {
        await admin('PUT', 'licenses/$lid', {'expires_at': ''});
        await admin('POST', 'licenses/$lid/activations/reset');
        final lic = (await admin('GET', 'licenses/$lid'))['data'] as Map;
        print('Restored license #$lid: machine_id=${lic['machine_id']} '
            'expires_at=${lic['expires_at']} status=${lic['status']}');
      });
    }
  });
}
