/// Elmahdi Pay Flutter SDK — buyer-facing client.
///
/// Quick start:
/// ```dart
/// import 'package:elmahdi_pay_flutter/elmahdi_pay.dart';
///
/// final client = ElmahdiPayClient(ElmahdiPayConfig(baseUrl: 'https://your-server.com'));
/// final methods = await client.public.getPaymentMethods();
/// ```
library elmahdi_pay;

export 'src/client.dart';
export 'src/exceptions.dart';
export 'src/models/models.dart';
