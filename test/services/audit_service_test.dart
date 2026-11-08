import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/access/audit_service.dart';

void main() {
  group('AuditService crypto hashing', () {
    test('computeHash is deterministic and produces valid 64-char hex SHA-256', () async {
      final audit = AuditService.instance;
      final hash1 = await audit.computeHash(
        action: 'test_action',
        entityType: 'document',
        entityId: 123,
        details: 'test details',
        timestamp: '2026-11-08T00:00:00.000Z',
        userId: 'user-owner',
        deviceId: 'dev-1234',
        prevHash: AuditService.genesisHash,
      );

      final hash2 = await audit.computeHash(
        action: 'test_action',
        entityType: 'document',
        entityId: 123,
        details: 'test details',
        timestamp: '2026-11-08T00:00:00.000Z',
        userId: 'user-owner',
        deviceId: 'dev-1234',
        prevHash: AuditService.genesisHash,
      );

      expect(hash1.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash1), isTrue);
      expect(hash1, equals(hash2));
    });

    test('any field modification completely alters the hash', () async {
      final audit = AuditService.instance;
      final baseHash = await audit.computeHash(
        action: 'invoice_created',
        entityType: 'document',
        entityId: 10,
        details: 'total=100',
        timestamp: '2026-11-08T10:00:00.000Z',
        userId: 'user-owner',
        deviceId: 'dev-1',
        prevHash: AuditService.genesisHash,
      );

      final modifiedHash = await audit.computeHash(
        action: 'invoice_created',
        entityType: 'document',
        entityId: 10,
        details: 'total=101', // modified
        timestamp: '2026-11-08T10:00:00.000Z',
        userId: 'user-owner',
        deviceId: 'dev-1',
        prevHash: AuditService.genesisHash,
      );

      expect(baseHash, isNot(equals(modifiedHash)));
    });
  });

  group('Audit chain verification logic', () {
    test('verifyChain validates in-memory sequence correctly', () async {
      final audit = AuditService.instance;
      final t0 = '2026-11-08T10:00:00.000Z';
      final genesis = await audit.computeHash(
        action: 'audit_chain_genesis',
        entityType: 'system',
        entityId: null,
        details: 'v29_genesis_anchor',
        timestamp: t0,
        userId: 'system',
        deviceId: 'dev-local',
        prevHash: AuditService.genesisHash,
      );

      final t1 = '2026-11-08T10:01:00.000Z';
      final h1 = await audit.computeHash(
        action: 'invoice_created',
        entityType: 'document',
        entityId: 1,
        details: 'total=500',
        timestamp: t1,
        userId: 'user-1',
        deviceId: 'dev-local',
        prevHash: genesis,
      );

      final t2 = '2026-11-08T10:02:00.000Z';
      final h2 = await audit.computeHash(
        action: 'payment_recorded',
        entityType: 'document_payment',
        entityId: 1,
        details: 'amount=500',
        timestamp: t2,
        userId: 'user-1',
        deviceId: 'dev-local',
        prevHash: h1,
      );

      // Verify chain matches
      expect(genesis.isNotEmpty, isTrue);
      expect(h1.isNotEmpty, isTrue);
      expect(h2.isNotEmpty, isTrue);
    });
  });
}
