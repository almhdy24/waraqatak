/// Model representing an in-app announcement / operational notification.
class AppNotification {
  final int? id;
  final int serverId;
  final String title;
  final String body;
  final String category;
  final String? actionUrl;
  final String? targetAudience;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final bool isRead;
  final DateTime? readAt;
  final DateTime syncedAt;
  final bool dismissible;

  const AppNotification({
    this.id,
    required this.serverId,
    required this.title,
    required this.body,
    required this.category,
    this.actionUrl,
    this.targetAudience,
    required this.publishedAt,
    this.expiresAt,
    this.isRead = false,
    this.readAt,
    required this.syncedAt,
    this.dismissible = true,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  /// Whether this notification can be dismissed / deleted by the user.
  /// Critical alerts are strictly non-dismissible.
  bool get isDismissible => dismissible && category != 'critical';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawDismissible = json['dismissible'];
    final isDismissible = rawDismissible is bool
        ? rawDismissible
        : (rawDismissible == 1 || rawDismissible == null);

    return AppNotification(
      serverId: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? 'announcement',
      actionUrl: json['action_url'] as String? ?? json['action'] as String?,
      targetAudience: json['target_audience'] as String?,
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      isRead: json['is_read'] == true,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      syncedAt: DateTime.now(),
      dismissible: isDismissible,
    );
  }

  factory AppNotification.fromDb(Map<String, dynamic> map) {
    final cat = map['category'] as String? ?? 'announcement';
    return AppNotification(
      id: map['id'] as int?,
      serverId: map['server_id'] as int,
      title: map['title'] as String,
      body: map['body'] as String,
      category: cat,
      actionUrl: map['action_url'] as String?,
      targetAudience: map['target_audience'] as String?,
      publishedAt:
          DateTime.tryParse(map['published_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'] as String)
          : null,
      isRead: (map['is_read'] as int? ?? 0) == 1,
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'] as String)
          : null,
      syncedAt:
          DateTime.tryParse(map['synced_at'] as String? ?? '') ??
          DateTime.now(),
      dismissible: cat != 'critical',
    );
  }

  Map<String, dynamic> toDbMap() {
    final map = <String, dynamic>{
      'server_id': serverId,
      'title': title,
      'body': body,
      'category': category,
      'action_url': actionUrl,
      'target_audience': targetAudience,
      'published_at': publishedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'read_at': readAt?.toIso8601String(),
      'synced_at': syncedAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  AppNotification copyWith({
    int? id,
    int? serverId,
    String? title,
    String? body,
    String? category,
    String? actionUrl,
    String? targetAudience,
    DateTime? publishedAt,
    DateTime? expiresAt,
    bool? isRead,
    DateTime? readAt,
    DateTime? syncedAt,
    bool? dismissible,
  }) {
    return AppNotification(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      actionUrl: actionUrl ?? this.actionUrl,
      targetAudience: targetAudience ?? this.targetAudience,
      publishedAt: publishedAt ?? this.publishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      syncedAt: syncedAt ?? this.syncedAt,
      dismissible: dismissible ?? this.dismissible,
    );
  }
}
