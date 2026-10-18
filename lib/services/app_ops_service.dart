import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/app_notification.dart';
import '../models/entitlement.dart';
import 'app_diagnostics_service.dart';
import 'license_service.dart';

/// Service managing remote configuration and in-app announcements/notifications.
///
/// Fully self-hosted, offline-first:
/// - Configuration and inbox are stored in local SQLite & SharedPreferences.
/// - Network errors, timeouts, or server unavailability NEVER block application flow.
/// - Read receipts are queued locally and synchronized idempotently.
class AppOpsService {
  AppOpsService._();
  static final AppOpsService instance = AppOpsService._();

  static const String appSlug = 'com.elmahdi.waraqatak';
  static const String apiBaseUrl = 'https://api.almhdy24.com';
  static const Duration requestTimeout = Duration(seconds: 10);

  // Storage keys
  static const String _kRemoteConfig = 'ops_remote_config';
  static const String _kPendingReads = 'ops_pending_read_ids';

  // Recognized allowlisted remote configuration keys
  static const Set<String> allowedConfigKeys = {
    'min_supported_version',
    'maintenance_mode',
    'announcements_poll_interval_hours',
    'support_whatsapp',
    'enable_diagnostics',
  };

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  Map<String, dynamic> _configCache = {};
  bool _initialized = false;
  DateTime? _lastInboxSyncTime;
  DateTime? _lastConfigSyncTime;
  static const Duration minInboxSyncInterval = Duration(minutes: 15);
  static const Duration minConfigSyncInterval = Duration(hours: 1);

