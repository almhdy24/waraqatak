class StocktakeSession {
  static const String statusDraft = 'draft';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  final int? id;
  final String sessionNumber;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? notes;
  final String? categoryFilter;
  final int totalItems;
  final int matchedItems;
  final int discrepantItems;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StocktakeSession({
    this.id,
    required this.sessionNumber,
    this.status = statusInProgress,
    required this.startedAt,
    this.completedAt,
    this.notes,
    this.categoryFilter,
    this.totalItems = 0,
    this.matchedItems = 0,
    this.discrepantItems = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == statusCompleted;
  bool get isCancelled => status == statusCancelled;
  bool get isActive => status == statusInProgress || status == statusDraft;

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_number': sessionNumber,
        'status': status,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'notes': notes,
        'category_filter': categoryFilter,
        'total_items': totalItems,
        'matched_items': matchedItems,
        'discrepant_items': discrepantItems,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory StocktakeSession.fromMap(Map<String, dynamic> map) => StocktakeSession(
        id: map['id'] as int?,
        sessionNumber: map['session_number'] as String,
        status: map['status'] as String? ?? statusInProgress,
        startedAt: DateTime.parse(map['started_at'] as String),
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
        notes: map['notes'] as String?,
        categoryFilter: map['category_filter'] as String?,
        totalItems: (map['total_items'] as num?)?.toInt() ?? 0,
        matchedItems: (map['matched_items'] as num?)?.toInt() ?? 0,
        discrepantItems: (map['discrepant_items'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  StocktakeSession copyWith({
    int? id,
    String? sessionNumber,
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? notes,
    String? categoryFilter,
    int? totalItems,
    int? matchedItems,
    int? discrepantItems,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      StocktakeSession(
        id: id ?? this.id,
        sessionNumber: sessionNumber ?? this.sessionNumber,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        notes: notes ?? this.notes,
        categoryFilter: categoryFilter ?? this.categoryFilter,
        totalItems: totalItems ?? this.totalItems,
        matchedItems: matchedItems ?? this.matchedItems,
        discrepantItems: discrepantItems ?? this.discrepantItems,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class StocktakeItem {
  static const String statusPending = 'pending';
  static const String statusCounted = 'counted';
  static const String statusMatched = 'matched';
  static const String statusReconciled = 'reconciled';
  static const String statusSkipped = 'skipped';

  final int? id;
  final int sessionId;
  final int productId;
  final double baselineQuantity;
  final double? countedQuantity; // null = uncounted, 0.0 = physically counted zero
  final double? reconciledSystemQuantity;
  final double? variance;
  final double? unitCost;
  final String? notes;
  final String status;

  // Joined display attributes
  final String? productName;
  final String? productUnit;
  final String? productBarcode;
  final String? productCode;
  final String? productCategory;

  const StocktakeItem({
    this.id,
    required this.sessionId,
    required this.productId,
    required this.baselineQuantity,
    this.countedQuantity,
    this.reconciledSystemQuantity,
    this.variance,
    this.unitCost,
    this.notes,
    this.status = statusPending,
    this.productName,
    this.productUnit,
    this.productBarcode,
    this.productCode,
    this.productCategory,
  });

  bool get isCounted => countedQuantity != null;
  double get currentVariance =>
      isCounted ? (countedQuantity! - baselineQuantity) : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'product_id': productId,
        'baseline_quantity': baselineQuantity,
        'counted_quantity': countedQuantity,
        'reconciled_system_quantity': reconciledSystemQuantity,
        'variance': variance,
        'unit_cost': unitCost,
        'notes': notes,
        'status': status,
      };

  factory StocktakeItem.fromMap(Map<String, dynamic> map) => StocktakeItem(
        id: map['id'] as int?,
        sessionId: map['session_id'] as int,
        productId: map['product_id'] as int,
        baselineQuantity: (map['baseline_quantity'] as num).toDouble(),
        countedQuantity: (map['counted_quantity'] as num?)?.toDouble(),
        reconciledSystemQuantity:
            (map['reconciled_system_quantity'] as num?)?.toDouble(),
        variance: (map['variance'] as num?)?.toDouble(),
        unitCost: (map['unit_cost'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
        status: map['status'] as String? ?? statusPending,
        productName: map['product_name'] as String?,
        productUnit: map['product_unit'] as String?,
        productBarcode: map['product_barcode'] as String?,
        productCode: map['product_code'] as String?,
        productCategory: map['product_category'] as String?,
      );

  StocktakeItem copyWith({
    int? id,
    int? sessionId,
    int? productId,
    double? baselineQuantity,
    double? countedQuantity,
    double? reconciledSystemQuantity,
    double? variance,
    double? unitCost,
    String? notes,
    String? status,
    String? productName,
    String? productUnit,
    String? productBarcode,
    String? productCode,
    String? productCategory,
  }) =>
      StocktakeItem(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        productId: productId ?? this.productId,
        baselineQuantity: baselineQuantity ?? this.baselineQuantity,
        countedQuantity: countedQuantity ?? this.countedQuantity,
        reconciledSystemQuantity:
            reconciledSystemQuantity ?? this.reconciledSystemQuantity,
        variance: variance ?? this.variance,
        unitCost: unitCost ?? this.unitCost,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        productName: productName ?? this.productName,
        productUnit: productUnit ?? this.productUnit,
        productBarcode: productBarcode ?? this.productBarcode,
        productCode: productCode ?? this.productCode,
        productCategory: productCategory ?? this.productCategory,
      );
}
