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
  /// Returns one of [ActivationOutcome]. On [ActivationOutcome.success] the
  /// license key is persisted via [LicenseService.storeLicense] with
  /// `isActive: true` and the expiry embedded in the key (null for lifetime
  /// keys). For every other outcome nothing is written to storage.
  ///
  /// Success requires both a 2xx answer from the server and a key whose
  /// payload parses. Keys that do not parse, were issued for another app, or
  /// are already expired are rejected as [ActivationOutcome.invalid] without
  /// contacting the server. So is a key whose `license_type` is not
  /// `lifetime` but whose `expires_at` is missing, null, unparseable or in
  /// the past: this guards against a server issuance mistake granting
  /// unlimited access. Legacy keys without a `license_type` still activate.
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

    // A key whose payload cannot be parsed is never stored, and is rejected
    // before the server is contacted so it cannot use up a device slot.
    final claims = LicenseKeyClaims.tryParse(key);
    if (claims == null ||
        !claims.allowsActivation(DateTime.now(), expectedAppSlug: appSlug)) {
      return ActivationOutcome.invalid;
    }

    try {
      await _sdk.public.activateLicense(
        ActivateLicenseRequest(licenseKey: key, machineId: deviceId),
      );
    } on ElmahdiPayRateLimitException {
      return ActivationOutcome.tooManyAttempts;
    } on ElmahdiPayNetworkException {
      return ActivationOutcome.serverUnreachable;
    } on ElmahdiPayApiException catch (e) {
      // 5xx is a server-side problem, not a key problem — treat as
      // unreachable so the UI doesn't incorrectly declare the key invalid.
      if (e.statusCode >= 500) return ActivationOutcome.serverUnreachable;
      // 401 (new hardened API), 403, 404, 409, 422 and any other 4xx all
      // collapse into "invalid". The server's own message is deliberately
      // not surfaced to the user.
      return ActivationOutcome.invalid;
    } on TypeError {
      // The server answered 2xx but the body lacked the expected fields.
      // The activation succeeded on the server; no response field is used.
    } on FormatException {
      // Same as above for a body that could not be decoded.
    } catch (_) {
      // Anything else is not a confirmed 2xx answer: store nothing.
      return ActivationOutcome.serverUnreachable;
    }

    await LicenseService.instance.storeLicense(
      licenseKey: key,
      expiresAt: claims?.expiresAt,
      isActive: true,
    );
    return ActivationOutcome.success;
  }

  static void close() {
    _client?.close();
    _client = null;
  }
}
