import 'dart:convert';

enum SealType { stamp, signature }

enum SealPageRule { firstPage, lastPage, allPages }

/// Represents the physical uploaded image asset stored in local application storage.
class DigitalSealAsset {
  final String id;
  final int businessId;
  final SealType type;
  final String filename;
  final String format; // 'png' or 'jpeg'
  final int width;
  final int height;
  final int bytesLength;
  final DateTime createdAt;
  final bool isDeleted;

  const DigitalSealAsset({
    required this.id,
    required this.businessId,
    required this.type,
    required this.filename,
    required this.format,
    required this.width,
    required this.height,
    required this.bytesLength,
    required this.createdAt,
    this.isDeleted = false,
  });

  double get aspectRatio => (height > 0 && width > 0) ? width / height : 1.0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_id': businessId,
    'type': type.name,
    'filename': filename,
    'format': format,
    'width': width,
    'height': height,
    'bytes_length': bytesLength,
    'created_at': createdAt.toIso8601String(),
    'is_deleted': isDeleted ? 1 : 0,
  };

  factory DigitalSealAsset.fromMap(Map<String, dynamic> map) =>
      DigitalSealAsset(
        id: map['id'] as String,
        businessId: map['business_id'] as int,
        type: SealType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => SealType.stamp,
        ),
        filename: map['filename'] as String,
        format: (map['format'] as String?)?.toLowerCase() ?? 'png',
        width: (map['width'] as num?)?.toInt() ?? 100,
        height: (map['height'] as num?)?.toInt() ?? 100,
        bytesLength: (map['bytes_length'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );
}

/// Represents the active business-level configuration for a seal (stamp or signature).
class DigitalSealConfig {
  final SealType type;
  final String? assetId;
  final bool isEnabled;
  final double startRatio;
  final double topRatio;
  final double widthRatio;
  final double aspectRatio;
  final double opacity;
  final SealPageRule pageRule;

  const DigitalSealConfig({
    required this.type,
    this.assetId,
    this.isEnabled = false,
    this.startRatio = 0.55,
    this.topRatio = 0.82,
    this.widthRatio = 0.22,
    this.aspectRatio = 1.0,
    this.opacity = 0.85,
    this.pageRule = SealPageRule.lastPage,
  });

  bool get hasAsset => assetId != null && assetId!.isNotEmpty;

  DigitalSealConfig copyWith({
    SealType? type,
    String? assetId,
    bool? isEnabled,
    double? startRatio,
    double? topRatio,
    double? widthRatio,
    double? aspectRatio,
    double? opacity,
    SealPageRule? pageRule,
  }) => DigitalSealConfig(
    type: type ?? this.type,
    assetId: assetId ?? this.assetId,
    isEnabled: isEnabled ?? this.isEnabled,
    startRatio: startRatio ?? this.startRatio,
    topRatio: topRatio ?? this.topRatio,
    widthRatio: widthRatio ?? this.widthRatio,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    opacity: opacity ?? this.opacity,
    pageRule: pageRule ?? this.pageRule,
  );

