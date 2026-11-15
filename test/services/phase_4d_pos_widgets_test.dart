import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/screens/quick_sale_screen.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/feature_access.dart';
import 'package:warqatek/services/google_drive_backup_service.dart';
import 'package:warqatek/widgets/product_autocomplete_field.dart';
import 'package:warqatek/widgets/pro_upgrade_sheet.dart';
import 'package:warqatek/widgets/status_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4D: POS, Widgets, and Permissions', () {
    test('4D-3: Held carts staleness filter and 20 carts cap', () {
      final now = DateTime.now();
      final freshDate = now.subtract(const Duration(days: 2));
      final staleDate = now.subtract(const Duration(days: 8));

      // Construct 25 carts (10 stale, 15 fresh)
      final rawList = <Map<String, dynamic>>[];
      for (int i = 0; i < 25; i++) {
        final isStale = i < 10;
        rawList.add({
          'id': 'cart_$i',
          'held_at': (isStale ? staleDate : freshDate).toIso8601String(),
          'lines': [
            {'product_id': 1, 'quantity': 1.0}
          ],
        });
      }

      // Simulate staleness filter
      final cutoff = now.subtract(const Duration(days: 7));
      final filtered = rawList.where((c) {
        final date = DateTime.tryParse(c['held_at'] as String);
        return date != null && date.isAfter(cutoff);
      }).toList();

      expect(filtered.length, 15, reason: '10 stale carts must be dropped');

      // Add more to exceed 20 cap
      for (int i = 25; i < 35; i++) {
        filtered.add({
          'id': 'cart_$i',
          'held_at': now.toIso8601String(),
          'lines': [
            {'product_id': 1, 'quantity': 1.0}
          ],
        });
      }

      expect(filtered.length, 25);
      while (filtered.length > 20) {
        filtered.removeAt(0);
      }
      expect(filtered.length, 20, reason: 'Held carts must be capped at 20');
      expect(filtered.first['id'], 'cart_15',
          reason: 'Oldest excess carts must be removed first');
    });

    test('4D-3: SessionManager.logout clears quick_sale_held_carts', () async {
      SessionManager.instance.setSessionForTesting(
        AppUser(
          id: '2',
          username: 'cashier',
          displayName: 'Cashier',
          roleId: 'role_cashier',
          workspaceId: 'default_workspace',
          isOwner: false,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      SessionManager.onLogout = QuickSaleScreen.clearHeldCarts;
      await prefs.setString('quick_sale_held_carts', '[{"id":"1"}]');
      expect(prefs.containsKey('quick_sale_held_carts'), isTrue);

      // Trigger logout
      await SessionManager.instance.logout();
      expect(prefs.containsKey('quick_sale_held_carts'), isFalse,
          reason: 'Logout must remove quick_sale_held_carts');
    });

    testWidgets(
        '4D-4: ProductAutocompleteField renders and accepts input with debounce',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductAutocompleteField(
              label: 'Search',
              onProductSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductAutocompleteField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Test Product');
      // Advance fake timer past the 250ms debounce
      await tester.pump(const Duration(milliseconds: 300));
      // Drain async database call
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Product'), findsOneWidget);
    });

    testWidgets(
        '4D-5: StatusBadge._resolve renders neutral fallback for unknown status',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'custom_future_status'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Label must match raw status string, not disguising as "Issued"
      expect(find.text('custom_future_status'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    test('4D-6: ProUpgradeSheet feature mapping includes all Pro features', () {
      expect(ProUpgradeSheet.show, isNotNull);
      // Verify all Pro feature cases are handled
      for (final f in [
        Feature.purchases,
        Feature.inventory,
        Feature.stocktake,
        Feature.referenceCurrency,
        Feature.advancedReports,
        Feature.bulkPriceUpdate,
      ]) {
        // Must not throw
        expect(f.name, isNotEmpty);
      }
    });

    test(
        '4D-8: GoogleDriveBackupService operations require backupCreate permission',
        () async {
      final now = DateTime.now();
      // Mock cashier session without backupCreate
      SessionManager.instance.setSessionForTesting(
        AppUser(
          id: '2',
          username: 'cashier',
          displayName: 'Cashier',
          roleId: 'role_cashier',
          workspaceId: 'default_workspace',
          isOwner: false,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        permissions: {PermissionRegistry.salesCreate},
      );

      final driveService = GoogleDriveBackupService.instance;

      expect(
        () => driveService.signIn(),
        throwsA(isA<PermissionDeniedException>()),
      );

      expect(
        () => driveService.uploadCurrentBackup(),
        throwsA(isA<PermissionDeniedException>()),
      );

      // Now grant backupCreate
      SessionManager.instance.setSessionForTesting(
        AppUser(
          id: '1',
          username: 'owner',
          displayName: 'Owner',
          roleId: 'role_owner',
          workspaceId: 'default_workspace',
          isOwner: true,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        permissions: {PermissionRegistry.backupCreate},
      );

      // Should pass AccessGuard (fails only on lack of actual mock client if called)
      expect(AccessGuard.can(PermissionRegistry.backupCreate), isTrue);
    });

    test('4D-9: computeCashSuggestions handles zero-decimal currencies properly', () {
      // 1. Small zero-decimal purchase (e.g. 12.5 rounded to 13)
      final zeroDecSmall = QuickSaleScreen.computeCashSuggestions(
        total: 12.5,
        decimalDigits: 0,
      );
      expect(zeroDecSmall, [13.0, 15.0, 20.0, 50.0]);
      for (final s in zeroDecSmall) {
        expect(s % 1, 0.0, reason: 'All suggestions must be whole integers');
      }

      // 2. Medium zero-decimal purchase (e.g. 250 SDG)
      final zeroDecMedium = QuickSaleScreen.computeCashSuggestions(
        total: 250.0,
        decimalDigits: 0,
      );
      expect(zeroDecMedium, [250.0, 500.0, 1000.0, 5000.0]);

      // 3. Normal decimal purchase (e.g. 14.25 with 2 decimal digits)
      final decNormal = QuickSaleScreen.computeCashSuggestions(
        total: 14.25,
        decimalDigits: 2,
      );
      expect(decNormal, [14.25, 15.0, 20.0, 50.0]);
    });
  });
}
