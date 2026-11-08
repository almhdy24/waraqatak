import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/access_dao.dart';
import '../../database/database_helper.dart';
import '../license_service.dart';
import 'access_guard.dart';
import 'session_manager.dart';

/// Result of verifying the cryptographic integrity of the audit log chain.
class AuditVerificationResult {
  final bool isValid;
  final int verifiedCount;
  final int? brokenAtId;
  final String? error;

  const AuditVerificationResult({
    required this.isValid,
    required this.verifiedCount,
    this.brokenAtId,
    this.error,
  });

  @override
  String toString() => isValid
      ? 'AuditVerificationResult(valid, count=$verifiedCount)'
      : 'AuditVerificationResult(INVALID at id=$brokenAtId: $error)';
}

/// Service managing the tamper-evident, actor-attributed audit log chain.
class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  static const String genesisHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final Sha256 _sha256 = Sha256();
  String? _testingDeviceId;
  String? _cachedDeviceId;

  @visibleForTesting
  void setTestingDeviceId(String? deviceId) {
    _testingDeviceId = deviceId;
  }

  /// Cached device identifier string.
  String get currentDeviceId =>
      _testingDeviceId ??
      _cachedDeviceId ??
      '00000000-0000-0000-0000-000000000000';

  /// Resolves current device identifier safely.
  Future<String> resolveDeviceId() async {
    if (_testingDeviceId != null) return _testingDeviceId!;
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      _cachedDeviceId = await LicenseService.instance.getOrCreateDeviceId();
    } catch (_) {
      _cachedDeviceId = '00000000-0000-0000-0000-000000000000';
    }
    return _cachedDeviceId!;
  }

  /// Formats the audit payload string for hashing.
  String formatPayload({
    required String action,
    String? entityType,
    int? entityId,
    String? details,
    required String timestamp,
    required String userId,
    required String deviceId,
    required String prevHash,
  }) {
    return [
      action,
      entityType ?? '',
      entityId?.toString() ?? '',
      details ?? '',
      timestamp,
      userId,
      deviceId,
      prevHash,
    ].join('|');
  }

  /// Computes the SHA-256 hash for an audit entry.
  Future<String> computeHash({
    required String action,
    String? entityType,
    int? entityId,
    String? details,
    required String timestamp,
    required String userId,
    required String deviceId,
    required String prevHash,
  }) async {
    final payload = formatPayload(
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: timestamp,
      userId: userId,
      deviceId: deviceId,
      prevHash: prevHash,
    );
    final hash = await _sha256.hash(utf8.encode(payload));
    return hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Ensures a genesis anchor record exists in the audit log chain.
  Future<String> ensureGenesis(
    DatabaseExecutor db, {
    String? deviceId,
  }) async {
    final existing = await db.rawQuery('''
      SELECT hash FROM audit_log
      WHERE action = 'audit_chain_genesis' AND hash IS NOT NULL
      ORDER BY id ASC
      LIMIT 1
    ''');
    if (existing.isNotEmpty) {
      return existing.first['hash'] as String;
    }

    final devId = deviceId ?? await resolveDeviceId();
    final now = DateTime.now().toIso8601String();
    const action = 'audit_chain_genesis';
    const entityType = 'system';
    const details = 'v29_genesis_anchor';
    const userId = 'system';
    const userName = 'النظام';
    const prev = genesisHash;

    final hash = await computeHash(
      action: action,
      entityType: entityType,
      entityId: null,
      details: details,
      timestamp: now,
      userId: userId,
      deviceId: devId,
      prevHash: prev,
    );

    await db.rawInsert('''
      INSERT INTO audit_log (
        action, entity_type, entity_id, details, timestamp,
        user_id, user_name, device_id, workspace_id, prev_hash, hash
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      action,
      entityType,
      null,
      details,
      now,
      userId,
      userName,
      devId,
      AccessDao.defaultWorkspaceId,
      prev,
      hash,
    ]);

    return hash;
  }

  /// Logs an event into the tamper-evident audit chain.
  Future<void> logEvent(
    DatabaseExecutor db,
    String action, {
    String? entityType,
    int? entityId,
    String? details,
  }) async {
    // 1. Find previous hash in the chain
    final lastRow = await db.rawQuery('''
      SELECT hash FROM audit_log
      WHERE hash IS NOT NULL
      ORDER BY id DESC
      LIMIT 1
    ''');

    String prevHash;
    final deviceId = await resolveDeviceId();
    if (lastRow.isEmpty) {
      prevHash = await ensureGenesis(db, deviceId: deviceId);
    } else {
      prevHash = lastRow.first['hash'] as String;
    }

    // 2. Resolve actor attribution
    String userId;
    String userName;
    if (AccessGuard.isSystemContext) {
      userId = 'system';
      userName = 'النظام';
    } else {
      final user = SessionManager.instance.currentUser;
      if (user != null) {
        userId = user.id;
        userName = user.displayName;
      } else {
        userId = AccessDao.ownerUserId;
        userName = 'المالك';
      }
    }

    final now = DateTime.now().toIso8601String();

    // 3. Compute hash
    final hash = await computeHash(
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: now,
      userId: userId,
      deviceId: deviceId,
      prevHash: prevHash,
    );

    // 4. Insert into audit_log
    await db.rawInsert('''
      INSERT INTO audit_log (
        action, entity_type, entity_id, details, timestamp,
        user_id, user_name, device_id, workspace_id, prev_hash, hash
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      action,
      entityType,
      entityId,
      details,
      now,
      userId,
      userName,
      deviceId,
      AccessDao.defaultWorkspaceId,
      prevHash,
      hash,
    ]);
  }

  /// Verifies the entire cryptographic hash chain of [audit_log].
  Future<AuditVerificationResult> verifyChain({DatabaseExecutor? db}) async {
    final executor = db ?? await DatabaseHelper.instance.database;
    final rows = await executor.rawQuery('''
      SELECT id, action, entity_type, entity_id, details, timestamp,
             user_id, device_id, prev_hash, hash
      FROM audit_log
      WHERE hash IS NOT NULL
      ORDER BY id ASC
    ''');

    if (rows.isEmpty) {
      return const AuditVerificationResult(isValid: true, verifiedCount: 0);
    }

    String expectedPrevHash = genesisHash;
    int verifiedCount = 0;

    for (final row in rows) {
      final id = row['id'] as int;
      final action = (row['action'] as String?) ?? '';
      final entityType = row['entity_type'] as String?;
      final entityId = row['entity_id'] as int?;
      final details = row['details'] as String?;
      final timestamp = (row['timestamp'] as String?) ?? '';
      final userId = (row['user_id'] as String?) ?? '';
      final deviceId = (row['device_id'] as String?) ?? '';
      final prevHash = (row['prev_hash'] as String?) ?? '';
      final storedHash = (row['hash'] as String?) ?? '';

      if (action == 'audit_chain_genesis') {
        expectedPrevHash = prevHash;
      }

      if (prevHash != expectedPrevHash) {
        return AuditVerificationResult(
          isValid: false,
          verifiedCount: verifiedCount,
          brokenAtId: id,
          error:
              'prev_hash mismatch: expected $expectedPrevHash but got $prevHash',
        );
      }

      final computed = await computeHash(
        action: action,
        entityType: entityType,
        entityId: entityId,
        details: details,
        timestamp: timestamp,
        userId: userId,
        deviceId: deviceId,
        prevHash: prevHash,
      );

      if (storedHash != computed) {
        return AuditVerificationResult(
          isValid: false,
          verifiedCount: verifiedCount,
          brokenAtId: id,
          error:
              'hash mismatch: expected computed $computed but stored was $storedHash',
        );
      }

      expectedPrevHash = storedHash;
      verifiedCount++;
    }

    return AuditVerificationResult(
      isValid: true,
      verifiedCount: verifiedCount,
    );
  }
}
