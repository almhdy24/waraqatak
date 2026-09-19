/// Buyer-side integration example: list payment methods → create order → poll status → activate license.
/// Run with: dart run example/lib/main.dart
library;

import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';

Future<void> main() async {
  final client = ElmahdiPayClient(
    ElmahdiPayConfig(
      baseUrl: 'https://your-server.com', // ← replace with your server URL
      timeout: const Duration(seconds: 20),
    ),
  );

  try {
    await _orderFlow(client);
    await _licenseActivationFlow(client);
  } finally {
    client.close();
  }
}

// ── 1. Submit an order ────────────────────────────────────────────────────────

Future<void> _orderFlow(ElmahdiPayClient client) async {
  print('\n=== Order flow ===');

  // Fetch active payment methods to display in your UI.
  final methods = await client.public.getPaymentMethods();
  print('Available methods: ${methods.map((m) => '${m.name} (${m.currency})').join(', ')}');

  // Optionally show the current exchange rate.
  final settings = await client.public.getSettings();
  if (settings.usdToSdgRate != null) {
    print('1 USD = ${settings.usdToSdgRate} SDG');
  }

  if (methods.isEmpty) {
    print('No payment methods — skipping.');
    return;
  }

  // Generate the idempotency key BEFORE the network call and persist it locally
  // (e.g. SharedPreferences). Reuse the same key on retry.
  final idempotencyKey = ElmahdiPayClient.generateIdempotencyKey();

  // Submit order without proof file (JSON body):
  final result = await client.public.createOrder(CreateOrderRequest(
    appSlug: 'com.example.myapp',
    paymentMethodId: methods.first.id,
    buyerName: 'Ali Hassan',
    buyerContact: 'ali@example.com',
    amount: 25.00,
    currency: 'USD',
    proofNote: 'Transferred via Faisal Islamic Bank',
    idempotencyKey: idempotencyKey,
  ));

  print('Order: ${result.reference} '
      '(status=${result.status}, idempotent=${result.idempotent})');

  // To include a payment proof image, pass proofFileBytes + proofFileName.
  // The SDK switches to multipart automatically:
  //
  //   final bytes = await File('receipt.jpg').readAsBytes();
  //   await client.public.createOrder(CreateOrderRequest(
  //     ...
  //     proofFileBytes: bytes,
  //     proofFileName: 'receipt.jpg',
  //   ));

  // Poll order status (in a real app: trigger on user tap / push notification).
  final order = await client.public.getOrder(result.reference);

  switch (order.status) {
    case OrderStatus.approved:
      print('Approved! License key: ${order.license?.licenseKey}');
    case OrderStatus.rejected:
      print('Rejected. Reason: ${order.adminNote}');
    case OrderStatus.pending:
      print('Pending admin review.');
  }
}

// ── 2. Activate a license on this device ─────────────────────────────────────

Future<void> _licenseActivationFlow(ElmahdiPayClient client) async {
  print('\n=== License activation ===');

  // Replace with the license_key from order.license.licenseKey after approval.
  const licenseKey = 'REPLACE_WITH_REAL_RSA_SIGNED_LICENSE_KEY';

  // Use a stable, unique device identifier (e.g. from device_info_plus package).
  const deviceId = 'unique-device-identifier';

  try {
    final result = await client.public.activateLicense(
      const ActivateLicenseRequest(
        licenseKey: licenseKey,
        deviceId: deviceId,
        deviceLabel: 'Samsung Galaxy S25',
      ),
    );

    if (result.reactivated) {
      print('Already activated on this device — last_seen_at updated.');
    } else {
      print('Activated! Activation ID: ${result.activation.id}');
    }
  } on ElmahdiPayForbiddenException catch (e) {
    if (e.maxDevices != null) {
      print('Device limit reached: ${e.activeDevices}/${e.maxDevices} active.');
    } else {
      print('Access denied: ${e.message}');
    }
  } on ElmahdiPayNotFoundException {
    print('License not found.');
  } on ElmahdiPayValidationException catch (e) {
    print('Invalid license key: ${e.message}');
  } on ElmahdiPayRateLimitException {
    print('Too many activation attempts — wait before retrying.');
  }
}