  Map<String, dynamic> toMap() => {
    'seal_type': type.name,
    'asset_id': assetId,
    'is_enabled': isEnabled ? 1 : 0,
    'start_ratio': startRatio,
    'top_ratio': topRatio,
    'width_ratio': widthRatio,
    'aspect_ratio': aspectRatio,
    'opacity': opacity,
    'page_rule': pageRule.name,
  };

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'asset_id': assetId,
    'is_enabled': isEnabled,
    'start_ratio': startRatio,
    'top_ratio': topRatio,
    'width_ratio': widthRatio,
    'aspect_ratio': aspectRatio,
    'opacity': opacity,
    'page_rule': pageRule.name,
  };

  factory DigitalSealConfig.fromMap(
    Map<String, dynamic> map, [
    SealType fallbackType = SealType.stamp,
  ]) {
    final type = SealType.values.firstWhere(
      (e) => e.name == (map['seal_type'] ?? map['type']),
      orElse: () => fallbackType,
    );
    final pageRule = SealPageRule.values.firstWhere(
      (e) => e.name == map['page_rule'],
      orElse: () => SealPageRule.lastPage,
    );

    final rawOpacity =
        (map['opacity'] as num?)?.toDouble() ??
        (type == SealType.stamp ? 0.85 : 1.0);
    final rawWidth = (map['width_ratio'] as num?)?.toDouble() ?? 0.22;
    final rawStart =
        (map['start_ratio'] as num?)?.toDouble() ??
        (type == SealType.stamp ? 0.55 : 0.15);
    final rawTop = (map['top_ratio'] as num?)?.toDouble() ?? 0.82;
    final rawAspect = (map['aspect_ratio'] as num?)?.toDouble() ?? 1.0;

    return DigitalSealConfig(
      type: type,
      assetId: map['asset_id'] as String?,
      isEnabled: (map['is_enabled'] is bool)
          ? map['is_enabled'] as bool
          : (map['is_enabled'] as num? ?? 0) == 1,
      startRatio: rawStart.clamp(0.0, 1.0),
      topRatio: rawTop.clamp(0.0, 1.0),
      widthRatio: rawWidth.clamp(0.05, 0.60),
      aspectRatio: rawAspect > 0 ? rawAspect : 1.0,
      opacity: rawOpacity.clamp(0.1, 1.0),
      pageRule: pageRule,
    );
  }

  factory DigitalSealConfig.fromJson(
    Map<String, dynamic> json, [
    SealType fallbackType = SealType.stamp,
  ]) => DigitalSealConfig.fromMap(json, fallbackType);
}

/// Represents an immutable historical snapshot captured when a document is issued.
class DocumentSealSnapshot {
  final int? id;
  final int documentId;
  final int businessId;
  final DateTime issuedAt;
  final DigitalSealConfig? stamp;
  final DigitalSealConfig? signature;
  final String rawJson;

  const DocumentSealSnapshot({
    this.id,
    required this.documentId,
    required this.businessId,
    required this.issuedAt,
    this.stamp,
    this.signature,
    required this.rawJson,
  });

  bool get hasActiveSeals =>
      (stamp != null && stamp!.isEnabled && stamp!.hasAsset) ||
      (signature != null && signature!.isEnabled && signature!.hasAsset);

  static String serializeData({
    required int businessId,
    required DateTime issuedAt,
    DigitalSealConfig? stamp,
    DigitalSealConfig? signature,
  }) {
    return jsonEncode({
      'version': 1,
      'business_id': businessId,
      'issued_at': issuedAt.toIso8601String(),
      'stamp': stamp?.toJson(),
      'signature': signature?.toJson(),
    });
  }

  factory DocumentSealSnapshot.fromRow(Map<String, dynamic> row) {
    final raw = row['snapshot_data'] as String;
    DigitalSealConfig? stamp;
    DigitalSealConfig? sig;
    DateTime issuedAt = DateTime.now();
    int businessId = (row['business_id'] as num?)?.toInt() ?? 1;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        if (decoded['business_id'] is num) {
          businessId = (decoded['business_id'] as num).toInt();
        }
        if (decoded['issued_at'] is String) {
          issuedAt =
              DateTime.tryParse(decoded['issued_at'] as String) ?? issuedAt;
        }
        if (decoded['stamp'] is Map<String, dynamic>) {
          stamp = DigitalSealConfig.fromJson(
            decoded['stamp'] as Map<String, dynamic>,
            SealType.stamp,
          );
        }
        if (decoded['signature'] is Map<String, dynamic>) {
          sig = DigitalSealConfig.fromJson(
            decoded['signature'] as Map<String, dynamic>,
            SealType.signature,
          );
        }
      }
    } catch (_) {
      // Return safe empty snapshot on corrupt JSON
    }

    return DocumentSealSnapshot(
      id: row['id'] as int?,
      documentId: row['document_id'] as int,
      businessId: businessId,
      issuedAt: issuedAt,
      stamp: stamp,
      signature: sig,
      rawJson: raw,
    );
  }
}