  /// Initialize service, load cached config and unread counter.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRemoteConfig);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _configCache = decoded;
        }
      }
    } catch (_) {}

    await refreshUnreadCount();

    // Trigger initial background sync
    unawaited(syncAll());
  }

  /// Refreshes the unread count from the local SQLite database.
  Future<void> refreshUnreadCount() async {
    try {
      final count = await DatabaseHelper.instance.getUnreadNotificationCount();
      unreadCount.value = count;
    } catch (_) {}
  }

  // ============================================================
  // REMOTE CONFIGURATION
  // ============================================================

  /// Retrieve a string setting from the local cached configuration.
  String? getString(String key, {String? defaultValue}) {
    final val = _configCache[key];
    if (val != null) return val.toString();
    return defaultValue;
  }

  /// Retrieve an integer setting from the local cached configuration.
  int? getInt(String key, {int? defaultValue}) {
    final val = _configCache[key];
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultValue;
    return defaultValue;
  }

  /// Retrieve a boolean setting from the local cached configuration.
  bool getBool(String key, {bool defaultValue = false}) {
    final val = _configCache[key];
    if (val is bool) return val;
    if (val is String) {
      final lower = val.toLowerCase().trim();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    if (val is num) return val != 0;
    return defaultValue;
  }

  /// Synchronize remote public settings from API backend.
  /// Set [force] to true to bypass client-side sync throttling.
  Future<void> syncRemoteConfig({bool force = false}) async {
    if (!force && _lastConfigSyncTime != null) {
      if (DateTime.now().difference(_lastConfigSyncTime!) <
          minConfigSyncInterval) {
        return;
      }
    }
    _lastConfigSyncTime = DateTime.now();

    HttpClient? client;
    try {
      final uri = Uri.parse('$apiBaseUrl/api/v1/ops/config?product=$appSlug');
      client = HttpClient()..connectionTimeout = requestTimeout;

      final req = await client.getUrl(uri).timeout(requestTimeout);
      req.headers.set('Accept', 'application/json');

      final res = await req.close().timeout(requestTimeout);
      if (res.statusCode == 200) {
        final bodyStr = await res.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        if (json is Map<String, dynamic> && json['success'] == true) {
          final data = json['data'];
          if (data is Map<String, dynamic> && data['settings'] is Map) {
            final rawSettings = data['settings'] as Map;
            final Map<String, dynamic> filtered = {};
            for (final entry in rawSettings.entries) {
              final k = entry.key.toString();
              if (allowedConfigKeys.contains(k)) {
                filtered[k] = entry.value;
              }
            }
            _configCache = filtered;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kRemoteConfig, jsonEncode(filtered));
          }
        }
      }
    } catch (_) {
      // Offline fallback: keep existing cache silently
    } finally {
      client?.close();
    }
  }

  // ============================================================
  // ANNOUNCEMENTS & IN-APP INBOX
  // ============================================================

  /// Returns cached notifications from the local database.
  Future<List<AppNotification>> getNotifications() async {
    try {
      final all = await DatabaseHelper.instance.getCachedNotifications();
      return all.where((n) => !n.isExpired).toList();
    } catch (_) {
      return [];
    }
  }

  /// Marks an announcement as read locally and queues the read receipt for sync.
  Future<void> markAsRead(int serverId) async {
    try {
      final now = DateTime.now();
      await DatabaseHelper.instance.markNotificationAsRead(serverId, now);
      await _enqueuePendingRead(serverId);
      await refreshUnreadCount();

      // Attempt to immediately acknowledge to server
      unawaited(syncInbox(force: true));
    } catch (_) {}
  }

  /// Synchronize in-app inbox and send pending read receipts.
  /// Set [force] to true to bypass client-side sync throttling (e.g. pull-to-refresh or immediate mark-as-read).
  Future<void> syncInbox({bool force = false}) async {
    if (!force && _lastInboxSyncTime != null) {
      if (DateTime.now().difference(_lastInboxSyncTime!) <
          minInboxSyncInterval) {
        return;
      }
    }
    _lastInboxSyncTime = DateTime.now();

    HttpClient? client;
    try {
      final machineId = await LicenseService.instance.getOrCreateDeviceId();
      final entitlement = await LicenseService.instance.checkEntitlement();
      final licenseKey = await LicenseService.instance.licenseKey;
      final pendingReads = await _getPendingReads();

      String clientStatus = 'all';
      if (entitlement.status == EntitlementStatus.licensed) {
        clientStatus = 'active_license';
      } else if (entitlement.status == EntitlementStatus.trialActive) {
        clientStatus = 'trial';
      } else if (entitlement.status == EntitlementStatus.licenseExpired ||
          entitlement.status == EntitlementStatus.trialExpired) {
        clientStatus = 'expired_license';
      }

      final payload = <String, dynamic>{
        'product': appSlug,
        'machine_id': machineId,
        'app_version': '1.1.3',
        'client_reported_status': clientStatus,
      };

      if (licenseKey != null && licenseKey.isNotEmpty) {
        payload['license_key'] = licenseKey;
      }

      if (pendingReads.isNotEmpty) {
        payload['mark_read'] = pendingReads.take(50).toList();
      }

      final uri = Uri.parse('$apiBaseUrl/api/v1/ops/inbox/sync');
      client = HttpClient()..connectionTimeout = requestTimeout;

      final req = await client.postUrl(uri).timeout(requestTimeout);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Accept', 'application/json');
      req.write(jsonEncode(payload));

      final res = await req.close().timeout(requestTimeout);
      if (res.statusCode == 200) {
        final bodyStr = await res.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        if (json is Map<String, dynamic> && json['success'] == true) {
          // Clear acknowledged reads
          if (pendingReads.isNotEmpty) {
            await _clearPendingReads(pendingReads.take(50).toList());
          }

          final data = json['data'];
          if (data is Map<String, dynamic> && data['notifications'] is List) {
            final list = data['notifications'] as List;
            for (final item in list) {
              if (item is Map<String, dynamic>) {
                final notif = AppNotification.fromJson(item);
                await DatabaseHelper.instance.upsertCachedNotification(notif);
              }
            }
          }
          await refreshUnreadCount();
        }
      }
    } catch (_) {
      // Offline fallback: keep existing cache
    } finally {
      client?.close();
    }
  }

  /// Synchronize remote configuration, announcements, and consented diagnostics.
  Future<void> syncAll({bool force = false}) async {
    await Future.wait([
      syncRemoteConfig(force: force),
      syncInbox(force: force),
      AppDiagnosticsService.instance.syncDiagnostics(force: force),
    ]);
  }

  // ── Pending Reads Queue ────────────────────────────────────────────────────

  Future<List<int>> _getPendingReads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingReads);
      if (list == null) return [];
      return list
          .map((s) => int.tryParse(s) ?? 0)
          .where((id) => id > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _enqueuePendingRead(int serverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await _getPendingReads();
      if (!current.contains(serverId)) {
        current.add(serverId);
        await prefs.setStringList(
          _kPendingReads,
          current.map((id) => id.toString()).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _clearPendingReads(List<int> acknowledged) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await _getPendingReads();
      current.removeWhere((id) => acknowledged.contains(id));
      await prefs.setStringList(
        _kPendingReads,
        current.map((id) => id.toString()).toList(),
      );
    } catch (_) {}
  }
}
