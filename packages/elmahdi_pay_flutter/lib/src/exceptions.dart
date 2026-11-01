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
  final String? correlationId;

  const ElmahdiPayApiException({
    required this.statusCode,
    required String message,
    this.errors,
    this.correlationId,
  }) : super(message);
}

class ElmahdiPayUnauthorizedException extends ElmahdiPayApiException {
  final String? errorCode;

  const ElmahdiPayUnauthorizedException({
    super.message = 'Unauthorized',
    this.errorCode,
    Map<String, dynamic>? rawBody,
    super.correlationId,
  }) : super(
          statusCode: 401,
          errors: rawBody,
        );
}

/// Thrown for 403 responses — license revoked, expired, or device limit reached.
///
/// When the device limit is hit, [maxDevices] and [activeDevices] are populated.
class ElmahdiPayForbiddenException extends ElmahdiPayApiException {
  final int? maxDevices;
  final int? activeDevices;

  const ElmahdiPayForbiddenException({
    required super.message,
    this.maxDevices,
    this.activeDevices,
    super.correlationId,
  }) : super(
          statusCode: 403,
        );
}

class ElmahdiPayNotFoundException extends ElmahdiPayApiException {
  const ElmahdiPayNotFoundException({
    super.message = 'Not found',
    super.correlationId,
  }) : super(
          statusCode: 404,
        );
}

class ElmahdiPayValidationException extends ElmahdiPayApiException {
  const ElmahdiPayValidationException({
    required super.message,
    super.errors,
    super.correlationId,
  }) : super(
          statusCode: 422,
        );
}

/// Thrown for 409 responses — license already activated on another device.
class ElmahdiPayAlreadyActivatedException extends ElmahdiPayApiException {
  const ElmahdiPayAlreadyActivatedException({
    super.message = 'License already activated on another device',
    super.correlationId,
  }) : super(
          statusCode: 409,
        );
}

class ElmahdiPayRateLimitException extends ElmahdiPayApiException {
  const ElmahdiPayRateLimitException({
    super.message = 'Rate limit exceeded — try again later',
    super.correlationId,
  }) : super(
          statusCode: 429,
        );
}
