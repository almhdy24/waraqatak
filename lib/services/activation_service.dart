import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import 'license_key.dart';
import 'license_notification_service.dart';
import 'license_service.dart';

/// Deterministic result of an activation attempt.
///
/// The screen maps each outcome to one user-facing sentence (see
/// `AppLocalizations`). The result never leaks server internals (status
/// codes, validation errors) and never varies with locale.
enum ActivationOutcome {
  /// Server accepted the key; the license has been stored locally.
  success,

  /// Key is unknown, expired, revoked, already in use on another device,
  /// or otherwise refused by the server. All 4xx client failures that are
  /// not rate-limiting collapse into this one outcome so that no path can
  /// enumerate which specific check rejected the key.
  invalid,

  /// Server returned HTTP 429. Caller should ask the user to wait.
  tooManyAttempts,

  /// Network error, timeout, 5xx, or a response that could not be parsed.
  /// This is never shown as "invalid key" — the key may well be valid; we
  /// just couldn't talk to the server reliably.
  serverUnreachable,

  /// Device identity could not be verified securely by the operating system.
  deviceUnavailable,

  /// The server accepted the key but it could not be saved on this device.
  storageFailed,
}

/// Detailed result of an activation attempt containing the user-safe outcome
/// and an optional server reference ID (correlation ID) for support tracking.
class DetailedActivationResult {
  final ActivationOutcome outcome;

  /// Opaque correlation / reference ID returned by the server (e.g. `req_abc123`).
  /// Safe to show to user for customer support lookup without disclosing internal checks.
  final String? referenceId;

  const DetailedActivationResult({
    required this.outcome,
    this.referenceId,
  });
}

enum LicenseVerifyOutcome { valid, expired, rejected, unreachable }

class LicenseVerifyDecision {
  final LicenseVerifyOutcome outcome;
  final VerifyLicenseResult? result;
  final String? reason;
  const LicenseVerifyDecision(this.outcome, {this.result, this.reason});
}

/// Thin wrapper around the Elmahdi Pay SDK used only for key activation.
///
/// Nothing is bought, priced, or paid for inside the app. The user enters a
/// previously obtained activation key here to unlock Pro features. The only
/// data sent to the server is the activation key and the per-install device
/// identifier.
class ActivationService {
  ActivationService._();

  /// App identifier the licensing server issues Waraqatak keys under.
  static const String appSlug = AppConstants.appId;

  /// HTTPS base URL for the licensing server.
  static const String _serverUrl = 'https://api.almhdy24.com';

  /// Hard per-request timeout. One request, no automatic retries.
  static const Duration _timeout = Duration(seconds: 15);

  static ElmahdiPayClient? _client;

  static ElmahdiPayClient get _sdk {
    _client ??= ElmahdiPayClient(
      ElmahdiPayConfig(baseUrl: _serverUrl, timeout: _timeout),
    );
    return _client!;
  }

  /// Replace the backing SDK client with one wrapping a `MockClient`.
  /// Tests only — never called from production code.
  @visibleForTesting
  static void debugOverrideClient(ElmahdiPayClient client) {
    _client?.close();
    _client = client;
  }

  /// Reset to the default SDK client. Tests should call this in tearDown.
  @visibleForTesting
  static void debugResetClient() {
    _client?.close();
    _client = null;
  }

  /// Characters a license key may contain: the server issues keys as
  /// `base64url(payload).base64url(signature)`.
  static final RegExp keyCharacter = RegExp(r'[A-Za-z0-9_.\-]');

  /// Normalize a pasted key.
  ///
  /// Clipboard paste on Android commonly injects:
  ///   - leading/trailing whitespace and newlines
  ///   - invisible zero-width characters (ZWSP, ZWNJ, ZWJ, WJ, BOM)
  ///
  /// These are stripped from the entire string so the user doesn't have to
  /// manually clean up a visually-identical paste. The key is never
  /// otherwise altered: casing, dashes, and all visible characters are
  /// preserved verbatim.
  static String normalizeKey(String input) {
    const zeroWidth = <String>[
      '\u200B', // ZERO WIDTH SPACE
      '\u200C', // ZERO WIDTH NON-JOINER
      '\u200D', // ZERO WIDTH JOINER
      '\u2060', // WORD JOINER
      '\uFEFF', // ZERO WIDTH NO-BREAK SPACE / BOM
    ];
    var s = input;
    for (final c in zeroWidth) {
      s = s.replaceAll(c, '');
    }
    // Strip ASCII whitespace, Unicode spaces, and all newline variants
    // anywhere in the string (not just the ends).
    s = s.replaceAll(RegExp(r'[\s\r\n]+'), '');
    return s;
  }

  /// Activate [rawKey] on this device, returning the deterministic outcome.
  /// Backward compatible wrapper for [activateDetailed].
  static Future<ActivationOutcome> activate(
    String rawKey,
    String deviceId,
  ) async {
    final result = await activateDetailed(rawKey, deviceId);
    return result.outcome;
  }

