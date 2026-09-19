class ElmahdiPayConfig {
  final String baseUrl;
  final Duration timeout;
  final Map<String, String> defaultHeaders;

  ElmahdiPayConfig({
    required String baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.defaultHeaders = const {},
  }) : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  String get apiBase => '$baseUrl/api/v1';
}
