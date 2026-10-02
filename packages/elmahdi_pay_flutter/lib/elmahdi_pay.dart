/// Elmahdi Pay Flutter SDK — activation-only.
///
/// ```dart
/// final client = ElmahdiPayClient(
///   ElmahdiPayConfig(baseUrl: 'https://your-server.com'),
/// );
/// await client.public.activateLicense(
///   ActivateLicenseRequest(licenseKey: key, machineId: machineId),
/// );
/// ```
library elmahdi_pay;

export 'src/client.dart';
export 'src/exceptions.dart';
export 'src/models/models.dart';