  /// Activate [rawKey] on this device with full diagnostic reference details.
  ///
  /// Supports both short (12-char Crockford Base32) and legacy (signed_long)
  /// keys.
  ///
  /// Returns a [DetailedActivationResult]. On [ActivationOutcome.success] the
  /// license key is persisted via [LicenseService.storeLicense] with
  /// `isActive: true` and the expiry embedded in the key or returned by
  /// the server (null for perpetual / lifetime keys). For every other outcome
  /// nothing is written to storage.
  ///
  /// Success requires both a 2xx answer from the server and a valid key format.
  /// Keys that do not parse, fail checksum, were issued for another app, or
  /// are already expired are rejected as [ActivationOutcome.invalid] without
  /// contacting the server.
  static Future<DetailedActivationResult> activateDetailed(
    String rawKey,
    String deviceId,
  ) async {
    final key = normalizeKey(rawKey);
    if (key.isEmpty) {
      return const DetailedActivationResult(outcome: ActivationOutcome.invalid);
    }

    final bool isShort = ShortLicenseKey.isShortKey(key);
    final String serverKey;
    final LicenseKeyClaims? claims;

    if (isShort) {
      final normKey = ShortLicenseKey.normalize(key);
      if (!ShortLicenseKey.verifyChecksum(normKey)) {
        return const DetailedActivationResult(outcome: ActivationOutcome.invalid);
      }
      serverKey = normKey;
      claims = null;
    } else {
      // Long key path: payload must parse and be valid for this app.
      claims = LicenseKeyClaims.tryParse(key);
      if (claims == null ||
          !claims.allowsActivation(DateTime.now(), expectedAppId: AppConstants.appId)) {
        return const DetailedActivationResult(outcome: ActivationOutcome.invalid);
      }
      serverKey = key;
    }

    ActivateLicenseResult? result;
    try {
      final deviceModel = await LicenseService.instance.getDeviceModel();
      result = await _sdk.public.activateLicense(
        ActivateLicenseRequest(
          licenseKey: serverKey,
          machineId: deviceId,
          deviceName: deviceModel,
          deviceModel: deviceModel,
          product: AppConstants.appId,
        ),
      );
    } on ElmahdiPayRateLimitException catch (e) {
      return DetailedActivationResult(
        outcome: ActivationOutcome.tooManyAttempts,
        referenceId: e.correlationId,
      );
    } on ElmahdiPayNetworkException {
      return const DetailedActivationResult(
        outcome: ActivationOutcome.serverUnreachable,
      );
    } on ElmahdiPayApiException catch (e) {
      // 5xx is a server-side problem, not a key problem — treat as
      // unreachable so the UI doesn't incorrectly declare the key invalid.
      if (e.statusCode >= 500) {
        return DetailedActivationResult(
          outcome: ActivationOutcome.serverUnreachable,
          referenceId: e.correlationId,
        );
      }
      // 401 (hardened API), 403, 404, 409, 422 and any other 4xx all
      // collapse into "invalid". The server's own message is deliberately
      // not surfaced to the user.
      return DetailedActivationResult(
        outcome: ActivationOutcome.invalid,
        referenceId: e.correlationId,
      );
    } on TypeError {
      // 2xx answer with an unreadable body: not a confirmed activation.
      return const DetailedActivationResult(
        outcome: ActivationOutcome.serverUnreachable,
      );
    } on FormatException {
      return const DetailedActivationResult(
        outcome: ActivationOutcome.serverUnreachable,
      );
    } catch (_) {
      // Anything else is not a confirmed 2xx answer: store nothing.
      return const DetailedActivationResult(
        outcome: ActivationOutcome.serverUnreachable,
      );
    }

    final DateTime? expiresAt;
    final String? licenseType;

    if (isShort) {
      if (result.license == null && result.effectiveToken.isEmpty) {
        return const DetailedActivationResult(
          outcome: ActivationOutcome.serverUnreachable,
        );
      }
      final lic = result.license;
      expiresAt = lic?.expiresAt;
      licenseType = lic?.type ?? LicenseKeyClaims.perpetualType;
    } else {
      // For long keys, the server must return a token; an empty token with no
      // license object means the response was not a confirmed activation (e.g.
      // a captive-portal HTML page returned with 200).
      if (result.effectiveToken.isEmpty && result.license == null) {
        return const DetailedActivationResult(
          outcome: ActivationOutcome.serverUnreachable,
        );
      }
      expiresAt = claims!.expiresAt;
      licenseType = claims.licenseType ?? LicenseKeyClaims.lifetimeType;
    }

    final stored = await LicenseService.instance.storeLicense(
      licenseKey: isShort ? ShortLicenseKey.format(serverKey) : serverKey,
      expiresAt: expiresAt,
      isActive: true,
      licenseType: licenseType,
      activationToken: result.effectiveToken,
    );
    if (!stored) {
      return DetailedActivationResult(
        outcome: ActivationOutcome.storageFailed,
        referenceId: result.correlationId,
      );
    }
    await LicenseNotificationService.instance.onLicenseActivated(
      expiresAt: expiresAt,
      licenseType: licenseType,
    );
    return DetailedActivationResult(
      outcome: ActivationOutcome.success,
      referenceId: result.correlationId,
    );
  }

