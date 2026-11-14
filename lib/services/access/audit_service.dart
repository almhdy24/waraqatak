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

  /// Formats the audit payload string for hashing (v2 includes userName for tamper proofing - C10).
  String formatPayload({
    required String action,
    String? entityType,
    int? entityId,
    String? details,
    required String timestamp,
    required String userId,
    String? userName,
    required String deviceId,
    required String prevHash,
  }) {
    if (userName != null) {
      return [
        'v2',
        action,
        entityType ?? '',
        entityId?.toString() ?? '',
        details ?? '',
        timestamp,
        userId,
        userName,
        deviceId,
        prevHash,
      ].join('|');
    }
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
    String? userName,
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
      userName: userName,
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
    const userName = 'system';
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

  Future<void> _chainLock = Future.value();

  @visibleForTesting
  void resetChainLockForTesting() {
    _chainLock = Future.value();
  }

  /// Logs an event into the tamper-evident audit chain.
  /// Execution is serialized to prevent hash chain forks from concurrent calls (D7).
  /// Reentrant calls inside a transaction do not wait on the outer lock to avoid deadlocks (C9).
  Future<void> logEvent(
    DatabaseExecutor db,
    String action, {
    String? entityType,
    int? entityId,
    String? details,
    String? userId,
    String? userName,
  }) {
    if (db is Transaction || db.runtimeType.toString().toLowerCase().contains('transaction')) {
      return _logEventInternal(
        db,
        action,
        entityType: entityType,
        entityId: entityId,
        details: details,
        explicitUserId: userId,
        explicitUserName: userName,
      );
    }

    final next = _chainLock.then((_) => _logEventInternal(
      db,
      action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      explicitUserId: userId,
      explicitUserName: userName,
    ));
    _chainLock = next.catchError((_) {});
    return next;
  }

  Future<void> _logEventInternal(
    DatabaseExecutor db,
    String action, {
    String? entityType,
    int? entityId,
    String? details,
    String? explicitUserId,
    String? explicitUserName,
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
    if (explicitUserId != null && explicitUserName != null) {
      userId = explicitUserId;
      userName = explicitUserName;
    } else if (AccessGuard.isSystemContext) {
      userId = 'system';
      userName = 'system';
    } else {
      final session = SessionManager.instance;
      if (session.isMultiUserEnabled) {
        if (session.isLocked || session.currentUser == null) {
          userId = 'unauthenticated';
          userName = 'unauthenticated';
        } else {
          userId = session.currentUser!.id;
          userName = session.currentUser!.displayName;
        }
      } else {
        final user = session.currentUser;
        if (user != null) {
          userId = user.id;
          userName = user.displayName;
        } else {
          userId = AccessDao.ownerUserId;
          userName = 'owner';
        }
      }
    }

    final now = DateTime.now().toIso8601String();

    // 3. Compute hash (includes userName for tamper protection - C10)
    final hash = await computeHash(
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: now,
      userId: userId,
      userName: userName,
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
  /// Uses cursor pagination with [pageSize] so memory remains bounded on large logs (D7).
  Future<AuditVerificationResult> verifyChain({
    DatabaseExecutor? db,
    int pageSize = 100,
    void Function(int verified, int total)? onProgress,
  }) async {
    final executor = db ?? await DatabaseHelper.instance.database;
    final countRow = await executor.rawQuery(
      'SELECT COUNT(*) as cnt FROM audit_log WHERE hash IS NOT NULL',
    );
    final totalCount = (countRow.first['cnt'] as num?)?.toInt() ?? 0;
    if (totalCount == 0) {
      return const AuditVerificationResult(isValid: true, verifiedCount: 0);
    }

    String expectedPrevHash = genesisHash;
    int verifiedCount = 0;
    int lastId = 0;

    while (true) {
      final rows = await executor.rawQuery('''
        SELECT id, action, entity_type, entity_id, details, timestamp,
               user_id, user_name, device_id, prev_hash, hash
        FROM audit_log
        WHERE hash IS NOT NULL AND id > ?
        ORDER BY id ASC
        LIMIT ?
      ''', [lastId, pageSize]);

      if (rows.isEmpty) break;

      for (final row in rows) {
        final id = (row['id'] as num).toInt();
        lastId = id;
        final action = (row['action'] as String?) ?? '';
        final entityType = row['entity_type'] as String?;
        final entityId = (row['entity_id'] as num?)?.toInt();
        final details = row['details'] as String?;
        final timestamp = (row['timestamp'] as String?) ?? '';
        final userId = (row['user_id'] as String?) ?? '';
        final userName = row['user_name'] as String?;
        final deviceId = (row['device_id'] as String?) ?? '';
        final prevHash = (row['prev_hash'] as String?) ?? '';
        final storedHash = (row['hash'] as String?) ?? '';

        if (action == 'audit_chain_genesis') {
          // Accept only the first audit_chain_genesis row. Treat any later one as tampering (C10)
          if (verifiedCount > 0) {
            return AuditVerificationResult(
              isValid: false,
              verifiedCount: verifiedCount,
              brokenAtId: id,
              error: 'Forged genesis anchor detected at row $id',
            );
          }
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

        // Try v2 hash with userName first (C10)
        final computedV2 = await computeHash(
          action: action,
          entityType: entityType,
          entityId: entityId,
          details: details,
          timestamp: timestamp,
          userId: userId,
          userName: userName,
          deviceId: deviceId,
          prevHash: prevHash,
        );

        bool hashValid = (storedHash == computedV2);
        if (!hashValid) {
          // Backward compatibility: try legacy v1 hash without userName
          final computedV1 = await computeHash(
            action: action,
            entityType: entityType,
            entityId: entityId,
            details: details,
            timestamp: timestamp,
            userId: userId,
            userName: null,
            deviceId: deviceId,
            prevHash: prevHash,
          );
          if (storedHash == computedV1) {
            hashValid = true;
          }
        }

        if (!hashValid) {
          return AuditVerificationResult(
            isValid: false,
            verifiedCount: verifiedCount,
            brokenAtId: id,
            error:
                'hash mismatch: stored was $storedHash at row $id',
          );
        }

        expectedPrevHash = storedHash;
        verifiedCount++;
        onProgress?.call(verifiedCount, totalCount);
      }
    }

    return AuditVerificationResult(
      isValid: true,
      verifiedCount: verifiedCount,
    );
  }
}
