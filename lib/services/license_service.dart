import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/entitlement.dart';
import 'activation_service.dart';
import 'license_key.dart';
import 'license_notification_service.dart';

/// Key/value storage used by [LicenseService]. Production uses
/// [SecureLicenseStorage]; tests inject an in-memory fake.
abstract class LicenseStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

/// Android Keystore-backed storage (EncryptedSharedPreferences).
class SecureLicenseStorage implements LicenseStorage {
  const SecureLicenseStorage();

  // v11 uses RSA-OAEP + AES-GCM via Android Keystore by default (API 23+).
  // resetOnError: false — don't silently wipe data on Keystore errors.
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  @override
  Future<String?> read({required String key}) async {
    try {
      return await _store.read(key: key);
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    try {
      await _store.write(key: key, value: value);
    } on Object catch (_) {}
  }

  @override
  Future<void> delete({required String key}) async {
    try {
      await _store.delete(key: key);
    } on Object catch (_) {}
  }
}

/// Manages device identity, trial tracking, and license persistence.
///
/// All sensitive values are stored in Android EncryptedSharedPreferences
/// (backed by the Android Keystore).
///
/// **Persistence note:** Android's EncryptedSharedPreferences are deleted on
/// uninstall, but device identity is derived deterministically from hardware
/// identifiers (Settings.Secure.ANDROID_ID hashed with SHA-256) and verified
/// against the central licensing server (`app_trials`). Reinstalling or clearing
/// app data does not grant a fresh trial: the server-authoritative trial window
/// and original trial start timestamp are preserved.
class LicenseService {
  LicenseService._(this._store, this._clock);
  static final instance =
      LicenseService._(const SecureLicenseStorage(), DateTime.now);

  /// A service with its own storage and clock. Tests only.
  @visibleForTesting
  factory LicenseService.forTesting({
    required LicenseStorage storage,
    required DateTime Function() clock,
  }) =>
      LicenseService._(storage, clock);

  final LicenseStorage _store;
  final DateTime Function() _clock;

  // Storage keys
  static const _kDeviceId      = 'wq_device_id';
  static const _kTrialStart    = 'wq_trial_start';
  static const _kLastLaunch    = 'wq_last_launch';
  static const _kLicenseKey    = 'wq_license_key';
  static const _kLicenseExpiry = 'wq_license_expiry';
  static const _kLicenseStatus = 'wq_license_status';
  static const _kLicenseType      = 'wq_license_type';
  static const _kLastSeen         = 'wq_last_seen';
  static const _kActivationToken  = 'wq_activation_token';
  static const _kTrialServerStart = 'wq_trial_server_start';
  static const _kTrialServerExpiry = 'wq_trial_server_expiry';
  static const _kTrialServerStatus = 'wq_trial_server_status';
  static const _kDeviceModelCache = 'wq_device_model_cache';

  static const int _trialDays = 14;

  /// In-memory cache so entitlement is only computed once per session.
  EntitlementState? _cached;

  // ── Device ID & Model ──────────────────────────────────────────────────────

  static const _deviceChannel = MethodChannel('com.elmahdi.waraqatak/device');

  /// Hardware device name / model (e.g. "Samsung Galaxy A16").
  /// Informational metadata for display only — not used as an identity secret.
  Future<String> getDeviceModel() async {
    final cached = await _store.read(key: _kDeviceModelCache);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    String model = 'Android Device';
    try {
      final res = await _deviceChannel.invokeMethod<String>('getDeviceModel');
      if (res != null && res.trim().isNotEmpty) {
        model = res.trim();
      }
    } catch (_) {}
    await _store.write(key: _kDeviceModelCache, value: model);
    return model;
  }

  /// Device identifier sent to the licensing server as `machine_id`.
  ///
  /// An already stored id is always kept, so existing activations stay valid.
  /// New installs derive the id from a hash of the Android ID, which is
  /// stable across uninstall/reinstall on the same device, so a reinstall
  /// can re-activate the same key.
  ///
  /// If the platform channel cannot obtain a valid Android ID (e.g. broken emulator
  /// value, restricted OS environment, or platform channel error), this method throws
  /// a [StateError] instead of generating a random transient UUID that would break
  /// device identity stability across reinstallations.
  Future<String> getOrCreateDeviceId() async {
    var id = await _store.read(key: _kDeviceId);
    if (id == null || id.isEmpty) {
      final stableId = await _stableDeviceId();
      if (stableId == null || stableId.isEmpty) {
        throw StateError(
          'Stable device identifier could not be retrieved from the operating system.',
        );
      }
      id = stableId;
      await _store.write(key: _kDeviceId, value: id);
    }
    return id;
  }