  /// Deactivates [rawKey] on the server for this device (best-effort).
  ///
  /// Releasing device slot on the licensing server allows the license to be
  /// activated on another device. Offline removal still completes locally
  /// even if this call fails.
  static Future<bool> deactivate(String rawKey, String deviceId) async {
    final key = normalizeKey(rawKey);
    if (key.isEmpty) return false;
    final serverKey =
        ShortLicenseKey.isShortKey(key) ? ShortLicenseKey.normalize(key) : key;
    try {
      await _sdk.public.deactivateLicense(
        DeactivateLicenseRequest(
          licenseKey: serverKey,
          machineId: deviceId,
          product: AppConstants.appId,
          reason: 'user_removed',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies license status authoritatively with the server.
  static Future<VerifyLicenseResult?> verifyLicenseOnline({
    required String tokenOrKey,
    required String deviceId,
  }) async {
    try {
      return await _sdk.public.verifyLicense(
        VerifyLicenseRequest(
          tokenOrKey: tokenOrKey,
          machineId: deviceId,
          product: AppConstants.appId,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static const List<String> _rejectionMarkers = [
    'revoked', 'deactivated', 'device_not_registered',
    'device_mismatch', 'license_not_found', 'not_found',
  ];

  static const List<String> _apiRejectionMarkers = [
    'revoked', 'deactivated', 'device_not_registered',
    'device_mismatch', 'license_not_found',
  ];

  @visibleForTesting
  static LicenseVerifyOutcome classifyApiException(int statusCode, String text) {
    if (statusCode != 403 && statusCode != 404 && statusCode != 410) {
      return LicenseVerifyOutcome.unreachable;
    }
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return LicenseVerifyOutcome.unreachable;
    if (t.contains('expired')) return LicenseVerifyOutcome.expired;
    for (final m in _apiRejectionMarkers) {
      if (t.contains(m)) return LicenseVerifyOutcome.rejected;
    }
    return LicenseVerifyOutcome.unreachable;
  }

  @visibleForTesting
  static LicenseVerifyOutcome classifyVerifyError(String? error) {
    final e = (error ?? '').trim().toLowerCase();
    if (e.isEmpty) return LicenseVerifyOutcome.unreachable;
    if (e.contains('expired')) return LicenseVerifyOutcome.expired;
    for (final m in _rejectionMarkers) {
      if (e.contains(m)) return LicenseVerifyOutcome.rejected;
    }
    // Unknown error text: never change the license state because of it.
    return LicenseVerifyOutcome.unreachable;
  }

  static Future<LicenseVerifyDecision> verifyLicenseDecision({
    required String tokenOrKey,
    required String deviceId,
  }) async {
    try {
      final r = await _sdk.public.verifyLicense(
        VerifyLicenseRequest(
          tokenOrKey: tokenOrKey,
          machineId: deviceId,
          product: AppConstants.appId,
        ),
      );
      if (r.valid) {
        return LicenseVerifyDecision(LicenseVerifyOutcome.valid, result: r);
      }
      final outcome = classifyVerifyError(r.error);
      return LicenseVerifyDecision(outcome, result: r, reason: r.error);
    } on ElmahdiPayRateLimitException {
      return const LicenseVerifyDecision(LicenseVerifyOutcome.unreachable);
    } on ElmahdiPayNetworkException {
      return const LicenseVerifyDecision(LicenseVerifyOutcome.unreachable);
    } on ElmahdiPayApiException catch (e) {
      final o = classifyApiException(e.statusCode, '${e.message} ${e.errors ?? ''}');
      if (o == LicenseVerifyOutcome.rejected || o == LicenseVerifyOutcome.expired) {
        return LicenseVerifyDecision(o, reason: e.message);
      }
      return const LicenseVerifyDecision(LicenseVerifyOutcome.unreachable);
    } catch (_) {
      return const LicenseVerifyDecision(LicenseVerifyOutcome.unreachable);
    }
  }

  /// Claims one-time free trial on the server.
  static Future<TrialClaimResult?> claimTrial({
    required String deviceId,
    String? deviceModel,
  }) async {
    try {
      return await _sdk.public.claimTrial(
        TrialClaimRequest(
          product: AppConstants.appId,
          machineId: deviceId,
          deviceName: deviceModel,
          deviceModel: deviceModel,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Checks server-side trial status.
  static Future<TrialStatusResult?> checkTrialStatus({
    required String deviceId,
  }) async {
    try {
      return await _sdk.public.getTrialStatus(
        TrialStatusRequest(
          product: AppConstants.appId,
          machineId: deviceId,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static void close() {
    _client?.close();
    _client = null;
  }
}
