import 'package:http/http.dart' as http;

import 'api/public_api.dart';
import 'config.dart';
import 'http_client.dart';

export 'api/public_api.dart';
export 'config.dart';

/// Activation-only client.
///
/// Call [ElmahdiPayClient.public.activateLicense] with a user-supplied
/// license key and a stable machine id to redeem the key against the
/// licensing server. No other endpoints are exposed.
class ElmahdiPayClient {
  final ElmahdiPayConfig config;

  late final PublicApi public;

  final HttpClient _http;

  ElmahdiPayClient(this.config, {http.Client? httpClient})
      : _http = HttpClient(config, client: httpClient) {
    public = PublicApi.create(_http);
  }

  /// Releases the underlying HTTP connection pool. Call in [dispose].
  void close() => _http.close();
}
