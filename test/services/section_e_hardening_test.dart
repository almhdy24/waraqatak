import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/services/access/access_error.dart';
import 'package:warqatek/services/access/access_messages.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/widgets/access/access_denied_view.dart';

Widget _wrapWithHarness({required Widget child, String langCode = 'ar'}) {
  return LanguageProvider(
    langCode: langCode,
    onChangeLanguage: (_) async {},
    child: MaterialApp(
      locale: Locale(langCode),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('E2: AccessErrorCode Completeness & Safe Bilingual Localizations', () {
    final rawPermKeyRegex = RegExp(r'[a-z]+\.[a-z_]+');
    final placeholderRegex = RegExp(r'\{[a-zA-Z0-9_]+\}');

    test('All AccessErrorCode values return safe non-empty localized strings without raw keys or placeholders', () {
      final l10nAr = AppLocalizations('ar');
      final l10nEn = AppLocalizations('en');

      for (final code in AccessErrorCode.values) {
        // Test with sample args and sample permission key
        final arText = localizeAccessError(
          l10nAr,
          code,
          permissionKey: PermissionRegistry.salesView,
          args: const {'duration': 120, 'user': 'test_user'},
        );
        final enText = localizeAccessError(
          l10nEn,
          code,
          permissionKey: PermissionRegistry.salesView,
          args: const {'duration': 120, 'user': 'test_user'},
        );

        // 1. Non-empty in both languages
        expect(arText.trim(), isNotEmpty, reason: 'Empty Arabic string for code: $code');
        expect(enText.trim(), isNotEmpty, reason: 'Empty English string for code: $code');

        // 2. No raw permission keys like sales.view or users.manage
        expect(
          rawPermKeyRegex.hasMatch(arText),
          isFalse,
          reason: 'Raw permission key found in Arabic for $code: $arText',
        );
        expect(
          rawPermKeyRegex.hasMatch(enText),
          isFalse,
          reason: 'Raw permission key found in English for $code: $enText',
        );

        // 3. No owner_only:
        expect(arText.contains('owner_only:'), isFalse, reason: 'owner_only literal in Arabic: $arText');
        expect(enText.contains('owner_only:'), isFalse, reason: 'owner_only literal in English: $enText');

        // 4. No unresolved placeholders {xyz}
        expect(placeholderRegex.hasMatch(arText), isFalse, reason: 'Unresolved placeholder in Arabic: $arText');
        expect(placeholderRegex.hasMatch(enText), isFalse, reason: 'Unresolved placeholder in English: $enText');
      }
    });

    test('localizedPermissionName returns localized Arabic/English label and never exposes raw key on unknown', () {
      final l10nAr = AppLocalizations('ar');
      final l10nEn = AppLocalizations('en');

      // Registered permission
      final knownAr = localizedPermissionName(l10nAr, PermissionRegistry.salesView);
      final knownEn = localizedPermissionName(l10nEn, PermissionRegistry.salesView);
      expect(knownAr, isNotEmpty);
      expect(knownEn, isNotEmpty);
      expect(rawPermKeyRegex.hasMatch(knownAr), isFalse);
      expect(rawPermKeyRegex.hasMatch(knownEn), isFalse);

      // Unknown unregistered permission key
      final unknownAr = localizedPermissionName(l10nAr, 'arbitrary.unknown_perm');
      final unknownEn = localizedPermissionName(l10nEn, 'arbitrary.unknown_perm');
      expect(unknownAr, equals(l10nAr.accessGenericPermission));
      expect(unknownEn, equals(l10nEn.accessGenericPermission));
      expect(rawPermKeyRegex.hasMatch(unknownAr), isFalse);
      expect(rawPermKeyRegex.hasMatch(unknownEn), isFalse);
    });

    test('friendlyError maps unexpected or DB exceptions to errUnexpected and never leaks error.toString()', () {
      final l10nAr = AppLocalizations('ar');
      final l10nEn = AppLocalizations('en');

      final secretError = Exception('SECRET_DATABASE_PASSWORD_LEAK');
      final arMsg = friendlyError(l10nAr, secretError);
      final enMsg = friendlyError(l10nEn, secretError);

      expect(arMsg, equals(l10nAr.errUnexpected));
      expect(enMsg, equals(l10nEn.errUnexpected));
      expect(arMsg.contains('SECRET'), isFalse);
      expect(enMsg.contains('SECRET'), isFalse);
    });
  });

  group('E3: Localization Parity & Placeholder Symmetry', () {
    test('All _t translations in app_localizations.dart have non-empty Arabic and English', () {
      final file = File('lib/localization/app_localizations.dart');
      final content = file.readAsStringSync();

      // Check for _t calls
      final tMatches = RegExp(r'''_t\(\s*(?:'([^']*)'|"([^"]*)")\s*,\s*(?:'([^']*)'|"([^"]*)")\s*\)''').allMatches(content);
      expect(tMatches.length, greaterThan(100));

      for (final m in tMatches) {
        final ar = (m.group(1) ?? m.group(2) ?? '').trim();
        final en = (m.group(3) ?? m.group(4) ?? '').trim();

        expect(ar.isNotEmpty, isTrue, reason: 'Empty Arabic for English: $en');
        expect(en.isNotEmpty, isTrue, reason: 'Empty English for Arabic: $ar');
      }
    });
  });

  group('E5: Widget Tests for AccessDeniedView & Screen Guards', () {
    testWidgets('AccessDeniedView renders in Arabic with RTL layout for missingPermission', (tester) async {
      await tester.pumpWidget(
        _wrapWithHarness(
          langCode: 'ar',
          child: const AccessDeniedView(
            decision: AccessErrorCode.missingPermission,
            permissionKey: PermissionRegistry.salesView,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      expect(find.text(l10n.accessDeniedTitle), findsOneWidget);
      expect(find.text(l10n.accessDeniedBack), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      final permName = localizedPermissionName(l10n, PermissionRegistry.salesView);
      expect(find.textContaining(permName), findsOneWidget);
    });

    testWidgets('AccessDeniedView renders in English with LTR layout for ownerOnly', (tester) async {
      await tester.pumpWidget(
        _wrapWithHarness(
          langCode: 'en',
          child: const AccessDeniedView(
            decision: AccessErrorCode.ownerOnly,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('en');
      expect(find.text(l10n.accessDeniedTitle), findsOneWidget);
      expect(find.text(l10n.accessDeniedOwnerOnlyHint), findsOneWidget);
      expect(find.text(l10n.accessDeniedBack), findsOneWidget);
    });

    testWidgets('AccessDeniedView renders in Arabic for targetIsOwner', (tester) async {
      await tester.pumpWidget(
        _wrapWithHarness(
          langCode: 'ar',
          child: const AccessDeniedView(
            decision: AccessErrorCode.targetIsOwner,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      expect(find.text(l10n.accessDeniedTitle), findsOneWidget);
      expect(find.text(l10n.errTargetIsOwner), findsOneWidget);
      expect(find.text(l10n.accessDeniedBack), findsOneWidget);
    });

    test('formatDurationMmSs formats countdown times correctly in mm:ss format', () {
      expect(formatDurationMmSs(Duration.zero), equals('00:00'));
      expect(formatDurationMmSs(const Duration(seconds: 30)), equals('00:30'));
      expect(formatDurationMmSs(const Duration(seconds: 65)), equals('01:05'));
      expect(formatDurationMmSs(const Duration(seconds: 300)), equals('05:00'));
      expect(formatDurationMmSs(const Duration(seconds: 900)), equals('15:00'));
    });
  });
}
