/// Elmahdi Pay Flutter SDK.
///
/// Public API (no auth):
/// ```dart
/// final client = ElmahdiPayClient(ElmahdiPayConfig(baseUrl: 'https://your-server.com'));
/// final methods = await client.public.getPaymentMethods();
/// ```
///
/// Admin API (Bearer token required):
/// ```dart
/// final client = ElmahdiPayClient(ElmahdiPayConfig(
///   baseUrl: 'https://your-server.com',
///   adminToken: 'your-admin-token',
/// ));
/// final stats = await client.admin.getStats();
/// ```
library elmahdi_pay;

export 'src/client.dart';
export 'src/exceptions.dart';
export 'src/models/models.dart';
