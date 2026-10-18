/// Represents a sanitized, first-party diagnostic error report.
///
/// Contains NO PII, NO customer names, NO financial amounts, NO invoice data.
class DiagnosticReport {
  final int? id;
  final String reportUuid;
  final String appVersion;
  final String platform;
  final String osVersion;
  final String exceptionType;
  final String? sanitizedMessage;
  final String? sanitizedStackTrace;
  final String operation;
  final DateTime occurredAt;
  final DateTime createdAt;
  final int retryCount;

  const DiagnosticReport({
    this.id,
    required this.reportUuid,
    required this.appVersion,
    required this.platform,
    required this.osVersion,
    required this.exceptionType,
    this.sanitizedMessage,
    this.sanitizedStackTrace,
    required this.operation,
    required this.occurredAt,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toDbMap() {
    return {
      if (id != null) 'id': id,
      'report_uuid': reportUuid,
      'app_version': appVersion,
      'platform': platform,
      'os_version': osVersion,
      'exception_type': exceptionType,
      'sanitized_message': sanitizedMessage,
      'sanitized_stack_trace': sanitizedStackTrace,
      'operation': operation,
      'occurred_at': occurredAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory DiagnosticReport.fromDb(Map<String, dynamic> map) {
    return DiagnosticReport(
      id: map['id'] as int?,
      reportUuid: map['report_uuid'] as String,
      appVersion: map['app_version'] as String,
      platform: map['platform'] as String,
      osVersion: map['os_version'] as String,
      exceptionType: map['exception_type'] as String,
      sanitizedMessage: map['sanitized_message'] as String?,
      sanitizedStackTrace: map['sanitized_stack_trace'] as String?,
      operation: map['operation'] as String,
      occurredAt: DateTime.parse(map['occurred_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Converts to the strict public API JSON payload schema.
  Map<String, dynamic> toApiPayload() {
    return {
      'report_uuid': reportUuid,
      'app_version': appVersion,
      'platform': platform,
      'os_version': osVersion,
      'exception_type': exceptionType,
      if (sanitizedMessage != null && sanitizedMessage!.isNotEmpty)
        'sanitized_message': sanitizedMessage,
      if (sanitizedStackTrace != null && sanitizedStackTrace!.isNotEmpty)
        'sanitized_stack_trace': sanitizedStackTrace,
      'operation': operation,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
    };
  }

  @override
  String toString() =>
      'DiagnosticReport($reportUuid, $exceptionType, $operation, $occurredAt)';
}
