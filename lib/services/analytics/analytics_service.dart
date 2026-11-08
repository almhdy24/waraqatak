import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:almhdy_analytics/almhdy_analytics.dart' hide SessionManager;
import '../../core/constants/app_constants.dart';
import '../access/session_manager.dart';

/// Strictly allowlisted analytics events for Waraqatak.
enum AnalyticsEvent {
  appOpened('app_opened'),
  screenViewed('screen_viewed'),
  documentCreated('document_created'),
  documentCancelled('document_cancelled'),
  paymentRecorded('payment_recorded'),
  productSaved('product_saved'),
  contactSaved('contact_saved'),
  stocktakeFinalized('stocktake_finalized'),
  reportOpened('report_opened'),
  pdfShared('pdf_shared'),
  csvExported('csv_exported'),
  csvImported('csv_imported'),
  backupCreated('backup_created'),
  backupRestored('backup_restored'),
  paywallViewed('paywall_viewed'),
  activationStarted('activation_started'),
  activationResult('activation_result'),
  multiUserEnabled('multi_user_enabled'),
  migrationResult('migration_result'),
  errorCaught('error_caught');

  final String eventName;
  const AnalyticsEvent(this.eventName);
}

/// Abstract sink interface enabling decoupled testing and SDK isolation.
abstract class AnalyticsSink {
  Future<void> initialize({
    required String projectKey,
    String? appVersion,
    String? storagePath,
    bool debug = false,
  });

  void track(String event, {Map<String, dynamic>? properties});

  Future<void> optOut();

  Future<void> optIn();

  void dispose();
}

/// Default real sink wrapping AlmHdyAnalytics.
class AlmHdyAnalyticsSink implements AnalyticsSink {
  @override
  Future<void> initialize({
    required String projectKey,
    String? appVersion,
    String? storagePath,
    bool debug = false,
  }) async {
    await AlmHdyAnalytics.instance.initialize(
      projectKey: projectKey,
      appVersion: appVersion,
      storagePath: storagePath,
      debug: debug,
    );
  }

  @override
  void track(String event, {Map<String, dynamic>? properties}) {
    AlmHdyAnalytics.instance.track(event, properties: properties);
  }

  @override
  Future<void> optOut() async {
    await AlmHdyAnalytics.instance.optOut();
  }

  @override
  Future<void> optIn() async {
    await AlmHdyAnalytics.instance.optIn();
  }

  @override
  void dispose() {
    AlmHdyAnalytics.instance.dispose();
  }
}

