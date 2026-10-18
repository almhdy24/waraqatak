import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/diagnostic_report.dart';
import 'app_ops_service.dart';

/// Self-hosted, privacy-first diagnostic error reporting service.
///
/// Principles:
/// - Explicit opt-in consent only (default is opted-out).
/// - Zero external SDKs (No Firebase, No Sentry).
/// - No PII, customer information, phone numbers, or invoice data collected.
/// - Strict length caps and deep redaction before local persistence.
/// - Bounded local SQLite queue (max 50 items).
class AppDiagnosticsService {
  AppDiagnosticsService._();
  static final AppDiagnosticsService instance = AppDiagnosticsService._();

  static const String kConsentPrefKey = 'ops_diagnostic_consent_granted';
  static const String remoteConfigFlag = 'enable_diagnostics';

  // Allowed safe operation identifiers
  static const Set<String> allowedOperations = {
    'app_launch',
    'invoice_pdf_generation',
    'receipt_printing',
    'backup_export',
    'backup_restore',
    'db_migration',
    'licensing_check',
    'ops_sync',
    'ui_render',
    'unhandled_exception',
  };

  static const int maxMessageLength = 255;
  static const int maxStackTraceLength = 4000;
  static const int maxBatchReports = 10;
  static const Duration minSyncInterval = Duration(minutes: 30);

  DateTime? _lastSyncTime;
  bool _initialized = false;
  String? _cachedAppVersion;
  int _syncGeneration = 0;

