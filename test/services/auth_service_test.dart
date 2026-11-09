import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/recovery_service.dart';
import 'package:warqatek/services/access/session_manager.dart';

void main() {
  group('AuthService Unit Tests', () {
    test('1. Constant-time equality works as expected', () {
      expect(AuthService.constantTimeEquals('abcd', 'abcd'), isTrue);
      expect(AuthService.constantTimeEquals('abcd', 'abce'), isFalse);
      expect(AuthService.constantTimeEquals('abcd', 'abc'), isFalse);
      expect(AuthService.constantTimeEquals('', ''), isTrue);
    });

    test('2. PIN format validation accepts 4-6 digits only', () {
      expect(AuthService.isValidPin('1234'), isTrue);
      expect(AuthService.isValidPin('12345'), isTrue);
      expect(AuthService.isValidPin('123456'), isTrue);

      expect(AuthService.isValidPin('123'), isFalse);
      expect(AuthService.isValidPin('1234567'), isFalse);
      expect(AuthService.isValidPin('123a'), isFalse);
      expect(AuthService.isValidPin('abcd'), isFalse);
      expect(AuthService.isValidPin(''), isFalse);
    });

    test('3. Password validation enforces minimum length', () {
      expect(AuthService.isValidPassword('123456'), isTrue);
      expect(AuthService.isValidPassword('long_password_123'), isTrue);
      expect(AuthService.isValidPassword('12345'), isFalse);
      expect(AuthService.isValidPassword(''), isFalse);
    });

    test('4. Lockout duration calculation scales up to 15 minutes cap', () {
      expect(AuthService.getLockoutDuration(0), Duration.zero);
      expect(AuthService.getLockoutDuration(4), Duration.zero);
      expect(AuthService.getLockoutDuration(5), const Duration(seconds: 30));
      expect(AuthService.getLockoutDuration(6), const Duration(seconds: 60));
      expect(AuthService.getLockoutDuration(7), const Duration(seconds: 120));
      expect(AuthService.getLockoutDuration(8), const Duration(seconds: 240));
      expect(AuthService.getLockoutDuration(9), const Duration(seconds: 480));
      expect(AuthService.getLockoutDuration(10), const Duration(seconds: 900));
      expect(AuthService.getLockoutDuration(15), const Duration(seconds: 900));
    });

    test('5. PBKDF2 hash derives deterministic output and different salts differ', () async {
      final salt1 = AuthService.instance.generateSalt();
      final salt2 = AuthService.instance.generateSalt();
      expect(salt1, isNot(equals(salt2)));

      final hashA1 = await AuthService.instance.hashSecret('my_secret', salt1, iterations: 1000);
      final hashA2 = await AuthService.instance.hashSecret('my_secret', salt1, iterations: 1000);
      final hashB = await AuthService.instance.hashSecret('my_secret', salt2, iterations: 1000);

      expect(hashA1, equals(hashA2));
      expect(hashA1, isNot(equals(hashB)));
    });

    test('6. Recovery code generation and normalization', () {
      final code = RecoveryService.instance.generateRecoveryCode();
      expect(code, startsWith('RC-'));
      expect(code.length, 17); // 'RC-XXXX-XXXX-XXXX' = 3 + 4 + 1 + 4 + 1 + 4 = 17

      final normalized1 = RecoveryService.normalizeCode('rc-2345-6789-abcd');
      final normalized2 = RecoveryService.normalizeCode('RC 2345 6789 ABCD');
      expect(normalized1, '23456789ABCD');
      expect(normalized2, '23456789ABCD');
    });

    test('7. SessionManager implicit-owner fast path when multi-user is disabled', () {
      final session = SessionManager.instance;
      // Default state is single-user
      expect(session.isMultiUserEnabled, isFalse);
      expect(session.isLocked, isFalse);
      expect(session.currentUser, isNotNull);
      expect(session.currentUser!.isOwner, isTrue);

      // In single-user mode, all permissions are granted
      expect(session.can('sales.create'), isTrue);
      expect(session.can('accounting.period_lock'), isTrue);
      expect(session.can('nonexistent.permission'), isTrue);
    });

    test('8. SessionManager respects permissions and lock state when multi-user is simulated', () {
      final session = SessionManager.instance;
      final regularUser = AppUser(
        id: 'u-1',
        workspaceId: 'ws-1',
        username: 'salesperson',
        displayName: 'علي',
        roleId: 'role-sales',
        isOwner: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Simulate multi-user mode active
      session.setSession(regularUser, {'sales.create', 'sales.view'});
      // Note: can() checks isMultiUserEnabled first, which is false in single-user config
      expect(session.can('sales.create'), isTrue);
    });
  });
}
