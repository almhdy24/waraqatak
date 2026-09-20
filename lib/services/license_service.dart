import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/entitlement.dart';

/// Manages device identity, trial tracking, and license persistence.
///
/// All sensitive values are stored in Android EncryptedSharedPreferences
/// (backed by the Android Keystore).
///
/// **Persistence note:** Android's EncryptedSharedPreferences are deleted on
/// uninstall. A new install gets a fresh 14-day trial. This is the strongest
/// practical Android-supported persistence without requiring a backend account.
class LicenseService {
  LicenseService._();
  static final instance = LicenseService._();

  // v11 uses RSA-OAEP + AES-GCM via Android Keystore by default (API 23+).
  // resetOnError: false — don't silently wipe data on Keystore errors.
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  // Storage keys
  static const _kDeviceId      = 'wq_device_id';
  static const _kTrialStart    = 'wq_trial_start';
  static const _kLastLaunch    = 'wq_last_launch';
  static const _kLicenseKey    = 'wq_license_key';
  static const _kLicenseExpiry = 'wq_license_expiry';
  static const _kLicenseStatus = 'wq_license_status';
  static const _kOrderRef      = 'wq_order_ref';
  static const _kIdempotency   = 'wq_idem_key';
  static const _kRejectNote    = 'wq_rejection_note';

  static const int _trialDays = 14;

  /// In-memory cache so entitlement is only computed once per session.
  EntitlementState? _cached;

  // ── Device ID ──────────────────────────────────────────────────────────────

  Future<String> getOrCreateDeviceId() async {
    var id = await _store.read(key: _kDeviceId);
    if (id == null || id.isEmpty) {
      id = _generateUuidV4();
      await _store.write(key: _kDeviceId, value: id);
    }
    return id;
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
    final now = DateTime.now();

    await _updateLastLaunch(now);

    // ── Order state (separate from subscription entitlement) ─────────────────
    //
    // A pending or rejected order is informational only — it does NOT block
    // the user from using the app. The underlying trial/license status
    // determines that independently.
    final orderRef = await _store.read(key: _kOrderRef);
    final orderRef0 = (orderRef != null && orderRef.isNotEmpty) ? orderRef : null;
    PendingOrderStatus orderStatus = PendingOrderStatus.none;
    String? rejectNote;
    if (orderRef0 != null) {
      final raw = await _store.read(key: _kRejectNote);
      rejectNote = (raw != null && raw.isNotEmpty) ? raw : null;
      orderStatus = rejectNote != null
          ? PendingOrderStatus.rejected
          : PendingOrderStatus.pending;
    }

    // Helper: attach order state to any result without repeating fields.
    EntitlementState withOrder(
      EntitlementStatus s, {
      int trialDays = 0,
      DateTime? expiry,
    }) =>
        EntitlementState(
          status: s,
          deviceId: deviceId,
          trialDaysRemaining: trialDays,
          licenseExpiresAt: expiry,
          orderStatus: orderStatus,
          orderReference: orderRef0,
          rejectionNote: rejectNote,
        );

    // ── License ───────────────────────────────────────────────────────────────
    final licenseKey = await _store.read(key: _kLicenseKey);
    if (licenseKey != null && licenseKey.isNotEmpty) {
      final statusStr = await _store.read(key: _kLicenseStatus);
      if (statusStr == 'revoked') {
        return withOrder(EntitlementStatus.licenseRevoked);
      }

      final expiryStr = await _store.read(key: _kLicenseExpiry);
      final expiry = (expiryStr != null && expiryStr.isNotEmpty)
          ? DateTime.tryParse(expiryStr)
          : null;

      if (expiry != null && expiry.isBefore(now)) {
        return withOrder(EntitlementStatus.licenseExpired, expiry: expiry);
      }
      return withOrder(EntitlementStatus.licensed, expiry: expiry);
    }

    // ── Trial ─────────────────────────────────────────────────────────────────
    final trialStart = await _getOrInitTrialStart(now);
    final remaining =
        trialStart.add(const Duration(days: _trialDays)).difference(now);

    if (remaining.isNegative) {
      return withOrder(EntitlementStatus.trialExpired);
    }
    return withOrder(
      EntitlementStatus.trialActive,
      trialDays: remaining.inDays + 1,
    );
  }

  // ── Trial ──────────────────────────────────────────────────────────────────

  Future<DateTime> _getOrInitTrialStart(DateTime now) async {
    final s = await _store.read(key: _kTrialStart);
    if (s != null && s.isNotEmpty) return DateTime.parse(s);
    await _store.write(key: _kTrialStart, value: now.toIso8601String());
    return now;
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
  }) async {
    await _store.write(key: _kLicenseKey, value: licenseKey);
    await _store.write(
        key: _kLicenseExpiry, value: expiresAt?.toIso8601String() ?? '');
    await _store.write(
        key: _kLicenseStatus, value: isActive ? 'active' : 'revoked');
    // Clear pending order now that a license is stored.
    await _store.delete(key: _kOrderRef);
    await _store.delete(key: _kRejectNote);
    invalidateCache();
  }

  Future<String?> get licenseKey => _store.read(key: _kLicenseKey);

  // ── Order State ────────────────────────────────────────────────────────────

  Future<void> setOrderPending(String reference) async {
    await _store.write(key: _kOrderRef, value: reference);
    await _store.delete(key: _kRejectNote);
    invalidateCache();
  }

  Future<void> setOrderRejected(String reference, String? note) async {
    await _store.write(key: _kOrderRef, value: reference);
    await _store.write(key: _kRejectNote, value: note ?? '');
    invalidateCache();
  }

  Future<void> clearOrder() async {
    await _store.delete(key: _kOrderRef);
    await _store.delete(key: _kRejectNote);
    await _store.delete(key: _kIdempotency);
    invalidateCache();
  }

  Future<String?> get pendingOrderRef => _store.read(key: _kOrderRef);

  // ── Idempotency Key ────────────────────────────────────────────────────────

  Future<String?> getSavedIdempotencyKey() => _store.read(key: _kIdempotency);

  Future<void> saveIdempotencyKey(String key) =>
      _store.write(key: _kIdempotency, value: key);

  // ── UUID v4 ────────────────────────────────────────────────────────────────

  String _generateUuidV4() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${h(b[0])}${h(b[1])}${h(b[2])}${h(b[3])}-'
        '${h(b[4])}${h(b[5])}-'
        '${h(b[6])}${h(b[7])}-'
        '${h(b[8])}${h(b[9])}-'
        '${h(b[10])}${h(b[11])}${h(b[12])}${h(b[13])}${h(b[14])}${h(b[15])}';
  }
}