  /// Initialize error hooks and diagnostic tracking.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Cache app version
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _cachedAppVersion = '1.1.2+6';
    }

    _installErrorHooks();
  }

  /// Installs global Flutter and Dart dispatcher error listeners while preserving
  /// existing handlers.
  void _installErrorHooks() {
    final originalFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Forward to original handler first
      originalFlutterOnError?.call(details);

      // Record diagnostic error silently
      recordError(
        details.exception,
        details.stack,
        operation: 'unhandled_exception',
      );
    };

    final originalPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      // Record diagnostic error silently
      recordError(error, stack, operation: 'unhandled_exception');

      // Forward to original platform dispatcher handler
      if (originalPlatformOnError != null) {
        return originalPlatformOnError(error, stack);
      }
      return true;
    };
  }

  // ============================================================
  // CONSENT CONTROLS
  // ============================================================

  /// Returns whether user has explicitly opted into diagnostic report sharing.
  /// Defaults to false (opted-out).
  Future<bool> isConsentGranted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kConsentPrefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Updates user consent state.
  /// If consent is revoked (false), immediately increments sync generation
  /// to abort any in-flight uploads and wipes any pending diagnostic reports.
  Future<void> setConsent(bool granted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kConsentPrefKey, granted);

      if (!granted) {
        _syncGeneration++;
        await DatabaseHelper.instance.clearAllDiagnosticReports();
      }
    } catch (_) {}
  }

  // ============================================================
  // RECORDING & REDACTION
  // ============================================================

  /// Records an observed application error with sanitization.
  /// Respects user consent: does nothing if opted-out.
  Future<void> recordError(
    dynamic error,
    StackTrace? stackTrace, {
    String operation = 'unhandled_exception',
  }) async {
    try {
      // Verify local user consent first
      final consent = await isConsentGranted();
      if (!consent) return;

      // Verify remote config feature flag (defaults to false until deliberately enabled)
      final remoteEnabled = AppOpsService.instance.getBool(
        remoteConfigFlag,
        defaultValue: false,
      );
      if (!remoteEnabled) return;

      final safeOp = allowedOperations.contains(operation)
          ? operation
          : 'unhandled_exception';

      final exType = sanitizeExceptionType(error.runtimeType.toString());
      final msg = sanitizeMessage(error.toString());
      final stack = sanitizeStackTrace(stackTrace?.toString());

      final report = DiagnosticReport(
        reportUuid: generateUuidV4(),
        appVersion: _cachedAppVersion ?? '1.1.1+5',
        platform: Platform.operatingSystem,
        osVersion: sanitizeOsVersion(Platform.operatingSystemVersion),
        exceptionType: exType,
        sanitizedMessage: msg,
        sanitizedStackTrace: stack,
        operation: safeOp,
        occurredAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.instance.insertDiagnosticReport(report);
    } catch (_) {
      // Silently catch all diagnostic errors to prevent disrupting business workflow
    }
  }

  // ============================================================
  // SANITIZATION HELPERS
  // ============================================================

  /// Sanitizes exception type string (max 128 chars, alphanumeric & underscores/colons).
  static String sanitizeExceptionType(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_:.]'), '').trim();
    if (cleaned.isEmpty) cleaned = 'UnknownException';
    if (cleaned.length > 128) cleaned = cleaned.substring(0, 128);
    return cleaned;
  }

  /// Sanitizes OS version string (max 64 chars).
  static String sanitizeOsVersion(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[\r\n\t]'), ' ').trim();
    if (cleaned.length > 64) cleaned = cleaned.substring(0, 64);
    return cleaned;
  }

  /// Deeply sanitizes exception message:
  /// - Strips filesystem absolute paths and content/file URIs
  /// - Strips Windows drive paths
  /// - Strips email patterns
  /// - Strips phone numbers (with optional country prefix) and numbers of 6+ digits
  /// - Strips Bearer tokens, secrets, passwords, auth keywords
  /// - Strips license key patterns (e.g. ABCD-EFGH-1234)
  /// - Strips financial currency amounts (SDG, USD, EUR, SAR, etc.)
  /// - Strips customer/client reference labels
  /// - Strips SQL query single-quoted literals
  /// - Normalizes whitespace and enforces maximum 255 characters
  static String sanitizeMessage(String raw) {
    if (raw.isEmpty) return '';

    String cleaned = raw;

    // 1. Remove Linux/Android/macOS filesystem paths & content/file URIs
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(file://|content://)?(/data/data|/storage|/home|/var|/tmp|/Users)/[^\s:;,)]+',
      ),
      '[path redacted]',
    );

    // 2. Remove Windows drive paths
    cleaned = cleaned.replaceAll(
      RegExp(r'[A-Za-z]:\\[^\s:;,)]+'),
      '[path redacted]',
    );

    // 3. Remove email addresses
    cleaned = cleaned.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[email redacted]',
    );

    // 4. Remove telephone numbers or numeric IDs with 6 or more digits
    cleaned = cleaned.replaceAll(
      RegExp(r'(\+\d{1,3}[- ]?)?\b\d{6,}\b'),
      '[number redacted]',
    );

    // 5. Remove auth tokens, keys, passwords, secrets
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(Bearer\s+[A-Za-z0-9._-]+|key=[A-Za-z0-9_-]+|token=[A-Za-z0-9_-]+|password=[^\s:;,)]+|secret=[^\s:;,)]+)',
        caseSensitive: false,
      ),
      '[secret redacted]',
    );

    // 6. Remove license key patterns (e.g. WARA-2026-LIVE-ABCD or XXXX-XXXX-XXXX)
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}(-[A-Za-z0-9]{4})?\b',
      ),
      '[license redacted]',
    );

    // 7. Remove financial amounts and currency codes
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(?:SDG|USD|EUR|SAR|AED|GBP)\s*[\d,.]+|[\d,.]+\s*(?:SDG|USD|EUR|SAR|AED|GBP|ج\.س|جنيه|ريال|درهم)',
        caseSensitive: false,
      ),
      '[amount redacted]',
    );

    // 8. Remove customer / client / vendor reference labels
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(customer|client|buyer|vendor):\s*[^\s,;()]*(?:\s+[^\s,;()]+){0,4}',
        caseSensitive: false,
      ),
      r'$1: [redacted]',
    );

    // 9. Redact single-quoted literals in database / SQL query contexts
    cleaned = cleaned.replaceAll(RegExp(r"'[^']*'"), "'[redacted]'");

    // 10. Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 11. Enforce length cap
    if (cleaned.length > maxMessageLength) {
      cleaned = cleaned.substring(0, maxMessageLength);
    }

    return cleaned;
  }

  /// Sanitizes stack trace:
  /// - Strips filesystem absolute paths while keeping package: URI references
  /// - Enforces maximum 4,000 characters
  static String sanitizeStackTrace(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';

    String cleaned = raw;

    // Remove local user directories and system absolute paths
    cleaned = cleaned.replaceAll(
      RegExp(r'(/data/data|/storage|/home|/var|/tmp|/Users)/[^\s:;,)]+/'),
      '.../',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[A-Za-z]:\\[^\s:;,)]+\\'), '...\\');

    // Enforce length cap
    if (cleaned.length > maxStackTraceLength) {
      cleaned = cleaned.substring(0, maxStackTraceLength);
    }

    return cleaned;
  }

  /// Cryptographically secure UUID v4 generator without extra dependencies.
  static String generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version to 0100 (v4)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to 10xx (RFC 4122)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int b) => b.toRadixString(16).padLeft(2, '0');

    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  // ============================================================
  // TRANSMISSION
  // ============================================================

  /// Synchronizes pending diagnostic reports to the self-hosted API.
  /// Only executes if user has consented AND remote feature flag allows it.
  /// Employs generation counters to strictly prevent race conditions with consent revocation.
  Future<void> syncDiagnostics({bool force = false}) async {
    final syncGen = _syncGeneration;

    // 1. Consent check
    if (!await isConsentGranted() || syncGen != _syncGeneration) return;

    // 2. Remote flag check (defaults to false until explicitly enabled remotely)
    final remoteEnabled = AppOpsService.instance.getBool(
      remoteConfigFlag,
      defaultValue: false,
    );
    if (!remoteEnabled) return;

    // 3. Client throttling check (max once every 30 minutes unless forced)
    if (!force && _lastSyncTime != null) {
      if (DateTime.now().difference(_lastSyncTime!) < minSyncInterval) {
        return;
      }
    }
    _lastSyncTime = DateTime.now();

    HttpClient? client;
    try {
      final pending = await DatabaseHelper.instance.getPendingDiagnosticReports(
        limit: maxBatchReports,
      );
      if (pending.isEmpty) return;

      // Double check consent and generation before preparing network payload
      if (!await isConsentGranted() || syncGen != _syncGeneration) return;

      final payload = {
        'product': AppOpsService.appSlug,
        'reports': pending.map((r) => r.toApiPayload()).toList(),
      };

      final uri = Uri.parse(
        '${AppOpsService.apiBaseUrl}/api/v1/ops/diagnostics/report',
      );
      client = HttpClient()..connectionTimeout = AppOpsService.requestTimeout;

      // Final pre-flight check right before establishing connection
      if (!await isConsentGranted() || syncGen != _syncGeneration) return;

      final req = await client
          .postUrl(uri)
          .timeout(AppOpsService.requestTimeout);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Accept', 'application/json');
      req.write(jsonEncode(payload));

      final res = await req.close().timeout(AppOpsService.requestTimeout);

      // Post-response check: do not process or touch DB if consent was revoked while request in-flight
      if (!await isConsentGranted() || syncGen != _syncGeneration) return;

      if (res.statusCode == 200) {
        final bodyStr = await res.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        if (json is Map<String, dynamic> && json['success'] == true) {
          final data = json['data'];
          if (data is Map<String, dynamic> &&
              data['acknowledged_uuids'] is List) {
            final acked = (data['acknowledged_uuids'] as List)
                .map((u) => u.toString())
                .toList();

            // Final check before deleting local reports
            if (await isConsentGranted() && syncGen == _syncGeneration) {
              await DatabaseHelper.instance.deleteDiagnosticReports(acked);
            }
          }
        }
      }
    } catch (_) {
      // Offline fallback: keep pending queue intact
    } finally {
      client?.close();
    }
  }
}
