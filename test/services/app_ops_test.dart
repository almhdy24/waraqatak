import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/app_notification.dart';
import 'package:warqatek/services/app_ops_service.dart';

void main() {
  group('AppNotification Model Tests', () {
    test('parses from API JSON payload correctly', () {
      final json = {
        'id': 42,
        'title': 'Test Announcement',
        'body': 'This is a test notification body.',
        'category': 'announcement',
        'action_url': 'https://almhdy24.com/products/waraqatak/privacy.html',
        'target_audience': 'all',
        'published_at': '2026-10-18T10:00:00.000Z',
        'expires_at': '2026-10-25T10:00:00.000Z',
        'is_read': false,
        'read_at': null,
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.serverId, equals(42));
      expect(notif.title, equals('Test Announcement'));
      expect(notif.body, equals('This is a test notification body.'));
      expect(notif.category, equals('announcement'));
      expect(
        notif.actionUrl,
        equals('https://almhdy24.com/products/waraqatak/privacy.html'),
      );
      expect(notif.targetAudience, equals('all'));
      expect(notif.isRead, isFalse);
      expect(notif.readAt, isNull);
    });

    test('serializes to and from SQLite map cleanly', () {
      final notif = AppNotification(
        id: 1,
        serverId: 101,
        title: 'New Update',
        body: 'Version 2 is available.',
        category: 'update',
        actionUrl: null,
        targetAudience: 'trial',
        publishedAt: DateTime.parse('2026-10-18 12:00:00'),
        expiresAt: DateTime.parse('2026-12-31 23:59:59'),
        isRead: true,
        readAt: DateTime.parse('2026-10-18 12:30:00'),
        syncedAt: DateTime.parse('2026-10-18 12:30:00'),
      );

      final map = notif.toDbMap();
      expect(map['server_id'], equals(101));
      expect(map['is_read'], equals(1));
      expect(map['title'], equals('New Update'));

      final restored = AppNotification.fromDb(map);
      expect(restored.serverId, equals(101));
      expect(restored.isRead, isTrue);
      expect(restored.category, equals('update'));
    });

    test('isExpired detects expired and unexpired dates', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final future = DateTime.now().add(const Duration(days: 2));

      final expired = AppNotification(
        serverId: 1,
        title: 'Expired',
        body: 'Expired',
        category: 'tips',
        publishedAt: past,
        expiresAt: past,
        syncedAt: DateTime.now(),
      );

      final active = AppNotification(
        serverId: 2,
        title: 'Active',
        body: 'Active',
        category: 'tips',
        publishedAt: past,
        expiresAt: future,
        syncedAt: DateTime.now(),
      );

      final noExpiry = AppNotification(
        serverId: 3,
        title: 'Perpetual',
        body: 'Perpetual',
        category: 'tips',
        publishedAt: past,
        expiresAt: null,
        syncedAt: DateTime.now(),
      );

      expect(expired.isExpired, isTrue);
      expect(active.isExpired, isFalse);
      expect(noExpiry.isExpired, isFalse);
    });
  });

  group('AppOpsService Contract & Allowlist Tests', () {
    test('service constants match production architecture specifications', () {
      expect(AppOpsService.appSlug, equals('com.elmahdi.waraqatak'));
      expect(AppOpsService.apiBaseUrl, equals('https://api.almhdy24.com'));
      expect(AppOpsService.requestTimeout, equals(const Duration(seconds: 10)));
      expect(
        AppOpsService.minInboxSyncInterval,
        equals(const Duration(minutes: 15)),
      );
      expect(
        AppOpsService.minConfigSyncInterval,
        equals(const Duration(hours: 1)),
      );
    });

    test(
      'remote config allowlist strictly permits only declared operational keys',
      () {
        final allowed = AppOpsService.allowedConfigKeys;

        expect(allowed.contains('min_supported_version'), isTrue);
        expect(allowed.contains('maintenance_mode'), isTrue);
        expect(allowed.contains('announcements_poll_interval_hours'), isTrue);
        expect(allowed.contains('support_whatsapp'), isTrue);
        expect(allowed.contains('enable_diagnostics'), isTrue);

        // Dangerous or arbitrary keys must never be accepted
        expect(allowed.contains('api_base_url'), isFalse);
        expect(allowed.contains('remote_command'), isFalse);
        expect(allowed.contains('bypass_licensing'), isFalse);
        expect(allowed.contains('arbitrary_flag'), isFalse);
      },
    );

    test(
      'safe URL regex allows only approved domain and rejects foreign hosts',
      () {
        final safeRe = RegExp(
          r'^https://([a-z0-9-]+\.)*almhdy24\.com(/.*)?$',
          caseSensitive: false,
        );

        expect(
          safeRe.hasMatch(
            'https://almhdy24.com/products/waraqatak/privacy.html',
          ),
          isTrue,
        );
        expect(safeRe.hasMatch('https://api.almhdy24.com/terms'), isTrue);
        expect(safeRe.hasMatch('https://panel.almhdy24.com/help'), isTrue);

        expect(
          safeRe.hasMatch('http://almhdy24.com/insecure'),
          isFalse,
        ); // non-https
        expect(safeRe.hasMatch('https://malicious.com'), isFalse);
        expect(
          safeRe.hasMatch('https://almhdy24.com.attacker.com/phish'),
          isFalse,
        );
        expect(safeRe.hasMatch('javascript:alert(1)'), isFalse);
      },
    );
  });
}
