import 'dart:math';

import 'package:http/http.dart' as http;

import 'api/public_api.dart';
import 'config.dart';
import 'http_client.dart';

export 'api/public_api.dart';
export 'config.dart';

class ElmahdiPayClient {
  final ElmahdiPayConfig config;

  /// All buyer-facing API methods: payment methods, orders, license activation.
  late final PublicApi public;

  final HttpClient _http;

  ElmahdiPayClient(this.config, {http.Client? httpClient})
      : _http = HttpClient(config, client: httpClient) {
    public = PublicApi.create(_http);
  }

  /// Generates a cryptographically random 64-hex-char idempotency key.
  ///
  /// Generate once before submitting an order and persist it locally.
  /// Pass the same key on retry to guarantee the server returns the same order.
  static String generateIdempotencyKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Releases the underlying HTTP connection pool. Call in [dispose].
  void close() => _http.close();
}