  Future<String?> _stableDeviceId() async {
    try {
      final hash = await _deviceChannel.invokeMethod<String>('stableIdHash');
      return hash == null ? null : uuidFromHash(hash);
    } catch (_) {
      return null;
    }
  }

  /// Formats the first 128 bits of a hex digest as a UUID (version 8,
  /// RFC 9562 custom), keeping the `machine_id` shape of earlier installs.
  static String? uuidFromHash(String hexDigest) {
    final hex = hexDigest.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{32,}$').hasMatch(hex)) return null;
    final b = List<int>.generate(
        16, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
    b[6] = (b[6] & 0x0f) | 0x80; // version 8
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
    return _formatUuid(b);
  }

  // ── Entitlement ────────────────────────────────────────────────────────────

  Future<EntitlementState> checkEntitlement({bool force = false}) async {
    if (!force && _cached != null) return _cached!;
    _cached = await _compute();
    return _cached!;
  }

  void invalidateCache() => _cached = null;

  Future<EntitlementState> _compute() async {
    String? deviceId;
    try {
      deviceId = await getOrCreateDeviceId();
    } catch (_) {
      // In restricted environments where Android ID cannot be obtained and no ID
      // was previously stored, fall back to an unpersisted placeholder so basic trial
      // evaluation and offline documents flow can continue without crashing.
      deviceId = '00000000-0000-0000-0000-000000000000';
    }
    final now = _clock();

    await _updateLastLaunch(now);

    // ── License ───────────────────────────────────────────────────────────────
    final licenseKey = await _store.read(key: _kLicenseKey);
    if (licenseKey != null && licenseKey.isNotEmpty) {
      final statusStr = await _store.read(key: _kLicenseStatus);
      if (statusStr == 'revoked') {
        return EntitlementState(
          status: EntitlementStatus.licenseRevoked,
          deviceId: deviceId,
        );
      }
      if (statusStr == 'expired') {
        DateTime? exp;
        final expiryStr = await _store.read(key: _kLicenseExpiry);
        if (expiryStr != null && expiryStr.isNotEmpty) {
          exp = DateTime.tryParse(expiryStr);
        }
        return EntitlementState(
          status: EntitlementStatus.licenseExpired,
          deviceId: deviceId,
          licenseExpiresAt: exp,
        );
      }

      // License expiry is compared against a clock that never runs backwards.
      final effectiveNow = await _effectiveNow(now);

      final expiryStr = await _store.read(key: _kLicenseExpiry);
      final storedType = await _store.read(key: _kLicenseType);
      DateTime? expiry;
      var usable = true;
      if (expiryStr != null && expiryStr.isNotEmpty) {
        expiry = DateTime.tryParse(expiryStr);
        // A stored expiry that cannot be read must never mean "unlimited".
        if (expiry == null) usable = false;
      } else {
        // Licenses stored before expiries were recorded fall back to the
        // expiry signed into the key itself.
        final claims = LicenseKeyClaims.tryParse(licenseKey);
        expiry = claims?.expiresAt;
        if (claims != null && claims.malformed) usable = false;
      }

      // No expiry is only valid for a lifetime or perpetual license. Installs activated
      // before the license type was stored have no type and keep the earlier
      // behaviour (no expiry = lifetime) so existing users are not locked.
      final typeAllowsNoExpiry = storedType == null ||
          storedType.isEmpty ||
          storedType == LicenseKeyClaims.lifetimeType ||
          storedType.toLowerCase() == LicenseKeyClaims.perpetualType;
      if (usable && expiry == null && !typeAllowsNoExpiry) usable = false;

      if (!usable || (expiry != null && expiry.isBefore(effectiveNow))) {
        return EntitlementState(
          status: EntitlementStatus.licenseExpired,
          deviceId: deviceId,
          licenseExpiresAt: expiry,
        );
      }
      return EntitlementState(
        status: EntitlementStatus.licensed,
        deviceId: deviceId,
        licenseExpiresAt: expiry,
      );
    }

    // ── Trial ─────────────────────────────────────────────────────────────────
    final trialStart = await _getOrInitTrialStart(now);
    final effective = await _effectiveNow(now);

    // 1. Authoritative server-side trial status check
    final serverStatus = await _store.read(key: _kTrialServerStatus);
    if (serverStatus == 'expired') {
      return EntitlementState(
        status: EntitlementStatus.trialExpired,
        deviceId: deviceId,
      );
    }

    final serverExpiryStr = await _store.read(key: _kTrialServerExpiry);
    if (serverExpiryStr != null && serverExpiryStr.isNotEmpty) {
      final serverExpiry = DateTime.tryParse(serverExpiryStr);
      if (serverExpiry != null) {
        final serverRemaining = serverExpiry.difference(effective);
        if (serverRemaining.isNegative) {
          await _store.write(key: _kTrialServerStatus, value: 'expired');
          return EntitlementState(
            status: EntitlementStatus.trialExpired,
            deviceId: deviceId,
          );
        }
        return EntitlementState(
          status: EntitlementStatus.trialActive,
          deviceId: deviceId,
          trialDaysRemaining: (serverRemaining.inDays + 1).clamp(0, _trialDays),
        );
      }
    }

    // 2. Local fallback if server trial not yet retrieved
    final remaining =
        trialStart.add(const Duration(days: _trialDays)).difference(effective);

    if (remaining.isNegative) {
      return EntitlementState(
        status: EntitlementStatus.trialExpired,
        deviceId: deviceId,
      );
    }
    return EntitlementState(
      status: EntitlementStatus.trialActive,
      deviceId: deviceId,
      trialDaysRemaining: (remaining.inDays + 1).clamp(0, _trialDays),
    );
  }

  // ── Trial ──────────────────────────────────────────────────────────────────

  Future<DateTime> _getOrInitTrialStart(DateTime now) async {
    final s = await _store.read(key: _kTrialStart);
    if (s != null && s.isNotEmpty) {
      final dt = DateTime.tryParse(s);
      if (dt != null) return dt;
    }

    // If trial start was not recorded (e.g. key was activated on first run
    // or legacy install), derive start from historical evidence if available
    // to prevent granting a fresh trial upon license removal.
    DateTime start = now;
    final seenStr = await _store.read(key: _kLastSeen);
    final launchStr = await _store.read(key: _kLastLaunch);
    final seen = seenStr != null ? DateTime.tryParse(seenStr) : null;
    if (seen != null && seen.isBefore(start)) {
      start = seen;
    }
    final launch = launchStr != null ? DateTime.tryParse(launchStr) : null;
    if (launch != null && launch.isBefore(start)) {
      start = launch;
    }

    await _store.write(key: _kTrialStart, value: start.toIso8601String());
    return start;
  }

  /// `max(wall clock, last time seen)`. The last-seen time is persisted and
  /// only ever moves forward, so setting the device clock back does not
  /// bring an expired license back.
  Future<DateTime> _effectiveNow(DateTime now) async {
    final s = await _store.read(key: _kLastSeen);
    final seen = (s == null || s.isEmpty) ? null : DateTime.tryParse(s);
    if (seen == null || now.isAfter(seen)) {
      await _store.write(key: _kLastSeen, value: now.toUtc().toIso8601String());
      return now;
    }
    return seen;
  }

  /// Clock-rollback protection: if current time is significantly behind the
  /// last recorded launch time, advance the trial start by the rollback delta
  /// so the user cannot gain extra trial days by rewinding the device clock.
  Future<void> _updateLastLaunch(DateTime now) async {
    final s = await _store.read(key: _kLastLaunch);
    if (s != null && s.isNotEmpty) {
      final last = DateTime.tryParse(s);
      if (last != null) {
        final rollback = last.difference(now); // positive when clock went back
        if (rollback > const Duration(minutes: 2)) {
          final trialStr = await _store.read(key: _kTrialStart);
          if (trialStr != null && trialStr.isNotEmpty) {
            final ts = DateTime.tryParse(trialStr);
            if (ts != null) {
              final adjusted = ts.add(rollback);
              await _store.write(
                  key: _kTrialStart, value: adjusted.toIso8601String());
            }
          }
        }
      }
    }
    await _store.write(key: _kLastLaunch, value: now.toIso8601String());
  }

  // ── License Persistence ────────────────────────────────────────────────────

  Future<void> storeLicense({
    required String licenseKey,
    required DateTime? expiresAt,
    required bool isActive,
    String? licenseType,
    String? activationToken,
  }) async {
    // Seed trial start if not already set, binding trial lifetime from
    // the installation / activation time.
    await _getOrInitTrialStart(_clock());
    await _store.write(key: _kLicenseKey, value: licenseKey);
    await _store.write(key: _kLicenseType, value: licenseType ?? '');
    await _store.write(
        key: _kLicenseExpiry, value: expiresAt?.toIso8601String() ?? '');
    await _store.write(
        key: _kLicenseStatus, value: isActive ? 'active' : 'revoked');
    if (activationToken != null) {
      await _store.write(key: _kActivationToken, value: activationToken);
    }
    invalidateCache();
  }

  Future<String?> get licenseKey => _store.read(key: _kLicenseKey);

  /// Authoritatively syncs free trial status with the licensing API.
  Future<void> syncTrialWithServer({bool force = false}) async {
    try {
      if (!force) {
        final key = await _store.read(key: _kLicenseKey);
        final status = await _store.read(key: _kLicenseStatus);
        if (key != null && key.isNotEmpty && status == 'active') {
          // Device is actively licensed; avoid claiming stray trial or dispatching trial notifications
          return;
        }
      }

      final deviceId = await getOrCreateDeviceId();
      final model = await getDeviceModel();

      final result = await ActivationService.claimTrial(
        deviceId: deviceId,
        deviceModel: model,
      );

      if (result == null || !result.success) return;

      if (result.startedAt != null) {
        await _store.write(
          key: _kTrialServerStart,
          value: result.startedAt!.toIso8601String(),
        );
      }
      if (result.expiresAt != null) {
        await _store.write(
          key: _kTrialServerExpiry,
          value: result.expiresAt!.toIso8601String(),
        );
      }
      await _store.write(
        key: _kTrialServerStatus,
        value: result.status,
      );

      invalidateCache();

      // Dispatch in-app notifications
      if (result.status == 'expired' || result.daysRemaining <= 0) {
        await LicenseNotificationService.instance.onTrialExpired();
      } else if (result.status == 'active') {
        if (result.daysRemaining <= 3) {
          await LicenseNotificationService.instance.onTrialExpiring(
            daysRemaining: result.daysRemaining,
          );
        } else if (result.eligible) {
          await LicenseNotificationService.instance.onTrialStarted(
            daysRemaining: result.daysRemaining,
          );
        }
      }
    } catch (_) {}
  }

  /// Authoritatively re-verifies stored license against the server.
  ///
  /// Prevents bypass via stale offline state or local tampering.
  /// If the server revoked or expired the key/device, entitlement fails closed.
  /// If the server is offline or unreachable, legitimate paying customers are NOT locked out.
  Future<void> verifyLicenseOnline() async {
    try {
      final key = await _store.read(key: _kLicenseKey);
      if (key == null || key.isEmpty) return;

      final token = await _store.read(key: _kActivationToken);
      final tokenOrKey = (token != null && token.isNotEmpty) ? token : key;
      final deviceId = await getOrCreateDeviceId();

      final result = await ActivationService.verifyLicenseOnline(
        tokenOrKey: tokenOrKey,
        deviceId: deviceId,
      );

      if (result == null) {
        // Network/connectivity failure — preserve offline use, never revoke
        return;
      }

      if (!result.valid) {
        final err = result.error ?? '';
        if (err.contains('expired')) {
          await _store.write(key: _kLicenseStatus, value: 'expired');
          invalidateCache();
          await LicenseNotificationService.instance.onLicenseExpired();
        } else {
          // Fail closed for any explicit rejection (revoked, deactivated,
          // device_not_registered, device_mismatch, license_not_found, etc.)
          await _store.write(key: _kLicenseStatus, value: 'revoked');
          invalidateCache();
          await LicenseNotificationService.instance
              .onLicenseRevoked(reason: err);
        }
      } else {
        // Confirmed valid by server
        await _store.write(key: _kLicenseStatus, value: 'active');
        final data = result.data;
        if (data != null && data['expires_at'] != null) {
          final expStr = data['expires_at'].toString();
          await _store.write(key: _kLicenseExpiry, value: expStr);
          final expDate = DateTime.tryParse(expStr);
          if (expDate != null) {
            final days = expDate.difference(DateTime.now()).inDays;
            if (days > 0 && days <= 7) {
              await LicenseNotificationService.instance
                  .onLicenseExpiring(daysRemaining: days);
            }
          }
        }
        invalidateCache();
      }
    } catch (_) {}
  }

  /// Deletes the stored license from this device.
  ///
  /// Clears `wq_license_key`, `wq_license_expiry`, `wq_license_status`,
  /// `wq_license_type`, and `wq_activation_token` so entitlement falls back to
  /// the trial path (or expired-trial path if the 14-day window has elapsed).
  /// The device identifier and trial start markers are intentionally **not**
  /// touched — removing the key is not meant to grant a fresh trial. The
  /// last-seen time is kept too, so removing a key cannot be used to rewind
  /// the clock guard.
  Future<void> clearLicense() async {
    await _store.delete(key: _kLicenseKey);
    await _store.delete(key: _kLicenseExpiry);
    await _store.delete(key: _kLicenseStatus);
    await _store.delete(key: _kLicenseType);
    await _store.delete(key: _kActivationToken);
    invalidateCache();
  }

  // ── UUID Formatting ────────────────────────────────────────────────────────

  static String _formatUuid(List<int> b) {
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${h(b[0])}${h(b[1])}${h(b[2])}${h(b[3])}-'
        '${h(b[4])}${h(b[5])}-'
        '${h(b[6])}${h(b[7])}-'
        '${h(b[8])}${h(b[9])}-'
        '${h(b[10])}${h(b[11])}${h(b[12])}${h(b[13])}${h(b[14])}${h(b[15])}';
  }
}
