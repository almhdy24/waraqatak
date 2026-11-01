enum DiagnosticSeverity { error, warning, info }

enum DiagnosticCategory {
  orphanedRecord,
  stockDiscrepancy,
  negativeStock,
  missingOpeningStock,
  inventoryCosting,
  documentBalanceMismatch,
  documentStatusMismatch,
  paymentMismatch,
  duplicateDocumentNumber,
  accountingReconciliation,
}

/// A structured diagnostic finding identified during read-only database integrity checks.
class DiagnosticFinding {
  /// Machine-readable code identifying the rule (e.g. 'orphaned_document_items').
  final String code;

  /// High-level diagnostic category.
  final DiagnosticCategory category;

  /// Severity level of the finding.
  final DiagnosticSeverity severity;

  /// Entity table name or domain type (e.g. 'documents', 'products', 'stock_movements').
  final String entityType;

  /// List of primary key IDs affected by this finding.
  final List<int> affectedIds;

  /// Brief human-readable title.
  final String title;

  /// Detailed explanation of the discrepancy and why it occurred or was flagged.
  final String explanation;

  /// Whether resolving or interpreting this finding requires business/human judgment,
  /// or if it represents an unambiguous mechanical corruption.
  final bool requiresManualReview;

  /// Diagnostic metadata with contextual values (e.g. expected vs actual amounts).
  final Map<String, dynamic>? metadata;

  const DiagnosticFinding({
    required this.code,
    required this.category,
    required this.severity,
    required this.entityType,
    required this.affectedIds,
    required this.title,
    required this.explanation,
    required this.requiresManualReview,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'category': category.name,
    'severity': severity.name,
    'entity_type': entityType,
    'affected_ids': affectedIds,
    'title': title,
    'explanation': explanation,
    'requires_manual_review': requiresManualReview,
    if (metadata != null) 'metadata': metadata,
  };

  @override
  String toString() =>
      '[$severity][$code] $title (affected: $affectedIds, manualReview: $requiresManualReview)';
}

/// Aggregated report of database diagnostic checks.
class DatabaseDiagnosticReport {
  final DateTime executedAt;
  final int totalChecksRun;
  final List<DiagnosticFinding> findings;

  const DatabaseDiagnosticReport({
    required this.executedAt,
    required this.totalChecksRun,
    required this.findings,
  });

  bool get isClean => findings.isEmpty;

  int get errorCount =>
      findings.where((f) => f.severity == DiagnosticSeverity.error).length;

  int get warningCount =>
      findings.where((f) => f.severity == DiagnosticSeverity.warning).length;

  int get infoCount =>
      findings.where((f) => f.severity == DiagnosticSeverity.info).length;

  int get manualReviewCount =>
      findings.where((f) => f.requiresManualReview).length;

  Map<String, dynamic> toMap() => {
    'executed_at': executedAt.toIso8601String(),
    'total_checks_run': totalChecksRun,
    'is_clean': isClean,
    'error_count': errorCount,
    'warning_count': warningCount,
    'info_count': infoCount,
    'manual_review_count': manualReviewCount,
    'findings': findings.map((f) => f.toMap()).toList(),
  };
}
