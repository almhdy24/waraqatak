enum OrderStatus {
  pending,
  approved,
  rejected;

  static OrderStatus fromString(String s) => switch (s) {
        'pending' => pending,
        'approved' => approved,
        'rejected' => rejected,
        _ => throw ArgumentError('Unknown OrderStatus: $s'),
      };

  @override
  String toString() => name;
}

enum LicenseStatus {
  active,
  revoked;

  static LicenseStatus fromString(String s) => switch (s) {
        'active' => active,
        'revoked' => revoked,
        _ => throw ArgumentError('Unknown LicenseStatus: $s'),
      };

  @override
  String toString() => name;
}

enum ActivationStatus {
  active,
  deactivated;

  static ActivationStatus fromString(String s) => switch (s) {
        'active' => active,
        'deactivated' => deactivated,
        _ => throw ArgumentError('Unknown ActivationStatus: $s'),
      };

  @override
  String toString() => name;
}
