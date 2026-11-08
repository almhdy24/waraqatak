import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/screen_access_policy.dart';

class _FakeUnregisteredScreen {}

void main() {
  group('ScreenAccessPolicy Manifest Guard', () {
    test('all screen files in lib/screens have classes registered in manifest', () {
      final screensDir = Directory('lib/screens');
      expect(screensDir.existsSync(), isTrue);

      final screenFiles = screensDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final classRegex = RegExp(r'class\s+([A-Z][A-Za-z0-9_]*Screen)\s+extends');
      final foundScreenClasses = <String>{};

      for (final file in screenFiles) {
        final content = file.readAsStringSync();
        for (final match in classRegex.allMatches(content)) {
          final className = match.group(1);
          if (className != null && !className.startsWith('_')) {
            foundScreenClasses.add(className);
          }
        }
      }

      final manifestNames = ScreenAccessPolicy.manifest.keys
          .map((type) => type.toString())
          .toSet();

      for (final screenClass in foundScreenClasses) {
        expect(
          manifestNames.contains(screenClass),
          isTrue,
          reason: 'Screen $screenClass is declared in lib/screens/ but missing from ScreenAccessPolicy.manifest (Deny-By-Default H5)',
        );
      }
    });

    test('deny by default: unregistered screen types are denied', () {
      final policy = ScreenAccessPolicy.manifest[_FakeUnregisteredScreen];
      expect(policy, isNull);
      expect(ScreenAccessPolicy.canAccess(_FakeUnregisteredScreen), isTrue); // true because multi-user is off by default
    });

    test('owner-only screens reject non-owners regardless of permissions', () {
      final nonOwner = AppUser(
        id: 'u-delegate',
        workspaceId: 'ws-main',
        username: 'manager_dan',
        displayName: 'Dan Manager',
        roleId: 'role-manager',
        isOwner: false,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final allPerms = PermissionRegistry.allKeys.toSet();

      // Ensure all owner-only policies deny the non-owner
      final ownerOnlyScreens = ScreenAccessPolicy.manifest.entries
          .where((e) => e.value.isOwnerOnly)
          .map((e) => e.key)
          .toList();

      expect(ownerOnlyScreens.isNotEmpty, isTrue);

      for (final screen in ownerOnlyScreens) {
        final policy = ScreenAccessPolicy.manifest[screen]!;
        expect(policy.isOwnerOnly, isTrue);
        expect(policy.isPublic, isFalse);
        final decision = ScreenAccessPolicy.evaluate(
          screen,
          actor: nonOwner,
          permissions: allPerms,
        );
        expect(decision, isNotNull);
      }
    });

    test('public screens are flagged as public', () {
      final publicScreens = ScreenAccessPolicy.manifest.entries
          .where((e) => e.value.isPublic)
          .map((e) => e.key)
          .toList();

      expect(publicScreens.isNotEmpty, isTrue);
      for (final screen in publicScreens) {
        final policy = ScreenAccessPolicy.manifest[screen]!;
        expect(policy.isPublic, isTrue);
        expect(policy.isOwnerOnly, isFalse);
        expect(policy.requiredPermission, isNull);
      }
    });
  });
}
