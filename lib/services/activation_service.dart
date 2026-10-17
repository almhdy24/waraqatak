import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter/foundation.dart';

import 'license_key.dart';
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
}

/// Thin wrapper around the Elmahdi Pay SDK used only for key activation.
///
/// Nothing is bought, priced, or paid for inside the app. The user enters a
/// previously obtained activation key here to unlock Pro features. The only
/// data sent to the server is the activation key and the per-install device
/// identifier.
class ActivationService {
  ActivationService._();

  /// App slug the licensing server issues Waraqatak keys under.
  static const String appSlug = 'com.elmahdi.waraqatak';

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

  /// Activate [rawKey] on this device.
  ///
  /// Supports both short (12-char Crockford Base32) and legacy (signed_long)
  /// keys.
  ///
  /// Returns one of [ActivationOutcome]. On [ActivationOutcome.success] the
  /// license key is persisted via [LicenseService.storeLicense] with
  /// `isActive: true` and the expiry embedded in the key or returned by
  /// the server (null for perpetual / lifetime keys). For every other outcome
  /// nothing is written to storage.
  ///
  /// Success requires both a 2xx answer from the server and a valid key format.
  /// Keys that do not parse, fail checksum, were issued for another app, or
  /// are already expired are rejected as [ActivationOutcome.invalid] without
  /// contacting the server.
  ///
  /// No automatic retries. Caller is responsible for re-invoking after a
  /// user-visible retry.
  static Future<ActivationOutcome> activate(
    String rawKey,
    String deviceId,
  ) async {
    final key = normalizeKey(rawKey);
    if (key.isEmpty) {
      return ActivationOutcome.invalid;
    }

    final bool isShort = ShortLicenseKey.isShortKey(key);
    final String serverKey;
    final LicenseKeyClaims? claims;

    if (isShort) {
      final normKey = ShortLicenseKey.normalize(key);
      if (!ShortLicenseKey.verifyChecksum(normKey)) {
        return ActivationOutcome.invalid;
      }
      serverKey = normKey;
      claims = null;
    } else {
      // Long key path: payload must parse and be valid for this app.
      claims = LicenseKeyClaims.tryParse(key);
      if (claims == null ||
          !claims.allowsActivation(DateTime.now(), expectedAppSlug: appSlug)) {
        return ActivationOutcome.invalid;
      }
      serverKey = key;
    }

    ActivateLicenseResult? result;
    try {
      result = await _sdk.public.activateLicense(
        ActivateLicenseRequest(licenseKey: serverKey, machineId: deviceId),
      );
    } on ElmahdiPayRateLimitException {
      return ActivationOutcome.tooManyAttempts;
    } on ElmahdiPayNetworkException {
      return ActivationOutcome.serverUnreachable;
    } on ElmahdiPayApiException catch (e) {
      // 5xx is a server-side problem, not a key problem — treat as
      // unreachable so the UI doesn't incorrectly declare the key invalid.
      if (e.statusCode >= 500) return ActivationOutcome.serverUnreachable;
      // 401 (hardened API), 403, 404, 409, 422 and any other 4xx all
      // collapse into "invalid". The server's own message is deliberately
      // not surfaced to the user.
      return ActivationOutcome.invalid;
    } on TypeError {
      // The server answered 2xx but the body lacked expected fields.
    } on FormatException {
      // Body could not be decoded.
    } catch (_) {
      // Anything else is not a confirmed 2xx answer: store nothing.
      return ActivationOutcome.serverUnreachable;
    }

    final DateTime? expiresAt;
    final String? licenseType;

    if (isShort) {
      if (result == null ||
          (result.license == null && result.effectiveToken.isEmpty)) {
        return ActivationOutcome.serverUnreachable;
      }
      final lic = result.license;
      expiresAt = lic?.expiresAt;
      licenseType = lic?.type ?? LicenseKeyClaims.perpetualType;
    } else {
      expiresAt = claims!.expiresAt;
      licenseType = claims.licenseType ?? LicenseKeyClaims.lifetimeType;
    }

    await LicenseService.instance.storeLicense(
      licenseKey: isShort ? ShortLicenseKey.format(serverKey) : serverKey,
      expiresAt: expiresAt,
      isActive: true,
      licenseType: licenseType,
      activationToken: result?.effectiveToken,
    );
    return ActivationOutcome.success;
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
          reason: 'user_removed',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static void close() {
    _client?.close();
    _client = null;
  }
}
