import 'enums.dart';

class License {
  final int id;
  final int orderId;
  final String appSlug;
  final String licenseKey;
  final LicenseStatus status;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final int maxDevices;
  final DateTime createdAt;

  const License({
    required this.id,
    required this.orderId,
    required this.appSlug,
    required this.licenseKey,
    required this.status,
    required this.issuedAt,
    this.expiresAt,
    required this.maxDevices,
    required this.createdAt,
  });

  factory License.fromJson(Map<String, dynamic> json) => License(
        id: json['id'] as int,
        orderId: json['order_id'] as int,
        appSlug: json['app_slug'] as String,
        licenseKey: json['license_key'] as String,
        status: LicenseStatus.fromString(json['status'] as String),
        issuedAt: _dt(json['issued_at'] as String),
        expiresAt: _dtOpt(json['expires_at'] as String?),
        maxDevices: json['max_devices'] as int,
        createdAt: _dt(json['created_at'] as String),
      );

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

DateTime _dt(String s) => DateTime.parse(s.replaceAll(' ', 'T'));
DateTime? _dtOpt(String? s) => s == null ? null : _dt(s);
