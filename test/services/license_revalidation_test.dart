import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/subscription_service.dart';

void main() {
  LicenseRevalidationOutcome classify(Object e) =>
      SubscriptionService.classifyRevalidationError(e);

  group('SubscriptionService.classifyRevalidationError', () {
    test('unknown key (404) revokes', () {
      expect(classify(const ElmahdiPayNotFoundException()),
          LicenseRevalidationOutcome.revoked);
    });

    test('403 revoked revokes', () {
      expect(
          classify(const ElmahdiPayForbiddenException(
              message: 'License has been revoked')),
          LicenseRevalidationOutcome.revoked);
    });

    test('403 expired marks expired', () {
      expect(
          classify(const ElmahdiPayForbiddenException(
              message: 'License has expired')),
          LicenseRevalidationOutcome.expired);
    });

    test('403 device limit keeps the license', () {
      expect(
          classify(const ElmahdiPayForbiddenException(
              message: 'Device limit reached',
              maxDevices: 1,
              activeDevices: 1)),
          LicenseRevalidationOutcome.keep);
    });

    test('network errors keep the license (offline-first)', () {
      expect(classify(const ElmahdiPayNetworkException('Network error')),
          LicenseRevalidationOutcome.keep);
    });

    test('rate limit, conflict and server errors keep the license', () {
      expect(classify(const ElmahdiPayRateLimitException()),
          LicenseRevalidationOutcome.keep);
      expect(classify(const ElmahdiPayAlreadyActivatedException()),
          LicenseRevalidationOutcome.keep);
      expect(
          classify(const ElmahdiPayApiException(
              statusCode: 500, message: 'Server error')),
          LicenseRevalidationOutcome.keep);
      expect(classify(Exception('anything')), LicenseRevalidationOutcome.keep);
    });
  });
}
