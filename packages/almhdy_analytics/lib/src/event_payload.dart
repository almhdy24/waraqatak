import 'dart:convert';

/// Data representation of a single AlmHdy Analytics event.
class AlmHdyEvent {
  final String? eventId;
  final String event;
  final String platform;
  final String? platformVersion;
  final String appVersion;
  final String? deviceModel;
  final String? country;
  final String? region;
  final String installationId;
  final String? sessionId;
  final String? userPseudoId;
  final Map<String, dynamic> properties;
  final String timestamp;

  AlmHdyEvent({
    this.eventId,
    required this.event,
    required this.platform,
    this.platformVersion,
    required this.appVersion,
    this.deviceModel,
    this.country,
    this.region,
    required this.installationId,
    this.sessionId,
    this.userPseudoId,
    Map<String, dynamic>? properties,
    String? timestamp,
  })  : properties =
            properties != null ? Map<String, dynamic>.from(properties) : {},
        timestamp = timestamp ?? DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() {
    return {
      if (eventId != null) 'event_id': eventId,
      'event': event,
      'platform': platform,
      if (platformVersion != null) 'platform_version': platformVersion,
      'app_version': appVersion,
      if (deviceModel != null) 'device_model': deviceModel,
      if (country != null) 'country': country,
      if (region != null) 'region': region,
      'installation_id': installationId,
      if (sessionId != null) 'session_id': sessionId,
      if (userPseudoId != null) 'user_pseudo_id': userPseudoId,
      'properties': properties,
      'timestamp': timestamp,
    };
  }

  factory AlmHdyEvent.fromJson(Map<String, dynamic> map) {
    return AlmHdyEvent(
      eventId: map['event_id'] as String?,
      event: map['event'] as String? ?? 'unknown',
      platform: map['platform'] as String? ?? 'unknown',
      platformVersion: map['platform_version'] as String?,
      appVersion: map['app_version'] as String? ?? '1.0.0',
      deviceModel: map['device_model'] as String?,
      country: map['country'] as String?,
      region: map['region'] as String?,
      installationId: map['installation_id'] as String? ?? 'unknown',
      sessionId: map['session_id'] as String?,
      userPseudoId: map['user_pseudo_id'] as String?,
      properties: map['properties'] is Map
          ? Map<String, dynamic>.from(map['properties'] as Map)
          : {},
      timestamp: map['timestamp'] as String?,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
