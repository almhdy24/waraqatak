import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_notification.dart';
import 'package:warqatek/services/app_ops_service.dart';
import 'package:warqatek/services/license_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('notif_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('cached_notifications');
    } catch (_) {}
  });

  group('AppNotification Model & Invariants', () {
    test('AppNotification.fromJson parses targeting fields and dismissibility', () {
      final json = {
        'id': 42,
        'title': 'ميزة جديدة',
        'body': 'تفاصيل التحديث الجديد',
        'category': 'update',
        'action': 'open_about',
        'language': 'ar',
        'severity': 'info',
        'dismissible': true,
        'priority': 5,
        'published_at': '2026-11-01T00:00:00.000Z',
      };

      final notif = AppNotification.fromJson(json);
      expect(notif.serverId, 42);
      expect(notif.title, 'ميزة جديدة');
      expect(notif.actionUrl, 'open_about');
      expect(notif.isDismissible, isTrue);

      final criticalJson = {
        'id': 99,
        'title': 'تنبيه أمني عاجل',
        'body': 'يرجى مراجعة حالة الترخيص',
        'category': 'critical',
        'action': 'open_license',
        'dismissible': true, // even if payload says true, critical category MUST be non-dismissible
      };

      final criticalNotif = AppNotification.fromJson(criticalJson);
      expect(criticalNotif.isDismissible, isFalse);
    });

    test('toDbMap and fromDb preserve SQLite schema compatibility', () {
      final notif = AppNotification(
        serverId: 10,
        title: 'إعلان',
        body: 'محتوى الإعلان',
        category: 'announcement',
        actionUrl: 'open_store_listing',
        publishedAt: DateTime.parse('2026-11-01T12:00:00Z'),
        syncedAt: DateTime.parse('2026-11-01T12:05:00Z'),
        dismissible: true,
      );

      final dbMap = notif.toDbMap();
      expect(dbMap['server_id'], 10);
      expect(dbMap['action_url'], 'open_store_listing');
      expect(dbMap['is_read'], 0);

      final fromDb = AppNotification.fromDb(dbMap);
      expect(fromDb.serverId, 10);
      expect(fromDb.actionUrl, 'open_store_listing');
      expect(fromDb.isDismissible, isTrue);
    });
  });

  group('Tombstones & AppOpsService', () {
    test('Tombstones add, remove, and reconcile with active server IDs', () async {
      final ops = AppOpsService.instance;

      expect(await ops.getTombstones(), isEmpty);

      await ops.addTombstone(101);
      await ops.addTombstone(102);
      await ops.addTombstone(103);

      var tombstones = await ops.getTombstones();
      expect(tombstones, containsAll([101, 102, 103]));

      // Restore / undo removes tombstone
      await ops.removeTombstone(102);
      tombstones = await ops.getTombstones();
      expect(tombstones, contains(101));
      expect(tombstones, isNot(contains(102)));
      expect(tombstones, contains(103));

      // Reconcile with active server IDs (server deleted 103, so 103 should be pruned)
      await ops.reconcileTombstones([101, 105, 106]);
      tombstones = await ops.getTombstones();
      expect(tombstones, contains(101));
      expect(tombstones, isNot(contains(103)));
    });
  });

  group('DatabaseHelper Data-Only Deletions', () {
    test('deleteCachedNotification and deleteAllCachedNotifications preserving critical alerts', () async {
      final db = DatabaseHelper.instance;

      final n1 = AppNotification(
        serverId: 1,
        title: 'إعلان عادي',
        body: 'نص عادي',
        category: 'announcement',
        publishedAt: DateTime.now(),
        syncedAt: DateTime.now(),
      );

      final n2 = AppNotification(
        serverId: 2,
        title: 'تنبيه أمني حرج',
        body: 'نص حرج غير قابل للحذف',
        category: 'critical',
        publishedAt: DateTime.now(),
        syncedAt: DateTime.now(),
      );

      final n3 = AppNotification(
        serverId: 3,
        title: 'تحديث تطبيق',
        body: 'نص تحديث',
        category: 'update',
        publishedAt: DateTime.now(),
        syncedAt: DateTime.now(),
      );

      await db.upsertCachedNotification(n1);
      await db.upsertCachedNotification(n2);
      await db.upsertCachedNotification(n3);

      var cached = await db.getCachedNotifications();
      expect(cached.length, 3);

      // Single delete
      final deletedCount = await db.deleteCachedNotification(1);
      expect(deletedCount, 1);

      cached = await db.getCachedNotifications();
      expect(cached.map((n) => n.serverId), containsAll([2, 3]));
      expect(cached.map((n) => n.serverId), isNot(contains(1)));

      // Bulk delete preserving critical
      await db.deleteAllCachedNotifications(preserveCritical: true);
      cached = await db.getCachedNotifications();

      expect(cached.length, 1);
      expect(cached.first.serverId, 2);
      expect(cached.first.category, 'critical');
    });
  });

  group('LicenseNotificationService Stable Dedupe Keys', () {
    test('Uses deterministic negative IDs preventing collisions', () {
      expect(LicenseNotificationService.idTrialActive, -101);
      expect(LicenseNotificationService.idTrialExpiring, -102);
      expect(LicenseNotificationService.idTrialExpired, -103);
      expect(LicenseNotificationService.idLicenseActive, -104);
      expect(LicenseNotificationService.idLicenseExpiring, -105);
      expect(LicenseNotificationService.idLicenseExpired, -106);
      expect(LicenseNotificationService.idLicenseRevoked, -107);
      expect(LicenseNotificationService.idServerNotice, -108);
    });
  });
}
