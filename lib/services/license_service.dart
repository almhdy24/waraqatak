import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/entitlement.dart';
import 'license_key.dart';

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
  Future<String?> read({required String key}) => _store.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _store.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _store.delete(key: key);
}

/// Manages device identity, trial tracking, and license persistence.
///
/// All sensitive values are stored in Android EncryptedSharedPreferences
/// (backed by the Android Keystore).
///
/// **Persistence note:** Android's EncryptedSharedPreferences are deleted on
/// uninstall. A new install gets a fresh 14-day trial. This is the strongest
/// practical Android-supported persistence without requiring a backend account.
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
  static const _kLicenseType   = 'wq_license_type';
  static const _kLastSeen      = 'wq_last_seen';

  static const int _trialDays = 14;

  /// In-memory cache so entitlement is only computed once per session.
  EntitlementState? _cached;

  // ── Device ID ──────────────────────────────────────────────────────────────

  static const _deviceChannel = MethodChannel('com.elmahdi.waraqatak/device');

  /// Device identifier sent to the licensing server as `machine_id`.
  ///
  /// An already stored id is always kept, so existing activations stay valid.
  /// New installs derive the id from a hash of the Android ID, which is
  /// stable across uninstall/reinstall on the same device, so a reinstall
  /// can re-activate the same key. Falls back to a random UUID.
  Future<String> getOrCreateDeviceId() async {
    var id = await _store.read(key: _kDeviceId);
    if (id == null || id.isEmpty) {
      id = await _stableDeviceId() ?? _generateUuidV4();
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
    final deviceId = await getOrCreateDeviceId();
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

      // No expiry is only valid for a lifetime license. Installs activated
      // before the license type was stored have no type and keep the earlier
      // behaviour (no expiry = lifetime) so existing users are not locked.
      final typeAllowsNoExpiry = storedType == null ||
          storedType.isEmpty ||
          storedType == LicenseKeyClaims.lifetimeType;
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
    final remaining =
        trialStart.add(const Duration(days: _trialDays)).difference(now);

    if (remaining.isNegative) {
      return EntitlementState(
        status: EntitlementStatus.trialExpired,
        deviceId: deviceId,
      );
    }
    return EntitlementState(
      status: EntitlementStatus.trialActive,
      deviceId: deviceId,
      trialDaysRemaining: remaining.inDays + 1,
    );
  }

  // ── Trial ──────────────────────────────────────────────────────────────────

  Future<DateTime> _getOrInitTrialStart(DateTime now) async {
    final s = await _store.read(key: _kTrialStart);
    if (s != null && s.isNotEmpty) return DateTime.parse(s);
    await _store.write(key: _kTrialStart, value: now.toIso8601String());
    return now;
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
  }) async {
    await _store.write(key: _kLicenseKey, value: licenseKey);
    await _store.write(key: _kLicenseType, value: licenseType ?? '');
    await _store.write(
        key: _kLicenseExpiry, value: expiresAt?.toIso8601String() ?? '');
    await _store.write(
        key: _kLicenseStatus, value: isActive ? 'active' : 'revoked');
    invalidateCache();
  }

  Future<String?> get licenseKey => _store.read(key: _kLicenseKey);

  /// Deletes the stored license from this device.
  ///
  /// Clears `wq_license_key`, `wq_license_expiry`, `wq_license_status` and
  /// `wq_license_type` so entitlement falls back to the trial path (or expired-trial path
  /// if the 14-day window has elapsed). The device identifier and trial
  /// start markers are intentionally **not** touched — removing the key
  /// is not meant to grant a fresh trial. The last-seen time is kept too,
  /// so removing a key cannot be used to rewind the clock guard.
  Future<void> clearLicense() async {
    await _store.delete(key: _kLicenseKey);
    await _store.delete(key: _kLicenseExpiry);
    await _store.delete(key: _kLicenseStatus);
    await _store.delete(key: _kLicenseType);
    invalidateCache();
  }

  // ── UUID v4 ────────────────────────────────────────────────────────────────

  String _generateUuidV4() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
    return _formatUuid(b);
  }

  static String _formatUuid(List<int> b) {
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${h(b[0])}${h(b[1])}${h(b[2])}${h(b[3])}-'
        '${h(b[4])}${h(b[5])}-'
        '${h(b[6])}${h(b[7])}-'
        '${h(b[8])}${h(b[9])}-'
        '${h(b[10])}${h(b[11])}${h(b[12])}${h(b[13])}${h(b[14])}${h(b[15])}';
  }
}
