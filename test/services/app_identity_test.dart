import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/core/constants/app_constants.dart';
import 'package:warqatek/services/license_key.dart';

void main() {
  group('App Identity & Identifier Unification (Batch 1)', () {
    test('AppConstants.appId is canonical com.elmahdi.waraqatak', () {
      expect(AppConstants.appId, 'com.elmahdi.waraqatak');
      expect(AppConstants.packageName, AppConstants.appId);
    });

    test('android/app/build.gradle.kts applicationId matches AppConstants.appId', () {
      final file = File('android/app/build.gradle.kts');
      expect(file.existsSync(), isTrue, reason: 'build.gradle.kts must exist');

      final content = file.readAsStringSync();
      final match = RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(content);

      expect(match, isNotNull, reason: 'applicationId must be declared in build.gradle.kts');
      final appId = match!.group(1);
      expect(appId, equals(AppConstants.appId));
    });

    test('AppConstants.appVersion and appBuild match pubspec.yaml', () {
      final file = File('pubspec.yaml');
      expect(file.existsSync(), isTrue, reason: 'pubspec.yaml must exist');

      final content = file.readAsStringSync();
      final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:-[a-zA-Z0-9.]+)?\+([0-9]+)', multiLine: true).firstMatch(content);

      expect(match, isNotNull, reason: 'version must be declared in pubspec.yaml');
      final versionStr = match!.group(1);
      final buildStr = match.group(2);

      expect(versionStr, equals(AppConstants.appVersion));
      expect(int.parse(buildStr!), equals(AppConstants.appBuild));
    });

    test('Long key payload app claim verification', () {
      String makeKey(Map<String, dynamic> payload) {
        final b64 = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
        return '$b64.mockSignature';
      }

      final now = DateTime.now();

      // Canonical ID is accepted
      final validClaims = LicenseKeyClaims.tryParse(makeKey({
        'license_id': 100,
        'app_slug': AppConstants.appId,
        'license_type': 'lifetime',
        'expires_at': null,
      }))!;
      expect(validClaims.allowsActivation(now, expectedAppId: AppConstants.appId), isTrue);

      // Old / non-canonical slug 'waraqatak' is rejected by app
      final oldSlugClaims = LicenseKeyClaims.tryParse(makeKey({
        'license_id': 100,
        'app_slug': 'waraqatak',
        'license_type': 'lifetime',
        'expires_at': null,
      }))!;
      expect(oldSlugClaims.allowsActivation(now, expectedAppId: AppConstants.appId), isFalse);

      // Other app is rejected
      final otherAppClaims = LicenseKeyClaims.tryParse(makeKey({
        'license_id': 100,
        'app_slug': 'com.other.app',
        'license_type': 'lifetime',
        'expires_at': null,
      }))!;
      expect(otherAppClaims.allowsActivation(now, expectedAppId: AppConstants.appId), isFalse);

      // Uppercase / whitespace is rejected (exact comparison)
      final upperCaseClaims = LicenseKeyClaims.tryParse(makeKey({
        'license_id': 100,
        'app_slug': 'COM.ELMAHDI.WARAQATAK',
        'license_type': 'lifetime',
        'expires_at': null,
      }))!;
      expect(upperCaseClaims.allowsActivation(now, expectedAppId: AppConstants.appId), isFalse);
    });
  });
}
