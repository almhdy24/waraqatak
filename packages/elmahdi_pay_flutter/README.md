# elmahdi_pay_flutter

Thin Flutter/Dart **buyer-side** client SDK for the Elmahdi Pay API.  
Covers only the four public endpoints a Flutter app needs: payment methods, exchange rate, order submission (with optional proof upload), order status polling, and license activation.

---

## Installation

```yaml
# pubspec.yaml
dependencies:
  elmahdi_pay_flutter:
    path: ../elmahdi_pay_flutter  # or git/pub when published
```

Single dependency: `package:http`.

---

## Quick start

```dart
import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';

final client = ElmahdiPayClient(
  ElmahdiPayConfig(baseUrl: 'https://your-server.com'),
);

// Always close when the widget/service is disposed.
client.close();
```

---

## Configuration

| Option | Type | Default | Description |
|---|---|---|---|
| `baseUrl` | `String` | required | Your server root URL (trailing slash stripped automatically) |
| `timeout` | `Duration` | 30 s | Per-request timeout |
| `defaultHeaders` | `Map<String,String>` | `{}` | Extra headers merged into every request |

---

## API reference

All methods are on `client.public`.

### List payment methods

```dart
final methods = await client.public.getPaymentMethods();
// → List<PaymentMethod>
// Shows buyer the available bank/cash options to choose from.
```

### Exchange rate

```dart
final settings = await client.public.getSettings();
// settings.usdToSdgRate → double? (null if not configured server-side)
```

### Create an order

```dart
// Generate the key BEFORE the call and persist it locally for retries.
final idempotencyKey = ElmahdiPayClient.generateIdempotencyKey();

// Without proof file — sends JSON:
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

print(result.reference);  // "ORD-XXXXXXXX"
print(result.idempotent); // true if server returned a cached match

// With proof file — multipart is chosen automatically:
final bytes = await File('receipt.jpg').readAsBytes();
await client.public.createOrder(CreateOrderRequest(
  // ... same required fields ...
  proofFileBytes: bytes,
  proofFileName: 'receipt.jpg',
  // Accepted MIME types: image/jpeg, image/png, image/webp, image/gif, application/pdf
  // Max size: 10 MB — validated server-side from file content, not extension.
));
```

> **Rate limit:** 5 orders / hour per IP. Throws `ElmahdiPayRateLimitException` when exceeded.

### Poll order status

```dart
final order = await client.public.getOrder('ORD-ABC12345');

switch (order.status) {
  case OrderStatus.approved:
    final key = order.license!.licenseKey; // RSA-signed, pass to activateLicense
    print('Approved — license: $key');
  case OrderStatus.rejected:
    print('Rejected: ${order.adminNote}');
  case OrderStatus.pending:
    print('Still pending.');
}
```

> Throws `ElmahdiPayNotFoundException` if the reference does not exist.

### Activate a license

```dart
try {
  final result = await client.public.activateLicense(
    ActivateLicenseRequest(
      licenseKey: order.license!.licenseKey,
      deviceId: 'stable-unique-device-id', // e.g. from device_info_plus
      deviceLabel: 'Samsung Galaxy S25',   // optional, shown in admin dashboard
    ),
  );

  if (result.reactivated) {
    // Same device — last_seen_at was updated. No need to re-store anything.
  } else {
    print('Activated on this device: activation #${result.activation.id}');
  }
} on ElmahdiPayForbiddenException catch (e) {
  if (e.maxDevices != null) {
    print('Limit: ${e.activeDevices}/${e.maxDevices} devices used.');
    // Prompt user to deactivate another device (admin action).
  } else {
    print('License revoked or expired.');
  }
}
```

Re-sending the same `deviceId` is **idempotent** — the server updates `last_seen_at` and returns `reactivated: true`. Safe to call on every app launch.

---

## Error handling

Every method throws a subtype of `ElmahdiPayException`:

| Exception | HTTP | Scenario |
|---|---|---|
| `ElmahdiPayNetworkException` | — | Timeout, no connection |
| `ElmahdiPayUnauthorizedException` | 401 | Server rejected credentials |
| `ElmahdiPayForbiddenException` | 403 | License revoked/expired/device limit |
| `ElmahdiPayNotFoundException` | 404 | Reference or license not found |
| `ElmahdiPayValidationException` | 422 | Invalid fields (`.errors` map has per-field detail) |
| `ElmahdiPayRateLimitException` | 429 | Too many requests from this IP |
| `ElmahdiPayApiException` | any | Other server error (`.statusCode` available) |

```dart
try {
  await client.public.createOrder(request);
} on ElmahdiPayValidationException catch (e) {
  // e.errors → {'buyer_name': 'is required', ...}
  showErrors(e.errors);
} on ElmahdiPayRateLimitException {
  showRetryMessage();
} on ElmahdiPayNetworkException {
  showOfflineMessage();
}
```

---

## Idempotency

Always generate the key **before** the network call and persist it locally (e.g. `SharedPreferences`). If the call fails mid-flight, retry with the **same key** — the server returns the original order instead of creating a duplicate.

```dart
// On order screen init:
String key = await prefs.getString('pending_order_key') ??
    ElmahdiPayClient.generateIdempotencyKey();
await prefs.setString('pending_order_key', key);

// On submit (and on any retry):
final result = await client.public.createOrder(
  CreateOrderRequest(..., idempotencyKey: key),
);

// On success, clear the persisted key:
await prefs.remove('pending_order_key');
```

---

## Models

| Model | Description |
|---|---|
| `Order` | Status response: reference, status, payment_method, license (if approved), admin_note (if rejected) |
| `License` | RSA-signed license included in an approved order |
| `LicenseActivation` | Per-device activation record |
| `ActivateLicenseResult` | Wraps `LicenseActivation` + `reactivated` flag |
| `CreateOrderRequest` | Input for `createOrder` |
| `CreateOrderResult` | Output of `createOrder`: reference, status, idempotent flag |
| `PaymentMethod` | id, name, currency, instructions |
| `PaySettings` | `usdToSdgRate` |

Enums: `OrderStatus` (pending/approved/rejected), `LicenseStatus` (active/revoked), `ActivationStatus` (active/deactivated).

---

## Running tests

```bash
cd elmahdi_pay_flutter
dart pub get
dart test
```

Tests use `package:http/testing.dart` — no additional mock libraries required.

---

## Running the example

```bash
cd example
dart pub get
# edit lib/main.dart — set baseUrl to your server
dart run lib/main.dart
```