/// Core Analytics Service providing allowlist validation, consent persistence,
/// offline safety, and fire-and-forget execution.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();

  AnalyticsService._internal();

  static const String _kConsentKey = 'analytics_enabled';
  static const String _kPendingMigrationFromKey = 'analytics_pending_mig_from';
  static const String _kPendingMigrationToKey = 'analytics_pending_mig_to';
  static const String _kPendingMigrationOkKey = 'analytics_pending_mig_ok';

  AnalyticsSink _sink = AlmHdyAnalyticsSink();
  bool _isEnabled = true;
  bool _isInitialized = false;
  String? _testProjectKey;

  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;

  // --- Allowed property values sets ---
  static const Set<String> _allowedLanguages = {'ar', 'en'};
  static const Set<String> _allowedThemes = {'light', 'dark', 'system'};
  static const Set<String> _allowedDocTypes = {
    'invoice',
    'purchase',
    'quotation',
    'receipt',
    'expense',
    'custom',
  };
  static const Set<String> _allowedItemBuckets = {'1', '2-5', '6-20', '21+'};
  static const Set<String> _allowedPaymentMethods = {
    'cash',
    'bank',
    'mobile',
    'other',
  };
  static const Set<String> _allowedContactKinds = {'customer', 'supplier'};
  static const Set<String> _allowedReports = {
    'sales',
    'products',
    'inventory',
    'advanced_inventory',
    'purchases',
    'accounting',
    'statement',
    'tax',
  };
  static const Set<String> _allowedPdfKinds = {
    'document',
    'report',
    'statement',
  };
  static const Set<String> _allowedCsvKinds = {'products', 'other'};
  static const Set<String> _allowedBackupDests = {
    'local',
    'drive',
    'user_chosen',
  };
  static const Set<String> _allowedPaywallFeatures = {
    'multi_user',
    'cloud_backup',
    'advanced_reports',
    'bulk_pricing',
    'general',
  };
  static const Set<String> _allowedActivationReasons = {
    'success',
    'network_error',
    'invalid_key',
    'expired',
    'device_limit',
    'revoked',
    'unknown',
  };
  static const Set<String> _allowedUserBuckets = {'1', '2-3', '4-10', '11+'};
  static const Set<String> _allowedErrorAreas = {
    'backup',
    'restore',
    'activation',
    'export',
    'sync',
    'migration',
  };
  static const Set<String> _allowedErrorKind = {
    'network',
    'io',
    'format',
    'crypto',
    'timeout',
    'state',
    'unknown',
  };
  static const Set<String> _allowedScreens = {
    'home',
    'invoices',
    'products',
    'customers',
    'suppliers',
    'reports',
    'settings',
    'sales_report',
    'product_report',
    'inventory_report',
    'advanced_inventory',
    'purchases_report',
    'accounting',
    'statement',
    'roles',
    'users',
    'audit_trail',
    'license',
    'backup',
    'database_diagnostic',
  };

  static const Set<String> _forbiddenKeys = {
    'amount',
    'price',
    'cost',
    'total',
    'quantity',
    'qty',
    'product_name',
    'barcode',
    'category',
    'customer_name',
    'supplier_name',
    'name',
    'phone',
    'mobile',
    'doc_number',
    'invoice_number',
    'path',
    'file',
    'message',
    'stack',
    'stack_trace',
    'license',
    'license_key',
    'key',
    'user',
    'username',
    'password',
    'user_id',
    'actor',
    'details',
  };

  /// Discretizes item counts into safe privacy-preserving buckets.
  static String itemCountBucket(int count) {
    if (count <= 1) return '1';
    if (count <= 5) return '2-5';
    if (count <= 20) return '6-20';
    return '21+';
  }

  /// Discretizes user counts into safe privacy-preserving buckets.
  static String userCountBucket(int count) {
    if (count <= 1) return '1';
    if (count <= 3) return '2-3';
    if (count <= 10) return '4-10';
    return '11+';
  }

  /// Sets custom sink for unit/integration testing.
  @visibleForTesting
  void setSinkForTesting(AnalyticsSink sink) {
    _sink = sink;
  }

  /// Sets mock project key for testing.
  @visibleForTesting
  void setProjectKeyForTesting(String? key) {
    _testProjectKey = key;
  }

  /// Resets internal state for unit tests.
  @visibleForTesting
  void resetForTesting() {
    _isEnabled = true;
    _isInitialized = false;
    _testProjectKey = null;
    _sink = AlmHdyAnalyticsSink();
  }

  /// Initializes analytics in a safe, unawaited, non-blocking manner.
  Future<void> initialize({
    String? storagePath,
    bool forceEnable = false,
  }) async {
    try {
      // 1. Load persisted consent
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_kConsentKey) ?? true;

      if (!_isEnabled) {
        _isInitialized = false;
        return;
      }

      // 2. Read project key from dart-define (or testing override)
      final key =
          _testProjectKey ??
          const String.fromEnvironment('ALMHDY_ANALYTICS_KEY');

      // If empty, analytics is disabled (no network, no tracking)
      if (key.isEmpty) {
        _isInitialized = false;
        return;
      }

      // In debug mode, require explicit define/key
      if (kDebugMode &&
          !forceEnable &&
          _testProjectKey == null &&
          key.isEmpty) {
        _isInitialized = false;
        return;
      }

      // 3. Resolve persistent storage path if not provided
      String? resolvedStoragePath = storagePath;
      if (resolvedStoragePath == null) {
        try {
          final dir = await getApplicationSupportDirectory();
          resolvedStoragePath = '${dir.path}/almhdy_analytics_buffer.json';
        } catch (_) {
          // Fallback to local default if path_provider fails
        }
      }

      // 4. Initialize sink
      await _sink.initialize(
        projectKey: key,
        appVersion: AppConstants.appVersion,
        storagePath: resolvedStoragePath,
        debug: kDebugMode,
      );

      _isInitialized = true;

      // 5. Check and dispatch pending migration event if any exists
      await _dispatchPendingMigrationIfAny(prefs);
    } catch (_) {
      // Silent error boundary: failure must never impact app startup
      _isInitialized = false;
    }
  }

  /// Sets user consent. If opting out, synchronizes with backend opt-out.
  Future<void> setEnabled(bool enabled) async {
    try {
      _isEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kConsentKey, enabled);

      if (!enabled) {
        await _sink.optOut();
      } else {
        await _sink.optIn();
      }
    } catch (_) {
      // Silent error boundary
    }
  }

  /// Records database migration result to SharedPreferences for dispatch on next init.
  /// (Called from startup without touching database or in-flight transactions).
  static Future<void> recordMigrationResult({
    required int fromVersion,
    required int toVersion,
    required bool ok,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPendingMigrationFromKey, fromVersion);
      await prefs.setInt(_kPendingMigrationToKey, toVersion);
      await prefs.setBool(_kPendingMigrationOkKey, ok);
    } catch (_) {}
  }

  Future<void> _dispatchPendingMigrationIfAny(SharedPreferences prefs) async {
    try {
      if (!prefs.containsKey(_kPendingMigrationFromKey)) return;

      final from = prefs.getInt(_kPendingMigrationFromKey);
      final to = prefs.getInt(_kPendingMigrationToKey);
      final ok = prefs.getBool(_kPendingMigrationOkKey) ?? true;

      await prefs.remove(_kPendingMigrationFromKey);
      await prefs.remove(_kPendingMigrationToKey);
      await prefs.remove(_kPendingMigrationOkKey);

      if (from != null && to != null) {
        track(AnalyticsEvent.migrationResult, {
          'from_version': from,
          'to_version': to,
          'ok': ok,
        });
      }
    } catch (_) {}
  }

  /// Tracks an allowlisted event with strict validation.
  /// Fire-and-forget; never awaited by callers.
  void track(AnalyticsEvent event, [Map<String, dynamic>? properties]) {
    if (!_isEnabled || !_isInitialized) return;

    // Drop all events if multi-user session is currently locked
    if (SessionManager.instance.isLocked) return;

    try {
      final sanitized = _validateAndSanitize(event, properties);
      _sink.track(event.eventName, properties: sanitized);
    } catch (e) {
      if (kDebugMode) {
        // Re-throw in debug/tests to catch invalid event construction early
        rethrow;
      }
      // Silently swallowed in production
    }
  }

  Map<String, dynamic>? _validateAndSanitize(
    AnalyticsEvent event,
    Map<String, dynamic>? props,
  ) {
    if (props == null || props.isEmpty) {
      if (_hasRequiredProperties(event)) {
        throw ArgumentError('Event ${event.eventName} requires properties.');
      }
      return null;
    }

    final sanitized = <String, dynamic>{};

    for (final entry in props.entries) {
      final key = entry.key.trim().toLowerCase();
      final val = entry.value;

      if (_forbiddenKeys.contains(key)) {
        throw ArgumentError(
          'Forbidden property key "$key" in ${event.eventName}.',
        );
      }

      _validateKeyAndValue(event, key, val);
      sanitized[key] = val;
    }

    return sanitized;
  }

  bool _hasRequiredProperties(AnalyticsEvent event) {
    switch (event) {
      case AnalyticsEvent.appOpened:
      case AnalyticsEvent.screenViewed:
      case AnalyticsEvent.documentCreated:
      case AnalyticsEvent.documentCancelled:
      case AnalyticsEvent.paymentRecorded:
      case AnalyticsEvent.productSaved:
      case AnalyticsEvent.contactSaved:
      case AnalyticsEvent.reportOpened:
      case AnalyticsEvent.pdfShared:
      case AnalyticsEvent.csvExported:
      case AnalyticsEvent.csvImported:
      case AnalyticsEvent.backupCreated:
      case AnalyticsEvent.backupRestored:
      case AnalyticsEvent.paywallViewed:
      case AnalyticsEvent.activationResult:
      case AnalyticsEvent.multiUserEnabled:
      case AnalyticsEvent.migrationResult:
      case AnalyticsEvent.errorCaught:
        return true;
      case AnalyticsEvent.stocktakeFinalized:
      case AnalyticsEvent.activationStarted:
        return false;
    }
  }

  void _validateKeyAndValue(AnalyticsEvent event, String key, dynamic val) {
    switch (event) {
      case AnalyticsEvent.appOpened:
        if (key == 'language' && _allowedLanguages.contains(val)) return;
        if (key == 'theme' && _allowedThemes.contains(val)) return;
        if (key == 'multi_user' && val is bool) return;
        break;

      case AnalyticsEvent.screenViewed:
        if (key == 'screen' && _allowedScreens.contains(val)) return;
        break;

      case AnalyticsEvent.documentCreated:
        if (key == 'type' && _allowedDocTypes.contains(val)) return;
        if (key == 'has_payment' && val is bool) return;
        if (key == 'item_count_bucket' && _allowedItemBuckets.contains(val)) {
          return;
        }
        break;

      case AnalyticsEvent.documentCancelled:
        if (key == 'type' && _allowedDocTypes.contains(val)) return;
        break;

      case AnalyticsEvent.paymentRecorded:
        if (key == 'method_category' && _allowedPaymentMethods.contains(val)) {
          return;
        }
        break;

      case AnalyticsEvent.productSaved:
        if (key == 'is_new' && val is bool) return;
        break;

      case AnalyticsEvent.contactSaved:
        if (key == 'kind' && _allowedContactKinds.contains(val)) return;
        if (key == 'is_new' && val is bool) return;
        break;

      case AnalyticsEvent.stocktakeFinalized:
        throw ArgumentError('stocktake_finalized accepts no properties.');

      case AnalyticsEvent.reportOpened:
        if (key == 'report' && _allowedReports.contains(val)) return;
        break;

      case AnalyticsEvent.pdfShared:
        if (key == 'kind' && _allowedPdfKinds.contains(val)) return;
        break;

      case AnalyticsEvent.csvExported:
        if (key == 'kind' && _allowedCsvKinds.contains(val)) return;
        break;

      case AnalyticsEvent.csvImported:
        if (key == 'kind' && _allowedCsvKinds.contains(val)) return;
        if (key == 'ok' && val is bool) return;
        break;

      case AnalyticsEvent.backupCreated:
        if (key == 'destination' && _allowedBackupDests.contains(val)) return;
        if (key == 'encrypted' && val is bool) return;
        break;

      case AnalyticsEvent.backupRestored:
        if (key == 'ok' && val is bool) return;
        break;

      case AnalyticsEvent.paywallViewed:
        if (key == 'feature' && _allowedPaywallFeatures.contains(val)) return;
        break;

      case AnalyticsEvent.activationStarted:
        throw ArgumentError('activation_started accepts no properties.');

      case AnalyticsEvent.activationResult:
        if (key == 'ok' && val is bool) return;
        if (key == 'reason' && _allowedActivationReasons.contains(val)) return;
        break;

      case AnalyticsEvent.multiUserEnabled:
        if (key == 'user_count_bucket' && _allowedUserBuckets.contains(val)) {
          return;
        }
        break;

      case AnalyticsEvent.migrationResult:
        if (key == 'from_version' && val is int) return;
        if (key == 'to_version' && val is int) return;
        if (key == 'ok' && val is bool) return;
        break;

      case AnalyticsEvent.errorCaught:
        if (key == 'area' && _allowedErrorAreas.contains(val)) return;
        if (key == 'kind' && _allowedErrorKind.contains(val)) return;
        break;
    }

    throw ArgumentError(
      'Invalid property "$key: $val" for event "${event.eventName}".',
    );
  }
}
