sealed class ElmahdiPayException implements Exception {
  final String message;
  const ElmahdiPayException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class ElmahdiPayNetworkException extends ElmahdiPayException {
  final Object? cause;
  const ElmahdiPayNetworkException(super.message, {this.cause});
}

class ElmahdiPayApiException extends ElmahdiPayException {
  final int statusCode;
  final Map<String, dynamic>? errors;

  const ElmahdiPayApiException({
    required this.statusCode,
    required String message,
    this.errors,
  }) : super(message);
}

class ElmahdiPayUnauthorizedException extends ElmahdiPayApiException {
  const ElmahdiPayUnauthorizedException({String message = 'Unauthorized'})
      : super(statusCode: 401, message: message);
}

/// Thrown for 403 responses — license revoked, expired, or device limit reached.
///
/// When the device limit is hit, [maxDevices] and [activeDevices] are populated.
class ElmahdiPayForbiddenException extends ElmahdiPayApiException {
  final int? maxDevices;
  final int? activeDevices;

  const ElmahdiPayForbiddenException({
    required String message,
    this.maxDevices,
    this.activeDevices,
  }) : super(statusCode: 403, message: message);
}

class ElmahdiPayNotFoundException extends ElmahdiPayApiException {
  const ElmahdiPayNotFoundException({String message = 'Not found'})
      : super(statusCode: 404, message: message);
}

class ElmahdiPayValidationException extends ElmahdiPayApiException {
  const ElmahdiPayValidationException({
    required String message,
    Map<String, dynamic>? errors,
  }) : super(statusCode: 422, message: message, errors: errors);
}

class ElmahdiPayRateLimitException extends ElmahdiPayApiException {
  const ElmahdiPayRateLimitException({
    String message = 'Rate limit exceeded — try again later',
  }) : super(statusCode: 429, message: message);
}
